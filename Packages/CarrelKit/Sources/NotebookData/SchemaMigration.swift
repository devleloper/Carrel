import Foundation

enum SchemaMigrationError: Error, Equatable {
    case malformed
}

/// The steps that bring a JSON file of an older schema version up to the current one.
///
/// Steps edit the JSON object before it is decoded, so the `Codable` types describe only the current schema and
/// never carry optional fields just to read old files. The migrated value reaches the disk with the next real
/// change, not when the file is read, and the file it replaces stays beside it as the previous generation.
struct SchemaMigration: Sendable {
    typealias Step = @Sendable (inout [String: Any]) throws -> Void

    /// `steps[0]` turns version 1 into version 2, `steps[1]` version 2 into version 3, and so on.
    private let steps: [Step]

    init(steps: [Step] = []) {
        self.steps = steps
    }

    var currentVersion: Int {
        steps.count + 1
    }

    /// Returns `data` in the current schema. Data that is already current is returned unchanged.
    func migrate(_ data: Data, from version: Int) throws -> Data {
        guard version < currentVersion else {
            return data
        }
        guard version >= 1, var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SchemaMigrationError.malformed
        }
        for step in steps[(version - 1)...] {
            try step(&object)
        }
        object["schemaVersion"] = currentVersion
        return try JSONSerialization.data(withJSONObject: object)
    }
}
