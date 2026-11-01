import PencilKit
import SwiftUI

enum EditorTool: Hashable {
    case pen(Int)
    case highlighter
    case eraser
    case lasso
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
            PenSettings(inkType: .fountainPen, colorHex: 0x1E1E1C, width: 3),
            PenSettings(inkType: .fountainPen, colorHex: 0x1649AE, width: 3),
            PenSettings(inkType: .pen, colorHex: 0xCB380D, width: 2.5),
        ],
        highlighterHex: 0xFFE45C,
        highlighterWidth: 22,
        isPreciseEraser: false,
        eraserWidth: 16
    )

    private static let defaultsKey = "toolSettings"

    static func load(from defaults: UserDefaults = .standard) -> ToolSettings {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let settings = try? JSONDecoder().decode(ToolSettings.self, from: data),
            settings.pens.count == standard.pens.count
        else {
            return .standard
        }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

@Observable
final class ToolPaletteModel {
    var settings: ToolSettings {
        didSet { settings.save() }
    }
    private(set) var selection: EditorTool = .pen(0)
    var isRulerActive = false
    @ObservationIgnored private var previousSelection: EditorTool = .pen(0)

    init(settings: ToolSettings = .load()) {
        self.settings = settings
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
        selection == .eraser ? selectPrevious() : select(.eraser)
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
            return settings.isPreciseEraser ? PKEraserTool(.bitmap, width: settings.eraserWidth) : PKEraserTool(.vector)
        case .lasso:
            return PKLassoTool()
        }
    }
}
