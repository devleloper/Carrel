import PencilKit
import SwiftUI

/// The selected tool and the user's palette, shared by every notebook so the pen stays in hand between them.
@Observable
final class ToolPaletteModel {
    var settings: ToolSettings {
        didSet { settings.save(to: defaults) }
    }
    private(set) var selection: EditorTool = .pen(0)
    /// The tool whose settings are open. It is always the selected tool.
    private(set) var toolWithOpenSettings: EditorTool?
    var isRulerActive = false
    /// Where the palette at the pen tip is open; `nil` while it is closed.
    private(set) var penTipPaletteAnchor: PenTipPaletteAnchor?
    /// The main palette's frame in global coordinates, which the palette at the pen tip keeps clear of. It is
    /// layout, not a setting, so it is not saved.
    var mainPaletteFrame: CGRect?
    var side: PaletteSide {
        didSet {
            defaults.set(side.rawValue, forKey: Self.sideKey)
            dismissPenTipPalette()
        }
    }
    var isCollapsed: Bool {
        didSet {
            defaults.set(isCollapsed, forKey: Self.collapsedKey)
            dismissPenTipPalette()
            if isCollapsed {
                dismissSettings()
            }
        }
    }
    @ObservationIgnored private var previousSelection: EditorTool = .pen(0)
    @ObservationIgnored private let defaults: UserDefaults

