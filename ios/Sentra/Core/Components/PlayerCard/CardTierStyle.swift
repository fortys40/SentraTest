import SwiftUI

enum PlayerCardAppearance: String, CaseIterable, Identifiable, Sendable {
    case bronze, silver, gold, elite, playerOfTheWeek, provisional

    var id: String { rawValue }

    init(overall: Int, appearances: Int64, isPlayerOfTheWeek: Bool = false) {
        if appearances < 3 {
            self = .provisional
        } else if isPlayerOfTheWeek {
            self = .playerOfTheWeek
        } else {
            switch CardTier(overall: overall) {
            case .bronze: self = .bronze
            case .silver: self = .silver
            case .gold: self = .gold
            case .elite: self = .elite
            }
        }
    }

    var showsOverall: Bool { self != .provisional }
}

struct CardTierStyle {
    let appearance: PlayerCardAppearance

    private var palette: CardMaterialPalette {
        switch appearance {
        case .bronze:
            return CardMaterialPalette(top: 0xF8DEC2, middle: 0xD9A776, bottom: 0xEDC69A,
                                       ink: 0x3B2415, accent: 0x7A491F, light: 0xFFF0D4,
                                       photoTint: 0xD29569, tintOpacity: 0.08, saturation: 0.96, contrast: 1.02)
        case .silver:
            return CardMaterialPalette(top: 0xF1F4F6, middle: 0xB9C3CA, bottom: 0xE8EEF0,
                                       ink: 0x25333F, accent: 0x51606C, light: 0xFFFFFF,
                                       photoTint: 0xACC4DA, tintOpacity: 0.06, saturation: 0.88, contrast: 1.02)
        case .gold:
            return CardMaterialPalette(top: 0xFFF1AD, middle: 0xE4BB57, bottom: 0xF6DF95,
                                       ink: 0x3F2D08, accent: 0x8B6214, light: 0xFFFBE6,
                                       photoTint: 0xE7C572, tintOpacity: 0.07, saturation: 0.98, contrast: 1.03)
        case .elite:
            return CardMaterialPalette(top: 0xFFFFFF, middle: 0xEBEADF, bottom: 0xFCF8E8,
                                       ink: 0x77580C, accent: 0xB89432, light: 0xFFFFFF,
                                       photoTint: 0xFFF9E0, tintOpacity: 0.05, saturation: 0.98, contrast: 0.98)
        case .playerOfTheWeek:
            return CardMaterialPalette(top: 0x0C141A, middle: 0x1A241E, bottom: 0x080E11,
                                       ink: 0xFFEAA6, accent: 0xEDC85A, light: 0xFFF3C7,
                                       photoTint: 0xFFD66D, tintOpacity: 0.06, saturation: 1.00, contrast: 1.12)
        case .provisional:
            return CardMaterialPalette(top: 0xEAEEEF, middle: 0xC3CCCB, bottom: 0xDDE3E3,
                                       ink: 0x384840, accent: 0x66776E, light: 0xFFFFFF,
                                       photoTint: 0xD3DBD8, tintOpacity: 0.04, saturation: 0.55, contrast: 0.98)
        }
    }

    var material: LinearGradient {
        LinearGradient(colors: [color(palette.top), color(palette.middle), color(palette.bottom)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var metal: LinearGradient {
        LinearGradient(stops: [.init(color: highlight, location: 0),
                               .init(color: accent, location: 0.28),
                               .init(color: highlight, location: 0.52),
                               .init(color: accent, location: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var ink: Color { color(palette.ink) }
    var accent: Color { color(palette.accent) }
    var highlight: Color { color(palette.light) }
    var bottom: Color { color(palette.bottom) }
    var photoTint: Color { color(palette.photoTint) }
    var photoTintOpacity: Double { palette.tintOpacity }
    var photoSaturation: Double { palette.saturation }
    var photoContrast: Double { palette.contrast }
    var photoBrightness: Double { appearance == .elite ? 0.025 : 0 }
    var hasMarbleTexture: Bool { appearance == .elite || appearance == .gold }

    private func color(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 255) / 255,
              green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

private struct CardMaterialPalette {
    let top: UInt32
    let middle: UInt32
    let bottom: UInt32
    let ink: UInt32
    let accent: UInt32
    let light: UInt32
    let photoTint: UInt32
    let tintOpacity: Double
    let saturation: Double
    let contrast: Double
}