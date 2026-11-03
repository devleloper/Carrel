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

        XCTAssertTrue(app.buttons["closeEditor"].waitForExistence(timeout: 10), "Creating a notebook should open it")
    }
}
