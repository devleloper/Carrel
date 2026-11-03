import CoreGraphics
import Foundation
import ImageIO
import NotebookDomain

@testable import NotebookData

/// A fresh directory per test, removed by the caller with `defer`.
func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(
        path: "CarrelTests-\(UUID().uuidString)",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

extension InkData {
    static func sample(seed: UInt8, contentVersion: Int = 4) -> InkData {
        let payload = Data((0..<256).map { UInt8(truncatingIfNeeded: $0 &* Int(seed) &+ 7) })
        return InkData(payload: payload, requiredContentVersion: contentVersion)
    }
}

struct NotebookFixture {
    static let supportedContentVersion = 5

    let directory: URL
    let recoveredDirectory: URL
    let store: NotebookStore
    let pageID: Page.ID

    init() throws {
        directory = try makeTemporaryDirectory()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let notebook = Notebook(
            title: "Linear Algebra",
            cover: Cover(preset: .forestCloth),
            defaultPaper: .standard,
            defaultPageSize: .a4,
            sortKey: .initial,
            now: now
        )
        let page = Page(sortKey: .initial, size: .a4, paper: .standard, now: now)
        pageID = page.id
        recoveredDirectory = directory.appending(path: "Recovered", directoryHint: .isDirectory)
        store = try NotebookStore.create(
            notebook,
            firstPage: page,
            at: directory.appending(path: "\(notebook.id.uuidString).notebook", directoryHint: .isDirectory),
            supportedContentVersion: Self.supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    func reopen() throws -> NotebookStore {
        try NotebookStore.open(
            at: store.package.url,
            supportedContentVersion: Self.supportedContentVersion,
            recoveredDirectory: recoveredDirectory
        )
    }

    var inkFileExists: Bool {
        FileManager.default.fileExists(atPath: store.package.inkURL(for: pageID).path(percentEncoded: false))
    }

    /// Flips the last byte of the current ink file, which the envelope checksum detects.
    func damageInk() throws {
        let url = store.package.inkURL(for: pageID)
        var data = try Data(contentsOf: url)
        data[data.count - 1] ^= 0xFF
        try data.write(to: url)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

extension NotebookStore {
    /// Imports a test image of the given size and places it on a page. Different sizes give different assets.
    func placeTestImage(
        width: Int = 640,
        height: Int = 480,
        on pageID: Page.ID,
        now: Date = .now
    ) async throws -> ImagePlacement {
        let image = try await importImage(TestImage.png(width: width, height: height))
        let placement = ImagePlacement(assetID: image.assetID, frame: PageRect(x: 72, y: 96, width: 240, height: 180))
        try addImagePlacement(placement, toPage: pageID, now: now)
        return placement
    }
}

enum TestImageError: Error {
    case cannotDraw
    case cannotEncode
    case cannotRead
}

/// Images drawn with Core Graphics on the host, encoded the way a photo or a screenshot arrives.
enum TestImage {
    static func png(width: Int, height: Int) throws -> Data {
        try encode(draw(width: width, height: height), as: "public.png", properties: [:])
    }

    static func jpeg(width: Int, height: Int, orientation: Int) throws -> Data {
        try encode(
            draw(width: width, height: height),
            as: "public.jpeg",
            properties: [kCGImagePropertyOrientation: orientation]
        )
    }

    static func properties(of data: Data) throws -> (type: String, width: Int, height: Int) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let type = CGImageSourceGetType(source),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw TestImageError.cannotRead
        }
        return (type as String, width, height)
    }

    private static func draw(width: Int, height: Int) throws -> CGImage {
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw TestImageError.cannotDraw
        }
        context.setFillColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.2, green: 0.35, blue: 0.3, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 3))
        guard let image = context.makeImage() else {
            throw TestImageError.cannotDraw
        }
        return image
    }

    private static func encode(_ image: CGImage, as type: String, properties: [CFString: Any]) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type as CFString, 1, nil) else {
            throw TestImageError.cannotEncode
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw TestImageError.cannotEncode
        }
        return output as Data
    }
}
