import CryptoKit
import Foundation
import NotebookDomain

/// The on-disk wrapper around a page's ink.
///
/// Layout, little-endian: magic (4) · format version (UInt16) · required content version (UInt16) ·
/// payload length (UInt64) · SHA-256 of the payload (32) · payload. The length catches truncation and the
/// checksum catches silent corruption, so a damaged file is never handed to PencilKit.
public enum InkEnvelope {
    static let magic = Data("CRLI".utf8)
    static let formatVersion: UInt16 = 1
    static let headerLength = 4 + 2 + 2 + 8 + 32

    public static func encode(_ ink: InkData) -> Data {
        var data = Data(capacity: headerLength + ink.payload.count)
        data.append(magic)
        data.appendLittleEndian(formatVersion)
        data.appendLittleEndian(UInt16(clamping: ink.requiredContentVersion))
        data.appendLittleEndian(UInt64(ink.payload.count))
        data.append(contentsOf: SHA256.hash(data: ink.payload))
        data.append(ink.payload)
        return data
    }

    public static func decode(_ data: Data) throws -> InkData {
        guard !data.isEmpty else {
            throw InkEnvelopeError.empty
        }
        guard data.count >= headerLength, data.prefix(magic.count) == magic else {
            throw InkEnvelopeError.foreignFormat
        }
        let bytes = Data(data)
        let version: UInt16 = bytes.readLittleEndian(at: 4)
        guard version == formatVersion else {
            throw InkEnvelopeError.unsupportedFormatVersion(version)
        }
        let requiredContentVersion: UInt16 = bytes.readLittleEndian(at: 6)
        let payloadLength: UInt64 = bytes.readLittleEndian(at: 8)
        guard UInt64(bytes.count - headerLength) == payloadLength else {
            throw InkEnvelopeError.truncated
        }
        let checksum = bytes.subdata(in: 16..<headerLength)
        let payload = bytes.subdata(in: headerLength..<bytes.count)
        guard Data(SHA256.hash(data: payload)) == checksum else {
            throw InkEnvelopeError.checksumMismatch
        }
        return InkData(payload: payload, requiredContentVersion: Int(requiredContentVersion))
    }

    public static func hash(of payload: Data) -> InkHash {
        InkHash(rawValue: SHA256.hexDigest(of: payload))
    }
}

public enum InkEnvelopeError: Error, Equatable {
    case empty
    case foreignFormat
    case unsupportedFormatVersion(UInt16)
    case truncated
    case checksumMismatch
}

extension Data {
    fileprivate mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    /// Expects a zero-based buffer; callers copy slices with `Data(_:)` first.
    fileprivate func readLittleEndian<Value: FixedWidthInteger>(at offset: Int) -> Value {
        let raw = withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Value.self) }
        return Value(littleEndian: raw)
    }
}
