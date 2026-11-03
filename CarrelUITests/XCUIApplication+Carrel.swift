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
}
