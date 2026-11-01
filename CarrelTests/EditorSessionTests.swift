import Foundation
import NotebookData
import NotebookDomain
import PencilKit
import Testing

@testable import Carrel

@MainActor
struct EditorSessionTests {
    private let root = FileManager.default.temporaryDirectory.appending(
        path: "EditorSessionTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )

    private func openSession() async throws -> (EditorSession, NotebookStore) {
        let library = try LibraryStore(
            layout: LibraryLayout(root: root),
            supportedContentVersion: InkCodec.supportedContentVersion
        )
        let notebook = try await library.createNotebook(
            title: "Physics",
            cover: Cover(preset: .navyCloth),
            paper: .standard,
            pageSize: .a4,
            folderID: nil
        )
        let store = try await library.store(for: notebook.id)
        return (await EditorSession.open(store), store)
    }

    private func drawing(strokeCount: Int) -> PKDrawing {
        let strokes = (0..<strokeCount).map { index in
            let points = [CGPoint(x: 40, y: 40 + index * 20), CGPoint(x: 200, y: 40 + index * 20)].map {
                PKStrokePoint(
                    location: $0,
                    timeOffset: 0,
                    size: CGSize(width: 3, height: 3),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            }
            return PKStroke(
                ink: PKInk(.pen, color: .black),
                path: PKStrokePath(controlPoints: points, creationDate: .now),
                transform: .identity,
                mask: nil
            )
        }
        return PKDrawing(strokes: strokes)
    }

    @Test func pageChangesAreShownAsSoonAsTheyAreSaved() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (session, _) = try await openSession()

        let page = try #require(await session.appendPage())

        #expect(session.pages.map(\.id).last == page.id)
        await session.moveToTrash(page.id)
        #expect(session.trashedPages.map(\.id) == [page.id])
    }

    @Test func duplicatingAPageCopiesStrokesThatWereNotSavedYet() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (session, _) = try await openSession()
        let original = try #require(session.pages.first)
        session.drawingDidChange(drawing(strokeCount: 2), on: original.id)

        await session.duplicatePage(original.id)

        let copy = try #require(session.pages.last)
        #expect(copy.id != original.id)
        #expect(await session.ink(for: copy.id).drawing?.strokes.count == 2)
    }

    @Test func theEditorStaysOpenWhileChangesCannotBeSaved() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (session, store) = try await openSession()
        let page = try #require(session.pages.first)
        try FileManager.default.removeItem(at: store.package.inkDirectory)

        session.drawingDidChange(drawing(strokeCount: 1), on: page.id)

        #expect(await session.saveAll() == false)
        #expect(session.errorMessage != nil)

        try FileManager.default.createDirectory(at: store.package.inkDirectory, withIntermediateDirectories: true)
        #expect(await session.saveAll())
    }
}
