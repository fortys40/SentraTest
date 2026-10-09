import SwiftUI

enum PlayerCardSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var width: CGFloat {
        switch self {
        case .small: return 240
        case .medium: return 320
        case .large: return 400
        }
    }
}

@MainActor
struct PlayerCardView: View {
    let example: PlayerCardExample
    var photo: CardPhoto?
    var size: PlayerCardSize = .medium
    var isPlayerOfTheWeek = false
    var reliability: Decimal?
    var countryCode: String?
    var groupColor: Color = SentraTheme.Colors.brand
    var motion: CardMotionMode = .device
    var onCropChange: ((PhotoCrop) -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var ratingSize: CGFloat = 52
    @ScaledMetric(relativeTo: .caption) private var labelSize: CGFloat = 12
    @ScaledMetric(relativeTo: .headline) private var numberSize: CGFloat = 20

    private var appearance: PlayerCardAppearance {
        PlayerCardAppearance(overall: example.overall, appearances: example.stats.appearances,
                             isPlayerOfTheWeek: isPlayerOfTheWeek)
    }
    private var style: CardTierStyle { CardTierStyle(appearance: appearance) }

    var body: some View {
        ZStack {
            Color.clear.aspectRatio(2.0 / 3.0, contentMode: .fit).accessibilityHidden(true)
            cardContent
        }
        .frame(idealWidth: size.width, maxWidth: size.width)
        .foregroundStyle(style.ink)
        .overlay {
            SentraCardShape().strokeBorder(style.metal, lineWidth: 1.7)
            SentraCardShape().inset(by: 5).strokeBorder(style.metal, lineWidth: 0.75)
            SentraCardShape().strokeBorder(style.highlight.opacity(0.7), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear, .clear], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(SentraCardShape())
        .modifier(CardMotionEffect(mode: motion, style: style))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: appearance)
        .accessibilityElement(children: .contain)
    }

    private var cardContent: some View {
        VStack(spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize { rating }
            portrait
            VStack(spacing: 3) {
                Text(verbatim: example.profile.displayName.uppercased(with: locale))
                    .font(.system(size: size == .small ? numberSize * 0.85 : numberSize, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: example.profile.displayName))
                if size != .small {
                    Text(example.title.label).font(.system(size: labelSize, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if appearance == .provisional {
                    Text("card.provisional").font(.system(size: labelSize, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                } else if appearance == .playerOfTheWeek {
                    Text("card.playerOfTheWeek").font(.system(size: labelSize, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.center)
            Rectangle().fill(style.accent.opacity(0.55)).frame(height: 0.75).accessibilityHidden(true)
            stats
            footer
        }
        .padding(.horizontal, size == .small ? 18 : 24)
        .padding(.top, 30)
        .padding(.bottom, 46)
    }

    private var portrait: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * 0.68
            ZStack(alignment: .topLeading) {
                CardPortraitView(name: example.profile.displayName, photo: photo, style: style)
                    .id(photo?.id)
                    .frame(width: width, height: width / CGFloat(PhotoCropGeometry.portraitAspectRatio))
                    .modifier(PhotoCropInteraction(photo: photo, onChange: onCropChange))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                if !dynamicTypeSize.isAccessibilitySize {
                    rating.frame(width: geometry.size.width * 0.17).padding(.top, 24)
                }
            }
        }
        .aspectRatio(1.18, contentMode: .fit)
    }

    private var rating: some View {
        VStack(spacing: 2) {
            if appearance.showsOverall {
                Text(example.overall, format: .number)
                    .font(.system(size: ratingSize * (size == .small ? 0.75 : 1), weight: .heavy))
                    .fontWidth(.condensed)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel(Text("card.overall \(example.overall)"))
            }
            Text(example.profile.position.shortLabel)
                .font(.system(size: labelSize, weight: .heavy))
                .accessibilityLabel(Text(example.profile.position.label))
            if let countryCode, let flag = flag(for: countryCode) {
                Text(verbatim: flag).font(.system(size: 18))
                    .accessibilityLabel(Text(verbatim: locale.localizedString(forRegionCode: countryCode) ?? countryCode))
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                count: dynamicTypeSize.isAccessibilitySize ? 2 : (size == .small ? 4 : 6)), spacing: 10) {
            statistic("card.appearances", fullTitle: "card.appearances.full", value: example.stats.appearances.formatted(.number.locale(locale)))
            statistic("card.winPercentage", fullTitle: "card.winPercentage.full", value: example.stats.winPercentage.map {
                ($0 / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
            })
            statistic("card.mvp", fullTitle: "card.mvp.full", value: example.stats.mvpCount.formatted(.number.locale(locale)))
            statistic("card.goals", fullTitle: "card.goals.full", value: example.stats.goals.formatted(.number.locale(locale)))
            if size != .small {
                statistic("card.streak.short", fullTitle: "card.streak.full", value: example.stats.currentStreak.formatted(.number.locale(locale)))
                statistic("card.reliability.short", fullTitle: "card.reliability.full", value: reliability.flatMap {
                    (0...1).contains($0) ? $0.formatted(.percent.precision(.fractionLength(0)).locale(locale)) : nil
                })
            }
        }
    }

    private func statistic(_ title: LocalizedStringResource, fullTitle: LocalizedStringResource, value: String?) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: labelSize, weight: .medium)).lineLimit(1).minimumScaleFactor(0.9)
            Text(verbatim: value ?? String(localized: "card.noResult.short"))
                .font(.system(size: numberSize * (size == .small ? 0.85 : 1), weight: .heavy))
                .fontWidth(.condensed).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(fullTitle))
        .accessibilityValue(Text(verbatim: value ?? String(localized: "card.statUnavailable")))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            ForEach(Array(example.badges.prefix(3))) { badge in
                Text(verbatim: badge.emoji).font(.system(size: size == .small ? 16 : 18))
                    .accessibilityLabel(Text(verbatim: badge.nameEL))
            }
            Text(verbatim: example.groupName.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(style.ink)
                .frame(width: 25, height: 29)
                .background(style.material, in: SentraPortraitFrame())
                .overlay { SentraPortraitFrame().strokeBorder(groupColor, lineWidth: 1.5) }
                .accessibilityLabel(Text(verbatim: example.groupName))
            Label("app.name", systemImage: "soccerball")
                .font(.system(size: labelSize, weight: .bold))
        }
        .frame(maxWidth: .infinity)
    }

    private func flag(for code: String) -> String? {
        let scalars = Array(code.uppercased().unicodeScalars)
        guard scalars.count == 2, scalars.allSatisfy({ (65...90).contains($0.value) }) else { return nil }
        return String(String.UnicodeScalarView(scalars.compactMap { UnicodeScalar(127_397 + $0.value) }))
    }
}