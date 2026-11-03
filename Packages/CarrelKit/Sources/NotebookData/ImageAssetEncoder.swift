import Foundation
import ImageIO

/// An image as it is stored in a notebook's `assets` folder.
struct EncodedImage {
    let heic: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

/// Turns an image in any format ImageIO reads into the HEIC that ADR-07 stores for it.
enum ImageAssetEncoder {
    /// The long side of a stored image, as ADR-07 sets it, so the memory a page with images needs stays predictable.
    static let maximumPixelSize = 4096
    static let compressionQuality = 0.8

    private static let heicType = "public.heic"

    /// Downscales and encodes an image. Only the pixels are written: the original's metadata, including where a
    /// photo was taken, does not travel into the notebook.
    static func encode(_ imageData: Data) throws -> EncodedImage {
        // The source keeps no decoded original and the thumbnail is decoded straight at the reduced size, so a
        // large photo never costs a full-size bitmap in memory.
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let thumbnailOptions =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                // Applies the EXIF orientation, so a portrait photo is stored upright.
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, sourceOptions),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
        else {
            throw NotebookStoreError.imageUnreadable
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, heicType as CFString, 1, nil) else {
            throw NotebookStoreError.imageEncodingFailed
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw NotebookStoreError.imageEncodingFailed
        }
        return EncodedImage(heic: output as Data, pixelWidth: image.width, pixelHeight: image.height)
    }
}
