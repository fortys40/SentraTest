import Foundation

@MainActor
protocol AuthService {
    func currentUserID() async throws -> UUID?
    func signOut() async throws
}

@MainActor
protocol ProfileService {
    func fetchProfile(id: UUID) async throws -> Profile
    func fetchProfiles(ids: [UUID]) async throws -> [Profile]
    func updateProfile(_ update: ProfileUpdate) async throws -> Profile
}

@MainActor
protocol GroupService {
    func fetchGroups() async throws -> [Group]
    func fetchGroup(id: UUID) async throws -> Group
    func fetchMembers(groupID: UUID) async throws -> [GroupMember]
    func createGroup(_ input: GroupCreation) async throws -> UUID
    func updateGroup(_ input: GroupUpdate) async throws
}

@MainActor
protocol MatchService {
    func fetchFormats() async throws -> [MatchFormat]
    func fetchMatches(groupID: UUID) async throws -> [Match]
    func fetchMatch(id: UUID) async throws -> Match
    func createMatch(_ input: MatchCreation) async throws -> UUID
    func updateMatch(_ input: MatchUpdate) async throws
    func cancelMatch(id: UUID) async throws
}

@MainActor
protocol RSVPService {
    func fetchResponses(matchID: UUID) async throws -> [RSVPWithWaitlistPosition]
    func fetchCounts(matchID: UUID) async throws -> MatchRSVPCounts
}

@MainActor
protocol GuestService {
    func fetchGuests(groupID: UUID) async throws -> [Guest]
}

@MainActor
protocol ResultService {
    func fetchParticipants(matchID: UUID) async throws -> [MatchParticipant]
    func fetchGoals(matchID: UUID) async throws -> [Goal]
}

@MainActor
protocol CostSplitService {
    func fetchPayments(matchID: UUID) async throws -> [Payment]
}

@MainActor
protocol VotingService {
    func fetchVotingState(matchID: UUID) async throws -> VotingState
    func fetchMVPResults(matchID: UUID) async throws -> [MVPResult]
}

@MainActor
protocol StatsService {
    func fetchStats(userID: UUID, groupID: UUID?) async throws -> PlayerStats
}

@MainActor
protocol RatingService {
    func fetchRatingHistory(userID: UUID, groupID: UUID) async throws -> [RatingHistoryEntry]
}

@MainActor
protocol BadgeService {
    func fetchBadgeDefinitions() async throws -> [BadgeDefinition]
    func fetchBadges(userID: UUID, groupID: UUID?) async throws -> [PlayerBadge]
}

enum PermissionState: String, Codable, Hashable, Sendable {
    case notDetermined
    case authorized
    case denied
}

@MainActor
protocol CalendarService {
    func calendarPermission() async throws -> PermissionState
    func addMatchToCalendar(_ match: Match) async throws -> String
}

@MainActor
protocol NotificationService {
    func notificationPermission() async throws -> PermissionState
    func requestNotificationPermission() async throws -> PermissionState
}