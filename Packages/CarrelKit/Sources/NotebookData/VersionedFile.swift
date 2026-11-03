import Foundation

enum VersionedFileError: Error, Equatable {
    case unreadable
    case newerSchema
}

/// Reads JSON files that are written with a previous generation kept beside them.
enum VersionedFile {
    /// A decoded generation, with the schema version it was written in.
    struct Generation<Value> {
        let value: Value
        /// Older than the current version when `value` was migrated on reading.
        let schemaVersion: Int
        /// Whether a newer generation was missing or damaged, so `value` comes from an older one.
        var isFallback = false
    }

    /// Decodes the first readable generation in `urls`, migrated to the current schema.
    ///
    /// A file written by a newer app stops the search: falling back to an older generation would silently
    /// discard the newer data on the next save. When an older generation is used, the damaged newer ones are
    /// moved to `recoveredDirectory`; left in place, the next write would make the damaged file the new
    /// "previous" and destroy the only intact copy.
    static func read<Value: Decodable>(
        _ type: Value.Type,
        from urls: [URL],
        migration: SchemaMigration,
        movingDamagedTo recoveredDirectory: URL? = nil
    ) throws -> Generation<Value> {
        var damaged: [URL] = []
        for (index, url) in urls.enumerated() {
            guard let data = try? Data(contentsOf: url) else {
                continue
            }
            var generation: Generation<Value>
            do {
                generation = try decodeGeneration(type, from: data, migration: migration)
            } catch VersionedFileError.newerSchema {
                throw VersionedFileError.newerSchema
            } catch {
                damaged.append(url)
                continue
            }
            if let recoveredDirectory {
                damaged.forEach { FileManager.default.quarantine($0, in: recoveredDirectory) }
            }
            generation.isFallback = index > 0
            return generation
        }
        throw VersionedFileError.unreadable
    }

    /// Decodes one generation, migrated to the current schema.
    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        migration: SchemaMigration
    ) throws -> Value {
        try decodeGeneration(type, from: data, migration: migration).value
    }

    /// The schema version is read first, so a file from a newer app is recognised before decoding fails on fields
    /// this app does not know.
    private static func decodeGeneration<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        migration: SchemaMigration
    ) throws -> Generation<Value> {
        guard let version = try? JSONCoding.decode(SchemaProbe.self, from: data).schemaVersion else {
            throw VersionedFileError.unreadable
        }
        guard version <= migration.currentVersion else {
            throw VersionedFileError.newerSchema
        }
        do {
            let value = try JSONCoding.decode(type, from: migration.migrate(data, from: version))
            return Generation(value: value, schemaVersion: version)
        } catch {
            throw VersionedFileError.unreadable
        }
    }

    static func write(_ value: some Encodable, to url: URL, keepingPreviousAt previousURL: URL) throws {
        try FileManager.default.replaceContents(
            of: url,
            with: JSONCoding.encode(value),
            keepingPreviousAt: previousURL
        )
    }
}
