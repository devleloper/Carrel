import NotebookDomain
import PencilKit
import UIKit

/// The latest drawing of every page the editor has loaded or changed.
///
/// The autosaver reads from here when it writes, so a drawing is encoded once per save, not once per stroke.
final class DrawingCache {
    private var drawings: [Page.ID: PKDrawing] = [:]

    subscript(pageID: Page.ID) -> PKDrawing? {
        get { drawings[pageID] }
        set { drawings[pageID] = newValue }
    }

    func inkData(for pageID: Page.ID) -> InkData? {
        drawings[pageID].map(InkCodec.inkData(from:))
    }

    func image(for page: Page, scale: CGFloat) -> UIImage? {
        guard let drawing = drawings[page.id], !drawing.strokes.isEmpty else {
            return nil
        }
        return InkRenderer.image(of: drawing, on: page, scale: scale)
    }
}
