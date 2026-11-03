import Foundation
import PencilKit
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

    @Test func choosingAToolSelectsItAndChoosingItAgainOpensItsSettings() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.choose(.highlighter)
        #expect(palette.selection == .highlighter)
        #expect(palette.toolWithOpenSettings == nil)

        palette.choose(.highlighter)
        #expect(palette.toolWithOpenSettings == .highlighter)

        palette.choose(.pen(1))
        #expect(palette.selection == .pen(1))
        #expect(palette.toolWithOpenSettings == nil)
    }

    @Test func moreHoldsTheArtInksAsSelectableTools() throws {
        let palette = ToolPaletteModel(defaults: defaults)
        #expect(palette.moreTools == [.artInk(.watercolor), .artInk(.crayon)])

        palette.choose(.artInk(.crayon))
        palette.setColor(InkPalette.plum.hex, for: .artInk(.crayon))
        palette.setWidth(.bold, for: .artInk(.crayon))

        let crayon = try #require(palette.currentTool as? PKInkingTool)
        #expect(crayon.inkType == .crayon)
        #expect(crayon.width == StrokeWidth.bold.points(for: .crayon))
        #expect(ToolPaletteModel(defaults: defaults).color(of: .artInk(.crayon)) == InkPalette.plum.hex)

        palette.choose(.artInk(.crayon))
        #expect(palette.toolWithOpenSettings == .artInk(.crayon))
    }

    @Test func theLassoHasNoSettingsToOpen() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.choose(.lasso)
        palette.choose(.lasso)

        #expect(palette.selection == .lasso)
        #expect(palette.toolWithOpenSettings == nil)
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

        palette.setColor(InkPalette.plum.hex, for: .pen(2))
        palette.setWidth(.bold, for: .highlighter)
        palette.settings.pens[0].inkType = .pencil
        palette.settings.eraser.mode = .pixel

        let relaunched = ToolPaletteModel(defaults: defaults)
        #expect(relaunched.color(of: .pen(2)) == InkPalette.plum.hex)
        #expect(relaunched.width(of: .highlighter) == .bold)
        #expect(relaunched.pen(at: 0)?.inkType == .pencil)
        #expect(relaunched.settings.eraser.mode == .pixel)
    }

    @Test func settingsWithADifferentNumberOfPensFallBackToTheStandardPalette() {
        var settings = ToolSettings.standard
        settings.pens.removeLast()
        settings.save(to: defaults)

        #expect(ToolSettings.load(from: defaults) == .standard)
    }

    @Test func settingsFromAnotherVersionKeepWhatTheyShareWithThisOne() throws {
        let saved = Data(
            """
            {
              "pens": [
                {"inkType": "fountainPen", "colorHex": \(InkPalette.plum.hex), "width": 2.5},
                {"inkType": "quill", "colorHex": \(InkPalette.green.hex), "width": "bold"},
                {"colorHex": \(InkPalette.sepia.hex)}
              ],
              "highlighter": {"colorHex": \(InkPalette.mint.hex), "width": "fine", "opacity": 0.4},
              "isPreciseEraser": true
            }
            """.utf8
        )

        let settings = try JSONDecoder().decode(ToolSettings.self, from: saved)

        #expect(settings.pens.map(\.colorHex) == [InkPalette.plum, InkPalette.green, InkPalette.sepia].map(\.hex))
        #expect(settings.pens[0].width == .medium, "A width saved as points by an earlier version")
        #expect(settings.pens[1].inkType == .fountainPen, "An ink type this version does not know")
        #expect(settings.pens[1].width == .bold)
        #expect(settings.highlighter == InkSettings(colorHex: InkPalette.mint.hex, width: .fine))
        #expect(settings.eraser == ToolSettings.standard.eraser)
        #expect(settings.watercolor == ToolSettings.standard.watercolor, "Saved before the art inks existed")
    }

    @Test func aPenWithoutAColorReturnsThePensToTheStandardPalette() throws {
        let saved = Data(
            """
            {"pens": [{"inkType": "pen"}, {"colorHex": 1}, {"colorHex": 2}], "eraser": {"mode": "pixel"}}
            """.utf8
        )

        let settings = try JSONDecoder().decode(ToolSettings.self, from: saved)

        #expect(settings.pens == ToolSettings.standard.pens)
        #expect(settings.eraser == EraserSettings(mode: .pixel, width: .medium))
    }

    @Test func customColorsAreToldApartByTheirDescription() {
        let red = String(localized: InkPalette.name(for: 0xD01010))
        let blue = String(localized: InkPalette.name(for: 0x1010D0))

        #expect(red.hasPrefix("Custom Color, "))
        #expect(red != blue)
        #expect(String(localized: InkPalette.name(for: InkPalette.sky.hex)) == "Sky")
    }

    @Test func theEraserHasAWidthOnlyWhileErasingPixels() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.select(.eraser)

        #expect(palette.width(of: .eraser) == nil)
        #expect((palette.currentTool as? PKEraserTool)?.eraserType == .vector)

        palette.settings.eraser.mode = .pixel
        palette.setWidth(.bold, for: .eraser)

        #expect(palette.width(of: .eraser) == .bold)
        let eraser = palette.currentTool as? PKEraserTool
        #expect(eraser?.eraserType == .fixedWidthBitmap)
        #expect(eraser?.width == StrokeWidth.bold.eraserPoints)
    }

    @Test func aPenDrawsWithItsInkColorAndWidth() throws {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.settings.pens[1].inkType = .monoline
        palette.setColor(InkPalette.green.hex, for: .pen(1))
        palette.setWidth(.fine, for: .pen(1))

        palette.select(.pen(1))

        let pen = try #require(palette.currentTool as? PKInkingTool)
        #expect(pen.inkType == .monoline)
        #expect(pen.color.hexValue == InkPalette.green.hex)
        #expect(pen.width == StrokeWidth.fine.points(for: .monoline))
    }

    @Test func toolsWithoutAColorOrWidthIgnoreSuchChanges() {
        let palette = ToolPaletteModel(defaults: defaults)
        let before = palette.settings

        palette.setColor(InkPalette.plum.hex, for: .lasso)
        palette.setWidth(.bold, for: .lasso)
        palette.setColor(InkPalette.plum.hex, for: .pen(7))

        #expect(palette.settings == before)
        #expect(palette.color(of: .eraser) == nil)
    }

    @Test func theSummaryNamesColorWidthAndInk() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.setColor(InkPalette.inkBlue.hex, for: .pen(0))
        palette.setWidth(.fine, for: .pen(0))
        palette.settings.pens[0].inkType = .fountainPen
        palette.setColor(0x123456, for: .highlighter)

        #expect(palette.summary(of: .pen(0)) == "Ink Blue, Fine, Fountain")
        #expect(palette.summary(of: .highlighter).hasPrefix("Custom Color, "))
        #expect(palette.summary(of: .highlighter).hasSuffix(", Medium"))
        #expect(palette.summary(of: .eraser) == "Whole Stroke")
        #expect(palette.summary(of: .lasso).isEmpty)
    }
}

