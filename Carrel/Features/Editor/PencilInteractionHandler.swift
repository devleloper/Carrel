import UIKit

/// Turns Apple Pencil double tap and squeeze into palette actions, following the user's system preferences.
final class PencilInteractionHandler: NSObject, UIPencilInteractionDelegate {
    private let palette: ToolPaletteModel
    private let togglePalette: (CGPoint?) -> Void

    /// - Parameter togglePalette: Opens the palette at the pen tip, at the hover location or `nil` when the pencil
    ///   is away from the screen, or closes it when it is open.
    init(palette: ToolPaletteModel, togglePalette: @escaping (CGPoint?) -> Void) {
        self.palette = palette
        self.togglePalette = togglePalette
    }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        perform(UIPencilInteraction.preferredTapAction, hoverLocation: tap.hoverPose?.location)
    }

    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        guard squeeze.phase == .ended else {
            return
        }
        perform(UIPencilInteraction.preferredSqueezeAction, hoverLocation: squeeze.hoverPose?.location)
    }

    /// The system shortcut and "ignore" are left to the system: the user chose them over the palette.
    private func perform(_ action: UIPencilPreferredAction, hoverLocation: CGPoint?) {
        switch action {
        case .switchEraser:
            palette.toggleEraser()
        case .switchPrevious:
            palette.selectPrevious()
        case .showColorPalette, .showInkAttributes, .showContextualPalette:
            togglePalette(hoverLocation)
        default:
            break
        }
    }
}
