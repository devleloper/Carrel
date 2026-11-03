import NotebookDomain
import SwiftUI

/// The editor's Paper control: tone and style of the current page as real swatches, and a way to give every page
/// the same paper.
struct PaperButton: View {
    let session: EditorSession
    @State private var isChoosing = false

    var body: some View {
        Button("Paper", systemImage: "doc.plaintext") { isChoosing = true }
            .disabled(session.currentPage == nil)
            .accessibilityIdentifier("paperChooser")
            .popover(isPresented: $isChoosing) {
                if let page = session.currentPage {
                    PagePaperChooser(session: session, pageID: page.id)
                }
            }
    }
}

private struct PagePaperChooser: View {
    let session: EditorSession
    let pageID: Page.ID
    @State private var isApplying = false
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 380

    private var paper: Paper {
        session.pages.first { $0.id == pageID }?.paper ?? session.notebook.defaultPaper
    }

    var body: some View {
        @Bindable var session = session
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("Paper for This Page")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                PaperChooser(
                    paper: Binding(
                        get: { paper },
                        set: { newPaper in apply { await session.setPaper(newPaper, forPage: pageID) } }
                    )
                )
                // Each change is built from the paper the store holds; a second change while the first is being
                // written would build on the old paper and undo the first.
                .disabled(isApplying)
                Divider()
                Button("Use for All Pages", systemImage: "square.stack") {
                    let paper = paper
                    apply { await session.setPaperForAllPages(paper) }
                }
                .disabled(isApplying || session.pages.allSatisfy { $0.paper == paper })
            }
            .padding(Theme.Spacing.xl)
        }
        // An ideal width rather than a fixed one, so the popover can narrow in Slide Over, Split View or at
        // large text sizes instead of clipping the tiles.
        .frame(idealWidth: width, maxWidth: width)
        .presentationCompactAdaptation(.popover)
        // The editor's alert cannot present over the popover.
        .errorAlert($session.errorMessage)
    }

    private func apply(_ change: @escaping () async -> Void) {
        isApplying = true
        Task {
            await change()
            isApplying = false
        }
    }
}
