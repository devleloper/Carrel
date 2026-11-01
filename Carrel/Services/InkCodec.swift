import NotebookDomain
import PencilKit

/// Converts between PencilKit drawings and the storage format.
enum InkCodec {
    /// New strokes stay readable on every system the app supports; raise this only with the minimum iPadOS.
    static let maximumContentVersion = PKContentVersion.version5

    /// The newest ink this system can read; pages that need more open read-only.
    static var supportedContentVersion: Int {
        PKContentVersion.latest.rawValue
    }

    static func inkData(from drawing: PKDrawing) -> InkData {
        InkData(payload: drawing.dataRepresentation(), requiredContentVersion: drawing.requiredContentVersion.rawValue)
    }

    static func drawing(from ink: InkData) throws -> PKDrawing {
        try PKDrawing(data: ink.payload)
    }
}
