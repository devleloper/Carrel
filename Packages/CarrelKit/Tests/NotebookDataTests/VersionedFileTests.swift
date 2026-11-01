import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct VersionedFileTests {
    @Test func fallsBackToThePreviousGenerationWhenTheCurrentOneIsDamaged() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appending(path: "library.json")
        let previous = directory.appending(path: "library.json.previous")
        try JSONCoding.encode(LibraryManifest()).write(to: previous)
        try Data("{ damaged".utf8).write(to: current)

        let manifest = try VersionedFile.read(
            LibraryManifest.self,
            from: [current, previous],
            supportedSchemaVersion: LibraryManifest.currentSchemaVersion
        )

        #expect(manifest == LibraryManifest())
    }

    @Test func aFileFromANewerAppIsNeverSkipped() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appending(path: "library.json")
        let previous = directory.appending(path: "library.json.previous")
        try Data(#"{ "schemaVersion": 99 }"#.utf8).write(to: current)
        try JSONCoding.encode(LibraryManifest()).write(to: previous)

        #expect(throws: VersionedFileError.newerSchema) {
            try VersionedFile.read(
                LibraryManifest.self,
                from: [current, previous],
                supportedSchemaVersion: LibraryManifest.currentSchemaVersion
            )
        }
    }
}
