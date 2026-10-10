import SwiftUI

struct PlayerRow: View {
    let name: String
    var position: FootballPosition = .any
    let status: RSVPStatus?
    var isGuest = false
    var waitlistPosition: Int64?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ?
            AnyLayout(VStackLayout(alignment: .leading, spacing: SentraTheme.Spacing.small)) :
            AnyLayout(HStackLayout(alignment: .center, spacing: SentraTheme.Spacing.medium))
        layout {
            HStack(spacing: SentraTheme.Spacing.medium) {
                SentraAvatar(name: name).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.tiny) {
                    Text(verbatim: name)
                        .font(SentraTheme.Typography.bodyStrong)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isGuest ? LocalizedStringResource("player.guest") : position.label)
                        .font(SentraTheme.Typography.caption)
                        .foregroundStyle(SentraTheme.Colors.mutedInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let status {
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.tiny) {
                    SentraStatusBadge(status: status)
                    if status == .waitlist, let waitlistPosition {
                        Text("waitlist.position \(waitlistPosition)")
                            .font(SentraTheme.Typography.caption)
                            .foregroundStyle(SentraTheme.Colors.mutedInk)
                    }
                }
            }
        }
        .padding(.vertical, SentraTheme.Spacing.small)
        .frame(minHeight: SentraTheme.Layout.rowHeight)
        .foregroundStyle(SentraTheme.Colors.ink)
        .accessibilityElement(children: .combine)
    }
}