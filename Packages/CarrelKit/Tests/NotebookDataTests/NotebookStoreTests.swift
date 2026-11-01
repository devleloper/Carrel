import Foundation
import NotebookDomain
import Testing

@testable import NotebookData

struct NotebookStoreTests {
    @Test func savedInkSurvivesReopening() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)

        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .ink(.sample(seed: 1)))
    }

    @Test func manifestRecordsInkBeforeTheInkFileAppears() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)

        let onDisk = try NotebookStore.readManifest(of: fixture.store.package)
        #expect(onDisk.pages.first?.hasInk == true)
    }

    @Test func damagedInkIsMovedAsideAndThePreviousGenerationIsUsed() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)
        try fixture.damageInk()

        let reopened = try fixture.reopen()

        #expect(await reopened.ink(for: fixture.pageID) == .recovered(.sample(seed: 1)))
        #expect(!fixture.inkFileExists)
        #expect(FileManager.default.directoryContents(at: fixture.recoveredDirectory).count == 1)
    }

    @Test func savingAfterRecoveryKeepsTheIntactGeneration() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)
        try fixture.damageInk()
        let reopened = try fixture.reopen()
        _ = await reopened.ink(for: fixture.pageID)

        try await reopened.saveInk(.sample(seed: 3), for: fixture.pageID)

        let previous = try Data(contentsOf: fixture.store.package.previousInkURL(for: fixture.pageID))
        #expect(try InkEnvelope.decode(previous) == .sample(seed: 1))
    }

    @Test func missingInkOfAPageWithInkIsReportedAsMissing() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try FileManager.default.removeItem(at: fixture.store.package.inkURL(for: fixture.pageID))

        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .missing)
    }

    @Test func lonePreviousGenerationIsRecovered() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID)
        try await fixture.store.saveInk(.sample(seed: 2), for: fixture.pageID)
        try FileManager.default.removeItem(at: fixture.store.package.inkURL(for: fixture.pageID))

        #expect(try await fixture.reopen().ink(for: fixture.pageID) == .recovered(.sample(seed: 1)))
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

        #expect(await reopened.manifest.activePages.map(\.id) == [fixture.pageID, orphanID])
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
        try await fixture.store.setPageInTrash(fixture.pageID, true, now: deletedAt)

        try await fixture.store.purgePages(deletedBefore: deletedAt.addingTimeInterval(1))

        #expect(await fixture.store.manifest.pages.isEmpty)
    }

    // MARK: Editing

    @Test func everyEditUpdatesTheNotebookModificationDate() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let later = Date(timeIntervalSince1970: 1_900_000_000)

        try await fixture.store.saveInk(.sample(seed: 1), for: fixture.pageID, now: later)

        #expect(await fixture.store.manifest.notebook.modifiedAt == later)
    }

    @Test func organizingKeepsTheModificationDate() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let before = await fixture.store.manifest.notebook.modifiedAt

        let notebook = try await fixture.store.organize { $0.isFavorite = true }

        #expect(notebook.isFavorite)
        #expect(notebook.modifiedAt == before)
    }

    @Test func aNewPageNeverSharesAKeyWithAPageInTheTrash() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let second = try await fixture.store.appendPage()
        try await fixture.store.setPageInTrash(second.id, true)

        let third = try await fixture.store.appendPage()
        try await fixture.store.setPageInTrash(second.id, false)

        let pages = await fixture.store.manifest.activePages
        #expect(pages.map(\.id) == [fixture.pageID, second.id, third.id])
        #expect(Set(pages.map(\.sortKey)).count == pages.count)
    }

    struct PageMove: Sendable, CustomTestStringConvertible {
        let index: Int
        let offset: Int
        let expectedOrder: [Int]

        var testDescription: String {
            "page \(index) by \(offset)"
        }
    }

    @Test(arguments: [
        PageMove(index: 0, offset: 1, expectedOrder: [1, 0, 2]),
        PageMove(index: 2, offset: -1, expectedOrder: [0, 2, 1]),
        PageMove(index: 1, offset: -1, expectedOrder: [1, 0, 2]),
        PageMove(index: 1, offset: 1, expectedOrder: [0, 2, 1]),
    ])
    func movingAPageReordersOnlyThatPage(_ move: PageMove) async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        _ = try await fixture.store.appendPage()
        _ = try await fixture.store.appendPage()
        let original = await fixture.store.manifest.activePages.map(\.id)

        try await fixture.store.movePage(original[move.index], by: move.offset)

        #expect(await fixture.store.manifest.activePages.map(\.id) == move.expectedOrder.map { original[$0] })
    }

    @Test func movingAPageSkipsOverPagesInTheTrash() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let trashed = try await fixture.store.appendPage()
        let last = try await fixture.store.appendPage()
        try await fixture.store.setPageInTrash(trashed.id, true)

        try await fixture.store.movePage(last.id, by: -1)
        try await fixture.store.setPageInTrash(trashed.id, false)

        let pages = await fixture.store.manifest.activePages
        #expect(pages.first?.id == last.id)
        #expect(Set(pages.map(\.sortKey)).count == pages.count)
    }

    @Test func duplicatingAPageCopiesItsInkRightAfterIt() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }
        let next = try await fixture.store.appendPage()
        try await fixture.store.saveInk(.sample(seed: 7), for: fixture.pageID)

        let copy = try #require(try await fixture.store.duplicatePage(fixture.pageID))

        #expect(await fixture.store.manifest.activePages.map(\.id) == [fixture.pageID, copy.id, next.id])
        #expect(try await fixture.reopen().ink(for: copy.id) == .ink(.sample(seed: 7)))
    }

    @Test func blankTitlesAreIgnoredWhenRenaming() async throws {
        let fixture = try NotebookFixture()
        defer { fixture.remove() }

        try await fixture.store.rename(to: "   ")

        #expect(await fixture.store.manifest.notebook.title == "Linear Algebra")
    }
}
