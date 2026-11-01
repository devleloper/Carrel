import Foundation

extension FileManager {
    /// Replaces the file at `url` with `data`, keeping the replaced generation at `previousURL`.
    ///
    /// The new contents are written next to the destination first and swapped in with `replaceItemAt`, so a
    /// crash leaves either the old or the new file in place, never a half-written one. A missing original is
    /// still handled by the recovery chain rather than assumed impossible.
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

    func directoryContents(at url: URL) -> [URL] {
        (try? contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
    }

    /// Total size of the regular files under `url`.
    func allocatedSize(ofDirectory url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey]
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
