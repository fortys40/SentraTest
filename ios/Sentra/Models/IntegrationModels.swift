import Foundation

struct DeviceToken: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let apnsToken: String
    let environment: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case apnsToken = "apns_token"
        case environment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WebResponder: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let groupID: UUID
    let inviteID: UUID
    let guestID: UUID
    let name: String
    let status: RSVPStatus
    let tokenHash: String
    let claimedByUserID: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case groupID = "group_id"
        case inviteID = "invite_id"
        case guestID = "guest_id"
        case name
        case status
        case tokenHash = "token_hash"
        case claimedByUserID = "claimed_by_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}