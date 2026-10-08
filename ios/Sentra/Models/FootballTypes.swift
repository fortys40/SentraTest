import Foundation

enum FootballPosition: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case goalkeeper = "GK"
    case defender = "DEF"
    case midfielder = "MID"
    case forward = "FWD"
    case any = "ANY"

    var id: String { rawValue }
}

enum GroupRole: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case owner
    case admin
    case member

    var id: String { rawValue }
}

enum MatchStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case scheduled
    case locked
    case finished
    case cancelled

    var id: String { rawValue }
}

enum RSVPStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case yes
    case maybe
    case no
    case waitlist

    var id: String { rawValue }
}

enum TeamSide: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case a = "A"
    case b = "B"

    var id: String { rawValue }
}

enum MatchWinner: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case a = "A"
    case b = "B"
    case draw

    var id: String { rawValue }
}

struct MatchFormat: Codable, Identifiable, Hashable, Sendable {
    let code: String
    let playersPerTeam: Int
    let active: Bool

    var id: String { code }
    var capacity: Int { playersPerTeam * 2 }

    static let fiveASide = MatchFormat(code: "5x5", playersPerTeam: 5, active: true)
    static let sevenASide = MatchFormat(code: "7x7", playersPerTeam: 7, active: true)
    static let eightASide = MatchFormat(code: "8x8", playersPerTeam: 8, active: true)
    static let elevenASide = MatchFormat(code: "11x11", playersPerTeam: 11, active: true)

    enum CodingKeys: String, CodingKey {
        case code
        case playersPerTeam = "players_per_team"
        case active
    }
}