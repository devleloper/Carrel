import Foundation

/// A file handed to the share sheet; identifiable so it can drive `sheet(item:)`.
struct SharedFile: Identifiable {
    let url: URL

    var id: URL { url }
}
