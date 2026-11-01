import CoreGraphics
import NotebookDomain

/// Where each page sits in the editor's vertical stream. Pure geometry, so it is tested without UIKit.
struct PageStackLayout: Equatable {
    struct Metrics: Equatable {
        var pageSpacing: CGFloat = 24
        var horizontalMargin: CGFloat = 28
    }

    let pageFrames: [CGRect]
    let contentSize: CGSize
    /// Points on screen per point of page; the widest page fits the container at zoom 1.
    let scale: CGFloat

    init(pageSizes: [PageSize], containerWidth: CGFloat, zoom: CGFloat, metrics: Metrics = Metrics()) {
        let widest = pageSizes.map { CGFloat($0.width) }.max() ?? CGFloat(PageSize.a4.width)
        let fitScale = max((containerWidth - metrics.horizontalMargin * 2) / widest, 0.1)
        scale = fitScale * zoom

        let sizes = pageSizes.map { CGSize(width: CGFloat($0.width) * scale, height: CGFloat($0.height) * scale) }
        let contentWidth = max(containerWidth, (sizes.map(\.width).max() ?? 0) + metrics.horizontalMargin * 2)
        var y = metrics.pageSpacing
        var frames: [CGRect] = []
        for size in sizes {
            frames.append(CGRect(x: (contentWidth - size.width) / 2, y: y, width: size.width, height: size.height))
            y += size.height + metrics.pageSpacing
        }
        pageFrames = frames
        contentSize = CGSize(width: contentWidth, height: y)
    }

    /// Pages within half a screen of `visibleRect`, which should hold a live canvas, at most `limit` of them.
    func pagesNear(_ visibleRect: CGRect, limit: Int) -> [Int] {
        let nearby = visibleRect.insetBy(dx: 0, dy: -visibleRect.height / 2)
        return Array(pageFrames.indices.filter { pageFrames[$0].intersects(nearby) }.prefix(limit))
    }

    /// The page that takes up most of `visibleRect`, considering only the first `count` pages.
    func mostVisiblePage(in visibleRect: CGRect, among count: Int) -> Int? {
        pageFrames.prefix(count).indices
            .map { (index: $0, height: pageFrames[$0].intersection(visibleRect).height) }
            .filter { $0.height > 0 }
            .max { $0.height < $1.height }?
            .index
    }
}
