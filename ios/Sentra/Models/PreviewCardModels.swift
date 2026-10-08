import Foundation

enum CardTier: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case bronze
    case silver
    case gold
    case elite

    var id: String { rawValue }

    init(overall: Int) {
        switch overall {
        case ..<65: self = .bronze
        case 65..<75: self = .silver
        case 75..<85: self = .gold
        default: self = .elite
        }
    }
}

enum PreviewPlayerTitle: String, Codable, Hashable, Sendable {
    case wall
    case scorer
    case everPresent
    case mvpMachine
}

struct CardDesign: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let tier: CardTier
}

struct RatingHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    let groupID: UUID
    let matchID: UUID
    let overall: Int
    let recordedAt: Date
}

struct PlayerCardExample: Codable, Identifiable, Hashable, Sendable {
    let profile: Profile
    let groupName: String
    let stats: PlayerStats
    let overall: Int
    let title: PreviewPlayerTitle
    let design: CardDesign
    let badges: [BadgeDefinition]

    var id: String { "\(profile.id.uuidString):\(design.id)" }
}