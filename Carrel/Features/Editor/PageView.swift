import NotebookDomain
import PencilKit
import UIKit

/// A canvas bound to one page for its whole life; `pageID` is `nil` only while it sits on the next-page outline.
final class PageCanvasView: PKCanvasView {
    var pageID: Page.ID?
    var isLoadingInk = false
    var isCreatingPage = false

    /// Shows the page at `scale` while keeping drawing coordinates in page points, independent of the device.
    func fit(_ pageSize: PageSize, scale: CGFloat) {
        minimumZoomScale = scale
        maximumZoomScale = scale
        zoomScale = scale
        contentSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        contentOffset = .zero
    }
}

/// One page slot in the editor: paper, a cached image of the ink, and a live canvas while the page is near the
/// visible area.
final class PageView: UIView {
    var page: Page? {
        didSet {
            if oldValue?.paper != page?.paper || oldValue?.size != page?.size {
                paperView.setNeedsDisplay()
            }
            updateOutline()
        }
    }
    /// Paper and size the next-page outline previews.
    var outlinePaper = Paper.standard
    var outlineSize = PageSize.a4

    private(set) var canvas: PageCanvasView?
    private let paperView = PaperView()
    private let inkImageView = UIImageView()
    private let unavailableLabel = UILabel()
    private let outlineLayer = CAShapeLayer()
    private var scale: CGFloat = 1

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
        outlineLayer.strokeColor = UIColor(light: 0x65584B, dark: 0xABA092).cgColor
        outlineLayer.lineDashPattern = [6, 6]
        outlineLayer.lineWidth = 1
        layer.addSublayer(outlineLayer)

        layer.shadowColor = UIColor(hex: 0x3B2A1A).cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
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
        outlineLayer.path = UIBezierPath(rect: bounds).cgPath
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
        canvas.overrideUserInterfaceStyle = paper.tone == .night ? .dark : .light
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

    /// The next-page outline is a dashed, faded page; the first stroke turns it into a real page without moving it.
    private func updateOutline() {
        let isOutline = page == nil && canvas?.pageID == nil
        outlineLayer.isHidden = !isOutline
        paperView.alpha = isOutline ? 0.45 : 1
        layer.shadowOpacity = isOutline ? 0 : 0.12
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
