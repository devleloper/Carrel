import Foundation
import NotebookDomain

/// Copies of notebooks taken before each editing session: a safety net beside the previous file generations.
///
/// On APFS a copy is a clone, so a snapshot costs almost no space until the notebook changes.
public struct SnapshotStore: Sendable {
    public static let recentCount = 5
    public static let dailyWindow: TimeInterval = 30 * 24 * 60 * 60

    private let layout: LibraryLayout

    public init(layout: LibraryLayout) {
        self.layout = layout
    }

    /// Snapshots a notebook through its store, so the copy includes changes still held in memory.
    public func takeSnapshot(of store: NotebookStore, now: Date = .now) async throws {
        let notebookID = await store.manifest.notebook.id
        guard let destination = try newSnapshotURL(for: notebookID, now: now) else {
            return
        }
        try await store.copyPackage(to: destination)
        Self.prune(destination.deletingLastPathComponent(), now: now)
    }

    /// Snapshots a package straight from its files, for a store that holds nothing in memory yet.
    func takeSnapshot(ofPackageAt packageURL: URL, notebookID: Notebook.ID, now: Date = .now) throws {
        guard let destination = try newSnapshotURL(for: notebookID, now: now) else {
            return
        }
        try FileManager.default.copyItem(at: packageURL, to: destination)
        Self.prune(destination.deletingLastPathComponent(), now: now)
    }

    /// `nil` when a snapshot was already taken this second.
    private func newSnapshotURL(for notebookID: Notebook.ID, now: Date) throws -> URL? {
        let directory = layout.snapshotsDirectory(for: notebookID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(
            path: "\(Int(now.timeIntervalSince1970)).notebook",
            directoryHint: .isDirectory
        )
        return FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) ? nil : destination
    }

    /// Keeps the most recent snapshots plus the newest one of each day inside the daily window.
    static func prune(_ directory: URL, now: Date, calendar: Calendar = .current) {
        let snapshots = FileManager.default.directoryContents(at: directory)
            .compactMap { url -> (url: URL, date: Date)? in
                guard let seconds = TimeInterval(url.deletingPathExtension().lastPathComponent) else {
                    return nil
                }
                return (url, Date(timeIntervalSince1970: seconds))
            }
            .sorted { $0.date > $1.date }

        var keep = Set(snapshots.prefix(recentCount).map(\.url))
        var keptDays = Set<DateComponents>()
        for snapshot in snapshots where now.timeIntervalSince(snapshot.date) <= dailyWindow {
            let day = calendar.dateComponents([.year, .month, .day], from: snapshot.date)
            if keptDays.insert(day).inserted {
                keep.insert(snapshot.url)
            }
        }
        for snapshot in snapshots where !keep.contains(snapshot.url) {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }
}
