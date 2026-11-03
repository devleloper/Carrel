import PencilKit
import SwiftUI

/// The three widths every drawing tool offers. Steps instead of a slider make a width easy to find again.
enum StrokeWidth: String, Codable, CaseIterable {
    case fine
    case medium
    case bold

    var title: LocalizedStringResource {
        switch self {
        case .fine: "Fine"
        case .medium: "Medium"
        case .bold: "Bold"
        }
    }

    /// The neighboring width in `offset` steps, stopping at the thinnest and the boldest.
    func stepped(by offset: Int) -> StrokeWidth {
        let cases = Self.allCases
        let index = cases.firstIndex(of: self) ?? 0
        return cases[min(max(index + offset, 0), cases.count - 1)]
    }

    /// PencilKit's width ranges differ by an order of magnitude between inks (monoline stops at 4 pt, the
    /// marker starts at 7.5), so each ink gets its own three steps inside its valid range.
    func points(for inkType: PKInkingTool.InkType) -> CGFloat {
        let steps: (fine: CGFloat, medium: CGFloat, bold: CGFloat)
        switch inkType {
        case .pen: steps = (1.8, 2.7, 4.5)
        case .monoline: steps = (0.8, 1.5, 3)
        case .fountainPen: steps = (2.5, 4, 7)
        case .pencil: steps = (2.4, 4, 7)
        case .marker: steps = (12, 20, 32)
        case .watercolor: steps = (20, 40, 64)
        case .crayon: steps = (16, 30, 46)
        default:
            let base = inkType.defaultWidth
            steps = (base * 0.6, base, base * 1.6)
        }
        let width =
            switch self {
            case .fine: steps.fine
            case .medium: steps.medium
            case .bold: steps.bold
            }
        return min(max(width, inkType.validWidthRange.lowerBound), inkType.validWidthRange.upperBound)
    }

    /// Widths of the pixel eraser; PencilKit does not make it thinner than about 16 pt.
    var eraserPoints: CGFloat {
        switch self {
        case .fine: 18
        case .medium: 32
        case .bold: 56
        }
    }
}

struct PenSettings: Codable, Hashable {
    var inkType: InkType
    var colorHex: UInt32
    var width: StrokeWidth
    /// Colors the user settled on lately for this pen, newest first, for the palette at the pen tip.
    var recentColors: [UInt32] = []

    enum InkType: String, Codable, CaseIterable {
        case pen
        case monoline
        case fountainPen
        case pencil

        var pencilKitType: PKInkingTool.InkType {
            switch self {
            case .pen: .pen
            case .monoline: .monoline
            case .fountainPen: .fountainPen
            case .pencil: .pencil
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .pen: "Ballpoint"
            case .monoline: "Monoline"
            case .fountainPen: "Fountain"
            case .pencil: "Pencil"
            }
        }
    }
}

/// Color and width of a tool whose ink type is fixed.
struct InkSettings: Codable, Hashable {
    var colorHex: UInt32
    var width: StrokeWidth
    /// Colors the user settled on lately for this tool, newest first, for the palette at the pen tip.
    var recentColors: [UInt32] = []
}

struct EraserSettings: Codable, Hashable {
    var mode: Mode
    var width: StrokeWidth

    enum Mode: String, Codable, CaseIterable {
        /// Removes whole strokes. The default: quick for notes, and it never cuts a stroke in two.
        case stroke
        /// Erases the pixels under a fixed-width tip.
        case pixel

        var title: LocalizedStringResource {
            switch self {
            case .stroke: "Whole Stroke"
            case .pixel: "Pixel"
            }
        }
    }
}

/// The user's palette. Persisted so pens, colors and widths survive relaunches.
struct ToolSettings: Codable, Hashable {
    var pens: [PenSettings]
    var highlighter: InkSettings
    var watercolor: InkSettings
    var crayon: InkSettings
    var eraser: EraserSettings

    static let standard = ToolSettings(
        pens: [
            PenSettings(inkType: .fountainPen, colorHex: InkPalette.carbon.hex, width: .medium),
            PenSettings(inkType: .fountainPen, colorHex: InkPalette.inkBlue.hex, width: .medium),
            PenSettings(inkType: .pen, colorHex: InkPalette.vermilion.hex, width: .medium),
        ],
        highlighter: InkSettings(colorHex: InkPalette.yellow.hex, width: .medium),
        watercolor: InkSettings(colorHex: InkPalette.sky.hex, width: .medium),
        crayon: InkSettings(colorHex: InkPalette.vermilion.hex, width: .medium),
        eraser: EraserSettings(mode: .stroke, width: .medium)
    )

