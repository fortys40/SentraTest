import Foundation

struct Match: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let groupID: UUID
    let seriesID: UUID?
    let occurrenceDate: String?
    let format: String
    let playersPerTeam: Int
    let capacity: Int
    let venue: String
    let startsAt: Date
    let rsvpLockAt: Date
    let expectedCost: Decimal?
    let status: MatchStatus
    let winner: MatchWinner?
    let scoreA: Int?
    let scoreB: Int?
    let goalsRecorded: Bool
    let finishedAt: Date?
    let mvpVotingClosesAt: Date?
    let mvpClosedAt: Date?
    let costSplitEnabled: Bool
    let totalCost: Decimal?
    let paidBy: UUID?
    let shareAmount: Decimal?
    let roundingRemainder: Decimal?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case seriesID = "series_id"
        case occurrenceDate = "occurrence_date"
        case format
        case playersPerTeam = "players_per_team"
        case capacity
        case venue
        case startsAt = "starts_at"
        case rsvpLockAt = "rsvp_lock_at"
        case expectedCost = "expected_cost"
        case status
        case winner
        case scoreA = "score_a"
        case scoreB = "score_b"
        case goalsRecorded = "goals_recorded"
        case finishedAt = "finished_at"
        case mvpVotingClosesAt = "mvp_voting_closes_at"
        case mvpClosedAt = "mvp_closed_at"
        case costSplitEnabled = "cost_split_enabled"
        case totalCost = "total_cost"
        case paidBy = "paid_by"
        case shareAmount = "share_amount"
        case roundingRemainder = "rounding_remainder"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct MatchSeries: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let groupID: UUID
    let weekday: Int
    let startTime: String
    let timezone: String
    let venue: String
    let format: String
    let playersPerTeam: Int
    let defaultCost: Decimal?
    let createDaysBefore: Int
    let rsvpLockHours: Decimal
    let active: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "group_id"
        case weekday
        case startTime = "start_time"
        case timezone
        case venue
        case format
        case playersPerTeam = "players_per_team"
        case defaultCost = "default_cost"
        case createDaysBefore = "create_days_before"
        case rsvpLockHours = "rsvp_lock_hours"
        case active
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SeriesSkip: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let seriesID: UUID
    let occurrenceDate: String
    let createdBy: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case seriesID = "series_id"
        case occurrenceDate = "occurrence_date"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct MatchParticipant: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let groupID: UUID
    let userID: UUID?
    let guestID: UUID?
    let team: TeamSide?
    let chargedToUserID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case groupID = "group_id"
        case userID = "user_id"
        case guestID = "guest_id"
        case team
        case chargedToUserID = "charged_to_user_id"
        case createdAt = "created_at"
    }
}

struct Goal: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let scorerParticipantID: UUID
    let team: TeamSide
    let minute: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case scorerParticipantID = "scorer_participant_id"
        case team
        case minute
        case createdAt = "created_at"
    }
}