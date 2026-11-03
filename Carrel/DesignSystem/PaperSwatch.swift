import NotebookDomain
import SwiftUI

/// The top left corner of a page, drawn by the shared renderer at a fixed magnification. A whole page shrunk to a
/// swatch would thin its rulings to nothing; the corner shows the line spacing, the margin and the tone as they are.
struct PaperSwatch: View {
    let paper: Paper

    /// The part of the page a swatch shows, in page points: from the left edge past the margin line, and from
    /// just above the first ruled line.
    private static let visibleWidth: CGFloat = 110
    private static let visibleTop: CGFloat = 45

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                let pageSize = PageSize.a4
                let scale = size.width / Self.visibleWidth
                let page = CGRect(
                    x: 0,
                    y: -Self.visibleTop * scale,
                    width: pageSize.width * scale,
                    height: pageSize.height * scale
                )
                PaperRenderer.draw(paper, pageSize: pageSize, in: page, context: cgContext)
            }
        }
    }
}
