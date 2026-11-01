import NotebookDomain
import SwiftUI

/// The editor: the page fills the window; glass controls float on the desk around it.
struct NotebookEditorView: View {
    let session: EditorSession
    @State private var palette = ToolPaletteModel()
    @State private var quickPaletteLocation: CGPoint?
    @State private var isShowingOverview = false
    @State private var exportedFile: SharedFile?
    @State private var renameDraft: String?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.desk.ignoresSafeArea()
            NotebookCanvas(session: session, palette: palette) { location in
                withAnimation(Theme.Motion.morph) {
                    quickPaletteLocation = location
                }
            }
            .ignoresSafeArea()
            .overlay { quickPalette }
        }
        .safeAreaInset(edge: .top) {
            EditorTopBar(
                session: session,
                palette: palette,
                onClose: close,
                onShowOverview: { isShowingOverview = true },
                onRename: { renameDraft = session.notebook.title },
                onExport: { Task { await exportPDF() } }
            )
        }
        .overlay(alignment: .leading) {
            ToolPaletteView(palette: palette)
                .padding(.leading, Theme.Spacing.l)
        }
        .overlay(alignment: .bottom) { recoveryBanner }
        .sheet(isPresented: $isShowingOverview) {
            PageOverviewView(session: session)
        }
        .sheet(item: $exportedFile) { file in
            ActivityView(items: [file.url])
        }
        .alert("Rename Notebook", isPresented: Binding(presenting: $renameDraft)) {
            TextField("Title", text: Binding(get: { renameDraft ?? "" }, set: { renameDraft = $0 }))
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let title = renameDraft ?? ""
                Task { try? await session.rename(to: title) }
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(presenting: $errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                flushInBackground()
            }
        }
    }

    private func close() {
        flushInBackground()
        dismiss()
    }

    private func flushInBackground() {
        let autosaver = session.autosaver
        BackgroundTask.run(named: "Save notebook") {
            await autosaver.flush()
        }
    }

    private func exportPDF() async {
        do {
            exportedFile = SharedFile(url: try await session.exportPDF())
        } catch {
            errorMessage = UserFacingError.message(for: error)
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
                .position(x: location.x, y: max(location.y - 80, 80))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
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
                    Button("Redo", systemImage: "arrow.uturn.forward") { session.undoManager.redo() }
                    Button("Pages", systemImage: "square.grid.2x2", action: onShowOverview)
                    moreMenu
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
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
        case .saving: String(localized: "Saving…")
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
                            Task { try? await session.setPaper(paper, forPage: page.id) }
                        }
                    }
                }
                Section("Tone for All Pages") {
                    ForEach(PaperTone.available, id: \.self) { tone in
                        Button(tone.title) {
                            let paper = Paper(style: page.paper.style, tone: tone)
                            Task { try? await session.setPaperForAllPages(paper) }
                        }
                    }
                }
            }
        }
    }
}

struct SharedFile: Identifiable {
    let url: URL

    var id: URL { url }
}

extension PaperStyle {
    var title: LocalizedStringKey {
        switch self {
        case .blank: "Blank"
        case .ruledNarrow: "Narrow Ruled"
        case .ruledWide: "Wide Ruled"
        case .ruledWithMargin: "Ruled with Margin"
        case .grid: "Grid"
        case .dots: "Dots"
        }
    }
}

extension PaperTone {
    var title: LocalizedStringKey {
        switch self {
        case .white: "White"
        case .cream: "Cream"
        case .linen: "Linen"
        case .night: "Night"
        }
    }
}
