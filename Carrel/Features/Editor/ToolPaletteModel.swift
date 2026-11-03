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
    @ObservationIgnored private var previousSelection: EditorTool = .pen(0)
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.settings = ToolSettings.load(from: defaults)
    }

    /// Every tool in palette order: the favorite pens, then highlighter, eraser and lasso.
    var tools: [EditorTool] {
        settings.pens.indices.map(EditorTool.pen) + [.highlighter, .eraser, .lasso]
    }

    func pen(at index: Int) -> PenSettings? {
        settings.pens.indices.contains(index) ? settings.pens[index] : nil
    }

    // MARK: Selection

    /// The palette's one gesture: a tap selects a tool, and a tap on the selected tool opens its settings.
    func choose(_ tool: EditorTool) {
        if tool == selection {
            toolWithOpenSettings = tool.hasSettings ? tool : nil
        } else {
            select(tool)
        }
    }

    func dismissSettings() {
        toolWithOpenSettings = nil
    }

    func select(_ tool: EditorTool) {
        guard tool != selection else {
            return
        }
        previousSelection = selection
        selection = tool
        toolWithOpenSettings = nil
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
        }
    }

    private func inkingTool(_ inkType: PKInkingTool.InkType, colorHex: UInt32, width: StrokeWidth) -> PKInkingTool {
        PKInkingTool(inkType, color: UIColor(hex: colorHex), width: width.points(for: inkType))
    }
}
