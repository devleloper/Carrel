import Foundation

/// An image shown on a page, under the ink. Several placements, on any pages of the notebook, can show the same
/// asset.
public struct ImagePlacement: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let assetID: AssetID
    /// The frame before rotation, in page points.
    public var frame: PageRect
    /// Radians around the center of `frame`. Positive values turn the image clockwise on the page.
    public var rotation: Double

    public init(id: UUID = UUID(), assetID: AssetID, frame: PageRect, rotation: Double = 0) {
        self.id = id
        self.assetID = assetID
        self.frame = frame
        self.rotation = rotation
    }

    enum CodingKeys: String, CodingKey {
        case id
        case assetID
        case frame
        case rotation
    }
}

/// SHA-256 of an asset file, in lowercase hex. Assets never change after they are written, so the ID names the
/// content and two imports of the same image share one file.
public struct AssetID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    /// Accepts only a SHA-256 in lowercase hex. The ID becomes a file name, so one read from a damaged or foreign
    /// manifest must never be able to point outside the assets folder; decoding such a manifest fails instead.
    public init?(rawValue: String) {
        let hexDigits = "0123456789abcdef".utf8
        guard rawValue.utf8.count == 64, rawValue.utf8.allSatisfy(hexDigits.contains) else {
            return nil
        }
        self.rawValue = rawValue
    }
}
