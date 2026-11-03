import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

/// Purging runs when the library opens, before any editing, so most tests purge from a freshly opened store.
struct ImageAssetPurgeTests {
    private static let deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private static let cutoff = deletedAt.addingTimeInterval(60)

    private func assetExists(_ assetID: AssetID, in fixture: NotebookFixture) -> Bool {
        fixture.store.imageURL(for: assetID) != nil
    }

    @Test func theImagesOfAPurgedPageAreDeletedUnlessAnotherPageShowsThem() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let otherPage = try await fixture.store.appendPage()
        let shared = try await fixture.store.placeTestImage(width: 300, on: fixture.pageID)
        let own = try await fixture.store.placeTestImage(width: 400, on: fixture.pageID)
        try await fixture.store.addImagePlacement(
            ImagePlacement(assetID: shared.assetID, frame: shared.frame),
            toPage: otherPage.id
        )
        try await fixture.store.setPageInTrash(fixture.pageID, true, now: Self.deletedAt)

        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        #expect(assetExists(shared.assetID, in: fixture))
        #expect(!assetExists(own.assetID, in: fixture))
    }

    @Test func anImageOnAPageInTheTrashIsKept() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)
        try await fixture.store.setPageInTrash(fixture.pageID, true, now: Self.cutoff)

        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        #expect(assetExists(placement.assetID, in: fixture))
    }

    @Test func anAssetNoPageEverUsedIsDeletedAndOtherFilesAreLeftAlone() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let orphan = try await fixture.store.importImage(TestImage.png(width: 300, height: 200))
        let unrelated = fixture.store.package.assetsDirectory.appending(path: "notes.pdf")
        try Data("pdf".utf8).write(to: unrelated)

        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        #expect(!assetExists(orphan.assetID, in: fixture))
        #expect(FileManager.default.fileExists(atPath: unrelated.path(percentEncoded: false)))
    }

    @Test func anImportWaitingToBePlacedSurvivesAPurgeInTheSameSession() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let image = try await fixture.store.importImage(TestImage.png(width: 300, height: 200))

        try await fixture.store.purgePages(deletedBefore: Self.cutoff)

        try await fixture.store.addImagePlacement(
            ImagePlacement(assetID: image.assetID, frame: PageRect(x: 0, y: 0, width: 300, height: 200)),
            toPage: fixture.pageID
        )
        #expect(assetExists(image.assetID, in: fixture))
    }

    @Test func aRemovedImageIsKeptWhileTheSessionOrThePreviousManifestCanShowIt() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)
        try await fixture.store.removeImagePlacement(placement.id, fromPage: fixture.pageID)

        try await fixture.store.purgePages(deletedBefore: Self.cutoff)
        #expect(assetExists(placement.assetID, in: fixture))

        let nextSession = try fixture.reopen()
        try await nextSession.purgePages(deletedBefore: Self.cutoff)
        #expect(assetExists(placement.assetID, in: fixture))

        try await nextSession.rename(to: "Linear Algebra II")
        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)
        #expect(!assetExists(placement.assetID, in: fixture))
    }

    @Test func fallingBackToThePreviousManifestFindsItsImages() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)
        try await fixture.store.removeImagePlacement(placement.id, fromPage: fixture.pageID)
        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        try Data("{ damaged".utf8).write(to: fixture.store.package.manifestURL)
        let recovered = try fixture.reopen()

        #expect(await recovered.manifest.imageAssetIDs == [placement.assetID])
        #expect(recovered.imageURL(for: placement.assetID) != nil)
    }

    /// Recovery deletes nothing: the images only a damaged manifest showed join it in the recovery folder.
    @Test func anImageOnlyADamagedManifestShowedIsMovedToRecoveredNotDeleted() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let placement = try await fixture.store.placeTestImage(on: fixture.pageID)
        let imageURL = try #require(fixture.store.imageURL(for: placement.assetID))
        let bytes = try Data(contentsOf: imageURL)

        try Data("{ damaged".utf8).write(to: fixture.store.package.manifestURL)
        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        #expect(!assetExists(placement.assetID, in: fixture))
        let recovered = FileManager.default.directoryContents(at: fixture.recoveredDirectory)
        let setAside = try #require(recovered.first { $0.lastPathComponent.hasSuffix(imageURL.lastPathComponent) })
        #expect(try Data(contentsOf: setAside) == bytes)
        #expect(recovered.contains { $0.lastPathComponent.hasSuffix("notebook.json") })
    }

    @Test func nothingIsDeletedWhileThePreviousManifestIsUnreadable() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let orphan = try await fixture.store.importImage(TestImage.png(width: 300, height: 200))
        try Data("{ damaged".utf8).write(to: fixture.store.package.previousManifestURL)

        try await fixture.reopen().purgePages(deletedBefore: Self.cutoff)

        #expect(assetExists(orphan.assetID, in: fixture))
    }
}
