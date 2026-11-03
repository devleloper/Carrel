import Foundation

public struct Page: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var sortKey: SortKey
    public var size: PageSize
    public var paper: Paper
    public var background: PageBackground
    public var tagIDs: Set<Tag.ID>
    /// Recorded before the first ink write, so a page whose ink file goes missing is recovered instead of
    /// silently opening empty.
    public var hasInk: Bool
    public var inkHash: InkHash?
    /// Drawn in this order, so a later placement covers an earlier one.
    public var imagePlacements: [ImagePlacement]
    public let createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?

    public init(id: UUID = UUID(), sortKey: SortKey, size: PageSize, paper: Paper, now: Date) {
        self.id = id
        self.sortKey = sortKey
        self.size = size
        self.paper = paper
        self.background = .paper
        self.tagIDs = []
        self.hasInk = false
        self.inkHash = nil
        self.imagePlacements = []
        self.createdAt = now
        self.modifiedAt = now
        self.deletedAt = nil
    }

    public var isInTrash: Bool {
        deletedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sortKey
        case size
        case paper
        case background
        case tagIDs
        case hasInk
        case inkHash
        case imagePlacements
        case createdAt
        case modifiedAt
        case deletedAt
    }
}

/// What lies under the ink. PDF pages arrive in 1.0; the case exists from schema v1 to avoid a migration.
public enum PageBackground: Hashable, Codable, Sendable {
    case paper
    case pdf(assetID: String, pageIndex: Int)
}
