import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct LibraryStoreTests {
    private func makeLibrary() throws -> (LibraryStore, URL) {
        let root = try makeTemporaryDirectory()
        return (try LibraryStore(layout: LibraryLayout(root: root), supportedContentVersion: 5), root)
    }

    private func createNotebook(in library: LibraryStore, title: String = "Physics") async throws -> Notebook {
        try await library.createNotebook(
            title: title,
            cover: Cover(preset: .navyCloth),
            paper: .standard,
            pageSize: .a4,
            folderID: nil
        )
    }

    @Test func createdNotebooksAreListedInCreationOrder() async throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try await createNotebook(in: library, title: "First")
        let second = try await createNotebook(in: library, title: "Second")

        let notebooks = await library.notebooks().sorted { $0.sortKey < $1.sortKey }
        #expect(notebooks.map(\.id) == [first.id, second.id])
    }

    @Test func notebooksInTheTrashArePurgedAfterThirtyDays() async throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook(in: library)
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try await library.updateNotebook(notebook.id) { $0.deletedAt = deletedAt }

        await library.purgeExpiredTrash(now: deletedAt.addingTimeInterval(LibraryStore.trashRetention - 60))
        #expect(await library.notebooks().count == 1)

        await library.purgeExpiredTrash(now: deletedAt.addingTimeInterval(LibraryStore.trashRetention + 60))
        #expect(await library.notebooks().isEmpty)
    }

    @Test func deletingAFolderKeepsItsNotebooks() async throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try await library.createFolder(title: "Fall 2026")
        let notebook = try await createNotebook(in: library)
        try await library.updateNotebook(notebook.id) { $0.folderID = folder.id }

        try await library.deleteFolder(folder.id)

        #expect(await library.folders().isEmpty)
        #expect(await library.notebooks().first?.folderID == nil)
    }

    @Test func backupRestoresNotebooksAndInk() async throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let backup = LibraryBackup(library: library)
        let notebook = try await createNotebook(in: library)
        let store = try await library.store(for: notebook.id)
        let pageID = try #require(await store.manifest.activePages.first?.id)
        try await store.saveInk(.sample(seed: 9), for: pageID)
        let archive = root.appending(path: "backup.aar")

        try await backup.write(to: archive)
        try await library.deleteNotebookPermanently(notebook.id)
        try await backup.restore(from: archive)

        let restored = try await library.store(for: notebook.id)
        #expect(await restored.ink(for: pageID) == .ink(.sample(seed: 9)))
        let recovered = FileManager.default.directoryContents(at: library.layout.recoveredDirectory)
        #expect(recovered.contains { $0.lastPathComponent.hasPrefix("Library-before-restore") })
    }

    @Test func restoringSomethingThatIsNotABackupKeepsTheLibrary() async throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook(in: library)
        let notABackup = root.appending(path: "notes.aar")
        try Data("not an archive".utf8).write(to: notABackup)

        await #expect(throws: (any Error).self) {
            try await LibraryBackup(library: library).restore(from: notABackup)
        }
        #expect(await library.notebooks().map(\.id) == [notebook.id])
    }
}
