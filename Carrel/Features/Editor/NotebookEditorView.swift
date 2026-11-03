import NotebookDomain
import SwiftUI

/// The editor: pages fill the window and scroll under the top bar; glass controls float above them.
struct NotebookEditorView: View {
    @Bindable var session: EditorSession
    @Environment(ToolPaletteModel.self) private var palette
    @State private var quickPaletteLocation: CGPoint?
    @State private var topBarHeight: CGFloat = 0
    /// The bar's lower edge in the window, which is also the canvas's coordinate space: the canvas fills the window.
    @State private var topBarBottom: CGFloat = 0
    @State private var quickPaletteHeight: CGFloat = 0
    @State private var isShowingOverview = false
    @State private var exportedFile: SharedFile?
    @State private var isRenaming = false
    @State private var titleDraft = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.desk.ignoresSafeArea()
            NotebookCanvas(session: session, palette: palette, topBarHeight: topBarHeight) { location in
                withAnimation(Theme.Motion.morph) {
                    quickPaletteLocation = location
                }
            }
            .ignoresSafeArea()
            .overlay { quickPalette }
        }
        // Inside the top bar's safe area, so the palette centers on the page area and never runs under the bar.
        .overlay { ToolPaletteView(palette: palette) }
        // A safe area bar, unlike an inset, drives the scroll edge effect of the scroll view beneath it, including
        // the canvas's UIKit one. The canvas ignores the safe area to reach under the bar, so it is told the bar's
        // height to keep the first page clear of it.
        .safeAreaBar(edge: .top) {
            EditorTopBar(
                session: session,
                palette: palette,
                onClose: close,
                onShowOverview: { isShowingOverview = true },
                onRename: {
                    titleDraft = session.notebook.title
                    isRenaming = true
                },
                onExport: { Task { await exportPDF() } }
            )
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { frame in
                topBarHeight = frame.height
                topBarBottom = frame.maxY
            }
        }
        .overlay(alignment: .bottom) { recoveryBanner }
        .sheet(isPresented: $isShowingOverview) {
            PageOverviewView(session: session)
        }
        .sheet(item: $exportedFile) { file in
            ActivityView(items: [file.url])
        }
        .alert("Rename Notebook", isPresented: $isRenaming) {
            TextField("Title", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = titleDraft
                Task { await session.rename(to: title) }
            }
        }
        .errorAlert($session.errorMessage)
        // The zoom transition would otherwise take a pinch on the pages as a request to close the notebook: it would
        // win the gesture from the canvas's zoom and close the editor without the save that `close()` waits for.
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveInBackground()
            }
        }
    }

    /// The editor closes only once everything is on disk; if a write fails it stays open with the error.
    private func close() {
        Task {
            if await session.saveAll() {
                dismiss()
            }
        }
    }

    private func saveInBackground() {
        let autosaver = session.autosaver
        BackgroundTask.run(named: "Save notebook") {
            await autosaver.flush()
        }
    }

    private func exportPDF() async {
        do {
            exportedFile = SharedFile(url: try await session.exportPDF())
        } catch {
            session.errorMessage = UserFacingError.message(for: error)
        }
    }

    @ViewBuilder
    private var quickPalette: some View {
        if let location = quickPaletteLocation {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { quickPaletteLocation = nil }
                QuickPaletteView(palette: palette) {
                    withAnimation(Theme.Motion.chrome) {
                        quickPaletteLocation = nil
                    }
                }
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    quickPaletteHeight = height
                }
                // Kept below the top bar, which lies above this overlay and would take every touch on the palette.
                .position(
                    x: location.x,
                    y: max(location.y - 80, topBarBottom + quickPaletteHeight / 2 + Theme.Spacing.s)
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            // The location is in the canvas's coordinates, which span the window; inside the safe area the palette
            // would open the height of the status bar and the top bar below the pen tip.
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var recoveryBanner: some View {
        if let notice = session.recoveryNotice {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "bandage")
                Text(notice)
                    .font(.subheadline)
                Button("OK") { session.dismissRecoveryNotice() }
            }
            .padding(Theme.Spacing.m)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

/// Title, page and save status, and the editor's actions.
private struct EditorTopBar: View {
    let session: EditorSession
    @Bindable var palette: ToolPaletteModel
    let onClose: () -> Void
    let onShowOverview: () -> Void
    let onRename: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Library")
            .accessibilityIdentifier("closeEditor")

            VStack(alignment: .leading, spacing: 2) {
                Text(session.notebook.title)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Text(statusLine)
                    .font(.subheadline)
                    .foregroundStyle(session.autosaver.status == .notSaved ? Theme.destructive : Theme.secondaryText)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("saveStatus")
            }

            Spacer()

            GlassEffectContainer(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    Button("Undo", systemImage: "arrow.uturn.backward") { session.undoManager.undo() }
                        .disabled(!session.canUndo)
                    Button("Redo", systemImage: "arrow.uturn.forward") { session.undoManager.redo() }
                        .disabled(!session.canRedo)
                    Button("Pages", systemImage: "square.grid.2x2", action: onShowOverview)
                    moreMenu
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        // Pages lie under the whole bar. Without a shape, only the buttons themselves are hit-testable and every
        // other touch in the bar, including one just beside a button, reaches the canvas and scrolls or draws.
        .contentShape(.rect)
    }

    private var statusLine: String {
        let pageNumber = min(session.currentPageIndex + 1, session.pages.count)
        let page = String(localized: "Page \(pageNumber) of \(session.pages.count)")
        return "\(page) · \(statusText)"
    }

    private var statusText: String {
        switch session.autosaver.status {
        case .saved: String(localized: "Saved")
        case .edited: String(localized: "Edited")
        case .stalled: String(localized: "Saving…")
        case .notSaved: String(localized: "Not Saved")
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Rename…", systemImage: "pencil", action: onRename)
            paperMenu
            Toggle("Ruler", systemImage: "ruler", isOn: $palette.isRulerActive)
            Divider()
            Button("Export PDF", systemImage: "square.and.arrow.up", action: onExport)
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    @ViewBuilder
    private var paperMenu: some View {
        if let page = session.currentPage {
            Menu("Paper", systemImage: "doc.plaintext") {
                Section("This Page") {
                    ForEach(PaperStyle.allCases, id: \.self) { style in
                        Button(style.title) {
                            let paper = Paper(style: style, tone: page.paper.tone)
                            Task { await session.setPaper(paper, forPage: page.id) }
                        }
                    }
                }
                Section("Tone for All Pages") {
                    ForEach(PaperTone.available, id: \.self) { tone in
                        Button(tone.title) {
                            let paper = Paper(style: page.paper.style, tone: tone)
                            Task { await session.setPaperForAllPages(paper) }
                        }
                    }
                }
            }
        }
    }
}
