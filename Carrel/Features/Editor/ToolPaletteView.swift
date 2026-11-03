import SwiftUI

/// The vertical palette on the desk margin: three favorite pens, highlighter, eraser, lasso and More. Tapping the
/// selected tool again opens its settings.
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
                .toolSettingsPopover(
                    for: tool,
                    palette: palette,
                    arrowEdge: .trailing,
                    dynamicTypeSize: dynamicTypeSize
                )
            }
            MoreToolsMenu(palette: palette, settingsArrowEdge: .trailing, settingsTypeSize: dynamicTypeSize)
        }
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .capsule)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

/// The art inks and the ruler. While an art ink is in hand the button shows it, so the palette always shows the
/// current tool, and choosing that ink again opens its settings like any other tool.
private struct MoreToolsMenu: View {
    @Bindable var palette: ToolPaletteModel
    let settingsArrowEdge: Edge
    let settingsTypeSize: DynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 44

    private var selectedArtInk: EditorTool? {
        palette.moreTools.contains(palette.selection) ? palette.selection : nil
    }

    var body: some View {
        Menu {
            Section("Art Inks") {
                ForEach(palette.moreTools, id: \.self) { tool in
                    Toggle(isOn: Binding(get: { palette.selection == tool }, set: { _ in palette.choose(tool) })) {
                        Label {
                            Text(tool.title)
                        } icon: {
                            Image(systemName: tool.systemImage)
                        }
                    }
                }
            }
            Toggle("Ruler", systemImage: "ruler", isOn: $palette.isRulerActive)
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More Tools")
        .accessibilityValue(Text(verbatim: accessibilityValue))
        .accessibilityIdentifier("moreTools")
        .toolSettingsPopover(
            for: selectedArtInk,
            palette: palette,
            arrowEdge: settingsArrowEdge,
            dynamicTypeSize: settingsTypeSize
        )
    }

    private var label: some View {
        Group {
            if let tool = selectedArtInk {
                ToolIcon(tool: tool, palette: palette)
            } else {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .font(.title3)
        .frame(width: size, height: size)
        .background {
            if selectedArtInk != nil {
                SelectionDisc()
            }
        }
        .contentShape(Circle())
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let tool = selectedArtInk {
            parts.append(String(localized: tool.title))
            parts.append(palette.summary(of: tool))
        }
        if palette.isRulerActive {
            parts.append(String(localized: "Ruler On"))
        }
        return parts.joined(separator: ", ")
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

extension ToolPaletteModel {
    /// Drives a settings popover: shown while `tool` has its settings open; dismissing it closes them.
    fileprivate func isShowingSettings(for tool: EditorTool?) -> Binding<Bool> {
        Binding(
            get: { tool != nil && self.toolWithOpenSettings == tool },
            set: { isPresented in
                if !isPresented {
                    self.dismissSettings()
                }
            }
        )
    }
}

extension View {
    /// Shows the settings of `tool` while they are open. A popover inherits the palette's capped text size; the
    /// settings scroll, so they get the reader's own size back.
    fileprivate func toolSettingsPopover(
        for tool: EditorTool?,
        palette: ToolPaletteModel,
        arrowEdge: Edge,
        dynamicTypeSize: DynamicTypeSize
    ) -> some View {
        popover(isPresented: palette.isShowingSettings(for: tool), arrowEdge: arrowEdge) {
            if let tool {
                ToolSettingsView(palette: palette, tool: tool)
                    .dynamicTypeSize(dynamicTypeSize)
            }
        }
    }
}
