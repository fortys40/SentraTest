import Foundation

enum AppError: LocalizedError, Equatable, Sendable {
    case configuration
    case notAuthenticated
    case forbidden
    case notFound
    case rsvpLocked
    case conflict
    case network
    case unavailable
    case unexpected

    var message: LocalizedStringResource {
        switch self {
        case .configuration: return "error.configuration"
        case .notAuthenticated: return "error.notAuthenticated"
        case .forbidden: return "error.forbidden"
        case .notFound: return "error.notFound"
        case .rsvpLocked: return "error.rsvpLocked"
        case .conflict: return "error.conflict"
        case .network: return "error.network"
        case .unavailable: return "error.unavailable"
        case .unexpected: return "error.unexpected"
        }
    }

    var errorDescription: String? { String(localized: message) }
}