import Foundation
import Supabase

@MainActor
final class LiveAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func currentUserID() async throws -> UUID? {
        try await SupabaseRequest.perform {
            do {
                return try await client.auth.session.user.id
            } catch AuthError.sessionMissing {
                return nil
            }
        }
    }

    func signOut() async throws {
        try await SupabaseRequest.perform {
            try await client.auth.signOut(scope: .local)
        }
    }
}