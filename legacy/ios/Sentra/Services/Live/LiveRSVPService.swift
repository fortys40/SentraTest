import Foundation
import Supabase

@MainActor
final class LiveRSVPService: RSVPService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func fetchResponses(matchID: UUID) async throws -> [RSVPWithWaitlistPosition] {
        try await SupabaseRequest.perform {
            try await client.from("rsvps_with_waitlist_position").select()
                .eq("match_id", value: matchID.uuidString)
                .order("created_at").order("id").execute().value
        }
    }

    func fetchCounts(matchID: UUID) async throws -> MatchRSVPCounts {
        try await SupabaseRequest.perform {
            try await client.from("match_rsvp_counts").select()
                .eq("match_id", value: matchID.uuidString).single().execute().value
        }
    }
}