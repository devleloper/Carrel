import CoreGraphics
import NotebookDomain
import Testing

@testable import Carrel

@MainActor
struct PageStackLayoutTests {
    private let metrics = PageStackLayout.Metrics(pageSpacing: 20)

    /// Fitting a page to a width divides by the page width, so a result can be off in the last binary digit.
    private func isClose(_ value: CGFloat, _ expected: CGFloat) -> Bool {
        abs(value - expected) < 0.001
    }

    @Test func theWidestPageSpansTheContainerAtZoomOne() {
        let layout = PageStackLayout(pageSizes: [.a4, .a4], containerWidth: 800, zoom: 1, metrics: metrics)

        #expect(layout.pageFrames[0].minX == 0)
        #expect(isClose(layout.pageFrames[0].width, 800))
        #expect(layout.pageFrames[0].minY == 20)
        #expect(layout.pageFrames[1].minY == layout.pageFrames[0].maxY + 20)
        #expect(isClose(layout.contentSize.width, 800))
        #expect(layout.contentSize.height == layout.pageFrames[1].maxY + 20)
        #expect(!layout.showsEdges(ofPageAt: 0))
        #expect(!layout.showsEdges(ofPageAt: 1))
    }

    @Test func narrowerPagesShowTheirEdgesBesideTheWidestOne() {
        let layout = PageStackLayout(
            pageSizes: [PageSize.a4.landscape, .a4],
            containerWidth: 800,
            zoom: 1,
            metrics: metrics
        )

        #expect(isClose(layout.pageFrames[0].width, 800))
        #expect(layout.pageFrames[1].width < 800)
        #expect(isClose(layout.pageFrames[1].midX, 400))
        #expect(!layout.showsEdges(ofPageAt: 0))
        #expect(layout.showsEdges(ofPageAt: 1))
    }

    @Test func zoomingOutPutsCenteredPagesOnTheDesk() {
        let layout = PageStackLayout(pageSizes: [.a4], containerWidth: 800, zoom: 0.5, metrics: metrics)

        #expect(isClose(layout.pageFrames[0].width, 400))
        #expect(isClose(layout.pageFrames[0].minX, 200))
        #expect(layout.contentSize.width == 800)
        #expect(layout.showsEdges(ofPageAt: 0))
    }

    @Test func zoomingInWidensTheContentToThePage() {
        let layout = PageStackLayout(pageSizes: [.a4], containerWidth: 800, zoom: 2, metrics: metrics)

        #expect(isClose(layout.pageFrames[0].width, 1600))
        #expect(layout.pageFrames[0].minX == 0)
        #expect(layout.contentSize.width == layout.pageFrames[0].width)
        #expect(!layout.showsEdges(ofPageAt: 0))
    }

    /// These widths make the fitted page width round to just above the container width.
    @Test(arguments: zip([PageSize.a4, .a4, .a4, .letter], [834, 1194, 504, 507] as [CGFloat]))
    func aPageThatFitsTheWidthIsExactlyAsWideAsTheContainer(pageSize: PageSize, containerWidth: CGFloat) {
        let layout = PageStackLayout(pageSizes: [pageSize, pageSize], containerWidth: containerWidth, zoom: 1)

        #expect(layout.contentSize.width == containerWidth)
        #expect(layout.pageFrames.allSatisfy { $0.minX == 0 && $0.width == containerWidth })
        #expect(!layout.showsEdges(ofPageAt: 0) && !layout.showsEdges(ofPageAt: 1))
    }

    @Test func zoomRestsBetweenHalfAndFourTimesTheFitToWidth() {
        #expect(PageStackLayout.restingZoom(after: 0.2) == 0.5)
        #expect(PageStackLayout.restingZoom(after: 0.75) == 0.75)
        #expect(PageStackLayout.restingZoom(after: 9) == 4)
    }

