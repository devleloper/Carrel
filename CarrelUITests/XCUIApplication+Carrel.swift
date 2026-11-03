import XCTest

extension XCUIApplication {
    /// Launches the app on an empty library with default settings, apart from the user's notebooks.
    @MainActor
    static func launchedForUITesting() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    /// Creates a notebook from the library and waits until its editor is open.
    @MainActor
    func createNotebook(titled title: String, file: StaticString = #filePath, line: UInt = #line) {
        buttons["newNotebook"].firstMatch.tap()
        let titleField = textFields["notebookTitle"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), file: file, line: line)
        titleField.tap()
        titleField.typeText(title)
        buttons["createNotebook"].tap()
        XCTAssertTrue(
            buttons["closeEditor"].waitForExistence(timeout: 10),
            "Creating a notebook should open it",
            file: file,
            line: line
        )
    }
}
