import CoreGraphics
import NotebookDomain
import Testing

@testable import Carrel

@MainActor
struct PageStackLayoutTests {
    private let metrics = PageStackLayout.Metrics(pageSpacing: 20, horizontalMargin: 30)

    @Test func theWidestPageFitsTheContainerAtZoomOne() {
        let layout = PageStackLayout(pageSizes: [.a4, .a4], containerWidth: 800, zoom: 1, metrics: metrics)

        #expect(layout.pageFrames[0].width == 740)
        #expect(layout.pageFrames[0].minX == 30)
        #expect(layout.pageFrames[1].minY == layout.pageFrames[0].maxY + 20)
        #expect(layout.contentSize.width == 800)
    }

    @Test func zoomingWidensTheContentAndKeepsPagesCentered() {
        let layout = PageStackLayout(pageSizes: [.a4], containerWidth: 800, zoom: 2, metrics: metrics)

        #expect(layout.pageFrames[0].width == 1480)
        #expect(layout.contentSize.width == 1540)
        #expect(layout.pageFrames[0].midX == layout.contentSize.width / 2)
    }

    @Test func onlyPagesNearTheVisibleAreaGetLiveCanvases() {
        let layout = PageStackLayout(pageSizes: Array(repeating: .a4, count: 10), containerWidth: 800, zoom: 1)
        let visible = CGRect(x: 0, y: layout.pageFrames[4].minY, width: 800, height: 600)

        let live = layout.pagesNear(visible, limit: 4)

        #expect(live.contains(4))
        #expect(!live.contains(0))
        #expect(live.count <= 4)
    }

    @Test func theMostVisiblePageIgnoresTheNextPageOutline() {
        let layout = PageStackLayout(pageSizes: [.a4, .a4], containerWidth: 800, zoom: 1)
        let visible = CGRect(x: 0, y: layout.pageFrames[1].minY, width: 800, height: 600)

        #expect(layout.mostVisiblePage(in: visible, among: 2) == 1)
        #expect(layout.mostVisiblePage(in: visible, among: 1) == nil)
    }
}
