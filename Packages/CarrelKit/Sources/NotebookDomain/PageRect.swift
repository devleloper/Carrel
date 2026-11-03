/// A rectangle in page points, measured from the top-left corner of the page with y growing downwards, the way
/// the page and its ink are drawn.
///
/// The domain has its own type instead of `CGRect` so that it stays free of graphics frameworks and the file
/// format names its fields instead of using `CGRect`'s nested arrays.
public struct PageRect: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
    }
}
