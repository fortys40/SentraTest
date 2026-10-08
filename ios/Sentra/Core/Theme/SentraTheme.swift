import SwiftUI
import UIKit

enum SentraTheme {
    enum Colors {
        static let background = adaptive(0xF5F7F5, 0x101A15)
        static let surface = adaptive(0xFFFFFF, 0x1A2720)
        static let surfaceMuted = adaptive(0xEDF2EE, 0x26382D)
        static let ink = adaptive(0x17271D, 0xF4F8F5)
        static let mutedInk = adaptive(0x58665D, 0xB6C9BE)
        static let primary = adaptive(0x007B45, 0x7BDCAE)
        static let onPrimary = adaptive(0xFFFFFF, 0x08251A)
        static let warning = adaptive(0x735000, 0xFFD16B)
        static let danger = adaptive(0xB92E43, 0xFFA5B1)
        static let waitlist = adaptive(0x3F5D74, 0xBAD2E4)
        static let border = adaptive(0xD8E1DA, 0x40564A)
        static let yesSurface = adaptive(0xE5F5EB, 0x153D29)
        static let maybeSurface = adaptive(0xFFF3D6, 0x423519)
        static let noSurface = adaptive(0xFFE8EC, 0x47242C)
        static let waitlistSurface = adaptive(0xE6EFF5, 0x273D48)
        static let brand = solid(0x00864A)
        static let darkGreen = solid(0x00482E)
        static let onBrand = solid(0xFFFFFF)
        static let maybeFill = solid(0xFFD16B)
        static let onMaybe = solid(0x473204)
        static let noFill = solid(0xD12F46)
        static let mvpSurface = solid(0x061B16)
        static let mvpRaised = solid(0x0D2B23)
        static let onMVP = solid(0xF4F8F5)
        static let mutedMVP = solid(0xB6CEC1)
        static let mvpAccent = solid(0x79E2AE)
        static let premiumSurface = solid(0x111B18)
        static let onPremium = solid(0xFCF6E6)
        static let bronze = solid(0xDBB18A)
        static let silver = solid(0xD3E0E5)
        static let gold = solid(0xE5C875)
        static let elite = solid(0xF4DB91)

        static func solid(_ value: UInt32) -> Color {
            Color(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
        }

        private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((value >> 16) & 255) / 255,
                    green: CGFloat((value >> 8) & 255) / 255,
                    blue: CGFloat(value & 255) / 255, alpha: 1
                )
            })
        }
    }

    enum Typography {
        static let brand = Font.system(.largeTitle).weight(.heavy).italic()
        static let title = Font.system(.title2).weight(.bold)
        static let heading = Font.system(.headline).weight(.bold)
        static let body = Font.body
        static let bodyStrong = Font.body.weight(.semibold)
        static let caption = Font.caption.weight(.medium)
        static let cardName = Font.system(.title3).weight(.bold)
        static let rating = Font.system(.largeTitle).weight(.heavy)
    }

    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let section: CGFloat = 40
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 8
    }

    enum Shadow {
        static let color = Color.black.opacity(0.06)
        static let radius: CGFloat = 10
        static let offset: CGFloat = 4
    }

    enum Motion {
        static let brief = Animation.easeInOut(duration: 0.18)
    }

    enum Layout {
        static let minimumTarget: CGFloat = 44
        static let buttonHeight: CGFloat = 52
        static let rowHeight: CGFloat = 60
        static let avatarSize: CGFloat = 40
        static let heroHeight: CGFloat = 360
        static let cardMinimumWidth: CGFloat = 280
        static let contentWidth: CGFloat = 880
    }
}

extension RSVPStatus {
    var label: LocalizedStringResource {
        switch self {
        case .yes: return "rsvp.yes"
        case .maybe: return "rsvp.maybe"
        case .no: return "rsvp.no"
        case .waitlist: return "rsvp.waitlist"
        }
    }

    var symbol: String {
        switch self {
        case .yes: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .waitlist: return "clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .yes: return SentraTheme.Colors.primary
        case .maybe: return SentraTheme.Colors.warning
        case .no: return SentraTheme.Colors.danger
        case .waitlist: return SentraTheme.Colors.waitlist
        }
    }

    var chipBackground: Color {
        switch self {
        case .yes: return SentraTheme.Colors.yesSurface
        case .maybe: return SentraTheme.Colors.maybeSurface
        case .no: return SentraTheme.Colors.noSurface
        case .waitlist: return SentraTheme.Colors.waitlistSurface
        }
    }

    var buttonBackground: Color {
        switch self {
        case .yes: return SentraTheme.Colors.brand
        case .maybe: return SentraTheme.Colors.maybeFill
        case .no: return SentraTheme.Colors.noFill
        case .waitlist: return SentraTheme.Colors.waitlistSurface
        }
    }

    var buttonForeground: Color {
        switch self {
        case .yes, .no: return SentraTheme.Colors.onBrand
        case .maybe: return SentraTheme.Colors.onMaybe
        case .waitlist: return SentraTheme.Colors.waitlist
        }
    }
}

extension FootballPosition {
    var label: LocalizedStringResource {
        switch self {
        case .goalkeeper: return "position.goalkeeper"
        case .defender: return "position.defender"
        case .midfielder: return "position.midfielder"
        case .forward: return "position.forward"
        case .any: return "position.any"
        }
    }

    var shortLabel: LocalizedStringResource {
        switch self {
        case .goalkeeper: return "position.goalkeeper.short"
        case .defender: return "position.defender.short"
        case .midfielder: return "position.midfielder.short"
        case .forward: return "position.forward.short"
        case .any: return "position.any.short"
        }
    }
}

extension MatchStatus {
    var label: LocalizedStringResource {
        switch self {
        case .scheduled: return "match.scheduled"
        case .locked: return "match.locked"
        case .finished: return "match.finished"
        case .cancelled: return "match.cancelled"
        }
    }
}

extension CardTier {
    var accent: Color {
        switch self {
        case .bronze: return SentraTheme.Colors.bronze
        case .silver: return SentraTheme.Colors.silver
        case .gold: return SentraTheme.Colors.gold
        case .elite: return SentraTheme.Colors.elite
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .bronze: return "tier.bronze"
        case .silver: return "tier.silver"
        case .gold: return "tier.gold"
        case .elite: return "tier.elite"
        }
    }
}

extension PreviewPlayerTitle {
    var label: LocalizedStringResource {
        switch self {
        case .wall: return "title.wall"
        case .scorer: return "title.scorer"
        case .everPresent: return "title.everPresent"
        case .mvpMachine: return "title.mvpMachine"
        }
    }
}