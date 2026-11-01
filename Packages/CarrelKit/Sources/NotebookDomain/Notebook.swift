import Foundation

public struct Notebook: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var folderID: Folder.ID?
    public var tagIDs: Set<Tag.ID>
    public var isFavorite: Bool
    public var sortKey: SortKey
    public var cover: Cover
    public var defaultPaper: Paper
    public var defaultPageSize: PageSize
    public let createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        folderID: Folder.ID? = nil,
        cover: Cover,
        defaultPaper: Paper,
        defaultPageSize: PageSize,
        sortKey: SortKey,
        now: Date
    ) {
        self.id = id
        self.title = title
        self.folderID = folderID
        self.tagIDs = []
        self.isFavorite = false
        self.sortKey = sortKey
        self.cover = cover
        self.defaultPaper = defaultPaper
        self.defaultPageSize = defaultPageSize
        self.createdAt = now
        self.modifiedAt = now
        self.deletedAt = nil
    }

    public var isInTrash: Bool {
        deletedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case folderID
        case tagIDs
        case isFavorite
        case sortKey
        case cover
        case defaultPaper
        case defaultPageSize
        case createdAt
        case modifiedAt
        case deletedAt
    }
}

public struct Folder: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var parentID: Folder.ID?
    public var title: String
    public var color: String?
    public var sortKey: SortKey
    public let createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), title: String, parentID: Folder.ID? = nil, sortKey: SortKey, now: Date) {
        self.id = id
        self.parentID = parentID
        self.title = title
        self.color = nil
        self.sortKey = sortKey
        self.createdAt = now
        self.modifiedAt = now
        self.deletedAt = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case parentID
        case title
        case color
        case sortKey
        case createdAt
        case modifiedAt
        case deletedAt
    }
}

/// Tags are part of schema v1 so that the tagging UI of 1.0 needs no migration.
public struct Tag: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var color: String?
    public let createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), name: String, now: Date) {
        self.id = id
        self.name = name
        self.color = nil
        self.createdAt = now
        self.modifiedAt = now
        self.deletedAt = nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case createdAt
        case modifiedAt
        case deletedAt
    }
}
