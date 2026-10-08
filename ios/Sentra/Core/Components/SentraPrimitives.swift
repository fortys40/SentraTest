import SwiftUI

struct SentraCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(SentraTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SentraTheme.Colors.surface, in: RoundedRectangle(cornerRadius: SentraTheme.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: SentraTheme.Radius.card)
                    .strokeBorder(SentraTheme.Colors.border.opacity(0.6), lineWidth: 0.5)
            }
            .shadow(color: SentraTheme.Shadow.color, radius: SentraTheme.Shadow.radius,
                    y: SentraTheme.Shadow.offset)
    }
}

struct SentraSectionHeader: View {
    let title: LocalizedStringResource

    var body: some View {
        Text(title)
            .font(SentraTheme.Typography.heading)
            .foregroundStyle(SentraTheme.Colors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SentraChip: View {
    let title: LocalizedStringResource
    let systemImage: String
    var tint: Color = SentraTheme.Colors.primary
    var background: Color?

    var body: some View {
        HStack(spacing: SentraTheme.Spacing.tiny) {
            Image(systemName: systemImage).accessibilityHidden(true)
            Text(title).fixedSize(horizontal: false, vertical: true)
        }
        .font(SentraTheme.Typography.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, SentraTheme.Spacing.small)
        .padding(.vertical, SentraTheme.Spacing.tiny)
        .background(background ?? tint.opacity(0.1), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct SentraStatusBadge: View {
    let status: RSVPStatus

    var body: some View {
        SentraChip(title: status.label, systemImage: status.symbol,
                   tint: status.color, background: status.chipBackground)
    }
}

struct SentraAvatar: View {
    let name: String
    var image: Image?
    var size: CGFloat = SentraTheme.Layout.avatarSize

    private var initials: String {
        name.split(whereSeparator: \.isWhitespace).prefix(2)
            .compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(SentraTheme.Colors.surfaceMuted)
            if let image {
                image.resizable().scaledToFill()
            } else if initials.isEmpty {
                Image(systemName: "person.fill").foregroundStyle(SentraTheme.Colors.primary)
            } else {
                Text(verbatim: initials)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(SentraTheme.Colors.primary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(Text(verbatim: name))
    }
}

struct SentraProgressHeader: View {
    let title: LocalizedStringResource
    let currentStep: Int
    let totalSteps: Int
    var stepTitles: [LocalizedStringResource] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 24

    var body: some View {
        let total = max(totalSteps, 1)
        let current = min(max(currentStep, 0), total)
        VStack(alignment: .leading, spacing: SentraTheme.Spacing.medium) {
            Text(title)
                .font(SentraTheme.Typography.heading)
                .accessibilityAddTraits(.isHeader)
            Text("progress.steps \(current) \(total)")
                .font(SentraTheme.Typography.caption)
                .foregroundStyle(SentraTheme.Colors.mutedInk)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: SentraTheme.Spacing.medium) {
                    ForEach(1...total, id: \.self) { step in
                        HStack(spacing: SentraTheme.Spacing.medium) {
                            marker(step, current: current)
                            stepTitle(step)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: SentraTheme.Spacing.small) {
                    ForEach(1...total, id: \.self) { step in
                        VStack(spacing: SentraTheme.Spacing.small) {
                            marker(step, current: current)
                            stepTitle(step)
                        }
                        .frame(maxWidth: .infinity)
                        if step < total {
                            Capsule()
                                .fill(step < current ? SentraTheme.Colors.brand : SentraTheme.Colors.border)
                                .frame(width: SentraTheme.Spacing.large, height: 2)
                                .padding(.top, markerSize / 2 - 1)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .foregroundStyle(SentraTheme.Colors.ink)
        .accessibilityElement(children: .combine)
    }

    private func marker(_ step: Int, current: Int) -> some View {
        ZStack {
            Circle().fill(step <= current ? SentraTheme.Colors.brand : SentraTheme.Colors.surfaceMuted)
            if step < current {
                Image(systemName: "checkmark")
            } else {
                Text(step, format: .number)
            }
        }
        .font(SentraTheme.Typography.caption)
        .foregroundStyle(step <= current ? SentraTheme.Colors.onBrand : SentraTheme.Colors.mutedInk)
        .frame(width: markerSize, height: markerSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stepTitle(_ step: Int) -> some View {
        if stepTitles.indices.contains(step - 1) {
            Text(stepTitles[step - 1])
                .font(SentraTheme.Typography.caption)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SentraSegmentedTabs<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> Text
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .overlay(alignment: .bottom) {
                Rectangle().fill(SentraTheme.Colors.border).frame(height: 0.5)
            }
            .animation(reduceMotion ? nil : SentraTheme.Motion.brief, value: selection)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            verticalTabs
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: SentraTheme.Spacing.small) {
                    ForEach(options, id: \.self) { option in tab(option, wraps: false) }
                }
                verticalTabs
            }
        }
    }

    private var verticalTabs: some View {
        VStack(spacing: SentraTheme.Spacing.tiny) {
            ForEach(options, id: \.self) { option in tab(option, wraps: true) }
        }
    }

    private func tab(_ option: Option, wraps: Bool) -> some View {
        Button { selection = option } label: {
            label(option)
                .font(SentraTheme.Typography.caption)
                .fixedSize(horizontal: !wraps, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SentraTheme.Spacing.small)
                .padding(.vertical, SentraTheme.Spacing.small)
                .frame(maxWidth: .infinity, minHeight: SentraTheme.Layout.minimumTarget)
                .foregroundStyle(selection == option ? SentraTheme.Colors.primary : SentraTheme.Colors.mutedInk)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selection == option ? SentraTheme.Colors.primary : .clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }
}