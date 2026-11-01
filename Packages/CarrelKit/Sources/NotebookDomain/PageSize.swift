/// Page dimensions in PostScript points, independent of the device that shows the page.
public struct PageSize: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let a4 = PageSize(width: 595.28, height: 841.89)
    public static let letter = PageSize(width: 612, height: 792)

    public var landscape: PageSize {
        PageSize(width: max(width, height), height: min(width, height))
    }

    enum CodingKeys: String, CodingKey {
        case width
        case height
    }
}
