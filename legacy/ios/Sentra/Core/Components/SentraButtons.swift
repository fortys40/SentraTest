import SwiftUI

struct SentraPrimaryButton: View {
    let title: LocalizedStringResource
    var systemImage: String = "arrow.right"
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SentraButtonLabel(title: title, systemImage: systemImage, isLoading: isLoading)
        }
        .buttonStyle(SentraButtonStyle(kind: .primary))
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
    }
}

struct SentraSecondaryButton: View {
    let title: LocalizedStringResource
    var systemImage: String = "arrow.clockwise"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SentraButtonLabel(title: title, systemImage: systemImage, isLoading: false)
        }
        .buttonStyle(SentraButtonStyle(kind: .secondary))
    }
}

struct SentraDestructiveButton: View {
    let title: LocalizedStringResource
    var systemImage: String = "trash"
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            SentraButtonLabel(title: title, systemImage: systemImage, isLoading: false)
        }
        .buttonStyle(SentraButtonStyle(kind: .destructive))
    }
}

private struct SentraButtonLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    let isLoading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SentraTheme.Spacing.medium) {
            ZStack {
                Image(systemName: isLoading && reduceMotion ? "hourglass" : systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .opacity(isLoading && !reduceMotion ? 0 : 1)
                if isLoading && !reduceMotion { ProgressView().tint(SentraTheme.Colors.onBrand) }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
            Text(title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(SentraTheme.Typography.bodyStrong)
        .padding(.horizontal, SentraTheme.Spacing.large)
        .padding(.vertical, SentraTheme.Spacing.medium)
        .frame(maxWidth: .infinity, minHeight: SentraTheme.Layout.buttonHeight)
        .contentShape(Rectangle())
    }
}

private struct SentraButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let foreground = kind == .secondary ? SentraTheme.Colors.ink : SentraTheme.Colors.onBrand
        let background = kind == .secondary ? SentraTheme.Colors.surface :
            (kind == .destructive ? SentraTheme.Colors.noFill : SentraTheme.Colors.brand)
        return configuration.label
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: SentraTheme.Radius.control))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: SentraTheme.Radius.control)
                        .strokeBorder(SentraTheme.Colors.border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .animation(reduceMotion ? nil : SentraTheme.Motion.brief, value: configuration.isPressed)
    }
}

struct RSVPButton: View {
    let status: RSVPStatus
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SentraTheme.Spacing.small) {
                Image(systemName: status.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text(status.label)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .font(SentraTheme.Typography.bodyStrong)
            .padding(SentraTheme.Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: SentraTheme.Layout.buttonHeight)
            .foregroundStyle(status.buttonForeground)
            .background(status.buttonBackground,
                        in: RoundedRectangle(cornerRadius: SentraTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: SentraTheme.Radius.control - 2)
                    .strokeBorder(status.buttonForeground.opacity(isSelected ? 0.8 : 0), lineWidth: 1)
                    .padding(3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(status == .waitlist)
        .accessibilityLabel(Text(status.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}