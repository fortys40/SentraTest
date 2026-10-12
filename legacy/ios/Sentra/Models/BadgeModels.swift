import Foundation

struct BadgeDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let code: String
    let nameEL: String
    let emoji: String
    let descriptionEL: String
    let ruleParams: [String: JSONValue]
    let active: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case nameEL = "name_el"
        case emoji
        case descriptionEL = "description_el"
        case ruleParams = "rule_params"
        case active
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PlayerBadge: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let groupID: UUID?
    let badgeCode: String
    let ruleSnapshot: JSONValue
    let awardedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case groupID = "group_id"
        case badgeCode = "badge_code"
        case ruleSnapshot = "rule_snapshot"
        case awardedAt = "awarded_at"
    }
}