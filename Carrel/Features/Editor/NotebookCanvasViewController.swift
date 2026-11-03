import NotebookDomain
import PencilKit
import UIKit

/// The writing surface: pages stacked vertically in a zoomable scroll view.
///
/// Only pages near the visible area get a live `PKCanvasView`, which keeps memory flat for long notebooks.
/// A canvas belongs to one page for its whole life and is discarded when the page scrolls away, so undo can
/// never apply one page's history to another.
final class NotebookCanvasViewController: UIViewController {
    var onShowPalette: ((CGPoint?) -> Void)?

    /// Height of the editor's top bar below the system safe area. Pages scroll under the bar, so it is an inset of
    /// the content rather than of the view.
    var topBarHeight: CGFloat = 0 {
        didSet {
            if topBarHeight != oldValue {
                updateTopInset()
            }
        }
    }

    private let session: EditorSession
    private let palette: ToolPaletteModel
    private let scrollView = UIScrollView()
    private let documentView = UIView()
    private var pageViews: [PageView] = []
    private var displayedPages: [Page] = []
    private var layout: PageStackLayout?
    /// Relative to fitting the widest page to the window's width, within `PageStackLayout.zoomRange`.
    private var zoom: CGFloat = 1
    private var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly
    private var lastStrokePoint: CGPoint?
    private let zoomTap = UITapGestureRecognizer()

    private let maximumLiveCanvases = 4
    private let layoutMetrics = PageStackLayout.Metrics()
    private static let directTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

    // Canvases get a delegate that implements no scroll-view callbacks, so PencilKit keeps full control of its
    // own zooming and scrolling.
    private lazy var inkObserver = InkObserver { [weak self] canvas in
        self?.canvasDrawingDidChange(canvas)
    }
    private lazy var pencilHandler = PencilInteractionHandler(palette: palette) { [weak self] hoverLocation in
        self?.showPalette(near: hoverLocation)
    }

    init(session: EditorSession, palette: ToolPaletteModel) {
        self.session = session
        self.palette = palette
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// PencilKit registers undo with the nearest undo manager in the responder chain; one per notebook keeps
    /// the history scoped to the notebook being edited.
    override var undoManager: UndoManager? {
        session.undoManager
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        configureScrollView()
        addFingerTap(UITapGestureRecognizer(), touches: 2, action: #selector(undoTapped))
        addFingerTap(UITapGestureRecognizer(), touches: 3, action: #selector(redoTapped))
        addFingerTap(zoomTap, touches: 1, taps: 2, action: #selector(zoomTapped))

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = pencilHandler
        view.addInteraction(pencilInteraction)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate),
            name: UIScene.didActivateNotification,
            object: nil
        )
        // PencilKit closes an undo group after the stroke's change reaches the delegate, so the history is read
        // from the undo manager's own notifications rather than from drawing changes.
        let undoHistoryChanges: [Notification.Name] = [
            .NSUndoManagerCheckpoint,
            .NSUndoManagerDidCloseUndoGroup,
            .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
        ]
        for name in undoHistoryChanges {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(undoHistoryDidChange),
                name: name,
                object: session.undoManager
            )
        }
        applyInputPolicy()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPages()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        pageViews.forEach { $0.releaseInkImage() }
    }

    private func configureScrollView() {
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        // Delaying touches would add latency to the first point of every stroke.
        scrollView.delaysContentTouches = false
        scrollView.contentInsetAdjustmentBehavior = .always
        // Pages scroll under the top bar. The bar is a SwiftUI safe area bar, which registers itself with this
        // scroll view's edge effect; the soft style fades handwriting out progressively under the bar's controls.
        scrollView.topEdgeEffect.style = .soft
        scrollView.panGestureRecognizer.allowedTouchTypes = Self.directTouchTypes
        scrollView.pinchGestureRecognizer?.allowedTouchTypes = Self.directTouchTypes
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.accessibilityIdentifier = "pages"
        view.addSubview(scrollView)
        scrollView.addSubview(documentView)
        zoomDidChange()
    }

    // MARK: Updates from SwiftUI

    func show(_ pages: [Page]) {
        guard pages != displayedPages else {
            return
        }
        displayedPages = pages

        var existing: [Page.ID: PageView] = [:]
        var outline: PageView?
        for pageView in pageViews {
            if let id = pageView.page?.id ?? pageView.canvas?.pageID {
                existing[id] = pageView
            } else {
                outline = pageView
            }
        }

        var updated: [PageView] = []
        for page in pages {
            let pageView = existing.removeValue(forKey: page.id) ?? makePageView()
            let wasOutline = pageView.page == nil
            pageView.page = page
            if wasOutline {
                pageView.pageDidMaterialize()
            }
            updated.append(pageView)
        }
        for removed in existing.values {
            discardCanvas(of: removed)
            removed.removeFromSuperview()
        }

        let outlineView = outline ?? makePageView()
        outlineView.page = nil
        outlineView.outlinePaper = pages.last?.paper ?? session.notebook.defaultPaper
        outlineView.outlineSize = pages.last?.size ?? session.notebook.defaultPageSize
        updated.append(outlineView)

        pageViews = updated
        layoutPages()
    }

    func apply(tool: any PKTool, isRulerActive: Bool) {
        for canvas in liveCanvases {
            canvas.tool = tool
            canvas.isRulerActive = isRulerActive
        }
    }

    /// Zooms as the View menu asks, keeping the spot of paper at the centre of the screen in place.
    func perform(_ command: PageStackLayout.ZoomCommand) {
        let target = PageStackLayout.zoom(after: command, from: zoom)
        guard target != zoom else {
            return
        }
        let viewportCenter = CGPoint(x: scrollView.bounds.width / 2, y: scrollView.bounds.height / 2)
        let centerInDocument = documentView.convert(
            CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY),
            from: scrollView
        )
        zoom(to: target, keeping: centerInDocument, at: viewportCenter)
    }