@MainActor
struct StrokeWidthTests {
    @Test func steppingStopsAtTheThinnestAndTheBoldest() {
        #expect(StrokeWidth.fine.stepped(by: -1) == .fine)
        #expect(StrokeWidth.fine.stepped(by: 1) == .medium)
        #expect(StrokeWidth.medium.stepped(by: 5) == .bold)
    }

    @Test func everyStepIsThickerAndInsideTheInksRange() {
        let inkTypes =
            PenSettings.InkType.allCases.map(\.pencilKitType) + ArtInk.allCases.map(\.pencilKitType) + [.marker]
        for inkType in inkTypes {
            let points = StrokeWidth.allCases.map { $0.points(for: inkType) }

            #expect(points == points.sorted(), "\(inkType.rawValue)")
            #expect(Set(points).count == points.count, "\(inkType.rawValue)")
            #expect(points.allSatisfy { inkType.validWidthRange.contains($0) }, "\(inkType.rawValue)")
        }
    }
}

@MainActor
struct PaletteDockingTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "PaletteDockingTests-\(UUID().uuidString)"))
    }

    @Test func thePaletteStartsExpandedOnTheLeadingEdge() {
        let palette = ToolPaletteModel(defaults: defaults)

        #expect(palette.side == .leading)
        #expect(!palette.isCollapsed)
    }

    @Test func sideAndCollapsedStateAreThereAfterARelaunch() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.side = .trailing
        palette.isCollapsed = true

        let relaunched = ToolPaletteModel(defaults: defaults)
        #expect(relaunched.side == .trailing)
        #expect(relaunched.isCollapsed)
    }

    @Test func collapsingClosesOpenSettings() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.choose(.pen(0))
        #expect(palette.toolWithOpenSettings == .pen(0))

        palette.isCollapsed = true

        #expect(palette.toolWithOpenSettings == nil)
    }

    @Test func aDroppedPaletteDocksToTheNearerEdge() {
        #expect(PaletteSide(droppedAt: 120, width: 1000) == .leading)
        #expect(PaletteSide(droppedAt: 499, width: 1000) == .leading)
        #expect(PaletteSide(droppedAt: 500, width: 1000) == .trailing)
        #expect(PaletteSide(droppedAt: 1200, width: 1000) == .trailing)
        #expect(PaletteSide(droppedAt: -40, width: 1000) == .leading)
    }
}
