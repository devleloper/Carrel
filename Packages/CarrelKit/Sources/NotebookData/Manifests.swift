import Foundation
import NotebookDomain

/// Contents of `notebook.json`: the notebook and the metadata of its pages. Ink lives in separate files.
public struct NotebookManifest: Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var notebook: Notebook
    public var pages: [Page]

    public init(notebook: Notebook, pages: [Page]) {
        self.schemaVersion = Self.currentSchemaVersion
        self.notebook = notebook
        self.pages = pages
    }

    /// Pages outside the Trash, in reading order.
    public var activePages: [Page] {
        pages.filter { !$0.isInTrash }.sorted { $0.sortKey < $1.sortKey }
    }

    public var trashedPages: [Page] {
        pages.filter(\.isInTrash).sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    public func pageIndex(of id: Page.ID) -> Int? {
        pages.firstIndex { $0.id == id }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case notebook
        case pages
    }
}

/// Contents of `library.json`: folders and tags. Notebooks describe themselves in their own packages.
public struct LibraryManifest: Hashable, Codable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var folders: [Folder]
    public var tags: [Tag]

    public init(folders: [Folder] = [], tags: [Tag] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.folders = folders
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case folders
        case tags
    }
}

/// Reads only the schema version, so a file from a newer app is recognised before full decoding fails.
struct SchemaProbe: Decodable {
    let schemaVersion: Int
}

enum JSONCoding {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        // Stable, readable output keeps diffs of exported packages and test fixtures meaningful.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
