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
            migration: LibraryManifest.migration
        ).value

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
                migration: LibraryManifest.migration
            )
        }
    }

    @Test func anOlderSchemaIsMigratedBeforeDecoding() throws {
        let migration = SchemaMigration(steps: [{ $0["tags"] = [] }])
        let versionOne = Data(#"{ "folders": [], "schemaVersion": 1 }"#.utf8)

        let manifest = try VersionedFile.decode(LibraryManifest.self, from: versionOne, migration: migration)

        #expect(manifest.schemaVersion == 2)
        #expect(manifest.tags.isEmpty)
    }

    @Test func aFileWithoutASchemaVersionIsUnreadable() {
        #expect(throws: VersionedFileError.unreadable) {
            try VersionedFile.decode(
                LibraryManifest.self,
                from: Data(#"{ "folders": [], "tags": [] }"#.utf8),
                migration: LibraryManifest.migration
            )
        }
    }

    @Test func aDamagedGenerationIsMovedAsideWhenAnOlderOneIsUsed() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let current = directory.appending(path: "library.json")
        let previous = directory.appending(path: "library.json.previous")
        let recovered = directory.appending(path: "Recovered", directoryHint: .isDirectory)
        try JSONCoding.encode(LibraryManifest()).write(to: previous)
        try Data("{ damaged".utf8).write(to: current)

        _ = try VersionedFile.read(
            LibraryManifest.self,
            from: [current, previous],
            migration: LibraryManifest.migration,
            movingDamagedTo: recovered
        )

        #expect(!FileManager.default.fileExists(atPath: current.path(percentEncoded: false)))
        #expect(FileManager.default.directoryContents(at: recovered).count == 1)
    }
}
