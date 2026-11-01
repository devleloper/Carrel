import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct SnapshotStoreTests {
    @Test func keepsRecentSessionsAndOnePerDay() throws {
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

        SnapshotStore.prune(directory, now: now, calendar: Calendar(identifier: .gregorian))

        #expect(FileManager.default.directoryContents(at: directory).count == 6)
    }

    @Test func snapshotCopiesTheNotebookPackage() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = LibraryLayout(root: root)
        let library = try LibraryStore(layout: layout, supportedContentVersion: 5)
        let notebook = try await library.createNotebook(
            title: "Chemistry",
            cover: Cover(preset: .sageLinen),
            paper: .standard,
            pageSize: .a4,
            folderID: nil
        )

        try SnapshotStore(layout: layout).takeSnapshot(of: notebook.id)

        let snapshots = FileManager.default.directoryContents(at: layout.snapshotsDirectory(for: notebook.id))
        #expect(snapshots.count == 1)
    }
}
