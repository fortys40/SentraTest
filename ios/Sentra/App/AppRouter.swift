import Observation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func push(_ route: AppRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func reset() { path.removeAll() }
}

@MainActor
struct SentraRootView: View {
    let environment: AppEnvironment

    var body: some View {
        @Bindable var router = environment.router
        NavigationStack(path: $router.path) {
            StepTwoDashboardPreview(environment: environment)
                .navigationDestination(for: AppRoute.self) { route in
                    SentraEmptyState(title: "error.unavailable", systemImage: "clock")
                        .padding(SentraTheme.Spacing.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(SentraTheme.Colors.background)
                        .navigationTitle(Text(route.title))
                }
        }
        .tint(SentraTheme.Colors.primary)
        .environment(environment)
        .onOpenURL { url in
            if let route = environment.deepLinkHandler.route(for: url) {
                router.push(route)
            }
        }
    }
}