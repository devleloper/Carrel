import XCTest

final class LibraryFlowTests: XCTestCase {
    private static let audits: XCUIAccessibilityAuditType = [
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatingANotebookOpensItAndKeepsItInTheLibrary() throws {
        let app = XCUIApplication.launchedForUITesting()

        app.createNotebook(titled: "Linear Algebra")

        XCTAssertTrue(app.staticTexts["saveStatus"].exists)
        try app.performAccessibilityAudit(for: Self.audits)
        app.buttons["closeEditor"].tap()

        XCTAssertTrue(app.buttons["Linear Algebra"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: Self.audits)
    }

    @MainActor
    func testTheEmptyLibraryPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication.launchedForUITesting()

        try app.performAccessibilityAudit(for: Self.audits)
    }
}
