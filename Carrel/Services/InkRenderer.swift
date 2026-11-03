import NotebookDomain
import PencilKit
import UIKit

/// Renders ink as it appears on its page.
enum InkRenderer {
    /// Ink is rendered in the appearance of the page's paper, not the app's theme, so thumbnails and exports
    /// match the canvas. `image(from:scale:)` follows the current trait collection; the explicit
    /// `draw(in:frame:from:darkUserInterfaceStyle:)` is async, and the PDF renderer and the canvas hand-off need
    /// the image synchronously.
    static func image(of drawing: PKDrawing, on page: Page, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: page.paper.tone.inkAppearance).performAsCurrent {
            let bounds = CGRect(x: 0, y: 0, width: page.size.width, height: page.size.height)
            image = drawing.image(from: bounds, scale: scale)
        }
        return image
    }
}
