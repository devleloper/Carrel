import Foundation
import NotebookData

/// Turns storage errors into sentences that tell the user what happened and what to do.
enum UserFacingError {
    static func message(for error: any Error) -> String {
        switch error {
        case LibraryBackupError.insufficientSpace, CocoaError.fileWriteOutOfSpace:
            String(localized: "There isn't enough free space on this iPad. Free up some space and try again.")
        case LibraryBackupError.notABackup:
            String(localized: "This file isn't a Carrel backup.")
        case NotebookStoreError.schemaNewerThanApp, LibraryStoreError.schemaNewerThanApp:
            String(localized: "This was saved by a newer version of Carrel. Update the app to open it.")
        case NotebookStoreError.manifestUnreadable:
            String(localized: "This notebook couldn't be read. Its files were kept so it can be recovered.")
        default:
            error.localizedDescription
        }
    }
}