    func scroll(toPage pageID: Page.ID) {
        guard let pageView = pageViews.first(where: { $0.page?.id == pageID }) else {
            return
        }
        let frame = documentView.convert(pageView.frame, to: scrollView)
        let target = CGPoint(
            x: scrollView.contentOffset.x,
            y: frame.minY - layoutMetrics.pageSpacing - scrollView.adjustedContentInset.top
        )
        scrollView.setContentOffset(clampedOffset(target), animated: true)
    }

    // MARK: Layout

    private var liveCanvases: [PageCanvasView] {
        pageViews.compactMap(\.canvas)
    }

    private func makePageView() -> PageView {
        let pageView = PageView()
        documentView.addSubview(pageView)
        return pageView
    }

    private func layoutPages() {
        // While a pinch is in progress the document is scaled by a transform; layout resumes when it ends.
        guard scrollView.zoomScale == 1, view.bounds.width > 0 else {
            return
        }
        let layout = PageStackLayout(
            pageSizes: pageViews.map(\.pageSize),
            containerWidth: view.bounds.width,
            zoom: zoom,
            metrics: layoutMetrics
        )
        for (index, pageView) in pageViews.enumerated() {
            pageView.frame = layout.pageFrames[index]
            pageView.showsEdges = layout.showsEdges(ofPageAt: index)
            pageView.apply(scale: layout.scale)
        }
        documentView.frame = CGRect(origin: .zero, size: layout.contentSize)
        scrollView.contentSize = layout.contentSize
        self.layout = layout
        updateLiveCanvases()
    }

    private func zoomDidChange() {
        scrollView.minimumZoomScale = PageStackLayout.zoomRange.lowerBound / zoom
        scrollView.maximumZoomScale = PageStackLayout.zoomRange.upperBound / zoom
        scrollView.accessibilityValue = Double(zoom).formatted(.percent.precision(.fractionLength(0)))
    }

    /// Lays the pages out at `newZoom`, a sharp re-render instead of a scaled bitmap, and scrolls so that
    /// `anchor` sits at `viewportPoint`, a point in the scroll view's frame.
    private func setZoom(_ newZoom: CGFloat, keeping anchor: PageStackLayout.Anchor?, at viewportPoint: CGPoint) {
        zoom = PageStackLayout.restingZoom(after: newZoom)
        scrollView.zoomScale = 1
        zoomDidChange()
        layoutPages()
        guard let anchor, let location = layout?.location(of: anchor) else {
            return
        }
        scrollView.contentOffset = clampedOffset(
            CGPoint(x: location.x - viewportPoint.x, y: location.y - viewportPoint.y)
        )
    }

