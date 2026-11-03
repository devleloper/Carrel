import XCTest

final class EditorZoomTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Zoom Out (⌘−) puts the pages on the desk, and Fit Width (⌘0) brings back the borderless default page, which
    /// with fingers drawing is the only way back after a pinch. A synthesized pinch does not reach the pages in the
    /// simulator, so the keyboard drives the zoom here.
    @MainActor
    func testZoomOutAndFitWidthFromTheKeyboard() throws {
        let app = XCUIApplication.launchedForUITesting()
        app.buttons["newNotebook"].firstMatch.tap()
        app.buttons["createNotebook"].tap()
        let pages = app.scrollViews["pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 10), "Creating a notebook should open it")
        XCTAssertTrue(wait(for: pages, toShow: "100"))

        // In the simulator the first key press after launch does not reach the app's shortcuts, so ⌘0, which
        // changes nothing at the default zoom, goes first.
        app.typeKey("0", modifierFlags: .command)
        app.typeKey("-", modifierFlags: .command)
        XCTAssertTrue(wait(for: pages, toShow: "75"), "Zoom Out should go to the next step down")
        app.typeKey("-", modifierFlags: .command)
        XCTAssertTrue(wait(for: pages, toShow: "50"), "Zoom Out should stop at 50%")

        app.typeKey("0", modifierFlags: .command)
        XCTAssertTrue(wait(for: pages, toShow: "100"), "Fit Width should return to the full width")
        XCTAssertTrue(app.staticTexts["saveStatus"].label.hasSuffix("· Saved"), "Zooming should not draw")
    }

    /// Waits for the pages' zoom, a percentage formatted for the current locale such as "75%", to start with `digits`.
    @MainActor
    private func wait(for pages: XCUIElement, toShow digits: String) -> Bool {
        let predicate = NSPredicate(format: "value BEGINSWITH %@", digits)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: pages)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
