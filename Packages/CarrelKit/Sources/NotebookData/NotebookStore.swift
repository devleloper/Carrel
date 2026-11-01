import Foundation
import NotebookDomain

/// The result of loading a page's ink, including how it was obtained.
public enum InkLoadResult: Equatable, Sendable {
    /// The page has never been written to.
    case empty
    case ink(InkData)
    /// The current file was damaged or missing; this is the previous generation.
    case recovered(InkData)
    /// Neither generation could be read. Damaged files were copied to the recovery folder.
    case unrecoverable
    /// The ink was written by a newer PencilKit. The page stays read-only and its file is never rewritten.
    case requiresNewerSystem
}

public enum NotebookStoreError: Error, Equatable {
    case manifestUnreadable
    case schemaNewerThanApp
    case requiresNewerSystem
}

/// Owns one notebook package on disk and is its only writer.
public actor NotebookStore {
    public nonisolated let package: NotebookPackage
    public private(set) var manifest: NotebookManifest

    private let supportedContentVersion: Int
    private let recoveredDirectory: URL
    private var writtenInkHashes: [Page.ID: InkHash] = [:]
    private var readOnlyPages: Set<Page.ID> = []
    private var hasUnwrittenManifestChanges = false

    private init(package: NotebookPackage, manifest: NotebookManifest, supportedContentVersion: Int, recoveredDirectory: URL) {
        self.package = package
        self.manifest = manifest
        self.supportedContentVersion = supportedContentVersion
        self.recoveredDirectory = recoveredDirectory
    }

    public static func create(
        _ notebook: Notebook,
        firstPage: Page,
        at url: URL,
        supportedContentVersion: Int,
        recoveredDirectory: URL
    ) throws -> NotebookStore {
        let package = NotebookPackage(url: url)
        try FileManager.default.createDirectory(at: package.inkDirectory, withIntermediateDirectories: true)
        let manifest = NotebookManifest(notebook: notebook, pages: [firstPage])
        try JSONCoding.encode(manifest).write(to: package.manifestURL, options: .atomic)
        return NotebookStore(
            package: package,
            manifest: manifest,
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    public static func open(
        at url: URL,
        supportedContentVersion: Int,
        recoveredDirectory: URL,
        now: Date = .now
    ) throws -> NotebookStore {
        let package = NotebookPackage(url: url)
        var manifest = try readManifest(of: package)
        if adoptOrphanInk(in: package, into: &manifest, now: now) {
            try FileManager.default.replaceContents(
                of: package.manifestURL,
                with: JSONCoding.encode(manifest),
                keepingPreviousAt: package.previousManifestURL
            )
        }
        return NotebookStore(
            package: package,
            manifest: manifest,
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    /// Reads the manifest, falling back to the previous generation when the current one is unreadable.
    static func readManifest(of package: NotebookPackage) throws -> NotebookManifest {
        for url in [package.manifestURL, package.previousManifestURL] {
            guard let data = try? Data(contentsOf: url) else {
                continue
            }
            if let probe = try? JSONCoding.decode(SchemaProbe.self, from: data),
                probe.schemaVersion > NotebookManifest.currentSchemaVersion
            {
                throw NotebookStoreError.schemaNewerThanApp
            }
            if let manifest = try? JSONCoding.decode(NotebookManifest.self, from: data) {
                return manifest
            }
        }
        throw NotebookStoreError.manifestUnreadable
    }

    /// Ink files without a manifest entry come from a crash between two writes; they become pages at the end.
    private static func adoptOrphanInk(in package: NotebookPackage, into manifest: inout NotebookManifest, now: Date) -> Bool {
        let knownPages = Set(manifest.pages.map(\.id))
        let orphans = FileManager.default.directoryContents(at: package.inkDirectory)
            .filter { $0.pathExtension == "ink" }
            .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
            .filter { !knownPages.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }
        guard !orphans.isEmpty else {
            return false
        }
        var lastKey = manifest.activePages.last?.sortKey
        for pageID in orphans {
            let key = SortKey.between(lastKey, nil)
            var page = Page(
                id: pageID,
                sortKey: key,
                size: manifest.notebook.defaultPageSize,
                paper: manifest.notebook.defaultPaper,
                now: now
            )
            page.hasInk = true
            manifest.pages.append(page)
            lastKey = key
        }
        return true
    }

    // MARK: Ink

    public func ink(for pageID: Page.ID) -> InkLoadResult {
        guard let page = manifest.pages.first(where: { $0.id == pageID }) else {
            return .empty
        }
        let currentURL = package.inkURL(for: pageID)
        let previousURL = package.previousInkURL(for: pageID)
        let current = readInk(at: currentURL)
        if case .success(let ink) = current {
            return accept(ink, for: pageID, isRecovered: false)
        }

        let hasPreviousGeneration = FileManager.default.fileExists(atPath: previousURL.path(percentEncoded: false))
        if case .failure(.missing) = current, !page.hasInk, !hasPreviousGeneration {
            return .empty
        }
        if case .failure(.damaged) = current {
            quarantine(currentURL, pageID: pageID)
        }
        if case .success(let ink) = readInk(at: previousURL) {
            return accept(ink, for: pageID, isRecovered: true)
        }
        if hasPreviousGeneration {
            quarantine(previousURL, pageID: pageID)
        }
        return .unrecoverable
    }

    /// Writes a page's ink. The manifest learns that the page has ink before the ink file first appears.
    public func saveInk(_ ink: InkData, for pageID: Page.ID, now: Date = .now) throws {
        guard !readOnlyPages.contains(pageID) else {
            throw NotebookStoreError.requiresNewerSystem
        }
        let hash = InkEnvelope.hash(of: ink.payload)
        guard writtenInkHashes[pageID] != hash, let pageIndex = manifest.pageIndex(of: pageID) else {
            return
        }

        if !manifest.pages[pageIndex].hasInk {
            var updated = manifest
            updated.pages[pageIndex].hasInk = true
            updated.pages[pageIndex].inkHash = hash
            updated.pages[pageIndex].modifiedAt = now
            try writeManifest(updated)
        } else {
            manifest.pages[pageIndex].inkHash = hash
            manifest.pages[pageIndex].modifiedAt = now
            manifest.notebook.modifiedAt = now
            hasUnwrittenManifestChanges = true
        }

        try FileManager.default.replaceContents(
            of: package.inkURL(for: pageID),
            with: InkEnvelope.encode(ink),
            keepingPreviousAt: package.previousInkURL(for: pageID)
        )
        writtenInkHashes[pageID] = hash
    }

    // MARK: Manifest

    /// Applies a structural change (pages, paper, title, trash) and writes the manifest immediately.
    @discardableResult
    public func updateManifest(_ change: @Sendable (inout NotebookManifest) -> Void) throws -> NotebookManifest {
        var updated = manifest
        change(&updated)
        try writeManifest(updated)
        return updated
    }

    /// Writes hashes and dates that `saveInk` kept in memory to avoid rewriting the manifest on every save.
    public func writePendingManifestChanges() throws {
        guard hasUnwrittenManifestChanges else {
            return
        }
        try writeManifest(manifest)
    }

    /// Permanently removes pages that have been in the Trash since before `cutoff`.
    public func purgePages(deletedBefore cutoff: Date) throws {
        let expired = manifest.pages.filter { ($0.deletedAt ?? .distantFuture) < cutoff }.map(\.id)
        guard !expired.isEmpty else {
            return
        }
        let expiredSet = Set(expired)
        try updateManifest { $0.pages.removeAll { expiredSet.contains($0.id) } }
        for pageID in expired {
            try? FileManager.default.removeItem(at: package.inkURL(for: pageID))
            try? FileManager.default.removeItem(at: package.previousInkURL(for: pageID))
        }
    }

    private func writeManifest(_ updated: NotebookManifest) throws {
        try FileManager.default.replaceContents(
            of: package.manifestURL,
            with: JSONCoding.encode(updated),
            keepingPreviousAt: package.previousManifestURL
        )
        manifest = updated
        hasUnwrittenManifestChanges = false
    }

    private func accept(_ ink: InkData, for pageID: Page.ID, isRecovered: Bool) -> InkLoadResult {
        guard ink.requiredContentVersion <= supportedContentVersion else {
            readOnlyPages.insert(pageID)
            return .requiresNewerSystem
        }
        if isRecovered {
            return .recovered(ink)
        }
        writtenInkHashes[pageID] = InkEnvelope.hash(of: ink.payload)
        return .ink(ink)
    }

    private enum InkReadFailure: Error {
        case missing
        case damaged
    }

    private func readInk(at url: URL) -> Result<InkData, InkReadFailure> {
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.missing)
        }
        guard let ink = try? InkEnvelope.decode(data) else {
            return .failure(.damaged)
        }
        return .success(ink)
    }

    /// Copies a damaged file aside so a later write cannot destroy what might still be salvaged.
    private func quarantine(_ url: URL, pageID: Page.ID) {
        let fileManager = FileManager.default
        let destination = recoveredDirectory.appending(
            path: "\(manifest.notebook.id.uuidString)-\(pageID.uuidString)-\(Int(Date.now.timeIntervalSince1970))-\(url.lastPathComponent)"
        )
        try? fileManager.createDirectory(at: recoveredDirectory, withIntermediateDirectories: true)
        try? fileManager.copyItem(at: url, to: destination)
    }
}
