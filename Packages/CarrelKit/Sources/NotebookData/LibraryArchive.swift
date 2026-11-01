import AppleArchive
import Foundation
import System

/// Reads and writes library backups as LZFSE-compressed Apple Archive files.
///
/// Apple Archive is a system framework that works in both directions, which keeps backups restorable without
/// a third-party ZIP library.
enum LibraryArchive {
    private static let fieldKeys = "TYP,PAT,LNK,DEV,DAT,MOD,FLG,MTM,BTM,CTM"

    static func write(directory: URL, to destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        guard
            let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(destination.path(percentEncoded: false)),
                mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)
            )
        else {
            throw LibraryArchiveError.cannotOpenStream
        }
        defer { try? fileStream.close() }

        guard let compressionStream = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: fileStream) else {
            throw LibraryArchiveError.cannotOpenStream
        }
        defer { try? compressionStream.close() }

        guard
            let encodeStream = ArchiveStream.encodeStream(writingTo: compressionStream),
            let keySet = ArchiveHeader.FieldKeySet(fieldKeys)
        else {
            throw LibraryArchiveError.cannotOpenStream
        }
        defer { try? encodeStream.close() }

        try encodeStream.writeDirectoryContents(
            archiveFrom: FilePath(directory.path(percentEncoded: false)),
            keySet: keySet
        )
    }

    static func extract(_ archive: URL, into directory: URL) throws {
        guard
            let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(archive.path(percentEncoded: false)),
                mode: .readOnly,
                options: [],
                permissions: FilePermissions(rawValue: 0o644)
            )
        else {
            throw LibraryArchiveError.cannotOpenStream
        }
        defer { try? fileStream.close() }

        guard
            let decompressionStream = ArchiveByteStream.decompressionStream(readingFrom: fileStream),
            let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressionStream),
            let extractStream = ArchiveStream.extractStream(
                extractingTo: FilePath(directory.path(percentEncoded: false)),
                flags: [.ignoreOperationNotPermitted]
            )
        else {
            throw LibraryArchiveError.cannotOpenStream
        }
        defer {
            try? extractStream.close()
            try? decodeStream.close()
            try? decompressionStream.close()
        }

        _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
    }
}

enum LibraryArchiveError: Error {
    case cannotOpenStream
}
