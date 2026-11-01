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

    /// Takes a snapshot of a notebook whose pending changes are already on disk, then prunes old ones.
    public func takeSnapshot(of notebookID: Notebook.ID, now: Date = .now) throws {
        let directory = layout.snapshotsDirectory(for: notebookID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appending(
            path: "\(Int(now.timeIntervalSince1970)).notebook",
            directoryHint: .isDirectory
        )
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.copyItem(at: layout.packageURL(for: notebookID), to: destination)
        Self.prune(directory, now: now)
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