    private static let sideKey = "toolPaletteSide"
    private static let collapsedKey = "toolPaletteIsCollapsed"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.settings = ToolSettings.load(from: defaults)
        self.side = defaults.string(forKey: Self.sideKey).flatMap(PaletteSide.init(rawValue:)) ?? .leading
        self.isCollapsed = defaults.bool(forKey: Self.collapsedKey)
    }

    /// Every tool in palette order: the favorite pens, then highlighter, eraser and lasso.
    var tools: [EditorTool] {
        settings.pens.indices.map(EditorTool.pen) + [.highlighter, .eraser, .lasso]
    }

    /// The tools behind More.
    let moreTools = ArtInk.allCases.map(EditorTool.artInk)

    func pen(at index: Int) -> PenSettings? {
        settings.pens.indices.contains(index) ? settings.pens[index] : nil
    }

    // MARK: Selection

    /// The palette's one gesture: a tap selects a tool, and a tap on the selected tool opens its settings. The
    /// palette at the pen tip closes, since it would show the tool it opened for.
    func choose(_ tool: EditorTool) {
        dismissPenTipPalette()
        if tool == selection {
            guard tool.hasSettings else {
                return
            }
            // The color in hand is about to change, and it should stay one tap away at the pen tip.
            rememberColor(of: tool)
            toolWithOpenSettings = tool
        } else {
            select(tool)
        }
    }

    /// Closing the settings of a tool settles its color, so it joins the tool's recent colors. Remembering every
    /// change instead would fill them with the steps of a drag through the color picker.
    func dismissSettings() {
        // Observation reports every assignment, and a drag of the palette calls this on each move.
        guard let tool = toolWithOpenSettings else {
            return
        }
        rememberColor(of: tool)
        toolWithOpenSettings = nil
    }

    private func rememberColor(of tool: EditorTool) {
        if let hex = color(of: tool) {
            settings.rememberColor(hex, for: tool)
        }
    }

    func select(_ tool: EditorTool) {
        guard tool != selection else {
            return
        }
        dismissSettings()
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

    // MARK: Palette at the pen tip

    var isPenTipPaletteOpen: Bool {
        penTipPaletteAnchor != nil
    }

    /// Opens the palette at `location`, the pen tip in the editor's coordinates, or beside the main palette when
    /// there is no tip to open at.
    func showPenTipPalette(at location: CGPoint?) {
        dismissSettings()
        penTipPaletteAnchor = location.map(PenTipPaletteAnchor.penTip) ?? .mainPalette
    }

    /// The pencil gesture that opens the palette also closes it.
    func togglePenTipPalette(at location: CGPoint?) {
        if isPenTipPaletteOpen {
            dismissPenTipPalette()
        } else {
            showPenTipPalette(at: location)
        }
    }

    func dismissPenTipPalette() {
        if penTipPaletteAnchor != nil {
            penTipPaletteAnchor = nil
        }
    }

    /// The second row of the palette at the pen tip: the tool's current color, then the colors settled on for it
    /// lately, filled up to five from its starter colors. Tools without a color have none.
    var quickColors: [UInt32] {
        guard let current = color(of: selection), let path = settings.recentColorsPath(for: selection) else {
            return []
        }
        var colors: [UInt32] = []
        for hex in [current] + settings[keyPath: path] + selection.starterColors where !colors.contains(hex) {
            colors.append(hex)
        }
        return Array(colors.prefix(ToolSettings.recentColorLimit))
    }

    /// A choice at the pen tip is final, so the palette closes with it.
    func selectAtPenTip(_ tool: EditorTool) {
        select(tool)
        dismissPenTipPalette()
    }

    /// The color the tool had stays among its recent colors, so switching back is one tap.
    func applyQuickColor(_ hex: UInt32) {
        rememberColor(of: selection)
        setColor(hex, for: selection)
        settings.rememberColor(hex, for: selection)
        dismissPenTipPalette()
    }

    // MARK: Tool settings

    func color(of tool: EditorTool) -> UInt32? {
        settings.colorPath(for: tool).map { settings[keyPath: $0] }
    }

    func setColor(_ hex: UInt32, for tool: EditorTool) {
        if let path = settings.colorPath(for: tool) {
            settings[keyPath: path] = hex
        }
    }

    /// The width the tool draws with; `nil` for tools without one and for the eraser while it removes whole
    /// strokes.
    func width(of tool: EditorTool) -> StrokeWidth? {
        if tool == .eraser, settings.eraser.mode == .stroke {
            return nil
        }
        return settings.widthPath(for: tool).map { settings[keyPath: $0] }
    }

    func setWidth(_ width: StrokeWidth, for tool: EditorTool) {
        if let path = settings.widthPath(for: tool) {
            settings[keyPath: path] = width
        }
    }

    /// How the tool is set up, in the words of its settings, such as "Ink Blue, Medium, Fountain". VoiceOver
    /// reads it after the tool's name.
    func summary(of tool: EditorTool) -> String {
        var parts: [LocalizedStringResource] = []
        if let hex = color(of: tool) {
            parts.append(InkPalette.name(for: hex))
        }
        if tool == .eraser {
            parts.append(settings.eraser.mode.title)
        }
        if let width = width(of: tool) {
            parts.append(width.title)
        }
        if case .pen(let index) = tool, let pen = pen(at: index) {
            parts.append(pen.inkType.title)
        }
        return parts.map { String(localized: $0) }.joined(separator: ", ")
    }

    // MARK: PencilKit

    var currentTool: any PKTool {
        switch selection {
        case .pen(let index):
            let pen = pen(at: index) ?? ToolSettings.standard.pens[0]
            return inkingTool(pen.inkType.pencilKitType, colorHex: pen.colorHex, width: pen.width)
        case .highlighter:
            return inkingTool(.marker, colorHex: settings.highlighter.colorHex, width: settings.highlighter.width)
        case .eraser:
            switch settings.eraser.mode {
            case .stroke: return PKEraserTool(.vector)
            case .pixel: return PKEraserTool(.fixedWidthBitmap, width: settings.eraser.width.eraserPoints)
            }
        case .lasso:
            return PKLassoTool()
        case .artInk(let artInk):
            let ink = settings[keyPath: ToolSettings.path(for: artInk)]
            return inkingTool(artInk.pencilKitType, colorHex: ink.colorHex, width: ink.width)
        }
    }

    private func inkingTool(_ inkType: PKInkingTool.InkType, colorHex: UInt32, width: StrokeWidth) -> PKInkingTool {
        PKInkingTool(inkType, color: UIColor(hex: colorHex), width: width.points(for: inkType))
    }
}

/// Where the palette at the pen tip opens. Nonisolated because the layout that places the palette reads it
/// outside the main actor.
nonisolated enum PenTipPaletteAnchor: Equatable {
    /// At the pen tip, in the editor's coordinates.
    case penTip(CGPoint)
    /// Beside the main palette, when the pencil is away from the screen and nothing has been written yet.
    case mainPalette
}

/// The window edge the palette docks to. The palette at the pen tip opens toward the same side, so docking the
/// palette on the right also moves that palette out from under a left hand.
nonisolated enum PaletteSide: String {
    case leading
    case trailing

    /// The side for a palette dropped at `x` in a window `width` points wide: the nearer edge.
    init(droppedAt x: CGFloat, width: CGFloat) {
        self = x < width / 2 ? .leading : .trailing
    }

    var other: PaletteSide {
        self == .leading ? .trailing : .leading
    }
}
