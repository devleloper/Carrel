import NotebookDomain
import SwiftUI

/// Creates a notebook in at most three taps: a title is optional, cover and paper have good defaults.
struct NewNotebookSheet: View {
    let onCreate: (NotebookDraft) -> Void
    @State private var draft = NotebookDraft()
    @Environment(\.dismiss) private var dismiss

    private let coverColumns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.m), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Untitled", text: $draft.title)
                        .font(.serifTitle(.title3))
                        .accessibilityIdentifier("notebookTitle")
                }
                Section("Cover") {
                    LazyVGrid(columns: coverColumns, spacing: Theme.Spacing.m) {
                        ForEach(CoverPreset.allCases, id: \.self) { preset in
                            coverButton(preset)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.s)
                }
                Section("Paper") {
                    PaperChooser(paper: $draft.paper)
                        .padding(.vertical, Theme.Spacing.s)
                    Picker("Size", selection: $draft.pageSize) {
                        Text("A4").tag(PageSize.a4)
                        Text("Letter").tag(PageSize.letter)
                        Text("A4 Landscape").tag(PageSize.a4.landscape)
                    }
                }
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("createNotebook")
                }
            }
        }
    }

    private func coverButton(_ preset: CoverPreset) -> some View {
        Button {
            draft.cover = preset
        } label: {
            NotebookCoverView(preset: preset)
                .padding(Theme.Spacing.xs)
                .overlay {
                    if draft.cover == preset {
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(CoverAppearance(preset).name))
        .accessibilityAddTraits(draft.cover == preset ? .isSelected : [])
    }
}
