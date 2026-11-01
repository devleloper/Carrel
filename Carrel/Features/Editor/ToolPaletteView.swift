import SwiftUI

/// The vertical palette on the desk margin. Tapping the selected tool again opens its settings.
struct ToolPaletteView: View {
    @Bindable var palette: ToolPaletteModel
    @State private var toolWithOpenSettings: EditorTool?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(palette.tools, id: \.self) { tool in
                if tool == .highlighter {
                    Divider()
                        .frame(width: 28)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                ToolButton(tool: tool, palette: palette) {
                    if palette.selection == tool, tool != .lasso {
                        toolWithOpenSettings = tool
                    } else {
                        palette.select(tool)
                    }
                }
                .popover(isPresented: settingsBinding(for: tool), arrowEdge: .trailing) {
                    ToolSettingsView(palette: palette, tool: tool)
                }
            }
        }
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .capsule)
    }

    private func settingsBinding(for tool: EditorTool) -> Binding<Bool> {
        Binding(
            get: { toolWithOpenSettings == tool },
            set: { isPresented in
                if !isPresented {
                    toolWithOpenSettings = nil
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
            if case .pen(let index) = palette.selection {
                recentColors(forPen: index)
            }
        }
        .padding(Theme.Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func recentColors(forPen index: Int) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(InkPalette.pens.prefix(6)) { swatch in
                Button {
                    palette.settings.pens[index].colorHex = swatch.hex
                    onDone()
                } label: {
                    Circle()
                        .fill(Color(uiColor: swatch.color))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
            }
        }
    }
}

/// One tool in either palette: its icon and the selection ring.
private struct ToolButton: View {
    let tool: EditorTool
    let palette: ToolPaletteModel
    let action: () -> Void

    private var isSelected: Bool {
        palette.selection == tool
    }

    var body: some View {
        Button(action: action) {
            icon
                .font(.title3)
                .foregroundStyle(Theme.primaryText)
                .frame(width: 44, height: 44)
                .background {
                    if isSelected {
                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: 2)
                            .background(Circle().fill(Theme.accent.opacity(0.14)))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var icon: some View {
        switch tool {
        case .pen(let index):
            Image(systemName: "pencil.tip")
                .symbolRenderingMode(.palette)
                .foregroundStyle(inkColor(palette.pen(at: index)?.colorHex), Theme.primaryText)
        case .highlighter:
            Image(systemName: "highlighter")
                .foregroundStyle(inkColor(palette.settings.highlighterHex))
        case .eraser:
            Image(systemName: "eraser")
        case .lasso:
            Image(systemName: "lasso")
        }
    }

    private var label: Text {
        switch tool {
        case .pen(let index): Text("Pen \(index + 1)")
        case .highlighter: Text("Highlighter")
        case .eraser: Text("Eraser")
        case .lasso: Text("Lasso")
        }
    }

    private func inkColor(_ hex: UInt32?) -> Color {
        Color(uiColor: UIColor(hex: hex ?? 0))
    }
}

/// Width, ink and color of the selected tool.
struct ToolSettingsView: View {
    @Bindable var palette: ToolPaletteModel
    let tool: EditorTool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            switch tool {
            case .pen(let index):
                if palette.pen(at: index) != nil {
                    penSettings(index)
                }
            case .highlighter:
                Text("Highlighter").font(.headline)
                swatchGrid(InkPalette.highlighters, selection: $palette.settings.highlighterHex)
                widthSlider($palette.settings.highlighterWidth, range: 10...40)
            case .eraser:
                Text("Eraser").font(.headline)
                Picker("Mode", selection: $palette.settings.isPreciseEraser) {
                    Text("Whole Stroke").tag(false)
                    Text("Precise").tag(true)
                }
                .pickerStyle(.segmented)
                if palette.settings.isPreciseEraser {
                    widthSlider($palette.settings.eraserWidth, range: 4...48)
                }
            case .lasso:
                EmptyView()
            }
        }
        .padding(Theme.Spacing.l)
        .frame(width: 300)
    }

    @ViewBuilder
    private func penSettings(_ index: Int) -> some View {
        Text("Pen \(index + 1)").font(.headline)
        Picker("Ink", selection: $palette.settings.pens[index].inkType) {
            ForEach(PenSettings.InkType.allCases, id: \.self) { type in
                Text(type.title).tag(type)
            }
        }
        .pickerStyle(.segmented)
        swatchGrid(InkPalette.pens, selection: $palette.settings.pens[index].colorHex)
        ColorPicker(
            "Custom Color",
            selection: colorBinding($palette.settings.pens[index].colorHex),
            supportsOpacity: false
        )
        widthSlider($palette.settings.pens[index].width, range: 1...12)
    }

    private func swatchGrid(_ swatches: [InkPalette.Swatch], selection: Binding<UInt32>) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 5), spacing: Theme.Spacing.s) {
            ForEach(swatches) { swatch in
                Button {
                    selection.wrappedValue = swatch.hex
                } label: {
                    Circle()
                        .fill(Color(uiColor: swatch.color))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selection.wrappedValue == swatch.hex {
                                Circle().strokeBorder(Theme.accent, lineWidth: 2).padding(-4)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.name)
            }
        }
    }

    private func widthSlider(_ width: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        LabeledContent("Width") {
            Slider(value: width, in: range)
        }
    }

    private func colorBinding(_ hex: Binding<UInt32>) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: UIColor(hex: hex.wrappedValue)) },
            set: { hex.wrappedValue = UIColor($0).hexValue }
        )
    }
}
