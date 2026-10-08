import Foundation

struct ProfileUpdate: Encodable, Hashable, Sendable {
    let displayName: String
    let position: FootballPosition
    let avatarURL: String?
    let onboardingCompleted: Bool

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(position, forKey: .position)
        if let avatarURL {
            try container.encode(avatarURL, forKey: .avatarURL)
        } else {
            try container.encodeNil(forKey: .avatarURL)
        }
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case position
        case avatarURL = "avatar_url"
        case onboardingCompleted = "onboarding_completed"
    }
}

struct GroupCreation: Encodable, Hashable, Sendable {
    let name: String
    let defaultFormat: String

    enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case defaultFormat = "p_default_format"
    }
}

struct GroupUpdate: Encodable, Hashable, Sendable {
    let groupID: UUID
    let name: String
    let defaultFormat: String

    enum CodingKeys: String, CodingKey {
        case groupID = "p_group_id"
        case name = "p_name"
        case defaultFormat = "p_default_format"
    }
}

struct MatchCreation: Encodable, Hashable, Sendable {
    let groupID: UUID
    let startsAt: Date
    let venue: String
    let format: String?
    let expectedCost: Decimal?
    let rsvpLockAt: Date?

    enum CodingKeys: String, CodingKey {
        case groupID = "p_group_id"
        case startsAt = "p_starts_at"
        case venue = "p_venue"
        case format = "p_format"
        case expectedCost = "p_expected_cost"
        case rsvpLockAt = "p_rsvp_lock_at"
    }
}

struct MatchUpdate: Encodable, Hashable, Sendable {
    let matchID: UUID
    let startsAt: Date
    let venue: String
    let format: String
    let rsvpLockAt: Date
    let expectedCost: Decimal?

    enum CodingKeys: String, CodingKey {
        case matchID = "p_match_id"
        case startsAt = "p_starts_at"
        case venue = "p_venue"
        case format = "p_format"
        case rsvpLockAt = "p_rsvp_lock_at"
        case expectedCost = "p_expected_cost"
    }
}

struct MatchIdentifier: Encodable, Hashable, Sendable {
    let matchID: UUID

    enum CodingKeys: String, CodingKey {
        case matchID = "p_match_id"
    }
}