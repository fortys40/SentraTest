import Foundation
import Supabase

@MainActor
final class LiveGroupService: GroupService {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func fetchGroups() async throws -> [Group] {
        try await SupabaseRequest.perform {
            try await client.from("groups").select()
                .order("created_at", ascending: false).order("id").execute().value
        }
    }

    func fetchGroup(id: UUID) async throws -> Group {
        try await SupabaseRequest.perform {
            try await client.from("groups").select()
                .eq("id", value: id.uuidString).single().execute().value
        }
    }

    func fetchMembers(groupID: UUID) async throws -> [GroupMember] {
        try await SupabaseRequest.perform {
            try await client.from("group_members").select()
                .eq("group_id", value: groupID.uuidString)
                .order("joined_at").order("id").execute().value
        }
    }

    func createGroup(_ input: GroupCreation) async throws -> UUID {
        try await SupabaseRequest.perform {
            try await client.rpc("create_group", params: input).execute().value
        }
    }

    func updateGroup(_ input: GroupUpdate) async throws {
        try await SupabaseRequest.perform {
            _ = try await client.rpc("update_group", params: input).execute()
        }
    }
}