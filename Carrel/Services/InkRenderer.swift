import NotebookDomain
import PencilKit
import UIKit

/// Renders ink as it appears on paper.
enum InkRenderer {
    /// Ink is content: it keeps its colors in dark mode, so it is always rendered with the light appearance.
    static func image(of drawing: PKDrawing, pageSize: PageSize, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let bounds = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
            image = drawing.image(from: bounds, scale: scale)
        }
        return image
    }
}
