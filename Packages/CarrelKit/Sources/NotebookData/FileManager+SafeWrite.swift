import Foundation

extension FileManager {
    /// Replaces the file at `url` with `data`, keeping the replaced generation at `previousURL`.
    ///
    /// The new contents are staged in a replacement directory on the same volume and swapped in with
    /// `replaceItemAt`, so a crash leaves either the old or the new file in place, never a half-written one.
    /// With no current file there is no generation to keep, and the file is written atomically.
    func replaceContents(of url: URL, with data: Data, keepingPreviousAt previousURL: URL) throws {
        guard fileExists(atPath: url.path(percentEncoded: false)) else {
            try data.write(to: url, options: .atomic)
            return
        }
        let stagingDirectory = try self.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: url,
            create: true
        )
        defer { try? removeItem(at: stagingDirectory) }

        let stagedFile = stagingDirectory.appending(path: url.lastPathComponent)
        try data.write(to: stagedFile)
        if fileExists(atPath: previousURL.path(percentEncoded: false)) {
            try removeItem(at: previousURL)
        }
        try copyItem(at: url, to: previousURL)
        _ = try replaceItemAt(url, withItemAt: stagedFile)
    }

    /// Moves a damaged file out of the way under a unique name, so it can still be salvaged later.
    func quarantine(_ url: URL, in recoveredDirectory: URL) {
        let name = "\(UUID().uuidString)-\(url.lastPathComponent)"
        try? createDirectory(at: recoveredDirectory, withIntermediateDirectories: true)
        try? moveItem(at: url, to: recoveredDirectory.appending(path: name))
    }
}
