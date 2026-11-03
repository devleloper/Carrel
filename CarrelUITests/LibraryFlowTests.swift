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

        app.buttons["newNotebook"].firstMatch.tap()
        let titleField = app.textFields["notebookTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Linear Algebra")
        app.buttons["createNotebook"].tap()

        let closeButton = app.buttons["closeEditor"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10), "Creating a notebook should open it")
        XCTAssertTrue(app.staticTexts["saveStatus"].exists)
        try app.performAccessibilityAudit(for: Self.audits)
        closeButton.tap()

        XCTAssertTrue(app.buttons["Linear Algebra"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: Self.audits)
    }

    @MainActor
    func testTheEmptyLibraryPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication.launchedForUITesting()

        try app.performAccessibilityAudit(for: Self.audits)
    }
}
