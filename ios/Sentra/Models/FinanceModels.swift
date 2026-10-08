import Foundation

struct Payment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let groupID: UUID
    let debtorUserID: UUID
    let amount: Decimal
    let includesGuestIDs: [UUID]
    let paid: Bool
    let paidAt: Date?
    let updatedBy: UUID?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case groupID = "group_id"
        case debtorUserID = "debtor_user_id"
        case amount
        case includesGuestIDs = "includes_guest_ids"
        case paid
        case paidAt = "paid_at"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct OutstandingPayment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let matchID: UUID
    let groupID: UUID
    let debtorUserID: UUID
    let amount: Decimal
    let includesGuestIDs: [UUID]
    let creditorUserID: UUID
    let creditorName: String

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case groupID = "group_id"
        case debtorUserID = "debtor_user_id"
        case amount
        case includesGuestIDs = "includes_guest_ids"
        case creditorUserID = "creditor_user_id"
        case creditorName = "creditor_name"
    }
}