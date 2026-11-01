import Foundation
import NotebookDomain
import Observation

/// Writes edited ink to disk while the user keeps writing, and reports whether everything is saved.
///
/// Pages are only marked dirty on each change and encoded when a save runs, so a long page is serialized once
/// per save instead of once per stroke. Writes run one at a time, so an older drawing of a page can never land
/// after a newer one.
@MainActor
@Observable
public final class InkAutosaver {
    public private(set) var status: SaveStatus = .saved
    public private(set) var lastErrorDescription: String?

    private let store: NotebookStore
    private let policy: AutosavePolicy
    private let encodeInk: (Page.ID) -> InkData?
    @ObservationIgnored private var dirtyPages: Set<Page.ID> = []
    @ObservationIgnored private var firstUnsavedChange: ContinuousClock.Instant?
    @ObservationIgnored private var lastChange: ContinuousClock.Instant?
    @ObservationIgnored private var writingSince: ContinuousClock.Instant?
    @ObservationIgnored private var lastWriteFailed = false
    @ObservationIgnored private var scheduledSave: Task<Void, Never>?
    @ObservationIgnored private var statusRefresh: Task<Void, Never>?
    @ObservationIgnored private var inFlightSave: Task<Void, Never>?

    /// - Parameter encodeInk: Returns the current ink of a page at the moment it is written.
    public init(
        store: NotebookStore,
        policy: AutosavePolicy = AutosavePolicy(),
        encodeInk: @escaping (Page.ID) -> InkData?
    ) {
        self.store = store
        self.policy = policy
        self.encodeInk = encodeInk
    }

    public func pageDidChange(_ pageID: Page.ID) {
        dirtyPages.insert(pageID)
        let now = ContinuousClock.now
        if firstUnsavedChange == nil {
            firstUnsavedChange = now
        }
        lastChange = now
        refreshStatus()
        scheduleSave()
    }

    /// Writes everything now, including manifest details kept in memory. Used when the app leaves the
    /// foreground and when the editor closes.
    public func flush() async {
        scheduledSave?.cancel()
        await save()
        try? await store.writePendingManifestChanges()
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
        let batchStart = firstUnsavedChange ?? .now
        writingSince = batchStart
        firstUnsavedChange = nil

        var failedPages: Set<Page.ID> = []
        for pageID in batch {
            guard let ink = encodeInk(pageID) else {
                continue
            }
            do {
                try await store.saveInk(ink, for: pageID)
            } catch NotebookStoreError.requiresNewerSystem {
                continue
            } catch {
                failedPages.insert(pageID)
                lastErrorDescription = error.localizedDescription
            }
        }

        writingSince = nil
        lastWriteFailed = !failedPages.isEmpty
        if lastWriteFailed {
            dirtyPages.formUnion(failedPages)
            firstUnsavedChange = min(firstUnsavedChange ?? batchStart, batchStart)
            scheduleSave(after: policy.retryDelay)
        } else if dirtyPages.isEmpty {
            lastErrorDescription = nil
        } else {
            scheduleSave()
        }
        refreshStatus()
    }

    private func refreshStatus() {
        let pendingSince = [firstUnsavedChange, writingSince].compactMap { $0 }.min()
        status = policy.status(firstUnsavedChange: pendingSince, lastWriteFailed: lastWriteFailed, now: .now)
        statusRefresh?.cancel()
        guard let pendingSince, status == .edited else {
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
}
