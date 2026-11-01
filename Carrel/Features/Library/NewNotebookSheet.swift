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
                    Picker("Style", selection: $draft.paper.style) {
                        ForEach(PaperStyle.allCases, id: \.self) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    Picker("Tone", selection: $draft.paper.tone) {
                        ForEach(PaperTone.available, id: \.self) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Size", selection: $draft.pageSize) {
                        Text("A4").tag(PageSize.a4)
                        Text("Letter").tag(PageSize.letter)
                        Text("A4 Landscape").tag(PageSize.a4.landscape)
                    }
                    PaperPreview(paper: draft.paper, size: draft.pageSize)
                        .aspectRatio(draft.pageSize.width / draft.pageSize.height, contentMode: .fit)
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
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
