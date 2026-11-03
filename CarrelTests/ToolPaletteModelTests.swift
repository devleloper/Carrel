import Foundation
import PencilKit
import SwiftUI
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

@MainActor
struct PenTipPaletteTests {
    private let defaults: UserDefaults
    private let tip = CGPoint(x: 300, y: 400)

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "PenTipPaletteTests-\(UUID().uuidString)"))
    }

    @Test func aColorChangedInTheSettingsJoinsThatPensRecentColorsWithTheOneBefore() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.select(.pen(1))
        palette.choose(.pen(1))

        palette.setColor(InkPalette.sky.hex, for: .pen(1))
        palette.setColor(InkPalette.sepia.hex, for: .pen(1))
        palette.dismissSettings()

        #expect(palette.settings.pens[1].recentColors == [InkPalette.sepia.hex, InkPalette.inkBlue.hex])
        #expect(palette.settings.pens[0].recentColors.isEmpty, "Each pen keeps its own colors")
        #expect(ToolPaletteModel(defaults: defaults).settings.pens[1].recentColors.first == InkPalette.sepia.hex)
    }

    @Test func recentColorsHaveNoDuplicatesAndKeepTheNewestFive() {
        var settings = ToolSettings.standard

        for swatch in InkPalette.pens {
            settings.rememberColor(swatch.hex, for: .pen(0))
        }
        settings.rememberColor(InkPalette.moss.hex, for: .pen(0))

        let colors = settings.pens[0].recentColors
        #expect(colors.count == ToolSettings.recentColorLimit)
        #expect(colors.first == InkPalette.moss.hex)
        #expect(Set(colors).count == colors.count)
        #expect(colors.last == InkPalette.plum.hex)
    }

    @Test func theColorRowShowsTheColorsOfTheToolInHand() {
        let palette = ToolPaletteModel(defaults: defaults)
        let starters = [InkPalette.carbon, InkPalette.inkBlue, InkPalette.vermilion, InkPalette.green, InkPalette.plum]

        #expect(palette.quickColors == starters.map(\.hex))

        palette.select(.pen(1))
        #expect(palette.quickColors.first == InkPalette.inkBlue.hex)
        #expect(palette.quickColors.count == 5)

        palette.select(.artInk(.watercolor))
        #expect(palette.quickColors.first == InkPalette.sky.hex)

        palette.select(.highlighter)
        #expect(palette.quickColors == InkPalette.highlighters.map(\.hex))

        palette.select(.lasso)
        #expect(palette.quickColors.isEmpty)
    }

    @Test func aQuickColorRecolorsTheToolInHandAndClosesThePalette() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.select(.pen(1))
        palette.showPenTipPalette(at: tip)

        palette.applyQuickColor(InkPalette.green.hex)

        #expect(palette.color(of: .pen(1)) == InkPalette.green.hex)
        #expect(palette.quickColors.prefix(2) == [InkPalette.green.hex, InkPalette.inkBlue.hex])
        #expect(!palette.isPenTipPaletteOpen)
    }

    @Test func aHighlighterColorStaysWithTheHighlighter() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.select(.highlighter)
        palette.choose(.highlighter)

        palette.setColor(0xC0FFEE, for: .highlighter)
        palette.dismissSettings()

        #expect(palette.quickColors == [0xC0FFEE] + InkPalette.highlighters.map(\.hex))
        #expect(palette.settings.pens.allSatisfy { $0.recentColors.isEmpty })
    }

    @Test func choosingAToolAtThePenTipSelectsItAndClosesThePalette() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.showPenTipPalette(at: tip)
        #expect(palette.penTipPaletteAnchor == .penTip(tip))

        palette.selectAtPenTip(.highlighter)

        #expect(palette.selection == .highlighter)
        #expect(palette.toolWithOpenSettings == nil)
        #expect(!palette.isPenTipPaletteOpen)
    }

    @Test func theGestureThatOpensThePaletteClosesItAgain() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.togglePenTipPalette(at: tip)
        #expect(palette.penTipPaletteAnchor == .penTip(tip))

        palette.togglePenTipPalette(at: CGPoint(x: 10, y: 10))
        #expect(!palette.isPenTipPaletteOpen)
    }

    @Test func withoutATipThePaletteOpensBesideTheMainPalette() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.togglePenTipPalette(at: nil)

        #expect(palette.penTipPaletteAnchor == .mainPalette)
    }

    @Test func openingThePaletteClosesOpenSettingsAndKeepsTheirColor() {
        let palette = ToolPaletteModel(defaults: defaults)
        palette.choose(.pen(0))
        palette.setColor(InkPalette.plum.hex, for: .pen(0))

        palette.showPenTipPalette(at: tip)

        #expect(palette.toolWithOpenSettings == nil)
        #expect(palette.settings.pens[0].recentColors.first == InkPalette.plum.hex)
    }

    @Test func usingTheMainPaletteClosesThePaletteAtThePenTip() {
        let palette = ToolPaletteModel(defaults: defaults)

        palette.showPenTipPalette(at: tip)
        palette.choose(.highlighter)
        #expect(!palette.isPenTipPaletteOpen, "A choice in the main palette")

        palette.showPenTipPalette(at: tip)
        palette.isCollapsed = true
        #expect(!palette.isPenTipPaletteOpen, "Collapsing the main palette")

        palette.showPenTipPalette(at: tip)
        palette.side = .trailing
        #expect(!palette.isPenTipPaletteOpen, "Docking the main palette")
    }
}

