import XCTest

final class ToolPaletteFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testThePaletteCollapsesExpandsAndPicksAnArtInkFromMore() throws {
        let app = XCUIApplication.launchedForUITesting()
        app.createNotebook(titled: "Sketches")

        let collapseButton = app.buttons["collapsePalette"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 5))
        collapseButton.tap()

        let expandButton = app.buttons["expandPalette"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 5), "The collapsed palette should offer to expand")
        let toolsHidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.buttons["moreTools"]
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [toolsHidden], timeout: 5),
            .completed,
            "The collapsed palette should hide its tools"
        )
        expandButton.tap()

        let moreButton = app.buttons["moreTools"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "The expanded palette should show its tools")
        moreButton.tap()
        let watercolor = app.buttons["Watercolor"]
        XCTAssertTrue(watercolor.waitForExistence(timeout: 5), "More should list the art inks")
        watercolor.tap()

        let selected = NSPredicate(format: "value BEGINSWITH %@", "Watercolor")
        let pickedWatercolor = XCTNSPredicateExpectation(predicate: selected, object: moreButton)
        XCTAssertEqual(XCTWaiter().wait(for: [pickedWatercolor], timeout: 5), .completed)

        moreButton.tap()
        XCTAssertTrue(watercolor.waitForExistence(timeout: 5))
        watercolor.tap()
        XCTAssertTrue(
            app.scrollViews["toolSettings"].waitForExistence(timeout: 5),
            "Choosing the art ink in hand again should open its settings"
        )
    }
}
