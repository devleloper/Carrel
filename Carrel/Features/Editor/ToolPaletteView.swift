import SwiftUI

/// The vertical palette on the desk margin. Tapping the selected tool again opens its settings.
struct ToolPaletteView: View {
    @Bindable var palette: ToolPaletteModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(palette.tools, id: \.self) { tool in
                if tool == .highlighter {
                    Divider()
                        .frame(width: 28)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                ToolButton(tool: tool, palette: palette) {
                    palette.choose(tool)
                }
                .popover(isPresented: settingsBinding(for: tool), arrowEdge: .trailing) {
                    // A popover inherits the palette's capped text size; the settings scroll, so they take
                    // the reader's full size.
                    ToolSettingsView(palette: palette, tool: tool)
                        .dynamicTypeSize(dynamicTypeSize)
                }
            }
        }
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .capsule)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func settingsBinding(for tool: EditorTool) -> Binding<Bool> {
        Binding(
            get: { palette.toolWithOpenSettings == tool },
            set: { isPresented in
                if !isPresented {
                    palette.dismissSettings()
                }
            }
        )
    }
}

/// The compact palette that opens at the pen tip after a Pencil Pro squeeze or double tap.
struct QuickPaletteView: View {
    @Bindable var palette: ToolPaletteModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(palette.tools, id: \.self) { tool in
                    ToolButton(tool: tool, palette: palette) {
                        palette.select(tool)
                        onDone()
                    }
                }
            }
            if case .pen = palette.selection, let current = palette.color(of: palette.selection) {
                quickColors(current: current)
            }
        }
        .padding(Theme.Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    /// The first pen colors, one tap away while writing; all of them are in the pen's settings.
    private static let quickColorCount = 6

    private func quickColors(current: UInt32) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(InkPalette.pens.prefix(Self.quickColorCount)) { swatch in
                SwatchButton(hex: swatch.hex, isSelected: swatch.hex == current) {
                    palette.setColor(swatch.hex, for: palette.selection)
                    onDone()
                }
            }
        }
    }
}