    static let recentColorLimit = 5

    /// Puts `hex` first among the recent colors of `tool`, which keeps the newest five.
    mutating func rememberColor(_ hex: UInt32, for tool: EditorTool) {
        guard let path = recentColorsPath(for: tool) else {
            return
        }
        var colors = self[keyPath: path]
        colors.removeAll { $0 == hex }
        colors.insert(hex, at: 0)
        self[keyPath: path] = Array(colors.prefix(Self.recentColorLimit))
    }

    private static let defaultsKey = "toolSettings"

    /// Settings that cannot be read at all are replaced by the standard palette; partly readable ones keep what
    /// they can, as their decoding describes.
    static func load(from defaults: UserDefaults) -> ToolSettings {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let settings = try? JSONDecoder().decode(ToolSettings.self, from: data)
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

    /// Where a tool keeps its color, or `nil` for tools without one.
    func colorPath(for tool: EditorTool) -> WritableKeyPath<ToolSettings, UInt32>? {
        switch tool {
        case .pen(let index): pens.indices.contains(index) ? \.pens[index].colorHex : nil
        case .highlighter: \.highlighter.colorHex
        case .artInk(let ink): Self.path(for: ink).appending(path: \.colorHex)
        case .eraser, .lasso: nil
        }
    }

    /// Where a tool keeps its width, or `nil` for tools without one.
    func widthPath(for tool: EditorTool) -> WritableKeyPath<ToolSettings, StrokeWidth>? {
        switch tool {
        case .pen(let index): pens.indices.contains(index) ? \.pens[index].width : nil
        case .highlighter: \.highlighter.width
        case .artInk(let ink): Self.path(for: ink).appending(path: \.width)
        case .eraser: \.eraser.width
        case .lasso: nil
        }
    }

    /// Where a tool keeps its recent colors, or `nil` for tools without a color.
    func recentColorsPath(for tool: EditorTool) -> WritableKeyPath<ToolSettings, [UInt32]>? {
        switch tool {
        case .pen(let index): pens.indices.contains(index) ? \.pens[index].recentColors : nil
        case .highlighter: \.highlighter.recentColors
        case .artInk(let ink): Self.path(for: ink).appending(path: \.recentColors)
        case .eraser, .lasso: nil
        }
    }

    static func path(for ink: ArtInk) -> WritableKeyPath<ToolSettings, InkSettings> {
        switch ink {
        case .watercolor: \.watercolor
        case .crayon: \.crayon
        }
    }
}

extension ToolSettings {
    /// Saved settings are read field by field, so settings written by an earlier or a later version of the app
    /// keep everything they share with this one; synthesized decoding would throw on the first missing field or
    /// unknown case and cost the user the whole palette whenever a setting is added. A tool that cannot be read
    /// gets its standard setup, and so do the pens when there is a different number of them, which would leave
    /// palette slots without a pen.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pens = container.decode(.pens, or: Self.standard.pens)
        self.init(
            pens: pens.count == Self.standard.pens.count ? pens : Self.standard.pens,
            highlighter: container.decode(.highlighter, or: Self.standard.highlighter),
            watercolor: container.decode(.watercolor, or: Self.standard.watercolor),
            crayon: container.decode(.crayon, or: Self.standard.crayon),
            eraser: container.decode(.eraser, or: Self.standard.eraser)
        )
    }
}

/// A pen without a color cannot draw anything the user chose, so it fails and the pens fall back as a whole.
extension PenSettings {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            inkType: container.decode(.inkType, or: .fountainPen),
            colorHex: try container.decode(UInt32.self, forKey: .colorHex),
            width: container.decode(.width, or: .medium),
            recentColors: container.decode(.recentColors, or: [])
        )
    }
}

extension InkSettings {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            colorHex: try container.decode(UInt32.self, forKey: .colorHex),
            width: container.decode(.width, or: .medium),
            recentColors: container.decode(.recentColors, or: [])
        )
    }
}

extension EraserSettings {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(mode: container.decode(.mode, or: .stroke), width: container.decode(.width, or: .medium))
    }
}

extension KeyedDecodingContainer {
    /// The value under `key`, or `fallback` when it is missing or cannot be read, such as an option added by a
    /// later version.
    fileprivate func decode<Value: Decodable>(_ key: Key, or fallback: Value) -> Value {
        (try? decodeIfPresent(Value.self, forKey: key)) ?? fallback
    }
}
