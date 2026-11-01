import Foundation
import NotebookData
import NotebookDomain
import Testing

@testable import Carrel

@MainActor
struct LibraryModelTests {
    private let root = FileManager.default.temporaryDirectory.appending(
        path: "LibraryModelTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )

    private func makeModel() throws -> LibraryModel {
        let layout = LibraryLayout(root: root)
        let store = try LibraryStore(layout: layout, supportedContentVersion: InkCodec.supportedContentVersion)
        return LibraryModel(store: store, snapshots: SnapshotStore(layout: layout))
    }

    @Test func blankTitlesBecomeUntitled() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()

        let notebook = try #require(await model.create(NotebookDraft(title: "   ")))

        #expect(notebook.title == "Untitled")
    }

    @Test func searchMatchesTitlesWithoutRegardToCaseOrAccents() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()
        _ = await model.create(NotebookDraft(title: "Résumé Drafts"))
        _ = await model.create(NotebookDraft(title: "Physics"))

        model.searchText = "resume"

        #expect(model.visibleNotebooks.map(\.title) == ["Résumé Drafts"])
    }

    @Test func trashedNotebooksOnlyAppearInTheTrash() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()
        let notebook = try #require(await model.create(NotebookDraft(title: "Old Notes")))

        await model.moveToTrash(notebook)

        #expect(model.visibleNotebooks.isEmpty)
        model.section = .trash
        #expect(model.visibleNotebooks.map(\.id) == [notebook.id])
    }

    @Test func notebooksCreatedInsideAFolderStayInIt() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()
        await model.createFolder(named: "Fall 2026")
        let folder = try #require(model.folders.first)

        _ = await model.create(NotebookDraft(title: "Algebra"))

        #expect(model.section == .folder(folder.id))
        #expect(model.visibleNotebooks.map(\.title) == ["Algebra"])
    }

    @Test func renamingFromTheLibraryChangesTheTitleEverywhere() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()
        let notebook = try #require(await model.create(NotebookDraft(title: "Algebra")))

        await model.rename(notebook, to: "Linear Algebra")

        #expect(model.notebooks.map(\.title) == ["Linear Algebra"])
        let session = try #require(await model.openSession(for: notebook))
        #expect(session.notebook.title == "Linear Algebra")
    }

    @Test func notebooksThatCannotBeReadAreCountedInsteadOfHidden() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let model = try makeModel()
        let package = NotebookPackage(url: LibraryLayout(root: root).packageURL(for: UUID()))
        try FileManager.default.createDirectory(at: package.url, withIntermediateDirectories: true)
        try Data("not a manifest".utf8).write(to: package.manifestURL)

        await model.load()

        #expect(model.unreadableNotebookCount == 1)
        #expect(FileManager.default.fileExists(atPath: package.manifestURL.path(percentEncoded: false)))
    }
}
