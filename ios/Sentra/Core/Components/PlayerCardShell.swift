import SwiftUI

struct PlayerCardShell: View {
    let example: PlayerCardExample
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var ratingSize: CGFloat = 52

    private var accent: Color { example.design.tier.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
            identity
            VStack(spacing: SentraTheme.Spacing.tiny) {
                Text(verbatim: example.profile.displayName)
                    .font(SentraTheme.Typography.cardName)
                    .fixedSize(horizontal: false, vertical: true)
                Text(example.title.label)
                    .font(SentraTheme.Typography.bodyStrong)
                    .foregroundStyle(accent)
                Text(verbatim: example.groupName)
                    .font(SentraTheme.Typography.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            Rectangle().fill(accent.opacity(0.7)).frame(height: 1).accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                    count: dynamicTypeSize.isAccessibilitySize ? 2 : 4),
                      spacing: SentraTheme.Spacing.medium) {
                statistic("card.appearances", value: example.stats.appearances.formatted(.number.locale(locale)))
                statistic("card.winPercentage", value: example.stats.winPercentage.map {
                    ($0 / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
                } ?? String(localized: "card.noResult.short"),
                          accessibleValue: example.stats.winPercentage == nil ? String(localized: "card.noResult") : nil)
                statistic("card.mvp", value: example.stats.mvpCount.formatted(.number.locale(locale)))
                statistic("card.goals", value: example.stats.goals.formatted(.number.locale(locale)))
            }
            Text("card.streak \(example.stats.currentStreak)")
                .font(SentraTheme.Typography.caption)
            ForEach(example.badges) { badge in
                HStack(spacing: SentraTheme.Spacing.small) {
                    Text(verbatim: badge.emoji).accessibilityHidden(true)
                    Text(verbatim: badge.nameEL)
                }
                .font(SentraTheme.Typography.caption)
            }
            Spacer(minLength: 0)
            ViewThatFits(in: .horizontal) {
                HStack { footer }
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) { footer }
            }
        }
        .padding(SentraTheme.Spacing.xLarge)
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 460, alignment: .topLeading)
        .foregroundStyle(SentraTheme.Colors.onPremium)
        .background(SentraTheme.Colors.premiumSurface, in: SentraCardSilhouette())
        .overlay {
            SentraCardSilhouette().strokeBorder(accent, lineWidth: 1.5)
        }
        .clipShape(SentraCardSilhouette())
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
    }

    private var identity: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ?
            AnyLayout(VStackLayout(alignment: .leading, spacing: SentraTheme.Spacing.large)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: SentraTheme.Spacing.large))
        return layout {
            VStack(alignment: .leading, spacing: SentraTheme.Spacing.tiny) {
                Text(example.overall, format: .number)
                    .font(.system(size: ratingSize, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .accessibilityLabel(Text("card.overall \(example.overall)"))
                Text(example.profile.position.shortLabel)
                    .font(SentraTheme.Typography.heading)
                    .accessibilityLabel(Text(example.profile.position.label))
            }
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            SentraAvatar(name: example.profile.displayName, size: 112)
                .overlay { Circle().strokeBorder(accent.opacity(0.6), lineWidth: 1) }
                .accessibilityHidden(true)
        }
    }

    private func statistic(_ title: LocalizedStringResource, value: String, accessibleValue: String? = nil) -> some View {
        VStack(spacing: SentraTheme.Spacing.tiny) {
            Text(verbatim: value)
                .font(SentraTheme.Typography.heading)
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title).font(SentraTheme.Typography.caption)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(verbatim: accessibleValue ?? value))
    }

    @ViewBuilder
    private var footer: some View {
        Text(example.design.tier.label)
            .font(SentraTheme.Typography.caption)
            .foregroundStyle(accent)
        Label("app.name", systemImage: "soccerball")
            .font(SentraTheme.Typography.caption)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct SentraCardSilhouette: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let bounds = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let cut = min(22, min(bounds.width, bounds.height) / 6)
        return Path { path in
            path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX - cut, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + cut))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX + cut, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY - cut))
            path.closeSubpath()
        }
    }

    func inset(by amount: CGFloat) -> SentraCardSilhouette {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}