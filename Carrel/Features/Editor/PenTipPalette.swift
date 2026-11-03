import SwiftUI

/// The layer that holds the palette at the pen tip above the page. It covers the editor with the same coordinates
/// as the writing surface, so the location the canvas reports is the location the palette points at.
///
/// While the palette is open, the first touch anywhere else closes it and is swallowed, so closing the palette
/// with the pen never leaves a dot on the page.
struct PenTipPaletteLayer: View {
    let palette: ToolPaletteModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if palette.isPenTipPaletteOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onChanged { _ in
                                palette.dismissPenTipPalette()
                            }
                        )
                        .accessibilityHidden(true)
                        .transition(.identity)
                }
                if let anchor = palette.penTipPaletteAnchor {
                    let placement = placement(for: anchor, in: proxy)
                    PenTipPaletteLayout(placement: placement) {
                        PenTipPaletteView(palette: palette)
                    }
                    .transition(transition(growingFrom: placement.origin, in: proxy.size))
                }
            }
        }
        .ignoresSafeArea()
        .animation(animation, value: palette.penTipPaletteAnchor)
        .onDisappear { palette.dismissPenTipPalette() }
    }

    /// The layer spans the whole window, under the top bar and the main palette, so the palette is placed in what
    /// is left: the safe area, which includes the top bar, without the main palette's edge of the window.
    private func placement(for anchor: PenTipPaletteAnchor, in proxy: GeometryProxy) -> PenTipPalettePlacement {
        let layer = proxy.frame(in: .global)
        let mainPalette = palette.mainPaletteFrame?.offsetBy(dx: -layer.minX, dy: -layer.minY)
        return PenTipPalettePlacement(
            anchor: anchor,
            side: palette.side,
            mainPalette: mainPalette,
            area: PenTipPalettePlacement.freeArea(
                in: CGRect(origin: .zero, size: proxy.size),
                safeAreaInsets: proxy.safeAreaInsets,
                mainPalette: mainPalette
            )
        )
    }

    /// The palette opens with a soft spring and closes faster, without overshoot, so it is gone by the time the
    /// pen comes back to the page.
    private var animation: Animation {
        let spring = palette.isPenTipPaletteOpen ? Theme.Motion.morph : Theme.Motion.chrome
        return Theme.Motion.resolved(spring, reduceMotion: reduceMotion)
    }

    /// The palette grows out of the pen tip and shrinks back into it. The layer fills the editor, so scaling it
    /// around the tip's position moves the palette along the line between the tip and its place.
    private func transition(growingFrom origin: CGPoint, in size: CGSize) -> AnyTransition {
        guard !reduceMotion, size.width > 0, size.height > 0 else {
            return .opacity
        }
        let anchor = UnitPoint(x: origin.x / size.width, y: origin.y / size.height)
        return .scale(scale: 0.3, anchor: anchor).combined(with: .opacity)
    }
}

/// The compact palette: the six tools above the colors of the tool in hand.
struct PenTipPaletteView: View {
    let palette: ToolPaletteModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(palette.tools, id: \.self) { tool in
                    ToolButton(tool: tool, palette: palette) {
                        palette.selectAtPenTip(tool)
                    }
                }
            }
            let colors = palette.quickColors
            if !colors.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(colors, id: \.self) { hex in
                        SwatchButton(hex: hex, isSelected: hex == palette.color(of: palette.selection)) {
                            palette.applyQuickColor(hex)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Palette at Pen Tip")
        .accessibilityIdentifier("penTipPalette")
        .accessibilityAction(.escape) { palette.dismissPenTipPalette() }
    }
}

/// Places its content with `PenTipPalettePlacement`. A layout measures the palette before placing it, so it
/// lands in the right spot on its very first frame.
private struct PenTipPaletteLayout: Layout {
    let placement: PenTipPalettePlacement

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let frame = placement.frame(of: size).offsetBy(dx: bounds.minX, dy: bounds.minY)
            subview.place(at: frame.origin, proposal: ProposedViewSize(size))
        }
    }
}

