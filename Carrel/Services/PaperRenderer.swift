import NotebookDomain
import UIKit

/// Draws paper rulings. Used by the editor, thumbnails and PDF export so every surface shows the same page.
enum PaperRenderer {
    private static let millimeter: CGFloat = 72 / 25.4
    private static let topMargin = 25 * millimeter
    private static let marginLineX = 25 * millimeter

    struct ToneColors {
        let background: UIColor
        let ruleLine: UIColor
        let marginLine: UIColor

        init(background: UInt32, ruleLine: UInt32, marginLine: UInt32) {
            self.background = UIColor(hex: background)
            self.ruleLine = UIColor(hex: ruleLine)
            self.marginLine = UIColor(hex: marginLine)
        }
    }

    static func colors(for tone: PaperTone) -> ToneColors {
        switch tone {
        case .white:
            ToneColors(background: 0xFCFCFA, ruleLine: 0xD5DCE6, marginLine: 0xEDC1B3)
        case .cream:
            ToneColors(background: 0xF6EEDC, ruleLine: 0xDCCFB5, marginLine: 0xE9B79E)
        case .linen:
            ToneColors(background: 0xECE8E0, ruleLine: 0xD3CCBF, marginLine: 0xE2B3A1)
        case .night:
            ToneColors(background: 0x22211F, ruleLine: 0x3A3835, marginLine: 0x5B3931)
        }
    }

    /// Draws `paper` for a page of `pageSize` into `rect`, scaling the rulings with the page.
    static func draw(_ paper: Paper, pageSize: PageSize, in rect: CGRect, context: CGContext) {
        let colors = colors(for: paper.tone)
        let scale = rect.width / CGFloat(pageSize.width)
        context.saveGState()
        defer { context.restoreGState() }

        context.setFillColor(colors.background.cgColor)
        context.fill(rect)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: scale, y: scale)

        let width = CGFloat(pageSize.width)
        let height = CGFloat(pageSize.height)
        context.setLineWidth(0.5)
        context.setStrokeColor(colors.ruleLine.cgColor)

        switch paper.style {
        case .blank:
            break
        case .ruledNarrow, .ruledWithMargin:
            drawRules(spacing: 7 * millimeter, width: width, height: height, context: context)
        case .ruledWide:
            drawRules(spacing: 9 * millimeter, width: width, height: height, context: context)
        case .grid:
            let spacing = 5 * millimeter
            for x in stride(from: spacing, to: width, by: spacing) {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: height))
            }
            for y in stride(from: spacing, to: height, by: spacing) {
                context.move(to: CGPoint(x: 0, y: y))
                context.addLine(to: CGPoint(x: width, y: y))
            }
            context.strokePath()
        case .dots:
            let spacing = 5 * millimeter
            let radius: CGFloat = 0.7
            context.setFillColor(colors.ruleLine.cgColor)
            for x in stride(from: spacing, to: width, by: spacing) {
                for y in stride(from: spacing, to: height, by: spacing) {
                    let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fillEllipse(in: dot)
                }
            }
        }

        if paper.style == .ruledWithMargin {
            context.setStrokeColor(colors.marginLine.cgColor)
            context.setLineWidth(0.75)
            context.move(to: CGPoint(x: marginLineX, y: 0))
            context.addLine(to: CGPoint(x: marginLineX, y: height))
            context.strokePath()
        }
    }

    private static func drawRules(spacing: CGFloat, width: CGFloat, height: CGFloat, context: CGContext) {
        for y in stride(from: topMargin, to: height - spacing, by: spacing) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: width, y: y))
        }
        context.strokePath()
    }
}
