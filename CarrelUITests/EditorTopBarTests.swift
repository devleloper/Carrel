import XCTest

final class EditorTopBarTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Puts a page under the bar and writes on the next one, then uses every bar button several times and taps the
    /// bar beside them. None of those touches may reach the page under the bar: a stroke would turn the save status
    /// to Edited.
    @MainActor
    func testTheBarAnswersEveryTouchWhilePagesLieUnderIt() throws {
        let app = XCUIApplication.launchedForUITesting()
        app.buttons["newNotebook"].firstMatch.tap()
        app.buttons["createNotebook"].tap()
        let status = app.staticTexts["saveStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10), "Creating a notebook should open it")

        showSecondPage(in: app)
        // Fingers draw in the simulator, which has no Apple Pencil setting; with Only Draw with Apple Pencil on,
        // this drag scrolls instead and the Undo checks below have nothing to undo.
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.65)))

        let undo = app.buttons["Undo"]
        let redo = app.buttons["Redo"]
        XCTAssertTrue(wait(for: undo, toBeEnabled: true), "The stroke should be undoable")
        for _ in 1...3 {
            XCTAssertTrue(wait(for: status, toEndWith: "Saved"))
            tapBesideTheButtons(in: app)
            XCTAssertFalse(wait(for: status, toEndWith: "Edited", timeout: 2), "A touch on the bar reached the page")

            // The buttons' state, unlike the status, does not change back by itself: autosave can turn Edited
            // into Saved before a slow machine gets to look at the status.
            undo.tap()
            XCTAssertTrue(wait(for: undo, toBeEnabled: false), "Undo should remove the stroke")
            XCTAssertTrue(redo.isEnabled)
            XCTAssertTrue(wait(for: status, toEndWith: "Saved"))
            redo.tap()
            XCTAssertTrue(wait(for: redo, toBeEnabled: false), "Redo should bring the stroke back")
            XCTAssertTrue(undo.isEnabled)

            app.buttons["Pages"].tap()
            let done = app.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5), "Pages should open the page overview")
            done.tap()

            app.buttons["More"].firstMatch.tap()
            let export = app.buttons["Export PDF"]
            XCTAssertTrue(export.waitForExistence(timeout: 5), "More should open its menu")
            status.tap()
            XCTAssertTrue(export.waitForNonExistence(timeout: 5))
        }

        app.buttons["closeEditor"].tap()
        XCTAssertTrue(app.buttons["newNotebook"].firstMatch.waitForExistence(timeout: 10))
    }

    /// Duplicates the empty first page and jumps to the copy, which leaves the first page under the bar.
    @MainActor
    private func showSecondPage(in app: XCUIApplication) {
        app.buttons["Pages"].tap()
        let firstPage = app.buttons["Page 1"]
        XCTAssertTrue(firstPage.waitForExistence(timeout: 5))
        firstPage.press(forDuration: 1)
        app.buttons["Duplicate"].tap()
        let secondPage = app.buttons["Page 2"]
        XCTAssertTrue(secondPage.waitForExistence(timeout: 5))
        secondPage.tap()
        XCTAssertTrue(app.buttons["closeEditor"].waitForExistence(timeout: 5))
    }

    /// Taps the bar where it has no control but the page lies underneath: between the title and the buttons, and
    /// along its lower edge below the title. The spots keep clear of the buttons, which also answer a finger that
    /// lands a few points outside them, and of the status bar, where a tap scrolls to the top.
    @MainActor
    private func tapBesideTheButtons(in app: XCUIApplication) {
        let undo = app.buttons["Undo"].frame
        let title = app.staticTexts["saveStatus"].frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let spots = [
            CGPoint(x: (title.maxX + undo.minX) / 2, y: undo.midY),
            CGPoint(x: (title.maxX + undo.minX) / 2, y: undo.maxY + 8),
            CGPoint(x: title.midX, y: undo.maxY + 8),
        ]
        for spot in spots {
            origin.withOffset(CGVector(dx: spot.x, dy: spot.y)).tap()
        }
    }

    /// Waits until a button is enabled or disabled.
    @MainActor
    private func wait(for button: XCUIElement, toBeEnabled isEnabled: Bool, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "enabled == %@", NSNumber(value: isEnabled))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits until the save status, "Page 1 of 2 · Saved" and the like, ends with `word`.
    @MainActor
    private func wait(for status: XCUIElement, toEndWith word: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label ENDSWITH %@", "· \(word)")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: status)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
