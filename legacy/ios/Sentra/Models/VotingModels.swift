import Foundation

struct MVPVote: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let voterID: UUID
    let votedParticipantID: UUID
    let votedUserID: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case voterID = "voter_id"
        case votedParticipantID = "voted_participant_id"
        case votedUserID = "voted_user_id"
        case createdAt = "created_at"
    }
}

struct MVPEligibleVoter: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let voterID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case voterID = "voter_id"
    }
}

struct MVPResult: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let participantID: UUID
    let votes: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case participantID = "participant_id"
        case votes
        case createdAt = "created_at"
    }
}

struct VotingState: Codable, Hashable, Sendable {
    let eligibleVoters: Int64
    let votesCast: Int64
    let hasVoted: Bool
    let closesAt: Date?
    let closedAt: Date?

    enum CodingKeys: String, CodingKey {
        case eligibleVoters = "eligible_voters"
        case votesCast = "votes_cast"
        case hasVoted = "has_voted"
        case closesAt = "closes_at"
        case closedAt = "closed_at"
    }
}