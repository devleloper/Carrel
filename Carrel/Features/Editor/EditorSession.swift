import NotebookData
import NotebookDomain
import PencilKit
import SwiftUI

/// What the editor may do with a page's ink.
enum PageInk {
    case editable(PKDrawing)
    case readOnly(message: String)
}

/// One open notebook: its pages, the ink being edited, and when that ink reaches the disk.
@Observable
final class EditorSession: Identifiable {
    let id: Notebook.ID
    private(set) var notebook: Notebook
    private(set) var pages: [Page] = []
    private(set) var trashedPages: [Page] = []
    private(set) var saveStatus: SaveStatus = .saved
    private(set) var saveErrorDescription: String?
    private(set) var recoveryNotice: String?
    var currentPageIndex = 0
    /// Set by the page overview; the canvas scrolls there and clears it.
    var scrollTarget: Page.ID?
    let undoManager = UndoManager()

    @ObservationIgnored private let store: NotebookStore
    @ObservationIgnored private let policy = AutosavePolicy()
    @ObservationIgnored private var drawings: [Page.ID: PKDrawing] = [:]
    @ObservationIgnored private var dirtyPages: Set<Page.ID> = []
    @ObservationIgnored private var firstUnsavedChange: ContinuousClock.Instant?
    @ObservationIgnored private var lastChange: ContinuousClock.Instant?
    @ObservationIgnored private var writingSince: ContinuousClock.Instant?
    @ObservationIgnored private var lastWriteFailed = false
    @ObservationIgnored private var scheduledSave: Task<Void, Never>?
    @ObservationIgnored private var statusRefresh: Task<Void, Never>?
    @ObservationIgnored private var inFlightSave: Task<Void, Never>?

    private init(store: NotebookStore, manifest: NotebookManifest) {
        self.id = manifest.notebook.id
        self.notebook = manifest.notebook
        self.store = store
        apply(manifest)
    }

    static func open(_ store: NotebookStore) async -> EditorSession {
        EditorSession(store: store, manifest: await store.manifest)
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
        dirtyPages.insert(pageID)
        let now = ContinuousClock.now
        if firstUnsavedChange == nil {
            firstUnsavedChange = now
        }
        lastChange = now
        refreshStatus()
        scheduleSave()
    }

    /// Ink rendered as it appears on paper. Ink is content, so it never adapts to dark mode.
    func inkImage(for page: Page, scale: CGFloat) -> UIImage? {
        guard let drawing = drawings[page.id], !drawing.strokes.isEmpty else {
            return nil
        }
        return Self.render(drawing, size: page.size, scale: scale)
    }

    func thumbnail(for page: Page, scale: CGFloat) async -> UIImage? {
        guard case .editable(let drawing) = await ink(for: page.id), !drawing.strokes.isEmpty else {
            return nil
        }
        return Self.render(drawing, size: page.size, scale: scale)
    }

    func dismissRecoveryNotice() {
        recoveryNotice = nil
    }

    private func decode(_ ink: InkData, for pageID: Page.ID) -> PageInk {
        guard let drawing = try? InkCodec.drawing(from: ink) else {
            return .readOnly(message: String(localized: "This page could not be read."))
        }
        drawings[pageID] = drawing
        return .editable(drawing)
    }

    static func render(_ drawing: PKDrawing, size: PageSize, scale: CGFloat) -> UIImage {
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: CGRect(x: 0, y: 0, width: size.width, height: size.height), scale: scale)
        }
        return image
    }

    // MARK: Saving

    /// Writes everything now. Called when the scene goes inactive and when the editor closes.
    func flush() async {
        scheduledSave?.cancel()
        await save()
        try? await store.writePendingManifestChanges()
    }

    /// Flushes under a background task, so leaving the app right after writing cannot cut the save short.
    func flushBeforeSuspension() {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save notebook", expirationHandler: nil)
        Task {
            await flush()
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }

    private func scheduleSave(after delay: Duration? = nil) {
        guard let firstUnsavedChange, let lastChange else {
            return
        }
        let deadline = delay.map { ContinuousClock.now + $0 }
            ?? policy.saveDeadline(firstUnsavedChange: firstUnsavedChange, lastChange: lastChange)
        scheduledSave?.cancel()
        scheduledSave = Task { [weak self] in
            try? await Task.sleep(until: deadline, clock: .continuous)
            guard !Task.isCancelled else {
                return
            }
            await self?.save()
        }
    }

    /// Runs one write at a time, so an older drawing of a page can never land after a newer one.
    private func save() async {
        while let running = inFlightSave {
            await running.value
        }
        guard !dirtyPages.isEmpty else {
            refreshStatus()
            return
        }
        let write = Task { await writeDirtyPages() }
        inFlightSave = write
        await write.value
        if inFlightSave == write {
            inFlightSave = nil
        }
    }

    private func writeDirtyPages() async {
        let batch = dirtyPages
        dirtyPages.removeAll()
        writingSince = firstUnsavedChange ?? .now
        firstUnsavedChange = nil

        var failedPages: Set<Page.ID> = []
        for pageID in batch {
            guard let drawing = drawings[pageID] else {
                continue
            }
            do {
                try await store.saveInk(InkCodec.inkData(from: drawing), for: pageID)
            } catch NotebookStoreError.requiresNewerSystem {
                continue
            } catch {
                failedPages.insert(pageID)
                saveErrorDescription = error.localizedDescription
            }
        }

        let batchStart = writingSince
        writingSince = nil
        lastWriteFailed = !failedPages.isEmpty
        if lastWriteFailed {
            dirtyPages.formUnion(failedPages)
            firstUnsavedChange = [firstUnsavedChange, batchStart].compactMap { $0 }.min()
            scheduleSave(after: .seconds(5))
        } else if dirtyPages.isEmpty {
            saveErrorDescription = nil
        } else {
            scheduleSave()
        }
        refreshStatus()
    }

    private func refreshStatus() {
        let pendingSince = [firstUnsavedChange, writingSince].compactMap { $0 }.min()
        saveStatus = policy.status(firstUnsavedChange: pendingSince, lastWriteFailed: lastWriteFailed, now: .now)
        statusRefresh?.cancel()
        guard let pendingSince, saveStatus == .edited else {
            return
        }
        let stallDeadline = policy.stallDeadline(firstUnsavedChange: pendingSince)
        statusRefresh = Task { [weak self] in
            try? await Task.sleep(until: stallDeadline, clock: .continuous)
            guard !Task.isCancelled else {
                return
            }
            self?.refreshStatus()
        }
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
        guard let index = pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }
        let target = index + offset
        guard pages.indices.contains(target) else {
            return
        }
        let lower: SortKey?
        let upper: SortKey?
        if offset < 0 {
            lower = pages.indices.contains(target - 1) ? pages[target - 1].sortKey : nil
            upper = pages[target].sortKey
        } else {
            lower = pages[target].sortKey
            upper = pages.indices.contains(target + 1) ? pages[target + 1].sortKey : nil
        }
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
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        try await updateManifest { manifest in
            manifest.notebook.title = trimmed
            manifest.notebook.modifiedAt = .now
        }
    }

    func exportPDF() async throws -> URL {
        var contents: [(Page, PKDrawing?)] = []
        for page in pages {
            if case .editable(let drawing) = await ink(for: page.id) {
                contents.append((page, drawing))
            } else {
                contents.append((page, nil))
            }
        }
        return try PDFExporter.export(title: notebook.title, pages: contents)
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
