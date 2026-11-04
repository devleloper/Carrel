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

    /// Audits the paper chooser in its sheet or popover. Element detection also scans the screen behind it, which
    /// VoiceOver leaves out on purpose while the chooser is up; on a 13-inch iPad the library's empty-state text
    /// shows beside the sheet and is reported as unreachable. Only issues inside the chooser count.
    @MainActor
    private func auditThePaperChooser(in app: XCUIApplication) throws {
        let chooser = app.otherElements["paperTiles"]
        XCTAssertTrue(chooser.waitForExistence(timeout: 5))
        let frame = chooser.frame
        try app.performAccessibilityAudit(for: Self.audits) { issue in
            guard issue.auditType == .elementDetection else {
                return false
            }
            guard let element = issue.element else {
                return true
            }
            return !frame.intersects(element.frame)
        }
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
        try auditThePaperChooser(in: app)
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
        try auditThePaperChooser(in: app)
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
