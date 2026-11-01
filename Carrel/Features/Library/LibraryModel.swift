import Foundation
import NotebookData
import NotebookDomain

struct NotebookDraft {
    var title = ""
    var cover = CoverPreset.forestCloth
    var paper = Paper.standard
    var pageSize = PageSize.a4
    var folderID: Folder.ID?
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

    @ObservationIgnored let library: LibraryStore

    init(library: LibraryStore) {
        self.library = library
    }

    var visibleNotebooks: [Notebook] {
        let inSection: [Notebook]
        switch section ?? .all {
        case .all: inSection = notebooks.filter { !$0.isInTrash }
        case .favorites: inSection = notebooks.filter { !$0.isInTrash && $0.isFavorite }
        case .trash: inSection = notebooks.filter(\.isInTrash)
        case .folder(let folderID): inSection = notebooks.filter { !$0.isInTrash && $0.folderID == folderID }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return inSection
            .filter { query.isEmpty || $0.title.localizedStandardContains(query) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var sectionTitle: String {
        switch section ?? .all {
        case .all: String(localized: "Library")
        case .favorites: String(localized: "Favorites")
        case .trash: String(localized: "Trash")
        case .folder(let folderID): folders.first { $0.id == folderID }?.title ?? String(localized: "Folder")
        }
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
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return await perform {
            let notebook = try await library.createNotebook(
                title: title.isEmpty ? String(localized: "Untitled") : title,
                cover: Cover(preset: draft.cover),
                paper: draft.paper,
                pageSize: draft.pageSize,
                folderID: draft.folderID ?? currentFolderID
            )
            await load()
            return notebook
        }
    }

    func openSession(for notebook: Notebook) async -> EditorSession? {
        await perform {
            let store = try await library.store(for: notebook.id)
            try? await library.takeSnapshot(of: notebook.id)
            return await EditorSession.open(store)
        }
    }

    func rename(_ notebook: Notebook, to title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        await update(notebook) { $0.title = trimmed }
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
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        await perform {
            let folder = try await library.createFolder(title: trimmed)
            await load()
            section = .folder(folder.id)
        }
    }

    func renameFolder(_ folder: Folder, to title: String) async {
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

    private var currentFolderID: Folder.ID? {
        if case .folder(let folderID) = section {
            return folderID
        }
        return nil
    }

    // MARK: Backup

    func makeBackup() async -> URL? {
        let fileName = "Carrel Backup \(Date.now.formatted(.iso8601.year().month().day())).aar"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        return await perform {
            try await library.backUp(to: url)
            UserDefaults.standard.set(Date.now, forKey: Self.lastBackupKey)
            return url
        }
    }

    func restoreBackup(from url: URL) async {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        await perform {
            try await library.restore(from: url)
            await load()
        }
    }

    var lastBackupDate: Date? {
        UserDefaults.standard.object(forKey: Self.lastBackupKey) as? Date
    }

    private static let lastBackupKey = "lastBackupDate"

    // MARK: Errors

    @discardableResult
    private func perform<Value>(_ operation: () async throws -> Value) async -> Value? {
        do {
            return try await operation()
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    private static func message(for error: any Error) -> String {
        switch error {
        case LibraryStoreError.insufficientSpace:
            String(localized: "There isn't enough free space on this iPad. Free up some space and try again.")
        case LibraryStoreError.backupUnreadable:
            String(localized: "This file isn't a Carrel backup.")
        case NotebookStoreError.schemaNewerThanApp:
            String(localized: "This notebook was saved by a newer version of Carrel. Update the app to open it.")
        case NotebookStoreError.manifestUnreadable:
            String(localized: "This notebook couldn't be read. Its files were kept so it can be recovered.")
        default:
            error.localizedDescription
        }
    }
}
