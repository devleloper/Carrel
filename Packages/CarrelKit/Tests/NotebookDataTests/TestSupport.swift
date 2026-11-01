import Foundation
import NotebookDomain

@testable import NotebookData

/// A fresh directory per test, removed by the caller with `defer`.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "CarrelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

extension InkData {
    static func sample(seed: UInt8, contentVersion: Int = 4) -> InkData {
        InkData(payload: Data((0..<256).map { UInt8(truncatingIfNeeded: Int($0) &* Int(seed) &+ 7) }), requiredContentVersion: contentVersion)
    }
}

struct NotebookFixture {
    static let supportedContentVersion = 5

    let directory: URL
    let recoveredDirectory: URL
    let store: NotebookStore
    let pageID: Page.ID

    init() throws {
        directory = try makeTemporaryDirectory()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let notebook = Notebook(
            title: "Linear Algebra",
            cover: Cover(preset: .forestCloth),
            defaultPaper: .standard,
            defaultPageSize: .a4,
            sortKey: .initial,
            now: now
        )
        let page = Page(sortKey: .initial, size: .a4, paper: .standard, now: now)
        pageID = page.id
        recoveredDirectory = directory.appending(path: "Recovered", directoryHint: .isDirectory)
        store = try NotebookStore.create(
            notebook,
            firstPage: page,
            at: directory.appending(path: "\(notebook.id.uuidString).notebook", directoryHint: .isDirectory),
            supportedContentVersion: Self.supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    func reopen() throws -> NotebookStore {
        try NotebookStore.open(
            at: store.package.url,
            supportedContentVersion: Self.supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
