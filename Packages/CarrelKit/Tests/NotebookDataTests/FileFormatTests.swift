import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

/// Files written by every version of the format. These bytes must keep decoding the same way: changing a coding
/// key, an enum case, the date format or the ink envelope would make existing notebooks unreadable.
struct FileFormatTests {
    @Test func notebookManifestVersionOneDecodes() throws {
        let manifest = try Self.decodeNotebookManifest(Self.notebookV1)

        #expect(manifest.schemaVersion == NotebookManifest.currentSchemaVersion)
        #expect(manifest.notebook.id == UUID(uuidString: "6F1C2B3A-1111-4C2B-9C3D-000000000001"))
        #expect(manifest.notebook.title == "Linear Algebra")
        #expect(manifest.notebook.cover == Cover(preset: .forestCloth))
        #expect(manifest.notebook.defaultPaper == Paper(style: .ruledWithMargin, tone: .cream))
        #expect(manifest.notebook.defaultPageSize == .a4)
        #expect(manifest.notebook.createdAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(manifest.notebook.isFavorite)

        let page = try #require(manifest.pages.first)
        #expect(page.sortKey == SortKey(rawValue: "i"))
        #expect(page.background == .paper)
        #expect(page.hasInk)
        #expect(page.inkHash == InkHash(rawValue: "abc123"))
        #expect(manifest.pages.last?.background == .pdf(assetID: "deadbeef", pageIndex: 2))
        #expect(manifest.pages.allSatisfy { $0.imagePlacements.isEmpty })
    }

