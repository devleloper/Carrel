import Foundation
import Testing

@testable import Carrel

@MainActor
struct ToolPaletteModelTests {
    @Test func paletteListsThreePensThenTheOtherTools() {
        let palette = ToolPaletteModel(settings: .standard)

        #expect(palette.tools == [.pen(0), .pen(1), .pen(2), .highlighter, .eraser, .lasso])
    }

    @Test func togglingTheEraserReturnsToThePreviousTool() {
        let palette = ToolPaletteModel(settings: .standard)
        palette.select(.pen(1))

        palette.toggleEraser()
        #expect(palette.selection == .eraser)

        palette.toggleEraser()
        #expect(palette.selection == .pen(1))
    }

    @Test func settingsSurviveARoundTripThroughUserDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "ToolPaletteModelTests-\(UUID().uuidString)"))
        var settings = ToolSettings.standard
        settings.pens[2].colorHex = 0x912964

        settings.save(to: defaults)

        #expect(ToolSettings.load(from: defaults) == settings)
    }
}
