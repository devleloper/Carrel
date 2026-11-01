import Foundation
import NotebookData

/// The composition root: builds the object graph once and hands it to the views.
final class AppDependencies {
    let library: LibraryModel
    let backup: BackupModel

    init(arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard) throws {
        let layout = LibraryLayout(root: Self.libraryRoot(arguments: arguments))
        let store = try LibraryStore(layout: layout, supportedContentVersion: InkCodec.supportedContentVersion)
        let library = LibraryModel(library: store, snapshots: SnapshotStore(layout: layout))
        self.library = library
        self.backup = BackupModel(backup: LibraryBackup(library: store), defaults: defaults) {
            await library.load()
        }
    }

    /// UI tests start from an empty library that never touches the user's notebooks.
    private static func libraryRoot(arguments: [String]) -> URL {
        if arguments.contains("-ui-testing") {
            return FileManager.default.temporaryDirectory.appending(
                path: "UITests-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        }
        return URL.applicationSupportDirectory.appending(path: "Carrel", directoryHint: .isDirectory)
    }
}
