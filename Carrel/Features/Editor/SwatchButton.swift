import SwiftUI

/// A color to pick: a 30 pt dot inside the full 44 pt target, ringed when it is the tool's current color.
struct SwatchButton: View {
    let hex: UInt32
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(uiColor: UIColor(hex: hex)))
                // Pale highlighter colors would otherwise dissolve into the glass behind them.
                .strokeBorder(Theme.primaryText.opacity(0.15), lineWidth: 1)
                .frame(width: 30, height: 30)
                .padding(5)
                .overlay {
                    if isSelected {
                        Circle().strokeBorder(Theme.accent, lineWidth: 2)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(InkPalette.name(for: hex)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
