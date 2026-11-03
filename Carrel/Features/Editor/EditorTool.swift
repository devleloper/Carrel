import PencilKit
import SwiftUI

/// A tool the palette can select. Pens are favorite slots: their settings belong to the slot index.
enum EditorTool: Hashable {
    case pen(Int)
    case highlighter
    case eraser
    case lasso
    case artInk(ArtInk)

    var title: LocalizedStringResource {
        switch self {
        case .pen(let index): "Pen \(index + 1)"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        case .artInk(let ink): ink.title
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        case .artInk(let ink): ink.systemImage
        }
    }

    /// The lasso has nothing to configure, so tapping it again does nothing.
    var hasSettings: Bool {
        self != .lasso
    }

    /// The colors the palette at the pen tip offers until the user has settled on colors of their own: distinct
    /// inks for pens and art inks, the highlighter colors for the highlighter.
    var starterColors: [UInt32] {
        switch self {
        case .pen, .artInk:
            [InkPalette.carbon, InkPalette.inkBlue, InkPalette.vermilion, InkPalette.green, InkPalette.plum].map(\.hex)
        case .highlighter: InkPalette.highlighters.map(\.hex)
        case .eraser, .lasso: []
        }
    }

    /// The colors offered in the tool's settings; empty for tools that do not draw.
    var swatches: [InkPalette.Swatch] {
        switch self {
        case .pen, .artInk: InkPalette.pens
        case .highlighter: InkPalette.highlighters
        case .eraser, .lasso: []
        }
    }
}

/// Inks for sketching rather than notes. They wait under More instead of taking one of the palette's seven
/// places.
enum ArtInk: String, Codable, CaseIterable {
    case watercolor
    case crayon

    var title: LocalizedStringResource {
        switch self {
        case .watercolor: "Watercolor"
        case .crayon: "Crayon"
        }
    }

    var systemImage: String {
        switch self {
        case .watercolor: "paintbrush.pointed"
        case .crayon: "scribble.variable"
        }
    }

    var pencilKitType: PKInkingTool.InkType {
        switch self {
        case .watercolor: .watercolor
        case .crayon: .crayon
        }
    }
}
