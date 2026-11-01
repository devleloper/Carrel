import Foundation

/// Serialized ink of one page, opaque to the domain. The app layer converts it to and from `PKDrawing`.
public struct InkData: Hashable, Sendable {
    public var payload: Data
    /// The `PKContentVersion` raw value a system needs to read `payload`.
    public var requiredContentVersion: Int

    public init(payload: Data, requiredContentVersion: Int) {
        self.payload = payload
        self.requiredContentVersion = requiredContentVersion
    }
}

/// SHA-256 of an ink payload, in lowercase hex.
public struct InkHash: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
