import Foundation

struct PhotoDimensions: Hashable, Sendable {
    let width: Double
    let height: Double

    var isValid: Bool { width.isFinite && height.isFinite && width > 0 && height > 0 }
}

struct NormalizedFaceRectangle: Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
            width > 0 && height > 0 && x + width <= 1 && y + height <= 1
    }

    var estimatedEyesY: Double { y + height * 0.38 }
}

struct PhotoCrop: Codable, Hashable, Sendable {
    let focusX: Double
    let focusY: Double
    let zoom: Double

    static let center = PhotoCrop(focusX: 0.5, focusY: 0.5, zoom: 1)

    init(focusX: Double, focusY: Double, zoom: Double) {
        self.focusX = focusX.isFinite ? min(max(focusX, 0), 1) : 0.5
        self.focusY = focusY.isFinite ? min(max(focusY, 0), 1) : 0.5
        self.zoom = zoom.isFinite ? min(max(zoom, 1), PhotoCropGeometry.maximumZoom) : 1
    }
}

struct CardPhoto: Identifiable, Hashable, Sendable {
    let id: UUID
    let imageData: Data
    let dimensions: PhotoDimensions
    let automaticCrop: PhotoCrop
    var crop: PhotoCrop
}

enum PhotoCropGeometry {
    static let maximumZoom = 4.0
    static let portraitAspectRatio = 0.9
    static let defaultViewport = PhotoDimensions(width: 240, height: 240 / portraitAspectRatio)

    static func displayedSize(image: PhotoDimensions, viewport: PhotoDimensions, zoom: Double) -> PhotoDimensions {
        guard image.isValid, viewport.isValid else { return PhotoDimensions(width: 1, height: 1) }
        let safeZoom = zoom.isFinite ? min(max(zoom, 1), maximumZoom) : 1
        let scale = max(viewport.width / image.width, viewport.height / image.height) * safeZoom
        return PhotoDimensions(width: image.width * scale, height: image.height * scale)
    }

    static func constrained(_ crop: PhotoCrop, image: PhotoDimensions,
                            viewport: PhotoDimensions = defaultViewport) -> PhotoCrop {
        guard image.isValid, viewport.isValid else { return .center }
        let safeCrop = PhotoCrop(focusX: crop.focusX, focusY: crop.focusY, zoom: crop.zoom)
        let size = displayedSize(image: image, viewport: viewport, zoom: safeCrop.zoom)
        let horizontalMargin = min(viewport.width / (2 * size.width), 0.5)
        let verticalMargin = min(viewport.height / (2 * size.height), 0.5)
        return PhotoCrop(focusX: min(max(safeCrop.focusX, horizontalMargin), 1 - horizontalMargin),
                         focusY: min(max(safeCrop.focusY, verticalMargin), 1 - verticalMargin), zoom: safeCrop.zoom)
    }

    static func automatic(image: PhotoDimensions, faces: [NormalizedFaceRectangle],
                          viewport: PhotoDimensions = defaultViewport) -> PhotoCrop {
        guard image.isValid, viewport.isValid,
              let face = faces.filter(\.isValid).max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            return constrained(.center, image: image, viewport: viewport)
        }
        let base = displayedSize(image: image, viewport: viewport, zoom: 1)
        let zoom = min(max(viewport.height * 0.48 / (face.height * base.height), 1), maximumZoom)
        let size = displayedSize(image: image, viewport: viewport, zoom: zoom)
        let focusY = face.estimatedEyesY + (0.5 - 0.4) * viewport.height / size.height
        return constrained(PhotoCrop(focusX: face.x + face.width / 2, focusY: focusY, zoom: zoom),
                           image: image, viewport: viewport)
    }

    static func panned(_ crop: PhotoCrop, horizontal: Double, vertical: Double,
                       image: PhotoDimensions, viewport: PhotoDimensions) -> PhotoCrop {
        guard horizontal.isFinite, vertical.isFinite else { return constrained(crop, image: image, viewport: viewport) }
        let size = displayedSize(image: image, viewport: viewport, zoom: crop.zoom)
        return constrained(PhotoCrop(focusX: crop.focusX - horizontal / size.width,
                                     focusY: crop.focusY - vertical / size.height, zoom: crop.zoom),
                           image: image, viewport: viewport)
    }

    static func zoomed(_ crop: PhotoCrop, magnification: Double, image: PhotoDimensions,
                       viewport: PhotoDimensions = defaultViewport) -> PhotoCrop {
        guard magnification.isFinite, magnification > 0 else { return constrained(crop, image: image, viewport: viewport) }
        return constrained(PhotoCrop(focusX: crop.focusX, focusY: crop.focusY, zoom: crop.zoom * magnification),
                           image: image, viewport: viewport)
    }

    static func projectedY(_ normalizedY: Double, crop: PhotoCrop, image: PhotoDimensions,
                           viewport: PhotoDimensions = defaultViewport) -> Double {
        let safeCrop = constrained(crop, image: image, viewport: viewport)
        let size = displayedSize(image: image, viewport: viewport, zoom: safeCrop.zoom)
        return viewport.height / 2 + (normalizedY - safeCrop.focusY) * size.height
    }
}