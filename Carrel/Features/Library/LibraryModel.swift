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

        var systemImage: String {
            switch self {
            case .all: "books.vertical"
            case .favorites: "star"
            case .trash: "trash"
            case .folder: "folder"
            }
        }
    }

    private(set) var notebooks: [Notebook] = []
    private(set) var folders: [Folder] = []
    /// Notebook packages that exist but cannot be opened. They are never deleted, only reported.
    private(set) var unreadableNotebookCount = 0
    /// `nil` only while the sidebar list has no selection; it then shows the whole library.
    var section: Section? = .all
    var searchText = ""
    var errorMessage: String?

    private let store: LibraryStore
    private let snapshots: SnapshotStore

    init(store: LibraryStore, snapshots: SnapshotStore) {
        self.store = store
        self.snapshots = snapshots
    }

    var currentSection: Section {
        section ?? .all
    }

    var visibleNotebooks: [Notebook] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let inSection = notebooks.filter(isInCurrentSection)
        let matching = query.isEmpty ? inSection : inSection.filter { $0.title.localizedStandardContains(query) }
        return matching.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func title(of section: Section) -> String {
        switch section {
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
        switch currentSection {
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
        if case .folder(let folderID) = currentSection {
            return folderID
        }
        return nil
    }

    func load() async {
        let contents = await store.contents()
        notebooks = contents.notebooks
        unreadableNotebookCount = contents.unreadable.count
        folders = await store.folders()
    }

    func purgeExpiredTrashAndLoad() async {
        await store.purgeExpiredTrash()
        await load()
    }

    // MARK: Notebooks

    func create(_ draft: NotebookDraft) async -> Notebook? {
        let title = Title.normalized(draft.title) ?? String(localized: "Untitled")
        let folderID = currentFolderID
        return await perform {
            try await store.createNotebook(
                title: title,
                cover: Cover(preset: draft.cover),
                paper: draft.paper,
                pageSize: draft.pageSize,
                folderID: folderID
            )
        }
    }

    /// Opens a notebook for editing, after taking a snapshot of it as it was before this session.
    func openSession(for notebook: Notebook) async -> EditorSession? {
        do {
            let notebookStore = try await store.store(for: notebook.id)
            // A snapshot is a safety net: failing to take one must not keep the user from their notes.
            try? await snapshots.takeSnapshot(of: notebookStore)
            return await EditorSession.open(notebookStore)
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }

    func rename(_ notebook: Notebook, to title: String) async {
        await perform { try await store.renameNotebook(notebook.id, to: title) }
    }

    func toggleFavorite(_ notebook: Notebook) async {
        let isFavorite = !notebook.isFavorite
        await organize(notebook) { $0.isFavorite = isFavorite }
    }

    func move(_ notebook: Notebook, to folderID: Folder.ID?) async {
        await organize(notebook) { $0.folderID = folderID }
    }

    func moveToTrash(_ notebook: Notebook, now: Date = .now) async {
        await organize(notebook) { $0.deletedAt = now }
    }

    func restore(_ notebook: Notebook) async {
        await organize(notebook) { $0.deletedAt = nil }
    }

    func deletePermanently(_ notebook: Notebook) async {
        await perform { try await store.deleteNotebookPermanently(notebook.id) }
    }

    private func organize(_ notebook: Notebook, _ change: @escaping @Sendable (inout Notebook) -> Void) async {
        await perform { try await store.organizeNotebook(notebook.id, change) }
    }

    // MARK: Folders

    func createFolder(named title: String) async {
        guard let title = Title.normalized(title) else {
            return
        }
        if let folder = await perform({ try await store.createFolder(title: title) }) {
            section = .folder(folder.id)
        }
    }

    func renameFolder(_ folder: Folder, to title: String) async {
        await perform { try await store.renameFolder(folder.id, to: title) }
    }

    func deleteFolder(_ folder: Folder) async {
        let deleted = await perform { try await store.deleteFolder(folder.id) } != nil
        if deleted, section == .folder(folder.id) {
            section = .all
        }
    }

    /// Runs a change, then reloads the library even if the change failed: a change that fails halfway, such as
    /// deleting a folder, may already have moved some notebooks.
    @discardableResult
    private func perform<Value>(_ change: () async throws -> Value) async -> Value? {
        let value: Value?
        do {
            value = try await change()
        } catch {
            errorMessage = UserFacingError.message(for: error)
            value = nil
        }
        await load()
        return value
    }
}
