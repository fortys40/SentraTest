import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

actor PhotoCropService {
    enum Failure: Error { case invalidImage }

    func prepare(data: Data) throws -> CardPhoto {
        try Task.checkCancellation()
        guard data.count <= 25 * 1_024 * 1_024,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure.invalidImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2_048,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.invalidImage
        }
        let request = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        try Task.checkCancellation()
        let faces = (request.results ?? []).filter { $0.confidence >= 0.5 }.map { observation in
            let bounds = observation.boundingBox
            return NormalizedFaceRectangle(x: Double(bounds.minX), y: Double(1 - bounds.maxY),
                                           width: Double(bounds.width), height: Double(bounds.height))
        }
        let dimensions = PhotoDimensions(width: Double(image.width), height: Double(image.height))
        let crop = PhotoCropGeometry.automatic(image: dimensions, faces: faces)
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Failure.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.invalidImage }
        try Task.checkCancellation()
        return CardPhoto(id: UUID(), imageData: output as Data, dimensions: dimensions, automaticCrop: crop, crop: crop)
    }
}