    @Test func aPinchThatEndsNearTheFitToWidthFitsItExactly() {
        #expect(PageStackLayout.restingZoom(after: 0.97) == 1)
        #expect(PageStackLayout.restingZoom(after: 1.03) == 1)
        #expect(PageStackLayout.restingZoom(after: 0.9) == 0.9)
        #expect(PageStackLayout.restingZoom(after: 1.1) == 1.1)
    }

    @Test func doubleTapSwitchesBetweenFitToWidthAndTwoHundredPercent() {
        #expect(PageStackLayout.zoomAfterDoubleTap(from: 1) == 2)
        #expect(PageStackLayout.zoomAfterDoubleTap(from: 0.995) == 2)
        #expect(PageStackLayout.zoomAfterDoubleTap(from: 2) == 1)
        #expect(PageStackLayout.zoomAfterDoubleTap(from: 0.5) == 1)
        #expect(PageStackLayout.zoomAfterDoubleTap(from: 3.4) == 1)
    }

    @Test func anAnchorStaysOnTheSameSpotOfPaperAcrossZooms() throws {
        let sizes = Array(repeating: PageSize.a4, count: 3)
        let fit = PageStackLayout(pageSizes: sizes, containerWidth: 800, zoom: 1, metrics: metrics)
        let zoomed = PageStackLayout(pageSizes: sizes, containerWidth: 800, zoom: 2, metrics: metrics)
        let spot = CGPoint(x: fit.pageFrames[1].midX, y: fit.pageFrames[1].minY + 100)

        let anchor = try #require(fit.anchor(at: spot))
        let roundTrip = try #require(fit.location(of: anchor))
        let location = try #require(zoomed.location(of: anchor))

        #expect(anchor.pageIndex == 1)
        #expect(isClose(roundTrip.x, spot.x) && isClose(roundTrip.y, spot.y))
        #expect(isClose(location.x, zoomed.pageFrames[1].midX))
        #expect(isClose(location.y, zoomed.pageFrames[1].minY + 200))
    }

    @Test func aSpotBetweenPagesAnchorsToTheNearestPage() throws {
        let layout = PageStackLayout(pageSizes: [.a4, .a4], containerWidth: 800, zoom: 1, metrics: metrics)
        let gap = CGPoint(x: 400, y: layout.pageFrames[1].minY - 5)

        let anchor = try #require(layout.anchor(at: gap))
        let location = try #require(layout.location(of: anchor))

        #expect(anchor.pageIndex == 1)
        #expect(isClose(location.y, gap.y))
        #expect(PageStackLayout(pageSizes: [], containerWidth: 800, zoom: 1).anchor(at: gap) == nil)
    }

    @Test func pagesWithinHalfAScreenOfTheVisibleAreaGetLiveCanvases() {
        let layout = PageStackLayout(
            pageSizes: Array(repeating: .a4, count: 10),
            containerWidth: 800,
            zoom: 1,
            metrics: metrics
        )
        let visible = CGRect(x: 0, y: layout.pageFrames[4].minY, width: 800, height: 600)

        #expect(layout.pagesNear(visible, limit: 4) == [3, 4])
    }

    @Test func visiblePagesKeepTheirCanvasesWhenMorePagesAreNearThanTheLimit() {
        let layout = PageStackLayout(
            pageSizes: Array(repeating: PageSize.a4.landscape, count: 12),
            containerWidth: 800,
            zoom: 1,
            metrics: metrics
        )
        let visible = CGRect(x: 0, y: layout.pageFrames[4].minY + 400, width: 800, height: 1300)

        #expect(layout.pagesNear(visible, limit: 4) == [4, 5, 6, 7])
    }

    @Test func theMostVisiblePageIgnoresTheNextPageOutline() {
        let layout = PageStackLayout(pageSizes: [.a4, .a4], containerWidth: 800, zoom: 1)
        let visible = CGRect(x: 0, y: layout.pageFrames[1].minY, width: 800, height: 600)

        #expect(layout.mostVisiblePage(in: visible, among: 2) == 1)
        #expect(layout.mostVisiblePage(in: visible, among: 1) == nil)
    }
}
