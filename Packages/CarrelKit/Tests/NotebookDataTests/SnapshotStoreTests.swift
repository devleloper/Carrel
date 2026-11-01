import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct SnapshotStoreTests {
    @Test func keepsRecentSessionsAndTheNewestOfEachDay() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ages: [TimeInterval] = [0, 60, 120, 180, 240, 300, 360, 86_400 * 2, 86_400 * 2 + 60, 86_400 * 40]
        for age in ages {
            let name = "\(Int(now.timeIntervalSince1970 - age)).notebook"
            try FileManager.default.createDirectory(
                at: directory.appending(path: name, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        SnapshotStore.prune(directory, now: now, calendar: calendar)

        let kept = Set(FileManager.default.directoryContents(at: directory).map(\.lastPathComponent))
        let expectedAges: [TimeInterval] = [0, 60, 120, 180, 240, 86_400 * 2]
        #expect(kept == Set(expectedAges.map { "\(Int(now.timeIntervalSince1970 - $0)).notebook" }))
    }

    @Test func snapshotIncludesChangesStillHeldInMemory() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)
        let layout = LibraryLayout(root: fixture.directory)

        try await SnapshotStore(layout: layout).takeSnapshot(of: fixture.store)

        let notebookID = await fixture.store.manifest.notebook.id
        let snapshots = FileManager.default.directoryContents(at: layout.snapshotsDirectory(for: notebookID))
        let snapshot = try #require(snapshots.first)
        let manifest = try NotebookStore.readManifest(of: NotebookPackage(url: snapshot))
        #expect(manifest.pages.first?.inkHash == InkEnvelope.hash(of: InkData.sample(seed: 2).payload))
    }
}
