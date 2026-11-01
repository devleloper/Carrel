import SwiftUI

/// The vertical palette on the desk margin: three favorite pens, highlighter, eraser and lasso.
/// Tapping the selected tool again opens its settings.
struct ToolPaletteView: View {
    @Bindable var palette: ToolPaletteModel
    @State private var toolWithOpenSettings: EditorTool?

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(palette.settings.pens.indices, id: \.self) { index in
                toolButton(.pen(index), label: "Pen \(index + 1)") {
                    PenIcon(colorHex: palette.settings.pens[index].colorHex)
                }
            }
            Divider()
                .frame(width: 28)
                .padding(.vertical, Theme.Spacing.xs)
            toolButton(.highlighter, label: "Highlighter") {
                Image(systemName: "highlighter")
                    .foregroundStyle(Color(uiColor: UIColor(hex: palette.settings.highlighterHex)))
            }
            toolButton(.eraser, label: "Eraser") {
                Image(systemName: "eraser")
            }
            toolButton(.lasso, label: "Lasso") {
                Image(systemName: "lasso")
            }
        }
        .font(.title3)
        .foregroundStyle(Theme.primaryText)
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .capsule)
    }

    private func toolButton(_ tool: EditorTool, label: LocalizedStringKey, @ViewBuilder icon: () -> some View) -> some View {
        let isSelected = palette.selection == tool
        return Button {
            if isSelected, tool != .lasso {
                toolWithOpenSettings = tool
            } else {
                palette.select(tool)
            }
        } label: {
            icon()
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
        .popover(isPresented: settingsBinding(for: tool), arrowEdge: .trailing) {
            ToolSettingsView(palette: palette, tool: tool)
        }
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
                ForEach(palette.settings.pens.indices, id: \.self) { index in
                    quickButton(.pen(index)) {
                        PenIcon(colorHex: palette.settings.pens[index].colorHex)
                    }
                }
                quickButton(.highlighter) { Image(systemName: "highlighter") }
                quickButton(.eraser) { Image(systemName: "eraser") }
                quickButton(.lasso) { Image(systemName: "lasso") }
            }
            if case .pen(let index) = palette.selection {
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
        .font(.title3)
        .foregroundStyle(Theme.primaryText)
        .padding(Theme.Spacing.m)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func quickButton(_ tool: EditorTool, @ViewBuilder icon: () -> some View) -> some View {
        Button {
            palette.select(tool)
            onDone()
        } label: {
            icon()
                .frame(width: 44, height: 44)
                .background {
                    if palette.selection == tool {
                        Circle().fill(Theme.accent.opacity(0.18))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct PenIcon: View {
    let colorHex: UInt32

    var body: some View {
        Image(systemName: "pencil.tip")
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color(uiColor: UIColor(hex: colorHex)), Theme.primaryText)
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
        ColorPicker("Custom Color", selection: colorBinding($palette.settings.pens[index].colorHex), supportsOpacity: false)
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

extension UIColor {
    var hexValue: UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let channel = { (value: CGFloat) in UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return channel(red) << 16 | channel(green) << 8 | channel(blue)
    }
}
