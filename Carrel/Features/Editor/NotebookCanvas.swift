import SwiftUI

/// Bridges the UIKit writing surface into SwiftUI. PencilKit drawings never pass through SwiftUI state:
/// only page structure, the current tool and scroll requests do.
struct NotebookCanvas: UIViewControllerRepresentable {
    let session: EditorSession
    let palette: ToolPaletteModel
    let onShowPalette: (CGPoint) -> Void

    func makeUIViewController(context: Context) -> NotebookCanvasViewController {
        let controller = NotebookCanvasViewController(session: session, palette: palette)
        controller.onShowPalette = onShowPalette
        return controller
    }

    func updateUIViewController(_ controller: NotebookCanvasViewController, context: Context) {
        controller.show(session.pages)
        controller.apply(tool: palette.currentTool, isRulerActive: palette.isRulerActive)
        if let target = session.scrollTarget {
            controller.scroll(toPage: target)
            Task { session.scrollTarget = nil }
        }
    }
}
