import NotebookDomain
import PencilKit
import UIKit

/// Exports a notebook as a PDF with paper and ink, one PDF page per notebook page.
enum PDFExporter {
    struct Content {
        let page: Page
        let drawing: PKDrawing?
    }

    static func export(title: String, pages: [Content]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(fileName(for: title)).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title]
        let firstSize = pages.first?.page.size ?? .a4
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: firstSize.width, height: firstSize.height),
            format: format
        )
        try renderer.writePDF(to: url) { context in
            for content in pages {
                let size = content.page.size
                let bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                PaperRenderer.draw(content.page.paper, pageSize: size, in: bounds, context: context.cgContext)
                if let drawing = content.drawing, !drawing.strokes.isEmpty {
                    // Ink is rasterized at three times the page resolution: sharp in print, small on disk.
                    InkRenderer.image(of: drawing, on: content.page, scale: 3).draw(in: bounds)
                }
            }
        }
        return url
    }

    private static func fileName(for title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: forbidden)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? String(localized: "Notebook") : cleaned
    }
}
