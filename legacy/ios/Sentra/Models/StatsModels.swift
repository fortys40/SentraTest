import Foundation

struct PlayerStats: Codable, Identifiable, Hashable, Sendable {
    let userID: UUID
    let groupID: UUID?
    let appearances: Int64
    let wins: Int64
    let losses: Int64
    let draws: Int64
    let goals: Int64
    let mvpCount: Int64
    let winPercentage: Decimal?
    let currentStreak: Int64

    var id: String { "\(userID.uuidString):\(groupID?.uuidString ?? "overall")" }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case groupID = "group_id"
        case appearances
        case wins
        case losses
        case draws
        case goals
        case mvpCount = "mvp_count"
        case winPercentage = "win_pct"
        case currentStreak = "current_streak"
    }
}

struct LateCancellation: Codable, Identifiable, Hashable, Sendable {
    let badgeCode: String
    let userID: UUID
    let groupID: UUID
    let matchID: UUID
    let lastCancelledAt: Date

    var id: String { "\(badgeCode):\(userID.uuidString):\(matchID.uuidString)" }

    enum CodingKeys: String, CodingKey {
        case badgeCode = "badge_code"
        case userID = "user_id"
        case groupID = "group_id"
        case matchID = "match_id"
        case lastCancelledAt = "last_cancelled_at"
    }
}