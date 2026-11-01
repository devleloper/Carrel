import Foundation
import NotebookData

/// The composition root: builds the object graph once and hands it to the views.
final class AppDependencies {
    let library: LibraryModel

    init(arguments: [String] = ProcessInfo.processInfo.arguments) throws {
        let store = try LibraryStore(
            layout: LibraryLayout(root: Self.libraryRoot(arguments: arguments)),
            supportedContentVersion: InkCodec.supportedContentVersion
        )
        library = LibraryModel(library: store)
    }

    /// UI tests start from an empty library that never touches the user's notebooks.
    private static func libraryRoot(arguments: [String]) -> URL {
        if arguments.contains("-ui-testing") {
            return FileManager.default.temporaryDirectory.appending(path: "UITests-\(UUID().uuidString)", directoryHint: .isDirectory)
        }
        return URL.applicationSupportDirectory.appending(path: "Carrel", directoryHint: .isDirectory)
    }
}
