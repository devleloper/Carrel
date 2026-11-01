import UIKit

/// Turns Apple Pencil double tap and squeeze into palette actions, following the user's system preferences.
final class PencilInteractionHandler: NSObject, UIPencilInteractionDelegate {
    private let palette: ToolPaletteModel
    private let showPalette: (CGPoint?) -> Void

    /// - Parameter showPalette: Opens the compact palette at the hover location, or `nil` when the pencil is
    ///   away from the screen.
    init(palette: ToolPaletteModel, showPalette: @escaping (CGPoint?) -> Void) {
        self.palette = palette
        self.showPalette = showPalette
    }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        switch UIPencilInteraction.preferredTapAction {
        case .switchEraser:
            palette.toggleEraser()
        case .switchPrevious:
            palette.selectPrevious()
        case .showColorPalette, .showInkAttributes, .showContextualPalette:
            showPalette(tap.hoverPose?.location)
        default:
            break
        }
    }

    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        guard squeeze.phase == .ended, UIPencilInteraction.preferredSqueezeAction != .ignore else {
            return
        }
        showPalette(squeeze.hoverPose?.location)
    }
}
