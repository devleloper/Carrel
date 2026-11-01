import PencilKit
import SwiftUI

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
}

struct PenSettings: Codable, Hashable {
    var inkType: InkType
    var colorHex: UInt32
    var width: CGFloat

    enum InkType: String, Codable, CaseIterable {
        case pen
        case fountainPen
        case monoline
        case pencil

        var pencilKitType: PKInkingTool.InkType {
            switch self {
            case .pen: .pen
            case .fountainPen: .fountainPen
            case .monoline: .monoline
            case .pencil: .pencil
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .pen: "Ballpoint"
            case .fountainPen: "Fountain"
            case .monoline: "Monoline"
            case .pencil: "Pencil"
            }
        }
    }
}

/// The user's palette. Persisted so pens, colors and widths survive relaunches.
struct ToolSettings: Codable, Hashable {
    var pens: [PenSettings]
    var highlighterHex: UInt32
    var highlighterWidth: CGFloat
    var isPreciseEraser: Bool
    var eraserWidth: CGFloat

    static let standard = ToolSettings(
        pens: [
            PenSettings(inkType: .fountainPen, colorHex: InkPalette.carbon.hex, width: 3),
            PenSettings(inkType: .fountainPen, colorHex: InkPalette.inkBlue.hex, width: 3),
            PenSettings(inkType: .pen, colorHex: InkPalette.vermilion.hex, width: 2.5),
        ],
        highlighterHex: InkPalette.yellow.hex,
        highlighterWidth: 22,
        isPreciseEraser: false,
        eraserWidth: 16
    )

    private static let defaultsKey = "toolSettings"

    /// Settings saved with a different number of pens would leave palette slots without a pen, so they are
    /// replaced by the standard palette.
    static func load(from defaults: UserDefaults) -> ToolSettings {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let settings = try? JSONDecoder().decode(ToolSettings.self, from: data),
            settings.pens.count == standard.pens.count
        else {
            return .standard
        }
        return settings
    }

    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// The selected tool and the user's palette, shared by every notebook so the pen stays in hand between them.
@Observable
final class ToolPaletteModel {
    var settings: ToolSettings {
        didSet { settings.save(to: defaults) }
    }
    private(set) var selection: EditorTool = .pen(0)
    var isRulerActive = false
    @ObservationIgnored private var previousSelection: EditorTool = .pen(0)
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.settings = ToolSettings.load(from: defaults)
    }

    func select(_ tool: EditorTool) {
        guard tool != selection else {
            return
        }
        previousSelection = selection
        selection = tool
    }

    func selectPrevious() {
        select(previousSelection)
    }

    func toggleEraser() {
        if selection == .eraser {
            selectPrevious()
        } else {
            select(.eraser)
        }
    }

    /// Every tool in palette order: the favorite pens, then highlighter, eraser and lasso.
    var tools: [EditorTool] {
        settings.pens.indices.map(EditorTool.pen) + [.highlighter, .eraser, .lasso]
    }

    func pen(at index: Int) -> PenSettings? {
        settings.pens.indices.contains(index) ? settings.pens[index] : nil
    }

    var currentTool: any PKTool {
        switch selection {
        case .pen(let index):
            let pen = pen(at: index) ?? ToolSettings.standard.pens[0]
            return PKInkingTool(pen.inkType.pencilKitType, color: UIColor(hex: pen.colorHex), width: pen.width)
        case .highlighter:
            return PKInkingTool(.marker, color: UIColor(hex: settings.highlighterHex), width: settings.highlighterWidth)
        case .eraser:
            if settings.isPreciseEraser {
                return PKEraserTool(.bitmap, width: settings.eraserWidth)
            }
            return PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        }
    }
}
