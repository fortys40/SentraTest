import SwiftUI

@main
@MainActor
struct SentraApp: App {
    @State private var environment: AppEnvironment

    init() {
        _environment = State(initialValue: AppEnvironment.preview(data: MockDataFactory.make(referenceDate: Date())))
        SentraLogger.record(.previewStarted)
    }

    var body: some Scene {
        WindowGroup {
            SentraRootView(environment: environment)
        }
    }
}