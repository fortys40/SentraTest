import Foundation
import Supabase

@MainActor
final class LiveProfileService: ProfileService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func fetchProfile(id: UUID) async throws -> Profile {
        try await SupabaseRequest.perform {
            try await client.from("profiles").select()
                .eq("id", value: id.uuidString).single().execute().value
        }
    }

    func fetchProfiles(ids: [UUID]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        return try await SupabaseRequest.perform {
            try await client.from("profiles").select()
                .in("id", values: ids.map(\.uuidString))
                .order("id").execute().value
        }
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> Profile {
        try await SupabaseRequest.perform {
            let userID = try await client.auth.session.user.id
            return try await client.from("profiles").update(update)
                .eq("id", value: userID.uuidString).select().single().execute().value
        }
    }
}