import Foundation
import NotebookDomain

public enum LibraryStoreError: Error, Equatable {
    case notebookNotFound
    case schemaNewerThanApp
}

/// The catalog of the library: folders, the list of notebooks, and the single `NotebookStore` per open notebook.
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
        for directory in [layout.notebooksDirectory, layout.recoveredDirectory, layout.snapshotsDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.layout = layout
        self.supportedContentVersion = supportedContentVersion
        self.manifest = try Self.readManifest(layout)
    }

    /// A missing or unreadable `library.json` costs only folder names, never notebooks, so it starts empty.
    private static func readManifest(_ layout: LibraryLayout) throws -> LibraryManifest {
        do {
            return try VersionedFile.read(
                LibraryManifest.self,
                from: [layout.manifestURL, layout.previousManifestURL],
                supportedSchemaVersion: LibraryManifest.currentSchemaVersion
            )
        } catch VersionedFileError.newerSchema {
            throw LibraryStoreError.schemaNewerThanApp
        } catch {
            return LibraryManifest()
        }
    }

    /// Forgets open notebooks and reads the library again, after its files were replaced by a restore.
    public func reload() throws {
        openStores.removeAll()
        manifest = try Self.readManifest(layout)
    }

    /// Writes changes that open notebooks keep in memory, so the files on disk are complete.
    public func writePendingChanges() async throws {
        for store in openStores.values {
            try await store.writePendingManifestChanges()
        }
    }

    // MARK: Notebooks

    /// Every readable notebook, including those in the Trash. Unreadable packages are skipped, not deleted.
    public func notebooks() async -> [Notebook] {
        var notebooks: [Notebook] = []
        let packages = FileManager.default.directoryContents(at: layout.notebooksDirectory)
            .filter { $0.pathExtension == "notebook" }
        for url in packages {
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
        openStores[notebook.id] = try NotebookStore.create(
            notebook,
            firstPage: firstPage,
            at: layout.packageURL(for: notebook.id),
            supportedContentVersion: supportedContentVersion,
            recoveredDirectory: layout.recoveredDirectory
        )
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
    public func updateNotebook(
        _ notebookID: Notebook.ID,
        now: Date = .now,
        _ change: @escaping @Sendable (inout Notebook) -> Void
    ) async throws -> Notebook {
        let manifest = try await store(for: notebookID).updateManifest { manifest in
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
        try updateFolders { $0.append(folder) }
        return folder
    }

    public func renameFolder(_ folderID: Folder.ID, to title: String, now: Date = .now) throws {
        try updateFolders { folders in
            guard let index = folders.firstIndex(where: { $0.id == folderID }) else {
                return
            }
            folders[index].title = title
            folders[index].modifiedAt = now
        }
    }

    /// Deletes a folder; its notebooks move to the top level rather than disappearing with it.
    public func deleteFolder(_ folderID: Folder.ID, now: Date = .now) async throws {
        for notebook in await notebooks() where notebook.folderID == folderID {
            try await updateNotebook(notebook.id, now: now) { $0.folderID = nil }
        }
        try updateFolders { folders in
            guard let index = folders.firstIndex(where: { $0.id == folderID }) else {
                return
            }
            folders[index].deletedAt = now
        }
    }

    private func updateFolders(_ change: (inout [Folder]) -> Void) throws {
        var updated = manifest
        change(&updated.folders)
        try VersionedFile.write(updated, to: layout.manifestURL, keepingPreviousAt: layout.previousManifestURL)
        manifest = updated
    }
}
