import CryptoKit
import Foundation
import ImageIO
import NotebookDomain
import Testing

@testable import NotebookData

struct ImageImportTests {
    @Test func aLargeImageIsDownscaledAndStoredAsHEIC() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        let image = try await fixture.store.importImage(TestImage.png(width: 6000, height: 3000))

        #expect(image.pixelWidth == ImageAssetEncoder.maximumPixelSize)
        #expect(image.pixelHeight == ImageAssetEncoder.maximumPixelSize / 2)
        let url = try #require(fixture.store.imageURL(for: image.assetID))
        let stored = try TestImage.properties(of: Data(contentsOf: url))
        #expect(stored.type == "public.heic")
        #expect(stored.width == image.pixelWidth)
        #expect(stored.height == image.pixelHeight)
    }

    @Test func aSmallImageKeepsItsSize() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        let image = try await fixture.store.importImage(TestImage.png(width: 800, height: 600))

        #expect(image.pixelWidth == 800)
        #expect(image.pixelHeight == 600)
    }

    @Test func aRotatedPhotoIsStoredUpright() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        // EXIF orientation 6: the camera stored a portrait photo as landscape pixels turned a quarter left.
        let photo = try TestImage.jpeg(width: 400, height: 200, orientation: 6)

        let image = try await fixture.store.importImage(photo)

        #expect(image.pixelWidth == 200)
        #expect(image.pixelHeight == 400)
    }

    @Test func theAssetIsNamedByTheSHA256OfItsContents() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        let image = try await fixture.store.importImage(TestImage.png(width: 300, height: 200))

        let url = try #require(fixture.store.imageURL(for: image.assetID))
        #expect(SHA256.hexDigest(of: try Data(contentsOf: url)) == image.assetID.rawValue)
        #expect(url.deletingLastPathComponent() == fixture.store.package.assetsDirectory)
    }

    @Test func importingTheSameImageTwiceStoresOneAsset() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let png = try TestImage.png(width: 640, height: 480)

        let first = try await fixture.store.importImage(png)
        let second = try await fixture.store.importImage(png)

        #expect(first == second)
        #expect(FileManager.default.directoryContents(at: fixture.store.package.assetsDirectory).count == 1)
    }

    @Test func aDamagedAssetIsMovedAsideAndReplacedOnTheNextImport() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let png = try TestImage.png(width: 640, height: 480)
        let image = try await fixture.store.importImage(png)
        let url = try #require(fixture.store.imageURL(for: image.assetID))
        try Data("damaged".utf8).write(to: url)

        _ = try await fixture.store.importImage(png)

        #expect(SHA256.hexDigest(of: try Data(contentsOf: url)) == image.assetID.rawValue)
        #expect(FileManager.default.directoryContents(at: fixture.recoveredDirectory).count == 1)
    }

    @Test func dataThatIsNotAnImageIsRefused() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        await #expect(throws: NotebookStoreError.imageUnreadable) {
            try await fixture.store.importImage(Data("not an image".utf8))
        }
        #expect(FileManager.default.directoryContents(at: fixture.store.package.assetsDirectory).isEmpty)
    }
}
