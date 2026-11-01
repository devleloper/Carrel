import Foundation
import NotebookData

/// Creating and restoring library backups, and remembering when the last one was made.
@Observable
final class BackupModel {
    private(set) var isWorking = false
    private(set) var lastBackupDate: Date?
    var errorMessage: String?

    private let backup: LibraryBackup
    private let defaults: UserDefaults
    private let onRestore: () async -> Void

    private static let lastBackupKey = "lastBackupDate"

    /// - Parameter onRestore: Reloads whatever shows the library after its files were replaced.
    init(backup: LibraryBackup, defaults: UserDefaults, onRestore: @escaping () async -> Void) {
        self.backup = backup
        self.defaults = defaults
        self.onRestore = onRestore
        self.lastBackupDate = defaults.object(forKey: Self.lastBackupKey) as? Date
    }

    /// Writes a backup to a temporary file and returns it, ready to be shared or saved to Files.
    func makeBackup(now: Date = .now) async -> URL? {
        let fileName = "Carrel Backup \(now.formatted(.iso8601.year().month().day())).aar"
        let url = FileManager.default.temporaryDirectory.appending(path: fileName)
        isWorking = true
        defer { isWorking = false }
        do {
            try await backup.write(to: url)
            defaults.set(now, forKey: Self.lastBackupKey)
            lastBackupDate = now
            return url
        } catch {
            errorMessage = UserFacingError.message(for: error)
            return nil
        }
    }

    func restore(from url: URL) async {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await backup.restore(from: url)
            await onRestore()
        } catch {
            errorMessage = UserFacingError.message(for: error)
        }
    }
}
