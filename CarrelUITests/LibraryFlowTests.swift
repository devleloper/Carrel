import XCTest

final class LibraryFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatingANotebookOpensItAndKeepsItInTheLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        app.buttons["newNotebook"].firstMatch.tap()
        let titleField = app.textFields["notebookTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Linear Algebra")
        app.buttons["createNotebook"].tap()

        let closeButton = app.buttons["closeEditor"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 10), "Creating a notebook should open it")
        XCTAssertTrue(app.staticTexts["saveStatus"].exists)
        closeButton.tap()

        XCTAssertTrue(app.buttons["Linear Algebra"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLibraryPassesTheAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        try app.performAccessibilityAudit(for: [.elementDetection, .hitRegion, .sufficientElementDescription])
    }
}
