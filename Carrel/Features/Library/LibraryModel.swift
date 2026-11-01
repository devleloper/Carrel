import Foundation
import NotebookData
import NotebookDomain

struct NotebookDraft {
    var title = ""
    var cover = CoverPreset.forestCloth
    var paper = Paper.standard
    var pageSize = PageSize.a4
}

/// The library screen's state: notebooks, folders, the selected section and search.
@Observable
final class LibraryModel {
    enum Section: Hashable {
        case all
        case favorites
        case trash
        case folder(Folder.ID)
    }

    private(set) var notebooks: [Notebook] = []
    private(set) var folders: [Folder] = []
    var section: Section? = .all
    var searchText = ""
    var errorMessage: String?

    private let library: LibraryStore
    private let snapshots: SnapshotStore

    init(library: LibraryStore, snapshots: SnapshotStore) {
        self.library = library
        self.snapshots = snapshots
    }

    var visibleNotebooks: [Notebook] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let inSection = notebooks.filter(isInCurrentSection)
        let matching = query.isEmpty ? inSection : inSection.filter { $0.title.localizedStandardContains(query) }
        return matching.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var sectionTitle: String {
        switch section ?? .all {
        case .all:
            String(localized: "Library")
        case .favorites:
            String(localized: "Favorites")
        case .trash:
            String(localized: "Trash")
        case .folder(let folderID):
            folders.first { $0.id == folderID }?.title ?? String(localized: "Folder")
        }
    }

    private func isInCurrentSection(_ notebook: Notebook) -> Bool {
        switch section ?? .all {
        case .all:
            !notebook.isInTrash
        case .favorites:
            !notebook.isInTrash && notebook.isFavorite
        case .trash:
            notebook.isInTrash
        case .folder(let folderID):
            !notebook.isInTrash && notebook.folderID == folderID
        }
    }

    private var currentFolderID: Folder.ID? {
        if case .folder(let folderID) = section {
            return folderID
        }
        return nil
    }

    func load() async {
        notebooks = await library.notebooks()
        folders = await library.folders()
    }

    func purgeExpiredTrashAndLoad() async {
        await library.purgeExpiredTrash()
        await load()
    }

    // MARK: Notebooks

    func create(_ draft: NotebookDraft) async -> Notebook? {
        let title = Title.normalized(draft.title) ?? String(localized: "Untitled")
        let folderID = currentFolderID
        return await perform {
            let notebook = try await library.createNotebook(
                title: title,
                cover: Cover(preset: draft.cover),
                paper: draft.paper,
                pageSize: draft.pageSize,
                folderID: folderID
            )
            await load()
            return notebook
        }
    }

    /// Opens a notebook for editing, after taking a snapshot of it as it was before this session.
    func openSession(for notebook: Notebook) async -> EditorSession? {
        await perform {
            let store = try await library.store(for: notebook.id)
            try await store.writePendingManifestChanges()
            // A snapshot is a safety net: failing to take one must not keep the user from their notes.
            try? snapshots.takeSnapshot(of: notebook.id)
            return await EditorSession.open(store)
        }
    }

    func rename(_ notebook: Notebook, to title: String) async {
        guard let title = Title.normalized(title) else {
            return
        }
        await update(notebook) { $0.title = title }
    }

    func toggleFavorite(_ notebook: Notebook) async {
        let isFavorite = !notebook.isFavorite
        await update(notebook) { $0.isFavorite = isFavorite }
    }

    func move(_ notebook: Notebook, to folderID: Folder.ID?) async {
        await update(notebook) { $0.folderID = folderID }
    }

    func moveToTrash(_ notebook: Notebook) async {
        await update(notebook) { $0.deletedAt = .now }
    }

    func restore(_ notebook: Notebook) async {
        await update(notebook) { $0.deletedAt = nil }
    }

    func deletePermanently(_ notebook: Notebook) async {
        await perform {
            try await library.deleteNotebookPermanently(notebook.id)
            await load()
        }
    }

    private func update(_ notebook: Notebook, _ change: @escaping @Sendable (inout Notebook) -> Void) async {
        await perform {
            try await library.updateNotebook(notebook.id, change)
            await load()
        }
    }

    // MARK: Folders

    func createFolder(named title: String) async {
        guard let title = Title.normalized(title) else {
            return
        }
        await perform {
            let folder = try await library.createFolder(title: title)
            await load()
            section = .folder(folder.id)
        }
    }

    func renameFolder(_ folder: Folder, to title: String) async {
        guard let title = Title.normalized(title) else {
            return
        }
        await perform {
            try await library.renameFolder(folder.id, to: title)
            await load()
        }
    }

    func deleteFolder(_ folder: Folder) async {
        await perform {
            try await library.deleteFolder(folder.id)
            if section == .folder(folder.id) {
                section = .all
            }
            await load()
        }
    }

    @discardableResult
    private func perform<Value>(_ operation: () async throws -> Value) async -> Value? {
        do {
            return try await operation()
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }
}
