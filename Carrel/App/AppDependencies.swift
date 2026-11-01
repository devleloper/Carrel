import Foundation
import NotebookData

/// The composition root: builds the object graph once and hands it to the views.
final class AppDependencies {
    let libraryModel: LibraryModel
    let backupModel: BackupModel
    let toolPalette: ToolPaletteModel

    init(arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        let isUITesting = arguments.contains("-ui-testing")
        let layout = LibraryLayout(root: isUITesting ? Self.uiTestingLibraryRoot() : Self.libraryRoot)
        let defaults = isUITesting ? Self.uiTestingDefaults() : .standard
        let store = try LibraryStore(layout: layout, supportedContentVersion: InkCodec.supportedContentVersion)
        let libraryModel = LibraryModel(store: store, snapshots: SnapshotStore(layout: layout))
        self.libraryModel = libraryModel
        self.backupModel = BackupModel(backup: LibraryBackup(store: store), defaults: defaults) {
            await libraryModel.load()
        }
        self.toolPalette = ToolPaletteModel(defaults: defaults)
    }

    private static let libraryRoot = URL.applicationSupportDirectory.appending(
        path: "Carrel",
        directoryHint: .isDirectory
    )

    // UI tests start from an empty library and default settings, and never touch the user's notebooks.

    private static func uiTestingLibraryRoot() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "UITests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
    }

    private static func uiTestingDefaults() -> UserDefaults {
        let suiteName = "UITests"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
}
