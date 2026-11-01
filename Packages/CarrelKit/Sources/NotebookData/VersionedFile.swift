import Foundation

enum VersionedFileError: Error, Equatable {
    case unreadable
    case newerSchema
}

/// Reads JSON files that are written with a previous generation kept beside them.
enum VersionedFile {
    /// Decodes the first readable generation in `urls`.
    ///
    /// A file written by a newer app stops the search: falling back to an older generation would silently
    /// discard the newer data on the next save. When an older generation is used, the damaged newer ones are
    /// moved to `recoveredDirectory`; left in place, the next write would make the damaged file the new
    /// "previous" and destroy the only intact copy.
    static func read<Value: Decodable>(
        _ type: Value.Type,
        from urls: [URL],
        supportedSchemaVersion: Int,
        movingDamagedTo recoveredDirectory: URL? = nil
    ) throws -> Value {
        var damaged: [URL] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url) else {
                continue
            }
            if let probe = try? JSONCoding.decode(SchemaProbe.self, from: data),
                probe.schemaVersion > supportedSchemaVersion
            {
                throw VersionedFileError.newerSchema
            }
            guard let value = try? JSONCoding.decode(type, from: data) else {
                damaged.append(url)
                continue
            }
            if let recoveredDirectory {
                damaged.forEach { FileManager.default.quarantine($0, in: recoveredDirectory) }
            }
            return value
        }
        throw VersionedFileError.unreadable
    }

    static func write(_ value: some Encodable, to url: URL, keepingPreviousAt previousURL: URL) throws {
        try FileManager.default.replaceContents(
            of: url,
            with: JSONCoding.encode(value),
            keepingPreviousAt: previousURL
        )
    }
}
