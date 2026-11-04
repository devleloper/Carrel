import NotebookDomain
import SwiftUI

/// Tone and style as tiles of real paper. The new notebook sheet and the editor's Paper control share it, so paper is
/// chosen the same way everywhere. Each tone is shown in the current style and each style in the current tone.
struct PaperChooser: View {
    @Binding var paper: Paper

    /// Tiles keep a width their titles fit in at every text size, so narrow windows and large text get fewer
    /// columns instead of clipped tiles.
    @ScaledMetric(relativeTo: .footnote) private var minimumTileWidth: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            tileGroup("Tone") {
                ForEach(PaperTone.allCases, id: \.self) { tone in
                    PaperTile(
                        paper: Paper(style: paper.style, tone: tone),
                        title: tone.title,
                        isSelected: paper.tone == tone
                    ) {
                        paper.tone = tone
                    }
                    .accessibilityIdentifier("paperTone.\(tone.rawValue)")
                }
            }
            tileGroup("Style") {
                ForEach(PaperStyle.allCases, id: \.self) { style in
                    PaperTile(
                        paper: Paper(style: style, tone: paper.tone),
                        title: style.title,
                        isSelected: paper.style == style
                    ) {
                        paper.style = style
                    }
                    .accessibilityIdentifier("paperStyle.\(style.rawValue)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paperTiles")
    }

    private func tileGroup(_ title: LocalizedStringKey, @ViewBuilder tiles: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minimumTileWidth), spacing: Theme.Spacing.m, alignment: .top)],
                spacing: Theme.Spacing.m
            ) {
                tiles()
            }
        }
    }
}

private struct PaperTile: View {
    let paper: Paper
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var maximumSwatchWidth: CGFloat = 88

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                PaperSwatch(paper: paper)
                    .aspectRatio(0.8, contentMode: .fit)
                    .frame(maxWidth: maximumSwatchWidth)
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay {
                        // The selected tile gets a thicker frame, not only a different color.
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Theme.accent : Theme.separator, lineWidth: isSelected ? 3 : 1)
                    }
                    .accessibilityHidden(true)
                Text(title)
                    .font(.footnote.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
