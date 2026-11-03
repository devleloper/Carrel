import NotebookData
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

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: Theme.Spacing.xxl)]

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model, isShowingSettings: $isShowingSettings)
        } detail: {
            NavigationStack {
                notebookGrid
                    .navigationTitle(model.title(of: model.currentSection))
                    .searchable(text: $model.searchText, prompt: "Search Notebooks")
                    .toolbar { newNotebookButton }
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
        // Set here rather than in the editor: values from a full-screen cover do not reach the menu bar's commands.
        .focusedSceneValue(openSession)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .alert("Rename Notebook", isPresented: Binding(presenting: $renamingNotebook)) {
            TextField("Title", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let notebook = renamingNotebook {
                    let title = titleDraft
                    Task { await model.rename(notebook, to: title) }
                }
            }
        }
        .errorAlert($model.errorMessage)
        .task { await model.purgeExpiredTrashAndLoad() }
    }

    @ToolbarContentBuilder
    private var newNotebookButton: some ToolbarContent {
        if model.section != .trash {
            ToolbarItem(placement: .primaryAction) {
                Button("New Notebook", systemImage: "plus") {
                    isCreatingNotebook = true
                }
                .accessibilityIdentifier("newNotebook")
            }
        }
    }

    private var notebookGrid: some View {
        ScrollView {
            if model.unreadableNotebookCount > 0, model.currentSection == .all {
                unreadableNotice
            }
            LazyVGrid(columns: columns, spacing: Theme.Spacing.xxl) {
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
                    .font(.serifTitle(.headline))
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
            if notebook.isFavorite {
                Button("Remove from Favorites", systemImage: "star.slash") {
                    Task { await model.toggleFavorite(notebook) }
                }
            } else {
                Button("Add to Favorites", systemImage: "star") {
                    Task { await model.toggleFavorite(notebook) }
                }
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

    /// Damaged notebooks are not hidden silently: their files stay in place, and the user learns they exist.
    private var unreadableNotice: some View {
        Label {
            Text(
                "\(model.unreadableNotebookCount) notebooks can't be opened. Their files were kept unchanged."
            )
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(.subheadline)
        .foregroundStyle(Theme.secondaryText)
        .padding(Theme.Spacing.m)
        .glassEffect(.regular, in: .capsule)
        .padding(.top, Theme.Spacing.l)
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.currentSection {
        case .trash:
            ContentUnavailableView(
                "Trash Is Empty",
                systemImage: "trash",
                description: Text("Deleted notebooks stay here for \(LibraryStore.trashRetentionDays) days.")
            )
        case .favorites:
            ContentUnavailableView(
                "No Favorites",
                systemImage: "star",
                description: Text("Touch and hold a notebook, then choose Add to Favorites.")
            )
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
}
