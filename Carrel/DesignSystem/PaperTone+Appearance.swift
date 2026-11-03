import NotebookDomain
import UIKit

extension PaperTone {
    /// The appearance a page and its ink take on this paper, whatever the app's theme. PencilKit keeps ink colors
    /// in their light variant and converts them for the dark appearance, so the same strokes stay readable on
    /// Night paper while the colors stored in the notebook never change.
    var inkAppearance: UIUserInterfaceStyle {
        switch self {
        case .white, .cream, .linen: .light
        case .night: .dark
        }
    }

    /// The line around a page on this paper. Night casts no visible shadow on the dark desk, so it gets a faint
    /// light edge instead. Pages keep it on the light desk too: they take their paper's appearance, not the
    /// desk's, and against the light desk the shadow already separates the page.
    var edge: UIColor? {
        switch self {
        case .white, .cream, .linen: nil
        case .night: Palette.nightPaperEdge
        }
    }
}
