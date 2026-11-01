import Foundation
import NotebookDomain

public enum LibraryStoreError: Error, Equatable {
    case notebookNotFound
    case insufficientSpace
    case backupUnreadable
}

/// Folders, the list of notebooks, and the single `NotebookStore` per open notebook.
///
/// Every change to a notebook goes through its `NotebookStore`, even a rename from the library, so the editor
/// and the library never hold two diverging copies of the same manifest.
public actor LibraryStore {
    public nonisolated let layout: LibraryLayout
    public static let trashRetention: TimeInterval = 30 * 24 * 60 * 60

    private let supportedContentVersion: Int
    private var manifest: LibraryManifest
    private var openStores: [Notebook.ID: NotebookStore] = [:]

    public init(layout: LibraryLayout, supportedContentVersion: Int) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: layout.notebooksDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.recoveredDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: layout.snapshotsDirectory, withIntermediateDirectories: true)
        self.layout = layout
        self.supportedContentVersion = supportedContentVersion
        self.manifest = Self.readManifest(layout)
    }

    private static func readManifest(_ layout: LibraryLayout) -> LibraryManifest {
        for url in [layout.manifestURL, layout.previousManifestURL] {
            if let data = try? Data(contentsOf: url), let manifest = try? JSONCoding.decode(LibraryManifest.self, from: data) {
                return manifest
            }
        }
        return LibraryManifest()
    }

    // MARK: Notebooks

    /// Every readable notebook, including those in the Trash. Unreadable packages are skipped, not deleted.
    public func notebooks() async -> [Notebook] {
        var notebooks: [Notebook] = []
        for url in FileManager.default.directoryContents(at: layout.notebooksDirectory) where url.pathExtension == "notebook" {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else {
                continue
            }
            if let store = openStores[id] {
                notebooks.append(await store.manifest.notebook)
            } else if let manifest = try? NotebookStore.readManifest(of: NotebookPackage(url: url)) {
                notebooks.append(manifest.notebook)
            }
        }
        return notebooks
    }

    public func createNotebook(
        title: String,
        cover: Cover,
        paper: Paper,
        pageSize: PageSize,
        folderID: Folder.ID?,
        now: Date = .now
    ) async throws -> Notebook {
        let lastKey = await notebooks().map(\.sortKey).max()
        let notebook = Notebook(
            title: title,
            folderID: folderID,
            cover: cover,
            defaultPaper: paper,
            defaultPageSize: pageSize,
            sortKey: SortKey.between(lastKey, nil),
            now: now
        )
        let firstPage = Page(sortKey: .initial, size: pageSize, paper: paper, now: now)
        let store = try NotebookStore.create(
            notebook,
            firstPage: firstPage,
            at: layout.packageURL(for: notebook.id),
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: layout.recoveredDirectory
        )
        openStores[notebook.id] = store
        return notebook
    }

    public func store(for notebookID: Notebook.ID) throws -> NotebookStore {
        if let store = openStores[notebookID] {
            return store
        }
        let url = layout.packageURL(for: notebookID)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw LibraryStoreError.notebookNotFound
        }
        let store = try NotebookStore.open(
            at: url,
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: layout.recoveredDirectory
        )
        openStores[notebookID] = store
        return store
    }

    @discardableResult
    public func updateNotebook(_ notebookID: Notebook.ID, now: Date = .now, _ change: @escaping @Sendable (inout Notebook) -> Void) async throws -> Notebook {
        let store = try store(for: notebookID)
        let manifest = try await store.updateManifest { manifest in
            change(&manifest.notebook)
            manifest.notebook.modifiedAt = now
        }
        return manifest.notebook
    }

    public func deleteNotebookPermanently(_ notebookID: Notebook.ID) throws {
        openStores[notebookID] = nil
        try FileManager.default.removeItem(at: layout.packageURL(for: notebookID))
        try? FileManager.default.removeItem(at: layout.snapshotsDirectory(for: notebookID))
    }

    /// Removes notebooks and pages that have been in the Trash longer than `trashRetention`.
    public func purgeExpiredTrash(now: Date = .now) async {
        let cutoff = now.addingTimeInterval(-Self.trashRetention)
        for notebook in await notebooks() {
            if let deletedAt = notebook.deletedAt, deletedAt < cutoff {
                try? deleteNotebookPermanently(notebook.id)
            } else if let store = try? store(for: notebook.id) {
                try? await store.purgePages(deletedBefore: cutoff)
            }
        }
    }

    // MARK: Folders

    public func folders() -> [Folder] {
        manifest.folders.filter { $0.deletedAt == nil }.sorted { $0.sortKey < $1.sortKey }
    }

    public func createFolder(title: String, now: Date = .now) throws -> Folder {
        let folder = Folder(title: title, sortKey: SortKey.between(folders().last?.sortKey, nil), now: now)
        var updated = manifest
        updated.folders.append(folder)
        try writeManifest(updated)
        return folder
    }

    public func renameFolder(_ folderID: Folder.ID, to title: String, now: Date = .now) throws {
        var updated = manifest
        guard let index = updated.folders.firstIndex(where: { $0.id == folderID }) else {
            return
        }
        updated.folders[index].title = title
        updated.folders[index].modifiedAt = now
        try writeManifest(updated)
    }

    /// Deletes a folder; its notebooks move to the top level rather than disappearing with it.
    public func deleteFolder(_ folderID: Folder.ID, now: Date = .now) async throws {
        for notebook in await notebooks() where notebook.folderID == folderID {
            try await updateNotebook(notebook.id, now: now) { $0.folderID = nil }
        }
        var updated = manifest
        guard let index = updated.folders.firstIndex(where: { $0.id == folderID }) else {
            return
        }
        updated.folders[index].deletedAt = now
        try writeManifest(updated)
    }

    private func writeManifest(_ updated: LibraryManifest) throws {
        try FileManager.default.replaceContents(
            of: layout.manifestURL,
            with: JSONCoding.encode(updated),
            keepingPreviousAt: layout.previousManifestURL
        )
        manifest = updated
    }

    // MARK: Snapshots

    /// Keeps a copy of a notebook as it was before an editing session; on APFS the copy is a cheap clone.
    public func takeSnapshot(of notebookID: Notebook.ID, now: Date = .now) async throws {
        if let store = openStores[notebookID] {
            try await store.writePendingManifestChanges()
        }
        let directory = layout.snapshotsDirectory(for: notebookID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(path: "\(Int(now.timeIntervalSince1970)).notebook", directoryHint: .isDirectory)
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.copyItem(at: layout.packageURL(for: notebookID), to: destination)
        SnapshotRetention.prune(directory, now: now)
    }

    // MARK: Backup

    /// Writes the whole library into one Apple Archive file at `destination`.
    public func backUp(to destination: URL) async throws {
        for store in openStores.values {
            try await store.writePendingManifestChanges()
        }
        let required = FileManager.default.allocatedSize(ofDirectory: layout.library)
        let available = (try? layout.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? .max
        guard available > required else {
            throw LibraryStoreError.insufficientSpace
        }
        try LibraryArchive.write(directory: layout.library, to: destination)
    }

    /// Replaces the library with a backup. The current library is moved to the recovery folder first.
    public func restore(from archive: URL, now: Date = .now) throws {
        let fileManager = FileManager.default
        let staging = layout.root.appending(path: "Restoring-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try LibraryArchive.extract(archive, into: staging)
        let restoredNotebooks = staging.appending(path: "Notebooks", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: restoredNotebooks.path(percentEncoded: false)) else {
            throw LibraryStoreError.backupUnreadable
        }

        openStores.removeAll()
        let replaced = layout.recoveredDirectory.appending(
            path: "Library-before-restore-\(Int(now.timeIntervalSince1970))",
            directoryHint: .isDirectory
        )
        try fileManager.moveItem(at: layout.library, to: replaced)
        try fileManager.moveItem(at: staging, to: layout.library)
        manifest = Self.readManifest(layout)
    }
}

/// Keeps the five most recent snapshots plus the newest one of each day for thirty days.
enum SnapshotRetention {
    static let recentCount = 5
    static let dailyWindow: TimeInterval = 30 * 24 * 60 * 60

    static func prune(_ directory: URL, now: Date, calendar: Calendar = .current) {
        let snapshots = FileManager.default.directoryContents(at: directory)
            .compactMap { url -> (url: URL, date: Date)? in
                guard let seconds = TimeInterval(url.deletingPathExtension().lastPathComponent) else {
                    return nil
                }
                return (url, Date(timeIntervalSince1970: seconds))
            }
            .sorted { $0.date > $1.date }

        var keep = Set(snapshots.prefix(recentCount).map(\.url))
        var keptDays = Set<DateComponents>()
        for snapshot in snapshots where now.timeIntervalSince(snapshot.date) <= dailyWindow {
            let day = calendar.dateComponents([.year, .month, .day], from: snapshot.date)
            if keptDays.insert(day).inserted {
                keep.insert(snapshot.url)
            }
        }
        for snapshot in snapshots where !keep.contains(snapshot.url) {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }
}
