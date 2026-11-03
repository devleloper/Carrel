import CryptoKit
import Foundation

extension SHA256 {
    /// The digest in lowercase hex, the form ink hashes and asset IDs are stored in.
    static func hexDigest(of data: Data) -> String {
        hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
