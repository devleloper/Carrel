import SwiftUI

/// One tool in either palette. The selected tool sits on a tinted, ringed disc, so the selection never depends
/// on telling colors apart.
struct ToolButton: View {
    let tool: EditorTool
    let palette: ToolPaletteModel
    let action: () -> Void
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 44

    private var isSelected: Bool {
        palette.selection == tool
    }

    var body: some View {
        Button(action: action) {
            ToolIcon(tool: tool, palette: palette)
                .font(.title3)
                .frame(width: size, height: size)
                .background {
                    if isSelected {
                        SelectionDisc()
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(tool.title))
        .accessibilityValue(Text(verbatim: palette.summary(of: tool)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(WidthAdjustment(tool: tool, palette: palette))
        .accessibilityShowsLargeContentViewer()
    }
}

/// A tool's symbol in the tool's own ink, so the palette shows what each pen writes with.
struct ToolIcon: View {
    let tool: EditorTool
    let palette: ToolPaletteModel

    var body: some View {
        let symbol = Image(systemName: tool.systemImage)
        switch tool {
        case .pen:
            symbol
                .symbolRenderingMode(.palette)
                .foregroundStyle(ink, Theme.primaryText)
        case .highlighter, .artInk:
            symbol.foregroundStyle(ink)
        case .eraser, .lasso:
            symbol.foregroundStyle(Theme.primaryText)
        }
    }

    private var ink: Color {
        Color(uiColor: UIColor(hex: palette.color(of: tool) ?? 0))
    }
}

/// The mark behind the selected tool.
struct SelectionDisc: View {
    var body: some View {
        Circle()
            .fill(Theme.accent.opacity(0.14))
            .strokeBorder(Theme.accent, lineWidth: 2)
    }
}

/// VoiceOver users change a tool's width by swiping up or down on it.
private struct WidthAdjustment: ViewModifier {
    let tool: EditorTool
    let palette: ToolPaletteModel

    func body(content: Content) -> some View {
        if let width = palette.width(of: tool) {
            content.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: palette.setWidth(width.stepped(by: 1), for: tool)
                case .decrement: palette.setWidth(width.stepped(by: -1), for: tool)
                @unknown default: break
                }
            }
        } else {
            content
        }
    }
}
