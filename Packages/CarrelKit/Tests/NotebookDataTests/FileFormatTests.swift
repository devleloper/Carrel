import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

/// Files written by version 1 of the format. These bytes must keep decoding the same way: changing a coding key,
/// an enum case, the date format or the ink envelope would make existing notebooks unreadable.
struct FileFormatTests {
    @Test func notebookManifestVersionOneDecodes() throws {
        let manifest = try JSONCoding.decode(NotebookManifest.self, from: Data(Self.notebookV1.utf8))

        #expect(manifest.schemaVersion == 1)
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
