import OSLog

enum SentraLogger {
    enum Event: String {
        case previewStarted = "preview_started"
        case liveEnvironmentCreated = "live_environment_created"
    }

    private static let logger = Logger(subsystem: "com.sarantos.sentra", category: "app")

    static func record(_ event: Event) {
        logger.info("\(event.rawValue, privacy: .public)")
    }
}