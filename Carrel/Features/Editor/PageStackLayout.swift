import CoreGraphics
import NotebookDomain

/// Where each page sits in the editor's vertical stream. Pure geometry, so it is tested without UIKit.
///
/// At zoom 1 the widest page spans the container edge to edge, and only a strip of desk separates consecutive
/// pages. Below 1 the pages lie on the desk with their edges showing; above 1 they are wider than the container.
struct PageStackLayout: Equatable {
    struct Metrics: Equatable {
        /// Desk between consecutive pages, above the first and below the last, in points on screen at any zoom.
        var pageSpacing: CGFloat = 12
    }

    /// A spot on a page in page points, which stays on the same spot of paper when the zoom changes.
    struct Anchor: Equatable {
        var pageIndex: Int
        var point: CGPoint
    }

    /// The View menu's zoom commands.
    enum ZoomCommand: Equatable {
        case zoomIn
        case zoomOut
        case fitWidth
    }

    /// Zoom relative to the widest page fitting the container's width.
    static let zoomRange: ClosedRange<CGFloat> = 0.5...4
    static let doubleTapZoom: CGFloat = 2
    /// Where Zoom In and Zoom Out stop.
    static let zoomSteps: [CGFloat] = [0.5, 0.75, 1, 1.5, 2, 3, 4]

    let pageFrames: [CGRect]
    let contentSize: CGSize
    /// Points on screen per point of page.
    let scale: CGFloat
    private let containerWidth: CGFloat

    init(pageSizes: [PageSize], containerWidth: CGFloat, zoom: CGFloat, metrics: Metrics = Metrics()) {
        let widest = pageSizes.map { CGFloat($0.width) }.max() ?? CGFloat(PageSize.a4.width)
        let scale = max(containerWidth / widest, 0.1) * zoom

        // Fitting a page to the container divides by the page width, so the result can land a fraction of a point
        // past the container, which would make the content scroll sideways at fit-to-width.
        let sizes = pageSizes.map { pageSize in
            let width = CGFloat(pageSize.width) * scale
            return CGSize(
                width: abs(width - containerWidth) < 0.5 ? containerWidth : width,
                height: CGFloat(pageSize.height) * scale
            )
        }
        let contentWidth = max(containerWidth, sizes.map(\.width).max() ?? 0)
        var y = metrics.pageSpacing
        var frames: [CGRect] = []
        for size in sizes {
            frames.append(CGRect(x: (contentWidth - size.width) / 2, y: y, width: size.width, height: size.height))
            y += size.height + metrics.pageSpacing
        }
        self.scale = scale
        self.containerWidth = containerWidth
        pageFrames = frames
        contentSize = CGSize(width: contentWidth, height: y)
    }

    /// The zoom a pinch settles at. A pinch that ends close to fitting the width fits it exactly, since a few
    /// percent off would leave slivers of desk and a shadow, or a page that scrolls sideways by a few points.
    static func restingZoom(after zoom: CGFloat) -> CGFloat {
        let clamped = min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
        return fitsWidth(clamped) ? 1 : clamped
    }

    /// Double tap goes to `doubleTapZoom` from fitting the width, and back to fitting the width from any other zoom.
    static func zoomAfterDoubleTap(from zoom: CGFloat) -> CGFloat {
        fitsWidth(zoom) ? doubleTapZoom : 1
    }

    /// Zoom In and Zoom Out go to the next step, so a zoom left between steps by a pinch rounds to one.
    static func zoom(after command: ZoomCommand, from zoom: CGFloat) -> CGFloat {
        switch command {
        case .zoomIn: zoomSteps.first { $0 > zoom + 0.01 } ?? zoomRange.upperBound
        case .zoomOut: zoomSteps.last { $0 < zoom - 0.01 } ?? zoomRange.lowerBound
        case .fitWidth: 1
        }
    }

    private static func fitsWidth(_ zoom: CGFloat) -> Bool {
        abs(zoom - 1) < 0.05
    }

    /// Whether the desk shows beside the page, so it needs its edges and shadow to read as a sheet on the desk.
    func showsEdges(ofPageAt index: Int) -> Bool {
        pageFrames[index].width < containerWidth
    }

    /// The spot under `point` on the vertically nearest page, or `nil` when there are no pages.
    func anchor(at point: CGPoint) -> Anchor? {
        let distance = { (index: Int) in self.verticalDistance(from: point.y, toPageAt: index) }
        guard let index = pageFrames.indices.min(by: { distance($0) < distance($1) }) else {
            return nil
        }
        let frame = pageFrames[index]
        return Anchor(
            pageIndex: index,
            point: CGPoint(x: (point.x - frame.minX) / scale, y: (point.y - frame.minY) / scale)
        )
    }

    /// Where `anchor` lies in this layout.
    func location(of anchor: Anchor) -> CGPoint? {
        guard pageFrames.indices.contains(anchor.pageIndex) else {
            return nil
        }
        let frame = pageFrames[anchor.pageIndex]
        return CGPoint(x: frame.minX + anchor.point.x * scale, y: frame.minY + anchor.point.y * scale)
    }

    /// Pages within half a screen of `visibleRect`, which should hold a live canvas, in order.
    ///
    /// When more than `limit` pages are near, those closest to the middle of the screen win, so every visible
    /// page can be written on even when short landscape pages fill the screen.
    func pagesNear(_ visibleRect: CGRect, limit: Int) -> [Int] {
        let nearby = visibleRect.insetBy(dx: 0, dy: -visibleRect.height / 2)
        let middle = visibleRect.midY
        let distanceFromMiddle = { (index: Int) in self.verticalDistance(from: middle, toPageAt: index) }
        return pageFrames.indices
            .filter { pageFrames[$0].intersects(nearby) }
            .sorted { distanceFromMiddle($0) < distanceFromMiddle($1) }
            .prefix(limit)
            .sorted()
    }

    /// The page that takes up most of `visibleRect`, considering only the first `count` pages.
    func mostVisiblePage(in visibleRect: CGRect, among count: Int) -> Int? {
        pageFrames.prefix(count).indices
            .map { (index: $0, height: pageFrames[$0].intersection(visibleRect).height) }
            .filter { $0.height > 0 }
            .max { $0.height < $1.height }?
            .index
    }

    private func verticalDistance(from y: CGFloat, toPageAt index: Int) -> CGFloat {
        max(pageFrames[index].minY - y, y - pageFrames[index].maxY, 0)
    }
}
