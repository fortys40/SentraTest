import SwiftUI

struct MatchSummaryCard: View {
    let match: Match
    let groupName: String
    let counts: MatchRSVPCounts?
    var players: [Profile] = []
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        SentraCard {
            VStack(alignment: .leading, spacing: SentraTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) {
                    Text(verbatim: groupName)
                        .font(SentraTheme.Typography.caption)
                        .foregroundStyle(SentraTheme.Colors.mutedInk)
                    Label {
                        Text(verbatim: DateFormatters.matchDate(match.startsAt, locale: locale, timeZone: timeZone))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "calendar").accessibilityHidden(true)
                    }
                    .font(SentraTheme.Typography.heading)
                    Label {
                        Text(verbatim: match.venue)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse").accessibilityHidden(true)
                    }
                    .font(SentraTheme.Typography.caption)
                    .foregroundStyle(SentraTheme.Colors.mutedInk)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: SentraTheme.Spacing.medium) { metadata }
                    VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) { metadata }
                }
                if let counts {
                    VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: SentraTheme.Spacing.medium) {
                                attendees
                                Text("match.confirmed \(counts.yesCount) \(match.capacity)")
                                    .font(SentraTheme.Typography.caption)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            VStack(alignment: .leading, spacing: SentraTheme.Spacing.small) {
                                attendees
                                Text("match.confirmed \(counts.yesCount) \(match.capacity)")
                                    .font(SentraTheme.Typography.caption)
                            }
                        }
                        ProgressView(value: Double(counts.yesCount), total: Double(max(match.capacity, 1)))
                            .tint(SentraTheme.Colors.brand)
                            .accessibilityLabel(Text("match.confirmed \(counts.yesCount) \(match.capacity)"))
                    }
                }
                if let cost = match.expectedCost {
                    LabeledContent {
                        Text(verbatim: DateFormatters.euros(cost, locale: locale))
                            .font(SentraTheme.Typography.bodyStrong)
                    } label: {
                        Text("match.expectedCost")
                    }
                    .font(SentraTheme.Typography.caption)
                }
            }
            .foregroundStyle(SentraTheme.Colors.ink)
        }
    }

    private var attendees: some View {
        HStack(spacing: -6) {
            ForEach(Array(players.prefix(4))) { player in
                SentraAvatar(name: player.displayName, size: 28)
                    .overlay { Circle().strokeBorder(SentraTheme.Colors.surface, lineWidth: 2) }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var metadata: some View {
        Text(verbatim: match.format).font(SentraTheme.Typography.bodyStrong)
        Text(match.status.label)
            .font(SentraTheme.Typography.caption)
            .foregroundStyle(SentraTheme.Colors.mutedInk)
    }
}