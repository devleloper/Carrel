import Foundation
import NotebookDomain

/// Contents of `notebook.json`: the notebook and the metadata of its pages. Ink lives in separate files.
public struct NotebookManifest: Hashable, Codable, Sendable {
    static let migration = SchemaMigration(steps: [addImagePlacements])
    public static let currentSchemaVersion = migration.currentVersion

    public private(set) var schemaVersion: Int
    public internal(set) var notebook: Notebook
    public internal(set) var pages: [Page]

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

    func pageIndex(of id: Page.ID) -> Int? {
        pages.firstIndex { $0.id == id }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case notebook
        case pages
    }
}

// MARK: - Migrations

extension NotebookManifest {
    /// Version 2 gives every page a list of image placements.
    private static func addImagePlacements(to manifest: inout [String: Any]) throws {
        guard let pages = manifest["pages"] as? [[String: Any]] else {
            throw SchemaMigrationError.malformed
        }
        manifest["pages"] = pages.map { page in
            page.merging(["imagePlacements": [Any]()]) { current, _ in current }
        }
    }
}

// MARK: - Page operations

extension NotebookManifest {
    /// Adds a page after every existing one, with the paper and size of the last page.
    @discardableResult
    mutating func appendPage(id: Page.ID = UUID(), now: Date) -> Page {
        let last = activePages.last
        let page = Page(
            id: id,
            sortKey: .between(pages.map(\.sortKey).max(), nil),
            size: last?.size ?? notebook.defaultPageSize,
            paper: last?.paper ?? notebook.defaultPaper,
            now: now
        )
        pages.append(page)
        return page
    }

    /// Inserts a copy of a page right after it. The caller copies the ink file.
    mutating func insertCopy(of pageID: Page.ID, hasInk: Bool, now: Date) -> Page? {
        guard let source = pages.first(where: { $0.id == pageID }) else {
            return nil
        }
        var copy = Page(
            sortKey: .between(source.sortKey, key(after: source.sortKey, excluding: source.id)),
            size: source.size,
            paper: source.paper,
            now: now
        )
        copy.tagIDs = source.tagIDs
        copy.hasInk = hasInk
        copy.inkHash = hasInk ? source.inkHash : nil
        pages.append(copy)
        return copy
    }

    /// Moves a page `offset` places in reading order, ignoring pages in the Trash.
    mutating func movePage(_ pageID: Page.ID, by offset: Int, now: Date) {
        let active = activePages
        guard let index = active.firstIndex(where: { $0.id == pageID }), active.indices.contains(index + offset) else {
            return
        }
        let target = index + offset
        let lowerIndex = offset < 0 ? target - 1 : target
        let lower = active.indices.contains(lowerIndex) ? active[lowerIndex].sortKey : nil
        let upper = key(after: lower, excluding: pageID)
        updatePage(pageID, now: now) { $0.sortKey = .between(lower, upper) }
    }

    mutating func updatePage(_ pageID: Page.ID, now: Date, _ change: (inout Page) -> Void) {
        guard let index = pageIndex(of: pageID) else {
            return
        }
        change(&pages[index])
        pages[index].modifiedAt = now
    }

    /// The nearest key above `key` among all pages, including those in the Trash, so a new key can never
    /// collide with the key of a page that is later restored.
    private func key(after lowerKey: SortKey?, excluding pageID: Page.ID) -> SortKey? {
        pages
            .filter { page in page.id != pageID && lowerKey.map { page.sortKey > $0 } ?? true }
            .map(\.sortKey)
            .min()
    }
}

/// Contents of `library.json`: folders and tags. Notebooks describe themselves in their own packages.
public struct LibraryManifest: Hashable, Codable, Sendable {
    static let migration = SchemaMigration()
    public static let currentSchemaVersion = migration.currentVersion

    public private(set) var schemaVersion: Int
    public internal(set) var folders: [Folder]
    public internal(set) var tags: [Tag]

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

/// Reads only the schema version, which decides whether a file needs migrating or comes from a newer app.
struct SchemaProbe: Decodable {
    let schemaVersion: Int
}

enum JSONCoding {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        // Stable, readable output keeps diffs of exported packages meaningful.
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
