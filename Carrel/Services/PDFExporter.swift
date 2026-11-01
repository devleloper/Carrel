import NotebookDomain
import PencilKit
import UIKit

/// Exports a notebook as a PDF with paper and ink, one PDF page per notebook page.
enum PDFExporter {
    static func export(title: String, pages: [(Page, PKDrawing?)]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(fileName(for: title)).pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title]
        let firstSize = pages.first?.0.size ?? .a4
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: firstSize.width, height: firstSize.height),
            format: format
        )
        try renderer.writePDF(to: url) { context in
            for (page, drawing) in pages {
                let bounds = CGRect(x: 0, y: 0, width: page.size.width, height: page.size.height)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                PaperRenderer.draw(page.paper, pageSize: page.size, in: bounds, context: context.cgContext)
                if let drawing, !drawing.strokes.isEmpty {
                    EditorSession.render(drawing, size: page.size, scale: 3).draw(in: bounds)
                }
            }
        }
        return url
    }

    private static func fileName(for title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: forbidden).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? String(localized: "Notebook") : cleaned
    }
}
