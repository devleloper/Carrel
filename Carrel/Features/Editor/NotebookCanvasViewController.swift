import NotebookDomain
import PencilKit
import UIKit

/// The writing surface: pages stacked vertically in a zoomable scroll view.
///
/// Only pages near the visible area get a live `PKCanvasView`, which keeps memory flat for long notebooks.
/// A canvas belongs to one page for its whole life and is discarded when the page scrolls away, so undo can
/// never apply one page's history to another.
final class NotebookCanvasViewController: UIViewController {
    var onShowPalette: ((CGPoint) -> Void)?

    private let session: EditorSession
    private let palette: ToolPaletteModel
    private let scrollView = UIScrollView()
    private let documentView = UIView()
    private var pageViews: [PageView] = []
    private var displayedPages: [Page] = []
    private var layout: PageStackLayout?
    private var zoom: CGFloat = 1
    private var drawingPolicy: PKCanvasViewDrawingPolicy = .pencilOnly
    private var lastStrokePoint: CGPoint?

    private let maximumZoom: CGFloat = 4
    private let maximumLiveCanvases = 4

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
        addFingerTap(touches: 2, action: #selector(undoTapped))
        addFingerTap(touches: 3, action: #selector(redoTapped))

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = pencilHandler
        view.addInteraction(pencilInteraction)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate),
            name: UIScene.didActivateNotification,
            object: nil
        )
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
        let fingersOnly = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        // Delaying touches would add latency to the first point of every stroke.
        scrollView.delaysContentTouches = false
        scrollView.contentInsetAdjustmentBehavior = .always
        scrollView.panGestureRecognizer.allowedTouchTypes = fingersOnly
        scrollView.pinchGestureRecognizer?.allowedTouchTypes = fingersOnly
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)
        scrollView.addSubview(documentView)
        updateZoomLimits()
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

    func scroll(toPage pageID: Page.ID) {
        guard let pageView = pageViews.first(where: { $0.page?.id == pageID }) else {
            return
        }
        let frame = documentView.convert(pageView.frame, to: scrollView)
        let target = CGPoint(x: scrollView.contentOffset.x, y: frame.minY - PageStackLayout.Metrics().pageSpacing)
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
            zoom: zoom
        )
        for (pageView, frame) in zip(pageViews, layout.pageFrames) {
            pageView.frame = frame
            pageView.apply(scale: layout.scale)
        }
        documentView.frame = CGRect(origin: .zero, size: layout.contentSize)
        scrollView.contentSize = layout.contentSize
        self.layout = layout
        updateLiveCanvases()
    }

    private func updateZoomLimits() {
        scrollView.minimumZoomScale = 1 / zoom
        scrollView.maximumZoomScale = maximumZoom / zoom
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
            } else if !live.contains(index), pageView.canvas != nil {
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
                pageView.showUnavailable(message)
            }
            canvas.isLoadingInk = false
        }
    }

    private func discardCanvas(of pageView: PageView) {
        guard let canvas = pageView.canvas else {
            return
        }
        let scale = pageView.bounds.width / CGFloat(pageView.pageSize.width) * traitCollection.displayScale
        let image = pageView.page.flatMap { session.inkImage(for: $0, scale: scale) }
        canvas.delegate = nil
        undoManager?.removeAllActions(withTarget: canvas)
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

    /// The first stroke on the next-page outline makes it a real page.
    private func createPage(from canvas: PageCanvasView) {
        guard !canvas.isCreatingPage, !canvas.drawing.strokes.isEmpty else {
            return
        }
        canvas.isCreatingPage = true
        Task {
            defer { canvas.isCreatingPage = false }
            guard let page = try? await session.appendPage() else {
                return
            }
            canvas.pageID = page.id
            session.drawingDidChange(canvas.drawing, on: page.id)
        }
    }

    /// Without a hover position (the pencil is away from the screen) the palette opens where writing stopped.
    private func showPalette(near hoverLocation: CGPoint?) {
        let fallback = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        onShowPalette?(hoverLocation ?? lastStrokePoint ?? fallback)
    }

    // MARK: Input

    private func addFingerTap(touches: Int, action: Selector) {
        let tap = UITapGestureRecognizer(target: self, action: action)
        tap.numberOfTouchesRequired = touches
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        scrollView.addGestureRecognizer(tap)
    }

    /// Follows Settings › Apple Pencil › Only Draw with Apple Pencil. When fingers may draw, scrolling needs two.
    private func applyInputPolicy() {
        let pencilOnly = UIPencilInteraction.prefersPencilOnlyDrawing
        drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        scrollView.panGestureRecognizer.minimumNumberOfTouches = pencilOnly ? 1 : 2
        for canvas in liveCanvases {
            canvas.drawingPolicy = drawingPolicy
        }
    }

    @objc private func sceneDidActivate() {
        applyInputPolicy()
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
}

extension NotebookCanvasViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        documentView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateLiveCanvases()
    }

    /// Converts the pinch into a new page scale and lays the pages out again, so ink is re-rendered sharply
    /// instead of staying a scaled bitmap.
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        let previousZoom = zoom
        let visibleCenter = CGPoint(
            x: (scrollView.contentOffset.x + scrollView.bounds.width / 2) / scale,
            y: (scrollView.contentOffset.y + scrollView.bounds.height / 2) / scale
        )
        zoom = min(max(zoom * scale, 1), maximumZoom)
        scrollView.zoomScale = 1
        updateZoomLimits()
        layoutPages()

        let factor = zoom / previousZoom
        scrollView.contentOffset = clampedOffset(
            CGPoint(
                x: visibleCenter.x * factor - scrollView.bounds.width / 2,
                y: visibleCenter.y * factor - scrollView.bounds.height / 2
            )
        )
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
