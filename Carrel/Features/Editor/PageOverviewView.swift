import NotebookData
import NotebookDomain
import SwiftUI

/// All pages as thumbnails: jump to a page, duplicate, reorder, delete, and restore deleted pages.
struct PageOverviewView: View {
    let session: EditorSession
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.xl)]

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.xl) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            session.scrollTarget = page.id
                            dismiss()
                        } label: {
                            VStack(spacing: Theme.Spacing.s) {
                                PageThumbnail(session: session, page: page)
                                Text("\(index + 1)")
                                    .font(.footnote.monospacedDigit())
                                    .foregroundStyle(
                                        index == session.currentPageIndex ? Theme.accent : Theme.secondaryText
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Page \(index + 1)")
                        .contextMenu { pageActions(for: page, at: index) }
                    }
                }
                .padding(Theme.Spacing.xl)

                if !session.trashedPages.isEmpty {
                    recentlyDeleted
                }
            }
            .background(Theme.desk)
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .errorAlert($session.errorMessage)
        }
    }

    @ViewBuilder
    private func pageActions(for page: Page, at index: Int) -> some View {
        Button("Duplicate", systemImage: "plus.square.on.square") {
            Task { await session.duplicatePage(page.id) }
        }
        Button("Move Earlier", systemImage: "arrow.up") {
            Task { await session.movePage(page.id, by: -1) }
        }
        .disabled(index == 0)
        Button("Move Later", systemImage: "arrow.down") {
            Task { await session.movePage(page.id, by: 1) }
        }
        .disabled(index == session.pages.count - 1)
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            Task { await session.moveToTrash(page.id) }
        }
        .disabled(session.pages.count == 1)
    }

    private var recentlyDeleted: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Recently Deleted")
                .font(.headline)
            Text("Deleted pages are kept for \(LibraryStore.trashRetentionDays) days.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.l) {
                    ForEach(session.trashedPages) { page in
                        VStack(spacing: Theme.Spacing.s) {
                            PageThumbnail(session: session, page: page)
                                .frame(width: 110)
                            Button("Restore") {
                                Task { await session.restore(page.id) }
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

struct PageThumbnail: View {
    let session: EditorSession
    let page: Page
    @State private var inkImage: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            PaperPreview(paper: page.paper, size: page.size)
            if let inkImage {
                Image(uiImage: inkImage)
                    .resizable()
            }
        }
        .aspectRatio(page.size.width / page.size.height, contentMode: .fit)
        .overlay {
            if let edge = page.paper.tone.edge {
                Rectangle().strokeBorder(Color(uiColor: edge), lineWidth: 1)
            }
        }
        .shadow(color: Theme.pageShadow.opacity(Theme.Elevation.page), radius: 4, y: 2)
        .task(id: page) {
            inkImage = await session.thumbnail(for: page, scale: CGFloat(160 / page.size.width) * displayScale)
        }
    }
}
