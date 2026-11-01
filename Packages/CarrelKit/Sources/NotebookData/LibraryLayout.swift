import Foundation
import NotebookDomain

/// Where the library lives on disk.
///
/// Everything a backup must contain sits under `library`; quarantine and snapshots are its siblings so that a
/// backup never carries them and a restore never overwrites them.
public struct LibraryLayout: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var library: URL {
        root.appending(path: "Library", directoryHint: .isDirectory)
    }

    public var manifestURL: URL {
        library.appending(path: "library.json")
    }

    public var previousManifestURL: URL {
        library.appending(path: "library.json.previous")
    }

    public var notebooksDirectory: URL {
        library.appending(path: "Notebooks", directoryHint: .isDirectory)
    }

    /// Damaged files and replaced libraries. Never cleaned automatically.
    public var recoveredDirectory: URL {
        root.appending(path: "Recovered", directoryHint: .isDirectory)
    }

    public var snapshotsDirectory: URL {
        root.appending(path: "Snapshots", directoryHint: .isDirectory)
    }

    public func packageURL(for notebookID: Notebook.ID) -> URL {
        notebooksDirectory.appending(path: "\(notebookID.uuidString).notebook", directoryHint: .isDirectory)
    }

    public func snapshotsDirectory(for notebookID: Notebook.ID) -> URL {
        snapshotsDirectory.appending(path: notebookID.uuidString, directoryHint: .isDirectory)
    }
}

/// File locations inside one `<id>.notebook` package.
public struct NotebookPackage: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var manifestURL: URL {
        url.appending(path: "notebook.json")
    }

    public var previousManifestURL: URL {
        url.appending(path: "notebook.json.previous")
    }

    public var inkDirectory: URL {
        url.appending(path: "ink", directoryHint: .isDirectory)
    }

    public func inkURL(for pageID: Page.ID) -> URL {
        inkDirectory.appending(path: "\(pageID.uuidString).ink")
    }

    public func previousInkURL(for pageID: Page.ID) -> URL {
        inkDirectory.appending(path: "\(pageID.uuidString).ink.previous")
    }
}
