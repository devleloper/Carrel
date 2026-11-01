import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

@MainActor
struct InkAutosaverTests {
    /// Ink the autosaver reads at write time, standing in for the editor's live drawings.
    final class InkSource {
        var inks: [Page.ID: InkData] = [:]
    }

    private let fastPolicy = AutosavePolicy(
        idleDelay: .milliseconds(50),
        maximumDelay: .milliseconds(150),
        stallMargin: .seconds(30),
        retryDelay: .seconds(30)
    )

    private func makeAutosaver(_ fixture: NotebookFixture, source: InkSource, policy: AutosavePolicy) -> InkAutosaver {
        InkAutosaver(store: fixture.store, policy: policy) { source.inks[$0] }
    }

    @Test func flushWritesTheInkAsItIsAtSaveTime() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let source = InkSource()
        let autosaver = makeAutosaver(fixture, source: source, policy: AutosavePolicy())

        source.inks[fixture.pageID] = .sample(seed: 1)
        autosaver.pageDidChange(fixture.pageID)
        source.inks[fixture.pageID] = .sample(seed: 2)
        await autosaver.flush()

        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .ink(.sample(seed: 2)))
        #expect(autosaver.status == .saved)
    }

    @Test func pendingChangesAreReportedAsEditedUntilWritten() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let source = InkSource()
        let autosaver = makeAutosaver(fixture, source: source, policy: AutosavePolicy())

        source.inks[fixture.pageID] = .sample(seed: 1)
        autosaver.pageDidChange(fixture.pageID)

        #expect(autosaver.status == .edited)
        await autosaver.flush()
        #expect(autosaver.status == .saved)
    }

    @Test func savesOnItsOwnAfterTheWriterPauses() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let source = InkSource()
        let autosaver = makeAutosaver(fixture, source: source, policy: fastPolicy)

        source.inks[fixture.pageID] = .sample(seed: 3)
        autosaver.pageDidChange(fixture.pageID)
        try await Task.sleep(for: .milliseconds(500))

        #expect(autosaver.status == .saved)
        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .ink(.sample(seed: 3)))
    }

    @Test func overlappingFlushesNeverLeaveOlderInkOnDisk() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let source = InkSource()
        let autosaver = makeAutosaver(fixture, source: source, policy: AutosavePolicy())

        source.inks[fixture.pageID] = .sample(seed: 1)
        autosaver.pageDidChange(fixture.pageID)
        async let firstFlush: Void = autosaver.flush()
        source.inks[fixture.pageID] = .sample(seed: 2)
        autosaver.pageDidChange(fixture.pageID)
        await autosaver.flush()
        await firstFlush

        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .ink(.sample(seed: 2)))
    }

    @Test func failedWritesAreReportedAndRetried() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let source = InkSource()
        let autosaver = makeAutosaver(fixture, source: source, policy: AutosavePolicy())
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try FileManager.default.removeItem(at: fixture.store.package.inkDirectory)

        source.inks[fixture.pageID] = .sample(seed: 2)
        autosaver.pageDidChange(fixture.pageID)
        await autosaver.flush()
        #expect(autosaver.status == .notSaved)

        let inkDirectory = fixture.store.package.inkDirectory
        try FileManager.default.createDirectory(at: inkDirectory, withIntermediateDirectories: true)
        await autosaver.flush()
        #expect(autosaver.status == .saved)
    }
}
