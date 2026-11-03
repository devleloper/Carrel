import Foundation
import NotebookDomain

public enum LibraryStoreError: Error, Equatable {
    case notebookNotFound
    case schemaNewerThanApp
}

/// A notebook package that exists but cannot be opened. Its files are left untouched.
public struct UnreadableNotebook: Equatable, Sendable {
    public let id: Notebook.ID
    public let reason: NotebookStoreError
}

/// What the library holds: the notebooks it can open, and the packages it cannot.
public struct LibraryContents: Equatable, Sendable {
    public let notebooks: [Notebook]
    public let unreadable: [UnreadableNotebook]
}

/// The catalog of the library: folders, the list of notebooks, and the single `NotebookStore` per open notebook.
///
/// Every change to a notebook goes through its `NotebookStore`, even a rename from the library, so the editor
/// and the library never hold two diverging copies of the same manifest.
public actor LibraryStore {
    public nonisolated let layout: LibraryLayout
    public static let trashRetentionDays = 30
    public static let trashRetention = TimeInterval(trashRetentionDays * 24 * 60 * 60)

    private let supportedContentVersion: Int
    private var manifest: LibraryManifest
    private var openStores: [Notebook.ID: NotebookStore] = [:]

    public init(layout: LibraryLayout, supportedContentVersion: Int) throws {
        for directory in [layout.notebooksDirectory, layout.recoveredDirectory, layout.snapshotsDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        self.layout = layout
        self.supportedContentVersion = supportedContentVersion
        self.manifest = try Self.readManifest(in: layout.libraryDirectory, movingDamagedTo: layout.recoveredDirectory)
    }

    /// A missing or unreadable `library.json` costs only folder names, never notebooks, so it starts empty.
    private static func readManifest(
        in libraryDirectory: URL,
        movingDamagedTo recoveredDirectory: URL?
    ) throws -> LibraryManifest {
        do {
            return try VersionedFile.read(
                LibraryManifest.self,
                from: [
                    LibraryLayout.manifestURL(in: libraryDirectory),
                    LibraryLayout.previousManifestURL(in: libraryDirectory),
                ],
                migration: LibraryManifest.migration,
                movingDamagedTo: recoveredDirectory
            )
        } catch VersionedFileError.newerSchema {
            throw LibraryStoreError.schemaNewerThanApp
        } catch {
            return LibraryManifest()
        }
    }

    /// Writes changes that open notebooks keep in memory, so the files on disk are complete.
    public func writePendingChanges() async throws {
        for store in openStores.values {
            try await store.writePendingManifestChanges()
        }
    }

    // MARK: Notebooks

    /// Every notebook, including those in the Trash, and the packages that cannot be read.
    public func contents() async -> LibraryContents {
        var notebooks: [Notebook] = []
        var unreadable: [UnreadableNotebook] = []
        let packages = FileManager.default.directoryContents(at: layout.notebooksDirectory)
        for url in packages {
            guard let id = LibraryLayout.notebookID(ofPackage: url) else {
                continue
            }
            if let store = openStores[id] {
                notebooks.append(await store.manifest.notebook)
                continue
            }
            do {
                notebooks.append(try NotebookStore.readManifest(of: NotebookPackage(url: url)).notebook)
            } catch {
                let reason = error as? NotebookStoreError ?? .manifestUnreadable
                unreadable.append(UnreadableNotebook(id: id, reason: reason))
            }
        }
        return LibraryContents(notebooks: notebooks, unreadable: unreadable)
    }

    public func createNotebook(
        title: String,
        cover: Cover,
        paper: Paper,
        pageSize: PageSize,
        folderID: Folder.ID?,
        now: Date = .now
    ) async throws -> Notebook {
        let lastKey = await contents().notebooks.map(\.sortKey).max()
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

    public func renameNotebook(_ notebookID: Notebook.ID, to title: String, now: Date = .now) async throws {
        try await store(for: notebookID).rename(to: title, now: now)
    }

    /// Changes how a notebook is organized: favorite, folder or Trash. The modification date stays as it is.
    @discardableResult
    public func organizeNotebook(
        _ notebookID: Notebook.ID,
        _ change: @escaping @Sendable (inout Notebook) -> Void
    ) async throws -> Notebook {
        try await store(for: notebookID).organize(change)
    }

    public func deleteNotebookPermanently(_ notebookID: Notebook.ID) throws {
        openStores[notebookID] = nil
        try FileManager.default.removeItem(at: layout.packageURL(for: notebookID))
        try? FileManager.default.removeItem(at: layout.snapshotsDirectory(for: notebookID))
    }

    /// Removes notebooks and pages that have been in the Trash longer than `trashRetention`.
    public func purgeExpiredTrash(now: Date = .now) async {
        let cutoff = now.addingTimeInterval(-Self.trashRetention)
        for notebook in await contents().notebooks {
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

    /// Renames a folder. A title that is blank after trimming is ignored, as it is for notebooks.
    public func renameFolder(_ folderID: Folder.ID, to title: String, now: Date = .now) throws {
        guard let title = Title.normalized(title) else {
            return
        }
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
        for notebook in await contents().notebooks where notebook.folderID == folderID {
            try await organizeNotebook(notebook.id) { $0.folderID = nil }
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

    // MARK: Restore

    /// Swaps in a library extracted to `staging` and keeps the current one at `replacedLocation`.
    ///
    /// The candidate is checked before anything moves, and the swap has no suspension point, so no other work on
    /// this actor can observe a half-replaced library.
    func replaceLibrary(with staging: URL, keepingCurrentAt replacedLocation: URL) throws {
        let candidate = try Self.readManifest(in: staging, movingDamagedTo: nil)
        let packages = FileManager.default.directoryContents(at: LibraryLayout.notebooksDirectory(in: staging))
        for url in packages where LibraryLayout.notebookID(ofPackage: url) != nil {
            do {
                _ = try NotebookStore.readManifest(of: NotebookPackage(url: url))
            } catch NotebookStoreError.schemaNewerThanApp {
                throw LibraryStoreError.schemaNewerThanApp
            } catch {
                // An unreadable package is restored as it was backed up and listed as unreadable afterwards.
                continue
            }
        }

        let fileManager = FileManager.default
        try fileManager.moveItem(at: layout.libraryDirectory, to: replacedLocation)
        do {
            try fileManager.moveItem(at: staging, to: layout.libraryDirectory)
        } catch {
            try? fileManager.moveItem(at: replacedLocation, to: layout.libraryDirectory)
            throw error
        }
        openStores.removeAll()
        manifest = candidate
    }
}