@MainActor
struct PenTipPalettePlacementTests {
    private let window = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let size = CGSize(width: 300, height: 100)

    private func frame(
        tip: CGPoint,
        side: PaletteSide = .leading,
        in bounds: CGRect? = nil,
        topInset: CGFloat = 0,
        mainPalette: CGRect? = nil
    ) -> CGRect {
        placement(.penTip(tip), side: side, in: bounds, topInset: topInset, mainPalette: mainPalette).frame(of: size)
    }

    private func placement(
        _ anchor: PenTipPaletteAnchor,
        side: PaletteSide = .leading,
        in bounds: CGRect? = nil,
        topInset: CGFloat = 0,
        mainPalette: CGRect? = nil
    ) -> PenTipPalettePlacement {
        let area = PenTipPalettePlacement.freeArea(
            in: bounds ?? window,
            safeAreaInsets: EdgeInsets(top: topInset, leading: 0, bottom: 0, trailing: 0),
            mainPalette: mainPalette
        )
        return PenTipPalettePlacement(anchor: anchor, side: side, mainPalette: mainPalette, area: area)
    }

    @Test func thePaletteOpensAboveTheTipAndTowardThePalettesSide() {
        let tip = CGPoint(x: 500, y: 400)

        #expect(frame(tip: tip, side: .leading) == CGRect(x: 176, y: 276, width: 300, height: 100))
        #expect(frame(tip: tip, side: .trailing) == CGRect(x: 524, y: 276, width: 300, height: 100))
    }

    @Test func withoutRoomAboveThePaletteOpensBelowTheTip() {
        #expect(frame(tip: CGPoint(x: 500, y: 60)).minY == 84)
    }

    @Test func thePaletteStaysBelowTheTopBar() {
        let belowTheBar = frame(tip: CGPoint(x: 500, y: 150), topInset: 84)

        #expect(belowTheBar.minY == 174, "Above the tip it would reach under the bar, so it opens below")
    }

    @Test func withoutRoomOnItsSideThePaletteOpensOnTheOtherSide() {
        #expect(frame(tip: CGPoint(x: 120, y: 400), side: .leading).minX == 144)
        #expect(frame(tip: CGPoint(x: 900, y: 400), side: .trailing).maxX == 876)
    }

    @Test func thePaletteKeepsClearOfTheMainPalette() {
        let leadingPalette = CGRect(x: 16, y: 300, width: 60, height: 400)
        #expect(frame(tip: CGPoint(x: 380, y: 400), side: .leading, mainPalette: leadingPalette).minX == 404)

        let trailingPalette = CGRect(x: 924, y: 300, width: 60, height: 400)
        let besideTrailing = frame(tip: CGPoint(x: 590, y: 400), side: .trailing, mainPalette: trailingPalette)
        #expect(besideTrailing.maxX == 566, "It would reach to 914, past the palette's margin at 908")
    }

    @Test func withoutATipThePaletteOpensBesideTheMainPalette() {
        let mainPalette = CGRect(x: 16, y: 200, width: 60, height: 400)
        let beside = placement(.mainPalette, mainPalette: mainPalette)

        #expect(beside.frame(of: size) == CGRect(x: 92, y: 350, width: 300, height: 100))
        #expect(beside.origin == CGPoint(x: 76, y: 400), "It grows out of the main palette's inner edge")

        let unmeasured = placement(.mainPalette).frame(of: size)
        #expect(unmeasured.midX == window.midX)
        #expect(unmeasured.midY == window.midY)
    }

    @Test func thePaletteStaysInsideTheWindowMargins() {
        let narrow = CGRect(x: 0, y: 0, width: 360, height: 800)

        let placed = frame(tip: CGPoint(x: 180, y: 400), in: narrow)

        #expect(placed.minX >= PenTipPalettePlacement.margin)
        #expect(placed.maxX <= narrow.maxX - PenTipPalettePlacement.margin)
    }
}
