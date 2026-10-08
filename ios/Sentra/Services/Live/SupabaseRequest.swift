import Foundation
import Supabase

@MainActor
enum SupabaseRequest {
    static func perform<Value: Sendable>(_ operation: () async throws -> Value) async throws -> Value {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw AppError.network
        } catch let error as PostgrestError {
            if error.message == "AUTH_REQUIRED" { throw AppError.notAuthenticated }
            if error.message == "RSVP_LOCKED" { throw AppError.rsvpLocked }
            switch error.code {
            case "42501": throw AppError.forbidden
            case "PGRST116": throw AppError.notFound
            case "23505", "40001", "40P01": throw AppError.conflict
            default: throw AppError.unexpected
            }
        } catch is AuthError {
            throw AppError.notAuthenticated
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.unexpected
        }
    }
}