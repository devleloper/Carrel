import Foundation

public enum LibraryBackupError: Error, Equatable {
    case insufficientSpace
    case notABackup
}

/// Backs up the whole library into one Apple Archive file and restores it.
public struct LibraryBackup: Sendable {
    private let store: LibraryStore

    public init(store: LibraryStore) {
        self.store = store
    }

    private var layout: LibraryLayout {
        store.layout
    }

    public func write(to destination: URL) async throws {
        try await store.writePendingChanges()
        let required = FileManager.default.allocatedSize(ofDirectory: layout.libraryDirectory)
        let values = try? layout.root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard (values?.volumeAvailableCapacityForImportantUsage ?? .max) > required else {
            throw LibraryBackupError.insufficientSpace
        }
        try LibraryArchive.write(directory: layout.libraryDirectory, to: destination)
    }

    /// Replaces the library with a backup. The current library is moved to the recovery folder, never deleted.
    public func restore(from archive: URL, now: Date = .now) async throws {
        let fileManager = FileManager.default
        let staging = layout.root.appending(path: "Restoring-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try LibraryArchive.extract(archive, into: staging)
        let notebooks = LibraryLayout.notebooksDirectory(in: staging)
        guard fileManager.fileExists(atPath: notebooks.path(percentEncoded: false)) else {
            throw LibraryBackupError.notABackup
        }
        let replaced = layout.recoveredDirectory.appending(
            path: "Library-before-restore-\(Int(now.timeIntervalSince1970))",
            directoryHint: .isDirectory
        )
        try await store.replaceLibrary(with: staging, keepingCurrentAt: replaced)
    }
}
