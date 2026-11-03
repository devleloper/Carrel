import SwiftUI

/// The settings of the selected tool, opened by tapping it again. Changes go straight into the tool's slot.
struct ToolSettingsView: View {
    @Bindable var palette: ToolPaletteModel
    let tool: EditorTool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(tool.title)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                if case .pen(let index) = tool, palette.pen(at: index) != nil {
                    section("Ink") {
                        optionPicker("Ink", selection: $palette.settings.pens[index].inkType, title: \.title)
                    }
                }
                if tool == .eraser {
                    section("Erase") {
                        optionPicker("Erase", selection: $palette.settings.eraser.mode, title: \.title)
                    }
                }
                if let colorHex = palette.color(of: tool) {
                    section("Color") {
                        colorChoices(selection: colorHex)
                    }
                }
                if let width = palette.width(of: tool) {
                    section("Width") {
                        optionPicker(
                            "Width",
                            selection: Binding(get: { width }, set: { palette.setWidth($0, for: tool) }),
                            title: \.title
                        )
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("toolSettings")
        .frame(idealWidth: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .accessibilityHidden(true)
            content()
        }
    }

    /// Segments read best at ordinary text sizes; at accessibility sizes their labels would be cut, so the
    /// choice becomes a menu.
    @ViewBuilder
    private func optionPicker<Option: Hashable & CaseIterable>(
        _ label: LocalizedStringKey,
        selection: Binding<Option>,
        title: KeyPath<Option, LocalizedStringResource>
    ) -> some View where Option.AllCases: RandomAccessCollection {
        let picker = Picker(label, selection: selection) {
            ForEach(Array(Option.allCases), id: \.self) { option in
                Text(option[keyPath: title]).tag(option)
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private func colorChoices(selection: UInt32) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: Theme.Spacing.xs), count: 5)) {
                ForEach(tool.swatches) { swatch in
                    SwatchButton(hex: swatch.hex, isSelected: swatch.hex == selection) {
                        palette.setColor(swatch.hex, for: tool)
                    }
                }
            }
            ColorPicker(selection: customColor(selection), supportsOpacity: false) {
                Text("Custom Color")
                    .foregroundStyle(Theme.primaryText)
            }
        }
    }

    private func customColor(_ hex: UInt32) -> Binding<Color> {
        Binding(
            get: { Color(uiColor: UIColor(hex: hex)) },
            set: { palette.setColor(UIColor($0).hexValue, for: tool) }
        )
    }
}
