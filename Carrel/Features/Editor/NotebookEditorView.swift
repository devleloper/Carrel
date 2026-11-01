import NotebookDomain
import SwiftUI

/// The editor: the page fills the window; glass controls float on the desk around it.
struct NotebookEditorView: View {
    let session: EditorSession
    @State private var palette = ToolPaletteModel()
    @State private var quickPaletteLocation: CGPoint?
    @State private var isShowingOverview = false
    @State private var exportedFile: SharedFile?
    @State private var isRenaming = false
    @State private var titleDraft = ""
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
        .safeAreaInset(edge: .top) { topBar }
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
        .alert("Rename Notebook", isPresented: $isRenaming) {
            TextField("Title", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                Task { try? await session.rename(to: titleDraft) }
            }
        }
        .alert("Something Went Wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.flushBeforeSuspension()
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                session.flushBeforeSuspension()
                dismiss()
            } label: {
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
                    .foregroundStyle(session.saveStatus == .notSaved ? Theme.destructive : Theme.secondaryText)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("saveStatus")
            }

            Spacer()

            GlassEffectContainer(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        session.undoManager.undo()
                    }
                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        session.undoManager.redo()
                    }
                    Button("Pages", systemImage: "square.grid.2x2") {
                        isShowingOverview = true
                    }
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
        let page = String(localized: "Page \(min(session.currentPageIndex + 1, session.pages.count)) of \(session.pages.count)")
        return "\(page) · \(statusText)"
    }

    private var statusText: String {
        switch session.saveStatus {
        case .saved: String(localized: "Saved")
        case .edited: String(localized: "Edited")
        case .saving: String(localized: "Saving…")
        case .notSaved: String(localized: "Not Saved")
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Rename…", systemImage: "pencil") {
                titleDraft = session.notebook.title
                isRenaming = true
            }
            paperMenu
            Toggle("Ruler", systemImage: "ruler", isOn: $palette.isRulerActive)
            Divider()
            Button("Export PDF", systemImage: "square.and.arrow.up") {
                Task { await exportPDF() }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private var paperMenu: some View {
        Menu("Paper", systemImage: "doc.plaintext") {
            if let page = currentPage {
                Section("This Page") {
                    ForEach(PaperStyle.allCases, id: \.self) { style in
                        Button(style.title) {
                            Task { try? await session.setPaper(Paper(style: style, tone: page.paper.tone), forPage: page.id) }
                        }
                    }
                }
                Section("Tone for All Pages") {
                    ForEach(PaperTone.available, id: \.self) { tone in
                        Button(tone.title) {
                            Task { try? await session.setPaperForAllPages(Paper(style: page.paper.style, tone: tone)) }
                        }
                    }
                }
            }
        }
    }

    private var currentPage: Page? {
        session.pages.indices.contains(session.currentPageIndex) ? session.pages[session.currentPageIndex] : nil
    }

    private func exportPDF() async {
        do {
            exportedFile = SharedFile(url: try await session.exportPDF())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: Overlays

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
