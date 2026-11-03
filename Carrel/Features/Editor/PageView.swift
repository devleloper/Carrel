import NotebookDomain
import PencilKit
import UIKit

/// A canvas bound to one page for its whole life; `pageID` is `nil` only while it sits on the next-page outline.
final class PageCanvasView: PKCanvasView {
    var pageID: Page.ID?
    var isLoadingInk = false
    var isCreatingPage = false

    /// Strokes on the next-page outline before their page exists; discarding the canvas would lose them.
    var holdsInkWithoutPage: Bool {
        pageID == nil && !drawing.strokes.isEmpty
    }

    /// Shows the page at `scale` while keeping drawing coordinates in page points, independent of the device.
    func fit(_ pageSize: PageSize, scale: CGFloat) {
        minimumZoomScale = scale
        maximumZoomScale = scale
        zoomScale = scale
        contentSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        contentOffset = .zero
    }
}

/// One page slot in the editor: paper, a cached image of the ink, and a live canvas while the page is near
/// the visible area.
final class PageView: UIView {
    var page: Page? {
        didSet {
            if oldValue?.paper != page?.paper || oldValue?.size != page?.size {
                paperDidChange()
            }
            updateOutline()
        }
    }
    /// Paper and size the next-page outline previews.
    var outlinePaper = Paper.standard {
        didSet {
            if page == nil, outlinePaper != oldValue {
                paperDidChange()
            }
        }
    }
    var outlineSize = PageSize.a4
    /// Whether the desk shows beside the page. A page that spans the window has no shadow: it would only fall on
    /// the strip of desk between pages and read as a border.
    var showsEdges = true {
        didSet {
            if oldValue != showsEdges {
                updateOutline()
            }
        }
    }

    private(set) var canvas: PageCanvasView?
    /// Points on screen per point of page.
    private(set) var scale: CGFloat = 1
    private let paperView = PaperView()
    private let inkImageView = UIImageView()
    private let unavailableLabel = UILabel()
    private let outlineLayer = CAShapeLayer()

    var paper: Paper {
        page?.paper ?? outlinePaper
    }

    var pageSize: PageSize {
        page?.size ?? outlineSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        paperView.owner = self
        addSubview(paperView)
        inkImageView.contentMode = .scaleToFill
        addSubview(inkImageView)
        unavailableLabel.font = .preferredFont(forTextStyle: .footnote)
        unavailableLabel.textColor = .secondaryLabel
        unavailableLabel.textAlignment = .center
        unavailableLabel.numberOfLines = 0
        unavailableLabel.isHidden = true
        addSubview(unavailableLabel)

        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = Palette.secondaryText.cgColor
        outlineLayer.lineDashPattern = [6, 6]
        outlineLayer.lineWidth = 1
        layer.addSublayer(outlineLayer)

        layer.shadowColor = Palette.pageShadow.cgColor
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        overrideUserInterfaceStyle = paper.tone.inkAppearance
        updateOutline()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        paperView.frame = bounds
        inkImageView.frame = bounds
        unavailableLabel.frame = bounds.insetBy(dx: 32, dy: 32)
        canvas?.frame = bounds
        outlineLayer.frame = bounds
        // Inset by half the line width, so the dashes stay whole when the outline spans the window.
        outlineLayer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }

    func apply(scale: CGFloat) {
        self.scale = scale
        canvas?.fit(pageSize, scale: scale)
    }

    func attach(_ canvas: PageCanvasView) {
        self.canvas = canvas
        canvas.frame = bounds
        canvas.fit(pageSize, scale: scale)
        addSubview(canvas)
        inkImageView.isHidden = true
    }

    func detachCanvas(leaving inkImage: UIImage?) {
        canvas?.removeFromSuperview()
        canvas = nil
        inkImageView.image = inkImage
        inkImageView.isHidden = false
    }

    func showUnavailable(_ message: String) {
        unavailableLabel.text = message
        unavailableLabel.isHidden = false
    }

    func releaseInkImage() {
        if canvas == nil {
            inkImageView.image = nil
        }
    }

    /// The page, its canvas and its labels take the paper's appearance, so PencilKit shows ink converted for
    /// dark paper and keeps it as written on light paper, whatever the app's theme.
    private func paperDidChange() {
        paperView.setNeedsDisplay()
        let appearance = paper.tone.inkAppearance
        guard appearance != overrideUserInterfaceStyle else {
            return
        }
        overrideUserInterfaceStyle = appearance
        // The cached image shows the ink in the other appearance. Only pages away from the visible area keep
        // one, and the canvas they get when they come near renders the ink again.
        releaseInkImage()
    }

    /// The next-page outline is a dashed, faded page; the first stroke turns it into a real page without moving it.
    private func updateOutline() {
        let isOutline = page == nil && canvas?.pageID == nil
        outlineLayer.isHidden = !isOutline
        paperView.alpha = isOutline ? 0.45 : 1
        layer.shadowOpacity = isOutline || !showsEdges ? 0 : Float(Theme.Elevation.page)
        let edge = isOutline ? nil : paper.tone.edge
        layer.borderColor = edge?.cgColor
        layer.borderWidth = edge == nil ? 0 : 1
    }

    func pageDidMaterialize() {
        UIView.animate(withDuration: 0.3) {
            self.updateOutline()
        }
    }
}

/// Draws the paper of its owner page with the shared renderer.
private final class PaperView: UIView {
    weak var owner: PageView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let owner, let context = UIGraphicsGetCurrentContext() else {
            return
        }
        PaperRenderer.draw(owner.paper, pageSize: owner.pageSize, in: bounds, context: context)
    }
}
