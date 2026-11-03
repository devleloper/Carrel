import SwiftUI

/// The vertical palette on the desk margin: three favorite pens, highlighter, eraser, lasso and More. Tapping the
/// selected tool again opens its settings.
///
/// The palette docks to the leading or trailing edge of the window; a drag moves it to the nearer one. It also
/// collapses into a single glass button that shows the tool in hand, and the two forms morph into each other.
struct ToolPaletteView: View {
    @Bindable var palette: ToolPaletteModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var glassNamespace
    @State private var dragOffset: CGSize = .zero
    /// Resets by itself when the system cancels the drag, which never reaches `onEnded`.
    @GestureState private var isDragging = false
    /// Under Reduce Motion the palette fades out and back in on its edge instead of crossing the window.
    @State private var isFadedOut = false
    @ScaledMetric(relativeTo: .title3) private var buttonSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title2) private var collapsedSize: CGFloat = 56

    private static let glassID = "toolPalette"

    var body: some View {
        GeometryReader { proxy in
            GlassEffectContainer(spacing: Theme.Spacing.s) {
                if palette.isCollapsed {
                    collapsedPalette
                } else {
                    expandedPalette
                }
            }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { frame in
                palette.mainPaletteFrame = frame
            }
            .offset(dragOffset)
            .opacity(isFadedOut ? 0 : 1)
            // A tap never moves far enough to start the drag, so the tools below keep their taps.
            .highPriorityGesture(docking(within: proxy.frame(in: .global)))
            .padding(.horizontal, Theme.Spacing.l)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: palette.side == .leading ? .leading : .trailing
            )
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onChange(of: isDragging) { _, isDragging in
            if !isDragging, dragOffset != .zero, !isFadedOut {
                dock(to: palette.side)
            }
        }
    }

    /// At large text sizes the column can be taller than a short window; it then scrolls rather than running
    /// under the top bar.
    private var expandedPalette: some View {
        ViewThatFits(in: .vertical) {
            paletteColumn
            ScrollView {
                paletteColumn
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(Theme.Spacing.s)
        .glassEffect(.regular, in: .capsule)
        .glassEffectID(Self.glassID, in: glassNamespace)
    }

    private var paletteColumn: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Button("Collapse Palette", systemImage: "arrow.down.right.and.arrow.up.left") {
                setCollapsed(true)
            }
            .labelStyle(.iconOnly)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(Circle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("collapsePalette")
            .accessibilityAction(named: moveActionTitle, moveToOtherSide)

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
                    arrowEdge: settingsArrowEdge,
                    dynamicTypeSize: dynamicTypeSize
                )
            }
            MoreToolsMenu(palette: palette, settingsArrowEdge: settingsArrowEdge, settingsTypeSize: dynamicTypeSize)
        }
    }

    /// The symbol keeps the text color, so the button reads on light and dark glass alike, and the ink shows as
    /// an outlined ring: neither Carbon on dark glass nor a pale highlighter on light glass can dissolve into it.
    private var collapsedPalette: some View {
        Button {
            setCollapsed(false)
        } label: {
            Image(systemName: palette.selection.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.primaryText)
                .frame(width: collapsedSize, height: collapsedSize)
                .overlay {
                    if let hex = palette.color(of: palette.selection) {
                        Circle()
                            .strokeBorder(Color(uiColor: UIColor(hex: hex)), lineWidth: 4)
                            .overlay { Circle().strokeBorder(Theme.primaryText.opacity(0.2), lineWidth: 1) }
                            .padding(Theme.Spacing.xs)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID(Self.glassID, in: glassNamespace)
        .accessibilityLabel("Expand Palette")
        .accessibilityValue(Text(verbatim: currentToolDescription))
        .accessibilityIdentifier("expandPalette")
        .accessibilityAction(named: moveActionTitle, moveToOtherSide)
    }

    /// Settings open toward the page, away from the window edge. The arrow sits on the popover's edge that faces
    /// the palette, which is the same edge as the palette's side.
    private var settingsArrowEdge: Edge {
        palette.side == .leading ? .leading : .trailing
    }

    private var currentToolDescription: String {
        [String(localized: palette.selection.title), palette.summary(of: palette.selection)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Dragging is not available to VoiceOver and Switch Control, so they move the palette with an action.
    private var moveActionTitle: Text {
        palette.side == .leading ? Text("Move to Right Edge") : Text("Move to Left Edge")
    }

    private func moveToOtherSide() {
        dock(to: palette.side.other)
    }

    private func setCollapsed(_ isCollapsed: Bool) {
        withAnimation(motion(Theme.Motion.morph)) {
            palette.isCollapsed = isCollapsed
        }
    }

    private func docking(within window: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .global)
            .updating($isDragging) { _, isDragging, _ in
                isDragging = true
            }
            .onChanged { drag in
                palette.dismissSettings()
                palette.dismissPenTipPalette()
                dragOffset = drag.translation
            }
            .onEnded { drag in
                dock(to: PaletteSide(droppedAt: drag.predictedEndLocation.x - window.minX, width: window.width))
            }
    }

    /// Settles the palette on `side`, wherever a drag left it. Under Reduce Motion it would otherwise slide across
    /// the whole window, the very motion the reader turned off, so it fades out in place and in on the edge.
    private func dock(to side: PaletteSide) {
        guard reduceMotion else {
            withAnimation(Theme.Motion.settle) {
                palette.side = side
                dragOffset = .zero
            }
            return
        }
        let fade = motion(Theme.Motion.settle)
        withAnimation(fade) {
            isFadedOut = true
        } completion: {
            palette.side = side
            dragOffset = .zero
            withAnimation(fade) {
                isFadedOut = false
            }
        }
    }

    private func motion(_ animation: Animation) -> Animation {
        Theme.Motion.resolved(animation, reduceMotion: reduceMotion)
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
