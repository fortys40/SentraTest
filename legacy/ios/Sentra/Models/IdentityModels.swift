import Foundation

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let position: FootballPosition
    let avatarURL: String?
    let onboardingCompleted: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case position
        case avatarURL = "avatar_url"
        case onboardingCompleted = "onboarding_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Group: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let ownerID: UUID
    let defaultFormat: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerID = "owner_id"
        case defaultFormat = "default_format"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct GroupMember: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let groupID: UUID
    let userID: UUID
    let role: GroupRole
    let joinedAt: Date
    let leftAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
        case leftAt = "left_at"
    }
}

struct GroupInvite: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let groupID: UUID
    let createdBy: UUID
    let expiresAt: Date?
    let revokedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case groupID = "group_id"
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case revokedAt = "revoked_at"
        case createdAt = "created_at"
    }
}

struct Guest: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let groupID: UUID
    let name: String
    let invitedBy: UUID
    let claimedByUserID: UUID?
    let claimedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case name
        case invitedBy = "invited_by"
        case claimedByUserID = "claimed_by_user_id"
        case claimedAt = "claimed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}