    @Test func notebookManifestVersionTwoDecodes() throws {
        let manifest = try Self.decodeNotebookManifest(Self.notebookV2)

        #expect(manifest.schemaVersion == 2)
        #expect(manifest.notebook.folderID == UUID(uuidString: "6F1C2B3A-4444-4C2B-9C3D-000000000004"))
        let page = try #require(manifest.pages.first)
        let rotatedID = try #require(UUID(uuidString: "6F1C2B3A-6666-4C2B-9C3D-000000000006"))
        let bannerID = try #require(UUID(uuidString: "6F1C2B3A-7777-4C2B-9C3D-000000000007"))
        let assetID = try #require(AssetID(rawValue: Self.assetHash))
        #expect(page.tagIDs == [UUID(uuidString: "6F1C2B3A-5555-4C2B-9C3D-000000000005")])
        #expect(
            page.imagePlacements == [
                ImagePlacement(
                    id: rotatedID,
                    assetID: assetID,
                    frame: PageRect(x: 72, y: 120.5, width: 300, height: 200.25),
                    rotation: 0.5
                ),
                ImagePlacement(
                    id: bannerID,
                    assetID: assetID,
                    frame: PageRect(x: 0, y: 0, width: 595.28, height: 400),
                    rotation: 0
                ),
            ]
        )
        #expect(manifest.pages.last?.imagePlacements.isEmpty == true)
    }

    @Test func notebookManifestVersionTwoEncodesToTheSameFields() throws {
        let manifest = try Self.decodeNotebookManifest(Self.notebookV2)

        let encoded = try JSONSerialization.jsonObject(with: JSONCoding.encode(manifest)) as? NSDictionary
        let golden = try JSONSerialization.jsonObject(with: Data(Self.notebookV2.utf8)) as? NSDictionary
        #expect(encoded == golden)
    }

    @Test func aManifestWithAMalformedAssetIDIsUnreadable() {
        let malformed = Self.notebookV2.replacing(Self.assetHash, with: "../../library")

        #expect(throws: VersionedFileError.unreadable) {
            try Self.decodeNotebookManifest(malformed)
        }
    }

    @Test func aVersionOnePackageIsRewrittenOnlyByARealChange() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let package = try Self.makePackage(in: directory, manifest: Self.notebookV1)

        let store = try NotebookStore.open(
            at: package.url,
            supportedContentVersion: NotebookFixture.supportedContentVersion,
            recoveredDirectory: directory.appending(path: "Recovered", directoryHint: .isDirectory)
        )
        #expect(await store.manifest.schemaVersion == NotebookManifest.currentSchemaVersion)
        #expect(try Data(contentsOf: package.manifestURL) == Data(Self.notebookV1.utf8))

        try await store.rename(to: "Linear Algebra II")

        let written = try JSONCoding.decode(SchemaProbe.self, from: Data(contentsOf: package.manifestURL))
        #expect(written.schemaVersion == NotebookManifest.currentSchemaVersion)
        #expect(try Data(contentsOf: package.previousManifestURL) == Data(Self.notebookV1.utf8))
    }

    /// The proposal's migration rule: by the first write of a migrated manifest, a snapshot holds the old version.
    /// Two library-side writes leave no old version in the package itself.
    @Test func aVersionOneNotebookIsSnapshottedBeforeTheLibraryRewritesIt() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = LibraryLayout(root: root)
        let library = try LibraryStore(layout: layout, supportedContentVersion: NotebookFixture.supportedContentVersion)
        let notebookID = try Self.makeLibraryPackage(in: layout, manifest: Self.notebookV1)

        try await library.organizeNotebook(notebookID) { $0.isFavorite = false }
        try await library.organizeNotebook(notebookID) { $0.isFavorite = true }

        let package = NotebookPackage(url: layout.packageURL(for: notebookID))
        #expect(try Data(contentsOf: package.previousManifestURL) != Data(Self.notebookV1.utf8))
        let snapshots = FileManager.default.directoryContents(at: layout.snapshotsDirectory(for: notebookID))
        let snapshot = try #require(snapshots.first)
        #expect(snapshots.count == 1)
        #expect(try Data(contentsOf: NotebookPackage(url: snapshot).manifestURL) == Data(Self.notebookV1.utf8))
    }

    @Test func aCurrentNotebookIsNotSnapshottedWhenTheLibraryOpensIt() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let layout = LibraryLayout(root: root)
        let library = try LibraryStore(layout: layout, supportedContentVersion: NotebookFixture.supportedContentVersion)
        let notebookID = try Self.makeLibraryPackage(in: layout, manifest: Self.notebookV2)

        try await library.organizeNotebook(notebookID) { $0.isFavorite = false }

        #expect(FileManager.default.directoryContents(at: layout.snapshotsDirectory(for: notebookID)).isEmpty)
    }

    @Test func aManifestFromANewerAppIsRefusedAndNeverRewritten() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let newer = Self.notebookV2.replacing(
            #""schemaVersion" : 2"#,
            with: "\"schemaVersion\" : \(NotebookManifest.currentSchemaVersion + 1)"
        )
        let package = try Self.makePackage(in: directory, manifest: newer)

        #expect(throws: NotebookStoreError.schemaNewerThanApp) {
            try NotebookStore.open(
                at: package.url,
                supportedContentVersion: NotebookFixture.supportedContentVersion,
                recoveredDirectory: directory.appending(path: "Recovered", directoryHint: .isDirectory)
            )
        }
        #expect(try Data(contentsOf: package.manifestURL) == Data(newer.utf8))
    }

    @Test func libraryManifestVersionOneDecodes() throws {
        let manifest = try JSONCoding.decode(LibraryManifest.self, from: Data(Self.libraryV1.utf8))

        #expect(manifest.folders.map(\.title) == ["Fall 2026"])
        #expect(manifest.tags.map(\.name) == ["exam"])
    }

    @Test func inkEnvelopeVersionOneHasAFixedLayout() throws {
        let ink = InkData(payload: Data([0x01, 0x02, 0x03, 0x04, 0xFE]), requiredContentVersion: 4)

        #expect(InkEnvelope.encode(ink) == Self.inkEnvelopeV1)
        #expect(try InkEnvelope.decode(Self.inkEnvelopeV1) == ink)
    }

    private static func decodeNotebookManifest(_ json: String) throws -> NotebookManifest {
        try VersionedFile.decode(NotebookManifest.self, from: Data(json.utf8), migration: NotebookManifest.migration)
    }

    /// Puts a package with the given manifest into a library and returns the ID of its notebook.
    private static func makeLibraryPackage(in layout: LibraryLayout, manifest json: String) throws -> Notebook.ID {
        let notebookID = try decodeNotebookManifest(json).notebook.id
        let package = NotebookPackage(url: layout.packageURL(for: notebookID))
        try FileManager.default.createDirectory(at: package.url, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: package.manifestURL)
        return notebookID
    }

    private static func makePackage(in directory: URL, manifest json: String) throws -> NotebookPackage {
        let package = NotebookPackage(url: directory.appending(path: "Physics.notebook", directoryHint: .isDirectory))
        try FileManager.default.createDirectory(at: package.url, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: package.manifestURL)
        return package
    }

    // "CRLI", format 1, content version 4, payload length 5, SHA-256 of the payload, payload.
    private static let inkEnvelopeV1 = Data(
        hexString: """
            43524c49010004000500000000000000\
            9a120942434d93d122466fa93acc524090c516062572759ee9fa8b5f8b9701fc\
            01020304fe
            """
    )

    private static let notebookV1 = """
        {
          "notebook" : {
            "cover" : { "preset" : "forestCloth" },
            "createdAt" : "2027-01-15T08:00:00Z",
            "defaultPageSize" : { "height" : 841.89, "width" : 595.28 },
            "defaultPaper" : { "style" : "ruledWithMargin", "tone" : "cream" },
            "id" : "6F1C2B3A-1111-4C2B-9C3D-000000000001",
            "isFavorite" : true,
            "modifiedAt" : "2027-01-15T09:00:00Z",
            "sortKey" : "i",
            "tagIDs" : [],
            "title" : "Linear Algebra"
          },
          "pages" : [
            {
              "background" : { "paper" : {} },
              "createdAt" : "2027-01-15T08:00:00Z",
              "hasInk" : true,
              "id" : "6F1C2B3A-2222-4C2B-9C3D-000000000002",
              "inkHash" : "abc123",
              "modifiedAt" : "2027-01-15T09:00:00Z",
              "paper" : { "style" : "ruledWithMargin", "tone" : "cream" },
              "size" : { "height" : 841.89, "width" : 595.28 },
              "sortKey" : "i",
              "tagIDs" : []
            },
            {
              "background" : { "pdf" : { "assetID" : "deadbeef", "pageIndex" : 2 } },
              "createdAt" : "2027-01-15T08:00:00Z",
              "deletedAt" : "2027-01-16T08:00:00Z",
              "hasInk" : false,
              "id" : "6F1C2B3A-3333-4C2B-9C3D-000000000003",
              "modifiedAt" : "2027-01-15T08:00:00Z",
              "paper" : { "style" : "grid", "tone" : "white" },
              "size" : { "height" : 612, "width" : 792 },
              "sortKey" : "r",
              "tagIDs" : []
            }
          ],
          "schemaVersion" : 1
        }
        """

    private static let assetHash = "9a120942434d93d122466fa93acc524090c516062572759ee9fa8b5f8b9701fc"

    private static let notebookV2 = """
        {
          "notebook" : {
            "cover" : { "preset" : "forestCloth" },
            "createdAt" : "2027-01-15T08:00:00Z",
            "defaultPageSize" : { "height" : 841.89, "width" : 595.28 },
            "defaultPaper" : { "style" : "ruledWithMargin", "tone" : "cream" },
            "folderID" : "6F1C2B3A-4444-4C2B-9C3D-000000000004",
            "id" : "6F1C2B3A-1111-4C2B-9C3D-000000000001",
            "isFavorite" : true,
            "modifiedAt" : "2027-01-15T09:00:00Z",
            "sortKey" : "i",
            "tagIDs" : [],
            "title" : "Linear Algebra"
          },
          "pages" : [
            {
              "background" : { "paper" : {} },
              "createdAt" : "2027-01-15T08:00:00Z",
              "hasInk" : true,
              "id" : "6F1C2B3A-2222-4C2B-9C3D-000000000002",
              "imagePlacements" : [
                {
                  "assetID" : "\(assetHash)",
                  "frame" : { "height" : 200.25, "width" : 300, "x" : 72, "y" : 120.5 },
                  "id" : "6F1C2B3A-6666-4C2B-9C3D-000000000006",
                  "rotation" : 0.5
                },
                {
                  "assetID" : "\(assetHash)",
                  "frame" : { "height" : 400, "width" : 595.28, "x" : 0, "y" : 0 },
                  "id" : "6F1C2B3A-7777-4C2B-9C3D-000000000007",
                  "rotation" : 0
                }
              ],
              "inkHash" : "abc123",
              "modifiedAt" : "2027-01-15T09:00:00Z",
              "paper" : { "style" : "ruledWithMargin", "tone" : "cream" },
              "size" : { "height" : 841.89, "width" : 595.28 },
              "sortKey" : "i",
              "tagIDs" : ["6F1C2B3A-5555-4C2B-9C3D-000000000005"]
            },
            {
              "background" : { "pdf" : { "assetID" : "deadbeef", "pageIndex" : 2 } },
              "createdAt" : "2027-01-15T08:00:00Z",
              "deletedAt" : "2027-01-16T08:00:00Z",
              "hasInk" : false,
              "id" : "6F1C2B3A-3333-4C2B-9C3D-000000000003",
              "imagePlacements" : [],
              "modifiedAt" : "2027-01-15T08:00:00Z",
              "paper" : { "style" : "grid", "tone" : "white" },
              "size" : { "height" : 612, "width" : 792 },
              "sortKey" : "r",
              "tagIDs" : []
            }
          ],
          "schemaVersion" : 2
        }
        """

    private static let libraryV1 = """
        {
          "folders" : [
            {
              "createdAt" : "2027-01-15T08:00:00Z",
              "id" : "6F1C2B3A-4444-4C2B-9C3D-000000000004",
              "modifiedAt" : "2027-01-15T08:00:00Z",
              "sortKey" : "i",
              "title" : "Fall 2026"
            }
          ],
          "schemaVersion" : 1,
          "tags" : [
            {
              "createdAt" : "2027-01-15T08:00:00Z",
              "id" : "6F1C2B3A-5555-4C2B-9C3D-000000000005",
              "modifiedAt" : "2027-01-15T08:00:00Z",
              "name" : "exam"
            }
          ]
        }
        """
}

extension Data {
    fileprivate init(hexString: String) {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while let next = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex), index < next {
            bytes.append(UInt8(hexString[index..<next], radix: 16) ?? 0)
            index = next
        }
        self.init(bytes)
    }
}
