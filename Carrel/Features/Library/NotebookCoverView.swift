import NotebookDomain
import SwiftUI

/// A notebook as an object on the desk: material, spine, a paper label with the title.
struct NotebookCoverView: View {
    let preset: CoverPreset
    var title: String?
    var isFavorite = false

    private var appearance: CoverAppearance {
        CoverAppearance(preset)
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 8, topTrailingRadius: 8)
        ZStack(alignment: .leading) {
            shape.fill(appearance.base)
            shape.fill(materialShading)
            Rectangle()
                .fill(appearance.spine)
                .frame(width: 10)
                .overlay(alignment: .trailing) {
                    Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
                }
            if let title {
                label(title)
            }
        }
        .clipShape(shape)
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryAccent)
                    .padding(Theme.Spacing.s)
                    .accessibilityLabel("Favorite")
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: Theme.pageShadow.opacity(0.22), radius: 6, x: 0, y: 4)
    }

    private var materialShading: LinearGradient {
        let highlight: Double = switch appearance.material {
        case .leather: 0.16
        case .cloth, .linen: 0.08
        case .kraft, .plain: 0.05
        }
        return LinearGradient(
            colors: [.white.opacity(highlight), .clear, .black.opacity(highlight)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: .serif, weight: .semibold))
            .foregroundStyle(Color(uiColor: UIColor(hex: 0x2B241E)))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(appearance.label, in: .rect(cornerRadius: 3))
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 28)
    }
}
