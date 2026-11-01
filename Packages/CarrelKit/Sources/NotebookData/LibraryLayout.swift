import Foundation
import NotebookDomain

/// Where the library lives on disk, and the only place that knows its file names.
///
/// Everything a backup must contain sits under `libraryDirectory`; quarantine and snapshots are its siblings so
/// that a backup never carries them and a restore never overwrites them.
public struct LibraryLayout: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public var libraryDirectory: URL {
        root.appending(path: "Library", directoryHint: .isDirectory)
    }

    public var manifestURL: URL {
        Self.manifestURL(in: libraryDirectory)
    }

    public var previousManifestURL: URL {
        Self.previousManifestURL(in: libraryDirectory)
    }

    public var notebooksDirectory: URL {
        Self.notebooksDirectory(in: libraryDirectory)
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

    /// The same names inside any library directory, such as one extracted from a backup.
    static func manifestURL(in libraryDirectory: URL) -> URL {
        libraryDirectory.appending(path: "library.json")
    }

    static func previousManifestURL(in libraryDirectory: URL) -> URL {
        libraryDirectory.appending(path: "library.json.previous")
    }

    static func notebooksDirectory(in libraryDirectory: URL) -> URL {
        libraryDirectory.appending(path: "Notebooks", directoryHint: .isDirectory)
    }

    /// The notebook a package directory belongs to, or `nil` for anything that is not a notebook package.
    static func notebookID(ofPackage url: URL) -> Notebook.ID? {
        guard url.pathExtension == "notebook" else {
            return nil
        }
        return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
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

    /// The page an ink file belongs to, or `nil` for anything that is not a current ink file.
    static func pageID(ofInkFile url: URL) -> Page.ID? {
        guard url.pathExtension == "ink" else {
            return nil
        }
        return UUID(uuidString: url.deletingPathExtension().lastPathComponent)
    }
}
