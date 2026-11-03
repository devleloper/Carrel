import SwiftUI

/// A tool the palette can select. Pens are favorite slots: their settings belong to the slot index.
enum EditorTool: Hashable {
    case pen(Int)
    case highlighter
    case eraser
    case lasso

    var title: LocalizedStringResource {
        switch self {
        case .pen(let index): "Pen \(index + 1)"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }

    /// The lasso has nothing to configure, so tapping it again does nothing.
    var hasSettings: Bool {
        self != .lasso
    }

    /// The colors offered in the tool's settings; empty for tools that do not draw.
    var swatches: [InkPalette.Swatch] {
        switch self {
        case .pen: InkPalette.pens
        case .highlighter: InkPalette.highlighters
        case .eraser, .lasso: []
        }
    }
}
