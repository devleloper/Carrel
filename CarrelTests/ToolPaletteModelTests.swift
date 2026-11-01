import Foundation
import Testing

@testable import Carrel

@MainActor
struct ToolPaletteModelTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "ToolPaletteModelTests-\(UUID().uuidString)"))
    }

    @Test func paletteListsThreePensThenTheOtherTools() {
        let palette = ToolPaletteModel(defaults: defaults)

        #expect(palette.tools == [.pen(0), .pen(1), .pen(2), .highlighter, .eraser, .lasso])
    }

    @Test func togglingTheEraserReturnsToThePreviousTool() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.select(.pen(1))

        palette.toggleEraser()
        #expect(palette.selection == .eraser)

        palette.toggleEraser()
        #expect(palette.selection == .pen(1))
    }

    @Test func changedSettingsAreThereAfterARelaunch() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.settings.pens[2].colorHex = InkPalette.plum.hex

        #expect(ToolPaletteModel(defaults: defaults).settings.pens[2].colorHex == InkPalette.plum.hex)
    }

    @Test func settingsWithADifferentNumberOfPensFallBackToTheStandardPalette() {
        var settings = ToolSettings.standard
        settings.pens.removeLast()
        settings.save(to: defaults)

        #expect(ToolSettings.load(from: defaults) == .standard)
    }
}
