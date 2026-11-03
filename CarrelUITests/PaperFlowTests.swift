import XCTest

final class PaperFlowTests: XCTestCase {
    private static let audits: XCUIAccessibilityAuditType = [
        .elementDetection,
        .hitRegion,
        .sufficientElementDescription,
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    @MainActor
    private func waitUntilSelected(_ element: XCUIElement) {
        let selected = NSPredicate(format: "isSelected == true")
        wait(for: [expectation(for: selected, evaluatedWith: element)], timeout: 5)
    }

    @MainActor
    func testANewNotebookCanStartOnLinenPaper() throws {
        let app = launch()

        app.buttons["newNotebook"].firstMatch.tap()
        let linen = app.buttons["paperTone.linen"]
        XCTAssertTrue(linen.waitForExistence(timeout: 5), "The new notebook sheet should offer Linen")
        linen.tap()
        waitUntilSelected(linen)
        try app.performAccessibilityAudit(for: Self.audits)
        app.buttons["createNotebook"].tap()

        let paperButton = app.buttons["paperChooser"]
        XCTAssertTrue(paperButton.waitForExistence(timeout: 10), "Creating a notebook should open it")
        paperButton.tap()
        waitUntilSelected(app.buttons["paperTone.linen"])
    }

    @MainActor
    func testNightPaperCanBeChosenForAPageFromTheTopBar() throws {
        let app = launch()
        app.buttons["newNotebook"].firstMatch.tap()
        let titleField = app.textFields["notebookTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Evening Notes")
        app.buttons["createNotebook"].tap()
        let paperButton = app.buttons["paperChooser"]
        XCTAssertTrue(paperButton.waitForExistence(timeout: 10))

        paperButton.tap()
        let night = app.buttons["paperTone.night"]
        XCTAssertTrue(night.waitForExistence(timeout: 5))
        night.tap()
        waitUntilSelected(night)
        try app.performAccessibilityAudit(for: Self.audits)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        XCTAssertTrue(night.waitForNonExistence(timeout: 5), "The paper chooser should close")

        // A reopened notebook gets a new session from the store, which takes a change only once it is written.
        app.buttons["closeEditor"].tap()
        let notebook = app.buttons["Evening Notes"]
        XCTAssertTrue(notebook.waitForExistence(timeout: 5))
        notebook.tap()
        XCTAssertTrue(paperButton.waitForExistence(timeout: 10))
        paperButton.tap()
        XCTAssertTrue(night.waitForExistence(timeout: 5))
        waitUntilSelected(night)
    }
}
