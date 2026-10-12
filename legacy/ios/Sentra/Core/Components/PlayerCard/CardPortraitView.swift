import SwiftUI
import UIKit

@MainActor
struct CardPortraitView: View {
    let name: String
    let photo: CardPhoto?
    let style: CardTierStyle
    @State private var decodedImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            let viewport = PhotoDimensions(width: Double(geometry.size.width), height: Double(geometry.size.height))
            ZStack {
                CardMaterial(style: style)
                if let photo, let decodedImage {
                    photograph(decodedImage, photo: photo, viewport: viewport)
                } else {
                    Text(verbatim: initials)
                        .font(.system(size: geometry.size.width * 0.26, weight: .heavy))
                        .foregroundStyle(style.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .mask {
                SentraPortraitFrame().fill(LinearGradient(stops: [
                    .init(color: .white, location: 0), .init(color: .white, location: 0.78),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                SentraPortraitFrame().stroke(style.ink.opacity(0.22), lineWidth: 6)
                    .blur(radius: 3).offset(y: 3).clipShape(SentraPortraitFrame())
                SentraPortraitFrame().strokeBorder(style.metal, lineWidth: 1.8)
                SentraPortraitFrame().inset(by: 4).strokeBorder(style.metal, lineWidth: 0.65)
            }
            .overlay(alignment: .top) {
                SentraCardCrest(style: style).offset(y: -18)
            }
        }
        .task(id: photo?.id) { decodedImage = photo.flatMap { UIImage(data: $0.imageData) } }
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func photograph(_ image: UIImage, photo: CardPhoto, viewport: PhotoDimensions) -> some View {
        let crop = PhotoCropGeometry.constrained(photo.crop, image: photo.dimensions, viewport: viewport)
        let displayed = PhotoCropGeometry.displayedSize(image: photo.dimensions, viewport: viewport, zoom: crop.zoom)
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: CGFloat(displayed.width), height: CGFloat(displayed.height))
            .offset(x: CGFloat((0.5 - crop.focusX) * displayed.width),
                    y: CGFloat((0.5 - crop.focusY) * displayed.height))
            .frame(width: CGFloat(viewport.width), height: CGFloat(viewport.height))
            .clipped()
            .saturation(style.photoSaturation)
            .contrast(style.photoContrast)
            .brightness(style.photoBrightness)
            .overlay { style.photoTint.opacity(style.photoTintOpacity).blendMode(.softLight) }
            .overlay {
                RadialGradient(colors: [.clear, .clear, .black.opacity(0.22)],
                               center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0,
                               endRadius: CGFloat(max(viewport.width, viewport.height)) * 0.75)
            }
            .overlay {
                if style.appearance == .playerOfTheWeek {
                    SentraPortraitFrame().stroke(style.highlight.opacity(0.5), lineWidth: 3).blur(radius: 3)
                }
            }
    }
}