import Foundation

extension FileManager {
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
