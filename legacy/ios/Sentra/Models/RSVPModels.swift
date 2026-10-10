import Foundation

struct RSVP: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let groupID: UUID
    let userID: UUID?
    let guestID: UUID?
    let status: RSVPStatus
    let waitlistedAt: Date?
    let waitlistOrder: Int64?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case groupID = "group_id"
        case userID = "user_id"
        case guestID = "guest_id"
        case status
        case waitlistedAt = "waitlisted_at"
        case waitlistOrder = "waitlist_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RSVPWithWaitlistPosition: Codable, Identifiable, Hashable, Sendable {
    let response: RSVP
    let positionInWaitlist: Int64?

    var id: UUID { response.id }

    init(response: RSVP, positionInWaitlist: Int64?) {
        self.response = response
        self.positionInWaitlist = positionInWaitlist
    }

    init(from decoder: Decoder) throws {
        response = try RSVP(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        positionInWaitlist = try container.decodeIfPresent(Int64.self, forKey: .positionInWaitlist)
    }

    func encode(to encoder: Encoder) throws {
        try response.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(positionInWaitlist, forKey: .positionInWaitlist)
    }

    enum CodingKeys: String, CodingKey {
        case positionInWaitlist = "position_in_waitlist"
    }
}

struct RSVPHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let rsvpID: UUID
    let matchID: UUID
    let groupID: UUID
    let userID: UUID?
    let guestID: UUID?
    let oldStatus: RSVPStatus?
    let newStatus: RSVPStatus
    let changedBy: UUID?
    let changedAt: Date
    let hoursBeforeKickoff: Decimal

    enum CodingKeys: String, CodingKey {
        case id
        case rsvpID = "rsvp_id"
        case matchID = "match_id"
        case groupID = "group_id"
        case userID = "user_id"
        case guestID = "guest_id"
        case oldStatus = "old_status"
        case newStatus = "new_status"
        case changedBy = "changed_by"
        case changedAt = "changed_at"
        case hoursBeforeKickoff = "hours_before_kickoff"
    }
}

struct MatchRSVPCounts: Codable, Identifiable, Hashable, Sendable {
    let matchID: UUID
    let groupID: UUID
    let capacity: Int
    let yesCount: Int64
    let maybeCount: Int64
    let noCount: Int64
    let waitlistCount: Int64

    var id: UUID { matchID }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case groupID = "group_id"
        case capacity
        case yesCount = "yes_count"
        case maybeCount = "maybe_count"
        case noCount = "no_count"
        case waitlistCount = "waitlist_count"
    }
}