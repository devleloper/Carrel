import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct LibraryStoreTests {
    private let root: URL
    private let library: LibraryStore

    init() throws {
        root = try makeTemporaryDirectory()
        library = try LibraryStore(layout: LibraryLayout(root: root), supportedContentVersion: 5)
    }

    private func createNotebook(title: String = "Physics") async throws -> Notebook {
        try await library.createNotebook(
            title: title,
            cover: Cover(preset: .navyCloth),
            paper: .standard,
            pageSize: .a4,
            folderID: nil
        )
    }

    private var replacedLibraries: [URL] {
        FileManager.default.directoryContents(at: library.layout.recoveredDirectory)
            .filter { $0.lastPathComponent.hasPrefix("Library-before-restore") }
    }

    @Test func createdNotebooksAreListedInCreationOrder() async throws {
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try await createNotebook(title: "First")
        let second = try await createNotebook(title: "Second")

        let notebooks = await library.contents().notebooks.sorted { $0.sortKey < $1.sortKey }
        #expect(notebooks.map(\.id) == [first.id, second.id])
    }

    @Test func notebooksInTheTrashArePurgedAfterTheRetentionPeriod() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try await library.organizeNotebook(notebook.id) { $0.deletedAt = deletedAt }

        await library.purgeExpiredTrash(now: deletedAt.addingTimeInterval(LibraryStore.trashRetention - 60))
        #expect(await library.contents().notebooks.count == 1)

        await library.purgeExpiredTrash(now: deletedAt.addingTimeInterval(LibraryStore.trashRetention + 60))
        #expect(await library.contents().notebooks.isEmpty)
    }

    @Test func blankTitlesAreIgnoredWhenRenamingAFolder() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try await library.createFolder(title: "Fall 2026")

        try await library.renameFolder(folder.id, to: "  ")

        #expect(await library.folders().map(\.title) == ["Fall 2026"])
    }

    @Test func deletingAFolderKeepsItsNotebooks() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = try await library.createFolder(title: "Fall 2026")
        let notebook = try await createNotebook()
        try await library.organizeNotebook(notebook.id) { $0.folderID = folder.id }

        try await library.deleteFolder(folder.id)

        #expect(await library.folders().isEmpty)
        #expect(await library.contents().notebooks.first?.folderID == nil)
    }

    @Test func renamingFromTheLibraryCountsAsAnEdit() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let later = Date(timeIntervalSince1970: 1_900_000_000)

        try await library.renameNotebook(notebook.id, to: "Physics II", now: later)

        let renamed = try #require(await library.contents().notebooks.first)
        #expect(renamed.title == "Physics II")
        #expect(renamed.modifiedAt == later)
    }

    @Test func anUnreadablePackageIsListedAndKept() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let package = NotebookPackage(url: library.layout.packageURL(for: notebook.id))
        try Data("{ damaged".utf8).write(to: package.manifestURL)

        let contents = await LibraryStore(layout: library.layout, supportedContentVersion: 5).contents()

        #expect(contents.notebooks.isEmpty)
        #expect(contents.unreadable == [UnreadableNotebook(id: notebook.id, reason: .manifestUnreadable)])
        #expect(FileManager.default.fileExists(atPath: package.url.path(percentEncoded: false)))
    }

    // MARK: Backup

    @Test func backupRestoresNotebooksAndInk() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let backup = LibraryBackup(store: library)
        let notebook = try await createNotebook()
        let store = try await library.store(for: notebook.id)
        let pageID = try #require(await store.manifest.activePages.first?.id)
        try await store.saveInk(.sample(seed: 9), for: pageID)
        let archive = root.appending(path: "backup.aar")

        try await backup.write(to: archive)
        try await library.deleteNotebookPermanently(notebook.id)
        try await backup.restore(from: archive)

        #expect(try await library.store(for: notebook.id).ink(for: pageID) == .ink(.sample(seed: 9)))
        #expect(replacedLibraries.count == 1)
    }

    @Test func anArchiveWithoutNotebooksIsNotABackup() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let unrelated = root.appending(path: "Unrelated", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: unrelated.appending(path: "notes.txt"))
        let archive = root.appending(path: "unrelated.aar")
        try LibraryArchive.write(directory: unrelated, to: archive)

        await #expect(throws: LibraryBackupError.notABackup) {
            try await LibraryBackup(store: library).restore(from: archive)
        }
        #expect(await library.contents().notebooks.map(\.id) == [notebook.id])
        #expect(replacedLibraries.isEmpty)
    }

    @Test func aFileThatIsNotAnArchiveLeavesTheLibraryUntouched() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let garbage = root.appending(path: "notes.aar")
        try Data("not an archive".utf8).write(to: garbage)

        await #expect(throws: (any Error).self) {
            try await LibraryBackup(store: library).restore(from: garbage)
        }
        #expect(await library.contents().notebooks.map(\.id) == [notebook.id])
        #expect(replacedLibraries.isEmpty)
    }

    @Test func aBackupFromANewerAppIsRejectedBeforeAnythingMoves() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let notebook = try await createNotebook()
        let package = NotebookPackage(url: library.layout.packageURL(for: notebook.id))
        let original = try Data(contentsOf: package.manifestURL)
        try Data(#"{ "schemaVersion": 99 }"#.utf8).write(to: package.manifestURL)
        let archive = root.appending(path: "future.aar")
        try LibraryArchive.write(directory: library.layout.libraryDirectory, to: archive)
        try original.write(to: package.manifestURL)

        await #expect(throws: LibraryStoreError.schemaNewerThanApp) {
            try await LibraryBackup(store: library).restore(from: archive)
        }
        #expect(replacedLibraries.isEmpty)
        #expect(try Data(contentsOf: package.manifestURL) == original)
    }
}