/// Where the palette at the pen tip goes: above the tip and toward the palette's side, so the writing hand does
/// not cover it, or beside the main palette when there is no tip; always whole inside the free area. All values
/// are in the layer's coordinates. Nonisolated because `Layout` places views outside the main actor.
nonisolated struct PenTipPalettePlacement {
    /// The distance from the tip, both up and sideways, so the palette never sits under the nib.
    static let gap: CGFloat = 24
    /// Keeps the palette off the window edges, where system gestures begin, and off the main palette.
    static let margin: CGFloat = 16

    let anchor: PenTipPaletteAnchor
    let side: PaletteSide
    let mainPalette: CGRect?
    /// Where the palette may go, from `freeArea(in:safeAreaInsets:mainPalette:)`.
    let area: CGRect

    /// The part of `bounds` the palette may cover: inside the safe area and its margin, and clear of the main
    /// palette by cutting off the window edge it is docked to.
    static func freeArea(in bounds: CGRect, safeAreaInsets insets: EdgeInsets, mainPalette: CGRect?) -> CGRect {
        // Both side insets are applied to both sides, so the area does not depend on the layout direction.
        let side = max(insets.leading, insets.trailing) + margin
        var area = CGRect(
            x: bounds.minX + side,
            y: bounds.minY + insets.top + margin,
            width: max(bounds.width - 2 * side, 0),
            height: max(bounds.height - insets.top - insets.bottom - 2 * margin, 0)
        )
        if let palette = mainPalette {
            if palette.midX < bounds.midX {
                let minX = min(max(area.minX, palette.maxX + margin), area.maxX)
                area = CGRect(x: minX, y: area.minY, width: area.maxX - minX, height: area.height)
            } else {
                let maxX = max(min(area.maxX, palette.minX - margin), area.minX)
                area = CGRect(x: area.minX, y: area.minY, width: maxX - area.minX, height: area.height)
            }
        }
        return area
    }

    /// The point the palette grows out of and shrinks back into.
    var origin: CGPoint {
        switch anchor {
        case .penTip(let tip):
            return tip
        case .mainPalette:
            guard let palette = mainPalette else {
                return CGPoint(x: area.midX, y: area.midY)
            }
            return CGPoint(x: palette.midX < area.midX ? palette.maxX : palette.minX, y: palette.midY)
        }
    }

    func frame(of size: CGSize) -> CGRect {
        let origin: CGPoint
        switch anchor {
        case .penTip(let tip):
            origin = Self.origin(of: size, tip: tip, side: side, within: area)
        case .mainPalette:
            origin = besideMainPalette(size)
        }
        return CGRect(
            x: Self.clamp(origin.x, from: area.minX, to: area.maxX - size.width),
            y: Self.clamp(origin.y, from: area.minY, to: area.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// Above the tip and toward `side`; below the tip, or across it, when the area ends first.
    private static func origin(of size: CGSize, tip: CGPoint, side: PaletteSide, within area: CGRect) -> CGPoint {
        var x = side == .leading ? tip.x - gap - size.width : tip.x + gap
        if side == .leading, x < area.minX {
            x = tip.x + gap
        } else if side == .trailing, x + size.width > area.maxX {
            x = tip.x - gap - size.width
        }

        var y = tip.y - gap - size.height
        if y < area.minY {
            y = tip.y + gap
        }
        return CGPoint(x: x, y: y)
    }

    /// Next to the main palette on the page side, level with its middle.
    private func besideMainPalette(_ size: CGSize) -> CGPoint {
        guard let palette = mainPalette else {
            return CGPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
        }
        let x = palette.midX < area.midX ? area.minX : area.maxX - size.width
        return CGPoint(x: x, y: palette.midY - size.height / 2)
    }

    /// Pins to the lower bound when the palette is larger than the area, so its start stays visible.
    private static func clamp(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        max(min(value, upper), lower)
    }
}
