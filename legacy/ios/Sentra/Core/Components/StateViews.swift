import SwiftUI

struct SentraEmptyState: View {
    let title: LocalizedStringResource
    var systemImage: String = "sportscourt"

    var body: some View {
        VStack(spacing: SentraTheme.Spacing.large) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(SentraTheme.Colors.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(SentraTheme.Typography.bodyStrong)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, SentraTheme.Spacing.xLarge)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ErrorStateView: View {
    let error: AppError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: SentraTheme.Spacing.large) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(SentraTheme.Colors.danger)
                .accessibilityHidden(true)
            Text(error.message)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SentraSecondaryButton(title: "action.retry", action: retry)
        }
        .padding(.vertical, SentraTheme.Spacing.xLarge)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingOverlay<Content: View>: View {
    let isLoading: Bool
    private let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isLoading: Bool, @ViewBuilder content: () -> Content) {
        self.isLoading = isLoading
        self.content = content()
    }

    var body: some View {
        content
            .disabled(isLoading)
            .accessibilityHidden(isLoading)
            .overlay {
                if isLoading {
                    ZStack {
                        SentraTheme.Colors.surface
                        VStack(spacing: SentraTheme.Spacing.medium) {
                            if reduceMotion {
                                Image(systemName: "hourglass").accessibilityHidden(true)
                            } else {
                                ProgressView().tint(SentraTheme.Colors.primary).accessibilityHidden(true)
                            }
                            Text("state.loading").font(SentraTheme.Typography.bodyStrong)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("state.loading"))
                }
            }
    }
}