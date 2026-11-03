import NotebookDomain
import PencilKit
import Testing
import UIKit

@testable import Carrel

@MainActor
struct PaperAppearanceTests {
    private func page(on tone: PaperTone) -> Page {
        Page(sortKey: .initial, size: .a4, paper: Paper(style: .blank, tone: tone), now: .now)
    }

    /// A black stroke across the top of the page, wide enough that the sampled pixel is fully covered.
    private var blackStroke: PKDrawing {
        let points = [CGPoint(x: 20, y: 40), CGPoint(x: 200, y: 40)].map {
            PKStrokePoint(
                location: $0,
                timeOffset: 0,
                size: CGSize(width: 12, height: 12),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        let stroke = PKStroke(
            ink: PKInk(.monoline, color: .black),
            path: PKStrokePath(controlPoints: points, creationDate: .now),
            transform: .identity,
            mask: nil
        )
        return PKDrawing(strokes: [stroke])
    }

    /// The brightest channel of the pixel at `point` of an image rendered at scale 1.
    private func brightness(of image: UIImage, at point: CGPoint) throws -> UInt8 {
        let cgImage = try #require(image.cgImage)
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try #require(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        let origin = CGPoint(x: -point.x, y: point.y + 1 - CGFloat(cgImage.height))
        context.draw(cgImage, in: CGRect(origin: origin, size: CGSize(width: cgImage.width, height: cgImage.height)))
        return pixel[0..<3].max() ?? 0
    }

    @Test func onlyNightPaperShowsInkInTheDarkAppearance() {
        let appearances = PaperTone.allCases.map(\.inkAppearance)

        #expect(appearances == [.light, .light, .light, .dark])
    }

    @Test func aCanvasFollowsThePaperOfItsPageWhateverTheAppTheme() {
        let screen = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        screen.overrideUserInterfaceStyle = .dark
        let pageView = PageView(frame: screen.bounds)
        screen.addSubview(pageView)
        pageView.page = page(on: .cream)
        let canvas = PageCanvasView()
        pageView.attach(canvas)
        pageView.updateTraitsIfNeeded()

        #expect(canvas.traitCollection.userInterfaceStyle == .light)

        pageView.page = page(on: .night)
        // Outside a window nothing runs the layout pass that would carry the new traits to the subviews.
        pageView.updateTraitsIfNeeded()

        #expect(canvas.traitCollection.userInterfaceStyle == .dark)
    }

    @Test func theNextPageOutlineTakesTheAppearanceOfItsPaper() {
        let outline = PageView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))

        outline.outlinePaper = Paper(style: .blank, tone: .night)

        #expect(outline.overrideUserInterfaceStyle == .dark)
        // The dashed outline is the edge of a page that does not exist yet.
        #expect(outline.layer.borderWidth == 0)
    }

    @Test func onlyAPageOnNightPaperHasALightEdge() {
        let pageView = PageView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))

        pageView.page = page(on: .night)
        #expect(pageView.layer.borderWidth == 1)

        pageView.page = page(on: .linen)
        #expect(pageView.layer.borderWidth == 0)
    }

    @Test func aCachedInkImageIsDroppedWhenThePaperChangesAppearance() throws {
        let pageView = PageView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        pageView.page = page(on: .cream)
        pageView.attach(PageCanvasView())
        let inkImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        pageView.detachCanvas(leaving: inkImage)
        let inkImageView = try #require(pageView.subviews.compactMap { $0 as? UIImageView }.first)

        pageView.page = page(on: .linen)
        #expect(inkImageView.image != nil, "Linen shows ink in the same appearance as Cream")

        pageView.page = page(on: .night)
        #expect(inkImageView.image == nil)
    }

    @Test func inkImagesMatchTheCanvasOfTheirPaper() throws {
        let stroke = blackStroke
        let onWhite = InkRenderer.image(of: stroke, on: page(on: .white), scale: 1)
        let onNight = InkRenderer.image(of: stroke, on: page(on: .night), scale: 1)

        #expect(try brightness(of: onWhite, at: CGPoint(x: 100, y: 40)) < 80)
        #expect(try brightness(of: onNight, at: CGPoint(x: 100, y: 40)) > 170)
    }
}
