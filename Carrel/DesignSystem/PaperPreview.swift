import NotebookDomain
import SwiftUI

/// Paper as SwiftUI draws it, with the same renderer as the editor and PDF export.
struct PaperPreview: View {
    let paper: Paper
    let size: PageSize

    var body: some View {
        Canvas { context, canvasSize in
            context.withCGContext { cgContext in
                let bounds = CGRect(origin: .zero, size: canvasSize)
                PaperRenderer.draw(paper, pageSize: size, in: bounds, context: cgContext)
            }
        }
    }
}
