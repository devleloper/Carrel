import NotebookData
import NotebookDomain
import PencilKit
import SwiftUI

/// What the editor may do with a page's ink.
enum PageInk {
    case editable(PKDrawing)
    case readOnly(message: String)

    var drawing: PKDrawing? {
        switch self {
        case .editable(let drawing): drawing
        case .readOnly: nil
        }
    }
}

/// One open notebook: its pages and the ink being edited.
///
/// Ink is written by `InkAutosaver`; every change to the page structure is an intent of `NotebookStore`, so the
/// rules for sort keys and modification dates live in one place and are tested there.
@Observable
final class EditorSession: Identifiable {
    let id: Notebook.ID
    let autosaver: InkAutosaver
    let undoManager = UndoManager()
    private(set) var notebook: Notebook
    private(set) var pages: [Page] = []
    private(set) var trashedPages: [Page] = []
    private(set) var recoveryNotice: String?
    var errorMessage: String?
    var currentPageIndex = 0
    /// Set by the page overview; the canvas scrolls there and clears it.
    var scrollTarget: Page.ID?

    private let store: NotebookStore
    private let drawings: DrawingCache

    private init(store: NotebookStore, manifest: NotebookManifest, autosavePolicy: AutosavePolicy) {
        let drawings = DrawingCache()
        self.id = manifest.notebook.id
        self.notebook = manifest.notebook
        self.store = store
        self.drawings = drawings
        self.autosaver = InkAutosaver(store: store, policy: autosavePolicy) { drawings.inkData(for: $0) }
        apply(manifest)
    }

    static func open(_ store: NotebookStore, autosavePolicy: AutosavePolicy = AutosavePolicy()) async -> EditorSession {
        EditorSession(store: store, manifest: await store.manifest, autosavePolicy: autosavePolicy)
    }

    var currentPage: Page? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    /// Writes everything now. Returns `false` and sets `errorMessage` when something could not be saved; the
    /// editor then stays open, so unsaved strokes are not thrown away with it.
    func saveAll() async -> Bool {
        await autosaver.flush()
        guard let error = autosaver.lastError else {
            return true
        }
        errorMessage = UserFacingError.message(for: error)
        return false
    }

    // MARK: Ink

    func ink(for pageID: Page.ID) async -> PageInk {
        if let drawing = drawings[pageID] {
            return .editable(drawing)
        }
        let result = await store.ink(for: pageID)
        // While the store was reading, the page may have been loaded by another caller or drawn on; the
        // drawing in memory is newer than the file.
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
        case .damaged:
            recoveryNotice = String(localized: "A damaged page could not be restored. Its files were kept.")
            return .editable(PKDrawing())
        case .missing:
            recoveryNotice = String(localized: "The ink of a page is missing. The page was left blank.")
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

    /// Read-only pages are exported with their paper only: their ink cannot be decoded on this system.
    func exportPDF() async throws -> URL {
        var contents: [PDFExporter.Content] = []
        for page in pages {
            let drawing = await ink(for: page.id).drawing
            contents.append(PDFExporter.Content(page: page, drawing: drawing))
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

    /// Adds a page after the last one. Returns `nil` and sets `errorMessage` when the page could not be added.
    func appendPage() async -> Page? {
        await perform { try await store.appendPage() }
    }

    func duplicatePage(_ pageID: Page.ID) async {
        // The store copies the page's ink file, so its latest strokes must be on disk first.
        guard await saveAll() else {
            return
        }
        await perform { _ = try await store.duplicatePage(pageID) }
    }

    func movePage(_ pageID: Page.ID, by offset: Int) async {
        await perform { try await store.movePage(pageID, by: offset) }
    }

    func moveToTrash(_ pageID: Page.ID) async {
        await perform { try await store.setPageInTrash(pageID, true) }
    }

    func restore(_ pageID: Page.ID) async {
        await perform { try await store.setPageInTrash(pageID, false) }
    }

    func setPaper(_ paper: Paper, forPage pageID: Page.ID) async {
        await perform { try await store.setPaper(paper, forPage: pageID) }
    }

    func setPaperForAllPages(_ paper: Paper) async {
        await perform { try await store.setPaperForAllPages(paper) }
    }

    func rename(to title: String) async {
        await perform { try await store.rename(to: title) }
    }

    /// Runs a change of the notebook and shows the result. A failed change leaves the store as it was.
    @discardableResult
    private func perform<Value>(_ change: () async throws -> Value) async -> Value? {
        do {
            let value = try await change()
            apply(await store.manifest)
            return value
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }

    private func apply(_ manifest: NotebookManifest) {
        notebook = manifest.notebook
        pages = manifest.activePages
        trashedPages = manifest.trashedPages
        currentPageIndex = min(currentPageIndex, max(pages.count - 1, 0))
    }
}
