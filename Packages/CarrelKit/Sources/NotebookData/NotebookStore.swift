import Foundation
import NotebookDomain

/// The result of loading a page's ink, including how it was obtained.
public enum InkLoadResult: Equatable, Sendable {
    /// The page has never been written to.
    case empty
    case ink(InkData)
    /// The current file was damaged or missing; this is the previous generation.
    case recovered(InkData)
    /// Neither generation could be read. The damaged files were moved to the recovery folder.
    case damaged
    /// The page had ink, but its file is gone and no earlier generation exists.
    case missing
    /// The ink was written by a newer PencilKit. The page stays read-only and its file is never rewritten.
    case requiresNewerSystem
}

public enum NotebookStoreError: Error, Equatable, Sendable {
    case manifestUnreadable
    case schemaNewerThanApp
    case requiresNewerSystem
}

/// Owns one notebook package on disk and serializes every write to it.
///
/// Editing the content (ink, pages, paper, title) updates the notebook's modification date here and nowhere
/// else; organizing it in the library (favorite, folder, Trash) does not, so the library's "recent" order
/// reflects writing, not housekeeping.
public actor NotebookStore {
    public nonisolated let package: NotebookPackage
    public private(set) var manifest: NotebookManifest

    private let supportedContentVersion: Int
    private let recoveredDirectory: URL
    private var writtenInkHashes: [Page.ID: InkHash] = [:]
    private var readOnlyPages: Set<Page.ID> = []
    private var hasUnwrittenManifestChanges = false

    private init(
        package: NotebookPackage,
        manifest: NotebookManifest,
        supportedContentVersion: Int,
        recoveredDirectory: URL
    ) {
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
        var manifest = try readManifest(of: package, movingDamagedTo: recoveredDirectory)
        if adoptOrphanInk(in: package, into: &manifest, now: now) {
            try VersionedFile.write(manifest, to: package.manifestURL, keepingPreviousAt: package.previousManifestURL)
        }
        return NotebookStore(
            package: package,
            manifest: manifest,
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    /// Reads the manifest. Listing the library passes no recovery folder, so it never moves files.
    static func readManifest(
        of package: NotebookPackage,
        movingDamagedTo recoveredDirectory: URL? = nil
    ) throws -> NotebookManifest {
        do {
            return try VersionedFile.read(
                NotebookManifest.self,
                from: [package.manifestURL, package.previousManifestURL],
                migration: NotebookManifest.migration,
                movingDamagedTo: recoveredDirectory
            )
        } catch VersionedFileError.newerSchema {
            throw NotebookStoreError.schemaNewerThanApp
        } catch {
            throw NotebookStoreError.manifestUnreadable
        }
    }

    /// Ink files without a manifest entry come from a crash between two writes; they become pages at the end.
    private static func adoptOrphanInk(
        in package: NotebookPackage,
        into manifest: inout NotebookManifest,
        now: Date
    ) -> Bool {
        let knownPages = Set(manifest.pages.map(\.id))
        let orphans = FileManager.default.directoryContents(at: package.inkDirectory)
            .compactMap(NotebookPackage.pageID(ofInkFile:))
            .filter { !knownPages.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }
        for pageID in orphans {
            manifest.appendPage(id: pageID, now: now)
            manifest.updatePage(pageID, now: now) { $0.hasInk = true }
        }
        return !orphans.isEmpty
    }

    // MARK: Ink

    public func ink(for pageID: Page.ID) -> InkLoadResult {
        guard let page = manifest.pages.first(where: { $0.id == pageID }) else {
            return .empty
        }
        let currentURL = package.inkURL(for: pageID)
        let previousURL = package.previousInkURL(for: pageID)
        let currentFailure: InkReadFailure
        switch readInk(at: currentURL) {
        case .success(let ink):
            return accept(ink, for: pageID, isRecovered: false)
        case .failure(let failure):
            currentFailure = failure
        }

        let hasPreviousGeneration = FileManager.default.fileExists(atPath: previousURL.path(percentEncoded: false))
        if currentFailure == .missing, !page.hasInk, !hasPreviousGeneration {
            return .empty
        }
        // A damaged file is moved, not copied: left in place, the next save would make it the "previous"
        // generation and delete the intact one.
        if currentFailure == .damaged {
            FileManager.default.quarantine(currentURL, in: recoveredDirectory)
        }
        switch readInk(at: previousURL) {
        case .success(let ink):
            return accept(ink, for: pageID, isRecovered: true)
        case .failure(.damaged):
            FileManager.default.quarantine(previousURL, in: recoveredDirectory)
            return .damaged
        case .failure(.missing):
            return currentFailure == .damaged ? .damaged : .missing
        }
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

        var updated = manifest
        updated.pages[pageIndex].inkHash = hash
        updated.pages[pageIndex].modifiedAt = now
        updated.notebook.modifiedAt = now
        if manifest.pages[pageIndex].hasInk {
            // Hashes and dates of later saves stay in memory until `writePendingManifestChanges`, so a save
            // rewrites one ink file instead of the ink file plus the manifest.
            manifest = updated
            hasUnwrittenManifestChanges = true
        } else {
            updated.pages[pageIndex].hasInk = true
            try writeManifest(updated)
        }

        try FileManager.default.replaceContents(
            of: package.inkURL(for: pageID),
            with: InkEnvelope.encode(ink),
            keepingPreviousAt: package.previousInkURL(for: pageID)
        )
        writtenInkHashes[pageID] = hash
    }

    // MARK: Editing the notebook

    public func appendPage(now: Date = .now) throws -> Page {
        var updated = manifest
        let page = updated.appendPage(now: now)
        try commitEdit(updated, now: now)
        return page
    }

    /// Inserts a copy of a page, ink included, right after it. Returns `nil` when the page does not exist.
    public func duplicatePage(_ pageID: Page.ID, now: Date = .now) throws -> Page? {
        let sourceURL = package.inkURL(for: pageID)
        let hasInkFile = FileManager.default.fileExists(atPath: sourceURL.path(percentEncoded: false))
        var updated = manifest
        guard let copy = updated.insertCopy(of: pageID, hasInk: hasInkFile, now: now) else {
            return nil
        }
        try commitEdit(updated, now: now)
        if hasInkFile {
            try FileManager.default.copyItem(at: sourceURL, to: package.inkURL(for: copy.id))
        }
        return copy
    }

    public func movePage(_ pageID: Page.ID, by offset: Int, now: Date = .now) throws {
        var updated = manifest
        updated.movePage(pageID, by: offset, now: now)
        try commitEdit(updated, now: now)
    }

    public func setPageInTrash(_ pageID: Page.ID, _ isInTrash: Bool, now: Date = .now) throws {
        var updated = manifest
        updated.updatePage(pageID, now: now) { $0.deletedAt = isInTrash ? now : nil }
        try commitEdit(updated, now: now)
    }

    public func setPaper(_ paper: Paper, forPage pageID: Page.ID, now: Date = .now) throws {
        var updated = manifest
        updated.updatePage(pageID, now: now) { $0.paper = paper }
        try commitEdit(updated, now: now)
    }

    public func setPaperForAllPages(_ paper: Paper, now: Date = .now) throws {
        var updated = manifest
        updated.notebook.defaultPaper = paper
        for page in manifest.pages {
            updated.updatePage(page.id, now: now) { $0.paper = paper }
        }
        try commitEdit(updated, now: now)
    }

    /// Renames the notebook. A title that is blank after trimming is ignored.
    public func rename(to title: String, now: Date = .now) throws {
        guard let title = Title.normalized(title) else {
            return
        }
        var updated = manifest
        updated.notebook.title = title
        try commitEdit(updated, now: now)
    }

    /// Writes hashes and dates that `saveInk` kept in memory.
    public func writePendingManifestChanges() throws {
        guard hasUnwrittenManifestChanges else {
            return
        }
        try writeManifest(manifest)
    }

    /// Copies the complete package, pending manifest changes included. On APFS the copy is a clone.
    public func copyPackage(to destination: URL) throws {
        try writePendingManifestChanges()
        try FileManager.default.copyItem(at: package.url, to: destination)
    }

    // MARK: Library housekeeping

    /// Changes how the notebook is organized (favorite, folder, Trash). These are not edits, so the
    /// modification date stays as it is.
    func organize(_ change: @Sendable (inout Notebook) -> Void) throws -> Notebook {
        var updated = manifest
        change(&updated.notebook)
        try writeManifest(updated)
        return updated.notebook
    }

    /// Permanently removes pages that have been in the Trash since before `cutoff`.
    func purgePages(deletedBefore cutoff: Date) throws {
        let expired = Set(manifest.pages.filter { ($0.deletedAt ?? .distantFuture) < cutoff }.map(\.id))
        guard !expired.isEmpty else {
            return
        }
        var updated = manifest
        updated.pages.removeAll { expired.contains($0.id) }
        try writeManifest(updated)
        for pageID in expired {
            try? FileManager.default.removeItem(at: package.inkURL(for: pageID))
            try? FileManager.default.removeItem(at: package.previousInkURL(for: pageID))
        }
    }

    // MARK: Private

    /// Every edit of the content goes through here, which is what keeps the modification date consistent.
    private func commitEdit(_ updated: NotebookManifest, now: Date) throws {
        var updated = updated
        updated.notebook.modifiedAt = now
        try writeManifest(updated)
    }

    private func writeManifest(_ updated: NotebookManifest) throws {
        try VersionedFile.write(updated, to: package.manifestURL, keepingPreviousAt: package.previousManifestURL)
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
}
