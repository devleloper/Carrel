import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct NotebookStoreTests {
    @Test func savedInkSurvivesReopening() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        let reopened = try fixture.reopen()

        #expect(await reopened.ink(for: fixture.pageID) == .ink(.sample(seed: 1)))
    }

    @Test func manifestRecordsInkBeforeTheInkFileAppears() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        let onDisk = try NotebookStore.readManifest(of: fixture.store.package)

        #expect(onDisk.pages.first?.hasInk == true)
    }

    @Test func damagedInkFallsBackToThePreviousGenerationAndIsQuarantined() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)

        let inkURL = fixture.store.package.inkURL(for: fixture.pageID)
        var data = try Data(contentsOf: inkURL)
        data[data.count - 1] ^= 0xFF
        try data.write(to: inkURL)

        let reopened = try fixture.reopen()
        #expect(await reopened.ink(for: fixture.pageID) == .recovered(.sample(seed: 1)))
        #expect(!FileManager.default.directoryContents(at: fixture.recoveredDirectory).isEmpty)
    }

    @Test func missingInkOfAPageWithInkIsNeverReportedAsEmpty() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try FileManager.default.removeItem(at: fixture.store.package.inkURL(for: fixture.pageID))

        let reopened = try fixture.reopen()
        #expect(await reopened.ink(for: fixture.pageID) == .unrecoverable)
    }

    @Test func lonePreviousGenerationIsRecovered() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)
        try FileManager.default.removeItem(at: fixture.store.package.inkURL(for: fixture.pageID))

        let reopened = try fixture.reopen()
        #expect(await reopened.ink(for: fixture.pageID) == .recovered(.sample(seed: 1)))
    }

    @Test func inkFromANewerSystemIsReadOnlyAndNeverRewritten() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let newer = InkData.sample(seed: 3, contentVersion: NotebookFixture.supportedContentVersion + 1)
        try await fixture.store.saveInk(newer, for: fixture.pageID)
        let inkURL = fixture.store.package.inkURL(for: fixture.pageID)
        let original = try Data(contentsOf: inkURL)

        let reopened = try fixture.reopen()
        #expect(await reopened.ink(for: fixture.pageID) == .requiresNewerSystem)
        await #expect(throws: NotebookStoreError.requiresNewerSystem) {
            try await reopened.saveInk(.sample(seed: 4), for: fixture.pageID)
        }
        #expect(try Data(contentsOf: inkURL) == original)
    }

    @Test func orphanInkBecomesARecoveredPage() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let orphanID = UUID()
        try InkEnvelope.encode(.sample(seed: 5)).write(to: fixture.store.package.inkURL(for: orphanID))

        let reopened = try fixture.reopen()
        let pages = await reopened.manifest.activePages

        #expect(pages.map(\.id) == [fixture.pageID, orphanID])
        #expect(await reopened.ink(for: orphanID) == .ink(.sample(seed: 5)))
    }

    @Test func identicalInkIsNotWrittenTwice() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)

        let previousURL = fixture.store.package.previousInkURL(for: fixture.pageID)
        #expect(!FileManager.default.fileExists(atPath: previousURL.path(percentEncoded: false)))
    }

    @Test func trashedPagesArePurgedAfterTheCutoff() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let pageID = fixture.pageID
        try await fixture.store.updateManifest { manifest in
            if let index = manifest.pageIndex(of: pageID) {
                manifest.pages[index].deletedAt = deletedAt
            }
        }

        try await fixture.store.purgePages(deletedBefore: deletedAt.addingTimeInterval(1))

        #expect(await fixture.store.manifest.pages.isEmpty)
    }
}