    /// The bar's height arrives after the first layout; a notebook resting at its top stays there, so the first
    /// page starts below the bar instead of under it.
    private func updateTopInset() {
        let wasAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top
        scrollView.contentInset.top = topBarHeight
        scrollView.verticalScrollIndicatorInsets.top = topBarHeight
        if wasAtTop {
            scrollView.contentOffset.y = -scrollView.adjustedContentInset.top
        }
    }

    private func clampedOffset(_ offset: CGPoint) -> CGPoint {
        let insets = scrollView.adjustedContentInset
        let maximumX = max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        let maximumY = max(scrollView.contentSize.height - scrollView.bounds.height + insets.bottom, -insets.top)
        return CGPoint(
            x: min(max(offset.x, 0), maximumX),
            y: min(max(offset.y, -insets.top), maximumY)
        )
    }

    // MARK: Live canvases

    private func updateLiveCanvases() {
        guard let layout else {
            return
        }
        let visible = documentView.convert(scrollView.bounds, from: scrollView)
        let live = Set(layout.pagesNear(visible, limit: maximumLiveCanvases))
        for (index, pageView) in pageViews.enumerated() {
            if live.contains(index), pageView.canvas == nil {
                attachCanvas(to: pageView)
            } else if !live.contains(index), let canvas = pageView.canvas, !canvas.holdsInkWithoutPage {
                discardCanvas(of: pageView)
            }
        }
        let current = layout.mostVisiblePage(in: visible, among: displayedPages.count) ?? 0
        if session.currentPageIndex != current {
            session.currentPageIndex = current
        }
    }

    private func attachCanvas(to pageView: PageView) {
        let canvas = PageCanvasView()
        canvas.pageID = pageView.page?.id
        canvas.delegate = inkObserver
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.drawingPolicy = drawingPolicy
        canvas.maximumSupportedContentVersion = InkCodec.maximumContentVersion
        canvas.tool = palette.currentTool
        canvas.isRulerActive = palette.isRulerActive
        pageView.attach(canvas)
        if let pageID = canvas.pageID {
            loadInk(of: pageID, into: canvas, on: pageView)
        }
    }

    private func loadInk(of pageID: Page.ID, into canvas: PageCanvasView, on pageView: PageView) {
        canvas.isLoadingInk = true
        canvas.isDrawingEnabled = false
        Task {
            let ink = await session.ink(for: pageID)
            guard canvas.pageID == pageID, canvas.superview != nil else {
                return
            }
            switch ink {
            case .editable(let drawing):
                canvas.drawing = drawing
                canvas.isDrawingEnabled = true
            case .readOnly(let message):
                // Drawing stays disabled, so ink this system cannot read is never overwritten.
                pageView.showUnavailable(message)
            }
            canvas.isLoadingInk = false
        }
    }

    private func discardCanvas(of pageView: PageView) {
        guard let canvas = pageView.canvas else {
            return
        }
        let scale = pageView.scale * traitCollection.displayScale
        let image = pageView.page.flatMap { session.inkImage(for: $0, scale: scale) }
        canvas.delegate = nil
        undoManager?.removeAllActions(withTarget: canvas)
        session.undoHistoryDidChange()
        pageView.detachCanvas(leaving: image)
    }

    private func canvasDrawingDidChange(_ canvas: PageCanvasView) {
        guard !canvas.isLoadingInk else {
            return
        }
        if let lastStroke = canvas.drawing.strokes.last {
            let bounds = lastStroke.renderBounds
            let point = CGPoint(x: bounds.maxX * canvas.zoomScale, y: bounds.maxY * canvas.zoomScale)
            lastStrokePoint = canvas.convert(point, to: view)
        }
        if let pageID = canvas.pageID {
            session.drawingDidChange(canvas.drawing, on: pageID)
        } else {
            createPage(from: canvas)
        }
    }

    /// The first stroke on the next-page outline makes it a real page. If that fails, the session shows the
    /// error and the strokes stay on the outline; the next stroke tries again.
    private func createPage(from canvas: PageCanvasView) {
        guard !canvas.isCreatingPage, !canvas.drawing.strokes.isEmpty else {
            return
        }
        canvas.isCreatingPage = true
        Task {
            defer { canvas.isCreatingPage = false }
            guard let page = await session.appendPage() else {
                return
            }
            canvas.pageID = page.id
            session.drawingDidChange(canvas.drawing, on: page.id)
        }
    }

