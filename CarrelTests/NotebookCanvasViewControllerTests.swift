import Foundation
import NotebookData
import NotebookDomain
import Testing
import UIKit

@testable import Carrel

@MainActor
struct NotebookCanvasViewControllerTests {
    private let root = FileManager.default.temporaryDirectory.appending(
        path: "NotebookCanvasViewControllerTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )

    /// The writing surface in a window of the test host, laid out on a new notebook.
    private func showCanvas() async throws -> (NotebookCanvasViewController, UIScrollView, UIWindow) {
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
        let session = await EditorSession.open(try await library.store(for: notebook.id))
        let defaults = try #require(UserDefaults(suiteName: "NotebookCanvasViewControllerTests-\(UUID().uuidString)"))
        let controller = NotebookCanvasViewController(session: session, palette: ToolPaletteModel(defaults: defaults))

        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 820, height: 1180)
        window.rootViewController = controller
        window.isHidden = false
        controller.show(session.pages)
        window.layoutIfNeeded()
        let scrollView = try #require(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
        return (controller, scrollView, window)
    }

    @Test func theFirstPageStartsBelowTheTopBarOnceItsHeightArrives() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (controller, scrollView, window) = try await showCanvas()
        defer { window.isHidden = true }
        let safeAreaTop = scrollView.safeAreaInsets.top

        controller.topBarHeight = 56

        #expect(scrollView.adjustedContentInset.top == safeAreaTop + 56)
        #expect(scrollView.contentOffset.y == -scrollView.adjustedContentInset.top)
    }

    @Test func aScrolledNotebookStaysPutWhenTheTopBarChangesHeight() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let (controller, scrollView, window) = try await showCanvas()
        defer { window.isHidden = true }
        controller.topBarHeight = 56

        scrollView.contentOffset.y = 300
        controller.topBarHeight = 72

        #expect(scrollView.contentOffset.y == 300)
        #expect(scrollView.adjustedContentInset.top == scrollView.safeAreaInsets.top + 72)
    }
}
