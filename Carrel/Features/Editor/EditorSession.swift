import NotebookData
import NotebookDomain
import PencilKit
import SwiftUI

/// What the editor may do with a page's ink.
enum PageInk {
    case editable(PKDrawing)
    case readOnly(message: String)
}

/// One open notebook: its pages and the ink being edited. Saving is delegated to `InkAutosaver`.
@Observable
final class EditorSession: Identifiable {
    let id: Notebook.ID
    let autosaver: InkAutosaver
    let undoManager = UndoManager()
    private(set) var notebook: Notebook
    private(set) var pages: [Page] = []
    private(set) var trashedPages: [Page] = []
    private(set) var recoveryNotice: String?
    var currentPageIndex = 0
    /// Set by the page overview; the canvas scrolls there and clears it.
    var scrollTarget: Page.ID?

    private let store: NotebookStore
    private let drawings: DrawingCache

    private init(store: NotebookStore, manifest: NotebookManifest) {
        let drawings = DrawingCache()
        self.id = manifest.notebook.id
        self.notebook = manifest.notebook
        self.store = store
        self.drawings = drawings
        self.autosaver = InkAutosaver(store: store) { drawings.inkData(for: $0) }
        apply(manifest)
    }

    static func open(_ store: NotebookStore) async -> EditorSession {
        EditorSession(store: store, manifest: await store.manifest)
    }

    var currentPage: Page? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    // MARK: Ink

    func ink(for pageID: Page.ID) async -> PageInk {
        if let drawing = drawings[pageID] {
            return .editable(drawing)
        }
        let result = await store.ink(for: pageID)
        if let drawing = drawings[pageID] {
            return .editable(drawing)
        }
        switch result {
        case .empty:
            return .editable(PKDrawing())
        case .ink(let ink):
            return decode(ink, for: pageID)
        case .recovered(let ink):
            recoveryNotice = String(localized: "A damaged page was restored from its last saved version.")
            return decode(ink, for: pageID)
        case .unrecoverable:
            recoveryNotice = String(localized: "A damaged page could not be restored. Its file was kept for recovery.")
            return .editable(PKDrawing())
        case .requiresNewerSystem:
            return .readOnly(message: String(localized: "This page was written with a newer version of iPadOS."))
        }
    }

    func drawingDidChange(_ drawing: PKDrawing, on pageID: Page.ID) {
        drawings[pageID] = drawing
        autosaver.pageDidChange(pageID)
    }

    func inkImage(for page: Page, scale: CGFloat) -> UIImage? {
        drawings.image(for: page, scale: scale)
    }

    func thumbnail(for page: Page, scale: CGFloat) async -> UIImage? {
        _ = await ink(for: page.id)
        return drawings.image(for: page, scale: scale)
    }

    func dismissRecoveryNotice() {
        recoveryNotice = nil
    }

    func exportPDF() async throws -> URL {
        var contents: [PDFExporter.Content] = []
        for page in pages {
            if case .editable(let drawing) = await ink(for: page.id) {
                contents.append(PDFExporter.Content(page: page, drawing: drawing))
            } else {
                contents.append(PDFExporter.Content(page: page, drawing: nil))
            }
        }
        return try PDFExporter.export(title: notebook.title, pages: contents)
    }

    private func decode(_ ink: InkData, for pageID: Page.ID) -> PageInk {
        guard let drawing = try? InkCodec.drawing(from: ink) else {
            return .readOnly(message: String(localized: "This page could not be read."))
        }
        drawings[pageID] = drawing
        return .editable(drawing)
    }

    // MARK: Pages

    /// Adds a page after the last one. The manifest is written before any ink of the new page.
    func appendPage() async throws -> Page {
        let last = pages.last
        let page = Page(
            sortKey: .between(last?.sortKey, nil),
            size: last?.size ?? notebook.defaultPageSize,
            paper: last?.paper ?? notebook.defaultPaper,
            now: .now
        )
        try await updateManifest { $0.pages.append(page) }
        return page
    }

    func duplicatePage(_ pageID: Page.ID) async throws {
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }
        let source = pages[index]
        let nextKey = pages.indices.contains(index + 1) ? pages[index + 1].sortKey : nil
        let copy = Page(sortKey: .between(source.sortKey, nextKey), size: source.size, paper: source.paper, now: .now)
        try await updateManifest { $0.pages.append(copy) }
        if case .editable(let drawing) = await ink(for: pageID), !drawing.strokes.isEmpty {
            drawingDidChange(drawing, on: copy.id)
        }
    }

    func movePage(_ pageID: Page.ID, by offset: Int) async throws {
        guard let index = pages.firstIndex(where: { $0.id == pageID }), pages.indices.contains(index + offset) else {
            return
        }
        let target = index + offset
        let neighbours = offset < 0 ? (target - 1, target) : (target, target + 1)
        let lower = pages.indices.contains(neighbours.0) ? pages[neighbours.0].sortKey : nil
        let upper = pages.indices.contains(neighbours.1) ? pages[neighbours.1].sortKey : nil
        let key = SortKey.between(lower, upper)
        try await updatePage(pageID) { $0.sortKey = key }
    }

    func moveToTrash(_ pageID: Page.ID) async throws {
        try await updatePage(pageID) { $0.deletedAt = .now }
    }

    func restore(_ pageID: Page.ID) async throws {
        try await updatePage(pageID) { $0.deletedAt = nil }
    }

    func setPaper(_ paper: Paper, forPage pageID: Page.ID) async throws {
        try await updatePage(pageID) { $0.paper = paper }
    }

    func setPaperForAllPages(_ paper: Paper) async throws {
        try await updateManifest { manifest in
            manifest.notebook.defaultPaper = paper
            for index in manifest.pages.indices {
                manifest.pages[index].paper = paper
            }
        }
    }

    func rename(to title: String) async throws {
        guard let title = Title.normalized(title) else {
            return
        }
        try await updateManifest { manifest in
            manifest.notebook.title = title
            manifest.notebook.modifiedAt = .now
        }
    }

    private func updatePage(_ pageID: Page.ID, _ change: @escaping @Sendable (inout Page) -> Void) async throws {
        try await updateManifest { manifest in
            if let index = manifest.pageIndex(of: pageID) {
                change(&manifest.pages[index])
                manifest.pages[index].modifiedAt = .now
            }
        }
    }

    private func updateManifest(_ change: @Sendable (inout NotebookManifest) -> Void) async throws {
        let manifest = try await store.updateManifest(change)
        apply(manifest)
    }

    private func apply(_ manifest: NotebookManifest) {
        notebook = manifest.notebook
        pages = manifest.activePages
        trashedPages = manifest.trashedPages
        currentPageIndex = min(currentPageIndex, max(pages.count - 1, 0))
    }
}