    /// Without a hover position (the pencil is away from the screen) the palette opens where writing stopped.
    /// Before the first stroke there is no such point, and the palette opens beside the main palette.
    private func showPalette(near hoverLocation: CGPoint?) {
        onShowPalette?(hoverLocation ?? lastStrokePoint)
    }

    // MARK: Input

    private func addFingerTap(_ tap: UITapGestureRecognizer, touches: Int, taps: Int = 1, action: Selector) {
        tap.addTarget(self, action: action)
        tap.numberOfTouchesRequired = touches
        tap.numberOfTapsRequired = taps
        tap.allowedTouchTypes = Self.directTouchTypes
        scrollView.addGestureRecognizer(tap)
    }

    /// Follows Settings › Apple Pencil › Only Draw with Apple Pencil. When fingers may draw, scrolling needs two
    /// and there is no double tap to zoom, which would be indistinguishable from two dots.
    private func applyInputPolicy() {
        let pencilOnly = UIPencilInteraction.prefersPencilOnlyDrawing
        drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        scrollView.panGestureRecognizer.minimumNumberOfTouches = pencilOnly ? 1 : 2
        zoomTap.isEnabled = pencilOnly
        for canvas in liveCanvases {
            canvas.drawingPolicy = drawingPolicy
        }
    }

    @objc private func sceneDidActivate() {
        applyInputPolicy()
    }

    @objc private func undoHistoryDidChange() {
        session.undoHistoryDidChange()
    }

    @objc private func undoTapped() {
        if session.undoManager.canUndo {
            session.undoManager.undo()
        }
    }

    @objc private func redoTapped() {
        if session.undoManager.canRedo {
            session.undoManager.redo()
        }
    }

    /// Switches between fitting the width and `PageStackLayout.doubleTapZoom`, keeping the tapped spot under the
    /// finger.
    @objc private func zoomTapped(_ tap: UITapGestureRecognizer) {
        zoom(
            to: PageStackLayout.zoomAfterDoubleTap(from: zoom),
            keeping: tap.location(in: documentView),
            at: tap.location(in: view)
        )
    }

    /// Zooms so that `documentPoint`, a point in the document, ends up at `viewportPoint`; animated unless Reduce
    /// Motion is on.
    private func zoom(to target: CGFloat, keeping documentPoint: CGPoint, at viewportPoint: CGPoint) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            setZoom(target, keeping: layout?.anchor(at: documentPoint), at: viewportPoint)
            return
        }
        // The animated zoom ends in scrollViewDidEndZooming, which lays the pages out sharply at the new zoom.
        let scale = target / zoom
        let visibleRect = CGRect(
            x: documentPoint.x - viewportPoint.x / scale,
            y: documentPoint.y - viewportPoint.y / scale,
            width: scrollView.bounds.width / scale,
            height: scrollView.bounds.height / scale
        )
        scrollView.zoom(to: visibleRect, animated: true)
    }
}

extension NotebookCanvasViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        documentView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateLiveCanvases()
    }

    /// Below fit-to-width the scaled document is narrower than the scroll view, which would pin it to the leading
    /// edge for the rest of the pinch.
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let margin = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        documentView.center.x = scrollView.contentSize.width / 2 + margin
    }

    /// Converts the pinch into a new page scale and lays the pages out again, so ink is re-rendered sharply
    /// instead of staying a scaled bitmap.
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        let viewportCenter = CGPoint(x: scrollView.bounds.width / 2, y: scrollView.bounds.height / 2)
        let centerInDocument = documentView.convert(
            CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY),
            from: scrollView
        )
        setZoom(zoom * scale, keeping: layout?.anchor(at: centerInDocument), at: viewportCenter)
    }
}

private final class InkObserver: NSObject, PKCanvasViewDelegate {
    private let onChange: (PageCanvasView) -> Void

    init(onChange: @escaping (PageCanvasView) -> Void) {
        self.onChange = onChange
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if let canvas = canvasView as? PageCanvasView {
            onChange(canvas)
        }
    }
}
