import SwiftUI

/// Bridges the UIKit writing surface into SwiftUI. PencilKit drawings never pass through SwiftUI state:
/// only page structure, the current tool and scroll requests do.
struct NotebookCanvas: UIViewControllerRepresentable {
    let session: EditorSession
    let palette: ToolPaletteModel
    let topBarHeight: CGFloat
    let onShowPalette: (CGPoint) -> Void

    func makeUIViewController(context: Context) -> NotebookCanvasViewController {
        let controller = NotebookCanvasViewController(session: session, palette: palette)
        controller.onShowPalette = onShowPalette
        return controller
    }

    func updateUIViewController(_ controller: NotebookCanvasViewController, context: Context) {
        controller.topBarHeight = topBarHeight
        controller.show(session.pages)
        controller.apply(tool: palette.currentTool, isRulerActive: palette.isRulerActive)
        // State must not change while SwiftUI is updating views, so each request is cleared right after.
        if let command = session.zoomCommand {
            controller.perform(command)
            Task { session.zoomCommand = nil }
        }
        if let target = session.scrollTarget {
            controller.scroll(toPage: target)
            Task { session.scrollTarget = nil }
        }
    }
}
