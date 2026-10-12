import Foundation
import Supabase

@MainActor
final class LiveMatchService: MatchService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func fetchFormats() async throws -> [MatchFormat] {
        try await SupabaseRequest.perform {
            try await client.from("match_formats").select().eq("active", value: true)
                .order("players_per_team").execute().value
        }
    }

    func fetchMatches(groupID: UUID) async throws -> [Match] {
        try await SupabaseRequest.perform {
            try await client.from("matches").select().eq("group_id", value: groupID.uuidString)
                .order("starts_at", ascending: false).order("id", ascending: false).execute().value
        }
    }

    func fetchMatch(id: UUID) async throws -> Match {
        try await SupabaseRequest.perform {
            try await client.from("matches").select()
                .eq("id", value: id.uuidString).single().execute().value
        }
    }

    func createMatch(_ input: MatchCreation) async throws -> UUID {
        try await SupabaseRequest.perform {
            try await client.rpc("create_match", params: input).execute().value
        }
    }

    func updateMatch(_ input: MatchUpdate) async throws {
        try await SupabaseRequest.perform {
            _ = try await client.rpc("update_match", params: input).execute()
        }
    }

    func cancelMatch(id: UUID) async throws {
        try await SupabaseRequest.perform {
            _ = try await client.rpc("cancel_match", params: MatchIdentifier(matchID: id)).execute()
        }
    }
}