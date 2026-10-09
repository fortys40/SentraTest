import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Sentra

final class PlayerCardTests: XCTestCase {
    func testFreeTierBoundariesUseOverall() {
        let cases: [(Int, PlayerCardAppearance)] = [
            (50, .bronze), (64, .bronze), (65, .silver), (74, .silver),
            (75, .gold), (84, .gold), (85, .elite), (99, .elite)
        ]
        for (overall, expected) in cases {
            XCTAssertEqual(PlayerCardAppearance(overall: overall, appearances: 3), expected)
        }
    }

    func testProvisionalHidesOverallUntilThirdAppearance() {
        for appearances in [Int64(0), 1, 2] {
            let appearance = PlayerCardAppearance(overall: 99, appearances: appearances)
            XCTAssertEqual(appearance, .provisional)
            XCTAssertFalse(appearance.showsOverall)
        }
        XCTAssertTrue(PlayerCardAppearance(overall: 65, appearances: 3).showsOverall)
    }

    func testPlayerOfTheWeekDoesNotOverrideProvisional() {
        XCTAssertEqual(PlayerCardAppearance(overall: 90, appearances: 2, isPlayerOfTheWeek: true), .provisional)
        XCTAssertEqual(PlayerCardAppearance(overall: 63, appearances: 3, isPlayerOfTheWeek: true), .playerOfTheWeek)
        XCTAssertEqual(PlayerCardAppearance(overall: 63, appearances: 3, isPlayerOfTheWeek: false), .bronze)
    }

    func testFaceCropPlacesEstimatedEyesAtFortyPercent() {
        let image = PhotoDimensions(width: 1_200, height: 1_800)
        let face = NormalizedFaceRectangle(x: 0.35, y: 0.22, width: 0.25, height: 0.20)
        let crop = PhotoCropGeometry.automatic(image: image, faces: [face])
        XCTAssertEqual(crop.focusX, 0.475, accuracy: 0.000_001)
        XCTAssertEqual(crop.zoom, 1.777_777_778, accuracy: 0.000_001)
        let position = PhotoCropGeometry.projectedY(face.estimatedEyesY, crop: crop, image: image)
        XCTAssertEqual(position / PhotoCropGeometry.defaultViewport.height, 0.4, accuracy: 0.000_001)
    }

    func testNoFaceUsesCenterCropAndLargestFaceWins() {
        let image = PhotoDimensions(width: 1_200, height: 1_800)
        XCTAssertEqual(PhotoCropGeometry.automatic(image: image, faces: []), .center)
        let small = NormalizedFaceRectangle(x: 0.1, y: 0.1, width: 0.05, height: 0.05)
        let large = NormalizedFaceRectangle(x: 0.35, y: 0.22, width: 0.25, height: 0.20)
        XCTAssertEqual(PhotoCropGeometry.automatic(image: image, faces: [small, large]),
                       PhotoCropGeometry.automatic(image: image, faces: [large]))
    }

    func testPanAndZoomCannotExposeEmptyImageEdges() {
        let image = PhotoDimensions(width: 2_000, height: 1_000)
        let viewport = PhotoCropGeometry.defaultViewport
        let crop = PhotoCropGeometry.panned(.center, horizontal: 10_000, vertical: -10_000,
                                           image: image, viewport: viewport)
        let size = PhotoCropGeometry.displayedSize(image: image, viewport: viewport, zoom: crop.zoom)
        XCTAssertEqual(crop.focusX, viewport.width / (2 * size.width), accuracy: 0.000_001)
        XCTAssertEqual(crop.focusY, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(PhotoCropGeometry.zoomed(crop, magnification: 100, image: image).zoom, 4)
        XCTAssertEqual(PhotoCropGeometry.zoomed(crop, magnification: 0.01, image: image).zoom, 1)
    }

    func testInvalidInputsAndTinyFacesStayBounded() {
        XCTAssertEqual(PhotoCrop(focusX: .nan, focusY: .infinity, zoom: -.infinity), .center)
        XCTAssertEqual(PhotoCropGeometry.automatic(image: PhotoDimensions(width: 0, height: 1), faces: []), .center)
        let image = PhotoDimensions(width: 1_200, height: 1_800)
        let tiny = NormalizedFaceRectangle(x: 0.45, y: 0.4, width: 0.01, height: 0.01)
        XCTAssertEqual(PhotoCropGeometry.automatic(image: image, faces: [tiny]).zoom, 4)
        let invalid = NormalizedFaceRectangle(x: -1, y: 0, width: 1, height: 1)
        XCTAssertEqual(PhotoCropGeometry.automatic(image: image, faces: [invalid]), .center)
    }

    func testCropIsIndependentOfCardDisplaySize() {
        let image = PhotoDimensions(width: 1_200, height: 1_800)
        let face = NormalizedFaceRectangle(x: 0.35, y: 0.22, width: 0.25, height: 0.20)
        let small = PhotoDimensions(width: 120, height: 120 / PhotoCropGeometry.portraitAspectRatio)
        let large = PhotoDimensions(width: 360, height: 360 / PhotoCropGeometry.portraitAspectRatio)
        let smallCrop = PhotoCropGeometry.automatic(image: image, faces: [face], viewport: small)
        let largeCrop = PhotoCropGeometry.automatic(image: image, faces: [face], viewport: large)
        XCTAssertEqual(smallCrop.focusX, largeCrop.focusX, accuracy: 0.000_001)
        XCTAssertEqual(smallCrop.focusY, largeCrop.focusY, accuracy: 0.000_001)
        XCTAssertEqual(smallCrop.zoom, largeCrop.zoom, accuracy: 0.000_001)
    }

    func testPhotoPreparationRejectsInvalidData() async {
        do {
            _ = try await PhotoCropService().prepare(data: Data())
            XCTFail("Invalid image data must be rejected")
        } catch PhotoCropService.Failure.invalidImage {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPhotoPreparationNormalizesOrientationAndRemovesLocationMetadata() async throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 320,
                                              bitsPerComponent: 8, bytesPerRow: 240 * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 240, height: 320))
        let image = try XCTUnwrap(context.makeImage())
        let input = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 12.0, kCGImagePropertyGPSLatitudeRef: "N"]
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let photo = try await PhotoCropService().prepare(data: input as Data)
        XCTAssertEqual(photo.dimensions, PhotoDimensions(width: 320, height: 240))
        XCTAssertEqual(photo.crop, .center)
        let output = try XCTUnwrap(CGImageSourceCreateWithData(photo.imageData as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
        XCTAssertEqual((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1, 1)
    }
}