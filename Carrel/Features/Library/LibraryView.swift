import NotebookDomain
import SwiftUI

struct LibraryView: View {
    @Bindable var model: LibraryModel
    @Namespace private var coverNamespace
    @State private var isCreatingNotebook = false
    @State private var pendingDraft: NotebookDraft?
    @State private var openSession: EditorSession?
    @State private var isShowingSettings = false
    @State private var renamingNotebook: Notebook?
    @State private var titleDraft = ""

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model, isShowingSettings: $isShowingSettings)
        } detail: {
            NavigationStack {
                notebookGrid
                    .navigationTitle(model.sectionTitle)
                    .searchable(text: $model.searchText, prompt: "Search Notebooks")
                    .toolbar {
                        if model.section != .trash {
                            ToolbarItem(placement: .primaryAction) {
                                Button("New Notebook", systemImage: "plus") {
                                    isCreatingNotebook = true
                                }
                                .accessibilityIdentifier("newNotebook")
                            }
                        }
                    }
            }
        }
        .tint(Theme.accent)
        .sheet(isPresented: $isCreatingNotebook, onDismiss: createPendingNotebook) {
            NewNotebookSheet { pendingDraft = $0 }
        }
        .fullScreenCover(item: $openSession, onDismiss: { Task { await model.load() } }) { session in
            NotebookEditorView(session: session)
                .navigationTransition(.zoom(sourceID: session.id, in: coverNamespace))
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(model: model)
        }
        .alert("Rename Notebook", isPresented: renameBinding) {
            TextField("Title", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let notebook = renamingNotebook {
                    Task { await model.rename(notebook, to: titleDraft) }
                }
            }
        }
        .alert("Something Went Wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task { await model.purgeExpiredTrashAndLoad() }
    }

    private var notebookGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: Theme.Spacing.xxl)], spacing: Theme.Spacing.xxl) {
                ForEach(model.visibleNotebooks) { notebook in
                    notebookCard(notebook)
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .background(Theme.desk)
        .overlay {
            if model.visibleNotebooks.isEmpty {
                emptyState
            }
        }
    }

    private func notebookCard(_ notebook: Notebook) -> some View {
        Button {
            guard !notebook.isInTrash else {
                return
            }
            Task { await open(notebook) }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                NotebookCoverView(preset: notebook.cover.preset, title: notebook.title, isFavorite: notebook.isFavorite)
                    .matchedTransitionSource(id: notebook.id, in: coverNamespace)
                Text(notebook.title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Text(notebook.modifiedAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(notebook.title)
        .contextMenu { actions(for: notebook) }
    }

    @ViewBuilder
    private func actions(for notebook: Notebook) -> some View {
        if notebook.isInTrash {
            Button("Restore", systemImage: "arrow.uturn.backward") {
                Task { await model.restore(notebook) }
            }
            Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                Task { await model.deletePermanently(notebook) }
            }
        } else {
            Button("Rename…", systemImage: "pencil") {
                titleDraft = notebook.title
                renamingNotebook = notebook
            }
            Button(notebook.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: notebook.isFavorite ? "star.slash" : "star") {
                Task { await model.toggleFavorite(notebook) }
            }
            Menu("Move to Folder", systemImage: "folder") {
                Button("No Folder") {
                    Task { await model.move(notebook, to: nil) }
                }
                ForEach(model.folders) { folder in
                    Button(folder.title) {
                        Task { await model.move(notebook, to: folder.id) }
                    }
                }
            }
            Divider()
            Button("Move to Trash", systemImage: "trash", role: .destructive) {
                Task { await model.moveToTrash(notebook) }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.section ?? .all {
        case .trash:
            ContentUnavailableView("Trash Is Empty", systemImage: "trash", description: Text("Deleted notebooks stay here for 30 days."))
        case .favorites:
            ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Touch and hold a notebook, then choose Add to Favorites."))
        default:
            if model.searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Notebooks", systemImage: "book.closed")
                } description: {
                    Text("Your notebooks will live here, on this iPad.")
                } actions: {
                    Button("New Notebook") { isCreatingNotebook = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                ContentUnavailableView.search(text: model.searchText)
            }
        }
    }

    private func open(_ notebook: Notebook) async {
        openSession = await model.openSession(for: notebook)
    }

    /// Creation waits for the sheet to finish dismissing, so the editor can be presented right after it.
    private func createPendingNotebook() {
        guard let draft = pendingDraft else {
            return
        }
        pendingDraft = nil
        Task {
            if let notebook = await model.create(draft) {
                await open(notebook)
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renamingNotebook != nil }, set: { if !$0 { renamingNotebook = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}
