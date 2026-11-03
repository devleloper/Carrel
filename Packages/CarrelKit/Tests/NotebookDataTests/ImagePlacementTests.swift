import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct ImagePlacementTests {
    private static let later = Date(timeIntervalSince1970: 1_900_000_000)
    private static let frame = PageRect(x: 72, y: 96, width: 240, height: 180)

    private func page(of fixture: NotebookFixture, in store: NotebookStore? = nil) async throws -> Page {
        let manifest = await (store ?? fixture.store).manifest
        return try #require(manifest.pages.first { $0.id == fixture.pageID })
    }

    @Test func placingAnImageIsAnEditThatSurvivesReopening() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        let placement = try await fixture.store.placeTestImage(on: fixture.pageID, now: Self.later)

        #expect(try await page(of: fixture).modifiedAt == Self.later)
        #expect(await fixture.store.manifest.notebook.modifiedAt == Self.later)
        #expect(try await page(of: fixture, in: fixture.reopen()).imagePlacements == [placement])
    }

    @Test func laterImagesAreStackedOnTop() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        let first = try await fixture.store.placeTestImage(on: fixture.pageID)
        let second = try await fixture.store.placeTestImage(on: fixture.pageID)

        #expect(try await page(of: fixture).imagePlacements.map(\.id) == [first.id, second.id])
    }

    @Test func aPlacementNeedsItsAssetOnDisk() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let assetID = try #require(AssetID(rawValue: String(repeating: "ab", count: 32)))
        let before = await fixture.store.manifest

        await #expect(throws: NotebookStoreError.assetMissing) {
            try await fixture.store.addImagePlacement(
                ImagePlacement(assetID: assetID, frame: Self.frame),
                toPage: fixture.pageID
            )
        }
        #expect(await fixture.store.manifest == before)
    }

    @Test func movingAndRotatingAnImageIsAnEdit() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)
        let moved = PageRect(x: 10, y: 20, width: 480, height: 360)

        try await fixture.store.updateImagePlacement(
            placement.id,
            onPage: fixture.pageID,
            frame: moved,
            rotation: .pi / 4,
            now: Self.later
        )

        let reopened = try await page(of: fixture, in: fixture.reopen())
        #expect(reopened.imagePlacements.first?.frame == moved)
        #expect(reopened.imagePlacements.first?.rotation == .pi / 4)
        #expect(reopened.modifiedAt == Self.later)
        #expect(await fixture.store.manifest.notebook.modifiedAt == Self.later)
    }

    @Test func removingAnImageIsAnEditThatKeepsItsAsset() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)

        try await fixture.store.removeImagePlacement(placement.id, fromPage: fixture.pageID, now: Self.later)

        #expect(try await page(of: fixture, in: fixture.reopen()).imagePlacements.isEmpty)
        #expect(await fixture.store.manifest.notebook.modifiedAt == Self.later)
        #expect(fixture.store.imageURL(for: placement.assetID) != nil)
    }

    @Test func changingAnImageThatIsNotThereWritesNothing() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let before = await fixture.store.manifest

        try await fixture.store.updateImagePlacement(
            UUID(),
            onPage: fixture.pageID,
            frame: Self.frame,
            rotation: 0,
            now: Self.later
        )
        try await fixture.store.removeImagePlacement(UUID(), fromPage: fixture.pageID, now: Self.later)

        #expect(await fixture.store.manifest == before)
        let previous = fixture.store.package.previousManifestURL
        #expect(!FileManager.default.fileExists(atPath: previous.path(percentEncoded: false)))
    }

    @Test func duplicatingAPageCopiesItsImagesAndSharesTheirAssets() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)

        let copy = try #require(try await fixture.store.duplicatePage(fixture.pageID))

        let copied = try #require(copy.imagePlacements.first)
        #expect(copy.imagePlacements.count == 1)
        #expect(copied.id != placement.id)
        #expect(copied.assetID == placement.assetID)
        #expect(copied.frame == placement.frame)
        #expect(FileManager.default.directoryContents(at: fixture.store.package.assetsDirectory).count == 1)
    }
}
