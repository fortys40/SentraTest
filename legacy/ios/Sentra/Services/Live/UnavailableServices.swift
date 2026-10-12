import Foundation

@MainActor
final class UnavailableServices: GuestService, ResultService, CostSplitService, VotingService,
    StatsService, RatingService, BadgeService, CalendarService, NotificationService {
    func fetchGuests(groupID: UUID) async throws -> [Guest] { throw AppError.unavailable }
    func fetchParticipants(matchID: UUID) async throws -> [MatchParticipant] { throw AppError.unavailable }
    func fetchGoals(matchID: UUID) async throws -> [Goal] { throw AppError.unavailable }
    func fetchPayments(matchID: UUID) async throws -> [Payment] { throw AppError.unavailable }
    func fetchVotingState(matchID: UUID) async throws -> VotingState { throw AppError.unavailable }
    func fetchMVPResults(matchID: UUID) async throws -> [MVPResult] { throw AppError.unavailable }
    func fetchStats(userID: UUID, groupID: UUID?) async throws -> PlayerStats { throw AppError.unavailable }
    func fetchRatingHistory(userID: UUID, groupID: UUID) async throws -> [RatingHistoryEntry] { throw AppError.unavailable }
    func fetchBadgeDefinitions() async throws -> [BadgeDefinition] { throw AppError.unavailable }
    func fetchBadges(userID: UUID, groupID: UUID?) async throws -> [PlayerBadge] { throw AppError.unavailable }
    func calendarPermission() async throws -> PermissionState { throw AppError.unavailable }
    func addMatchToCalendar(_ match: Match) async throws -> String { throw AppError.unavailable }
    func notificationPermission() async throws -> PermissionState { throw AppError.unavailable }
    func requestNotificationPermission() async throws -> PermissionState { throw AppError.unavailable }
}