import Foundation

@MainActor
final class MockServices: AuthService, ProfileService, GroupService, MatchService, RSVPService,
    GuestService, ResultService, CostSplitService, VotingService, StatsService, RatingService,
    BadgeService, CalendarService, NotificationService {
    let data: MockDataset
    private let failure: AppError?

    init(data: MockDataset = MockDataFactory.make(), failure: AppError? = nil) {
        self.data = data
        self.failure = failure
    }

    func currentUserID() async throws -> UUID? { try result(data.profiles.first?.id) }
    func signOut() async throws { throw AppError.unavailable }

    func fetchProfile(id: UUID) async throws -> Profile {
        try required(data.profiles.first { $0.id == id })
    }

    func fetchProfiles(ids: [UUID]) async throws -> [Profile] {
        try result(data.profiles.filter { ids.contains($0.id) })
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> Profile { throw AppError.unavailable }
    func fetchGroups() async throws -> [Group] { try result([data.group]) }

    func fetchGroup(id: UUID) async throws -> Group {
        try required(data.group.id == id ? data.group : nil)
    }

    func fetchMembers(groupID: UUID) async throws -> [GroupMember] {
        try result(data.members.filter { $0.groupID == groupID })
    }

    func createGroup(_ input: GroupCreation) async throws -> UUID { throw AppError.unavailable }
    func updateGroup(_ input: GroupUpdate) async throws { throw AppError.unavailable }

    func fetchFormats() async throws -> [MatchFormat] {
        try result([.fiveASide, .sevenASide, .eightASide, .elevenASide])
    }

    func fetchMatches(groupID: UUID) async throws -> [Match] {
        try result(data.matches.filter { $0.groupID == groupID })
    }

    func fetchMatch(id: UUID) async throws -> Match {
        try required(data.matches.first { $0.id == id })
    }

    func createMatch(_ input: MatchCreation) async throws -> UUID { throw AppError.unavailable }
    func updateMatch(_ input: MatchUpdate) async throws { throw AppError.unavailable }
    func cancelMatch(id: UUID) async throws { throw AppError.unavailable }

    func fetchResponses(matchID: UUID) async throws -> [RSVPWithWaitlistPosition] {
        try result(data.responses.filter { $0.response.matchID == matchID })
    }

    func fetchCounts(matchID: UUID) async throws -> MatchRSVPCounts {
        let match = try required(data.matches.first { $0.id == matchID })
        let responses = data.responses.filter { $0.response.matchID == matchID }.map(\.response)
        return MatchRSVPCounts(
            matchID: match.id, groupID: match.groupID, capacity: match.capacity,
            yesCount: Int64(responses.filter { $0.status == .yes }.count),
            maybeCount: Int64(responses.filter { $0.status == .maybe }.count),
            noCount: Int64(responses.filter { $0.status == .no }.count),
            waitlistCount: Int64(responses.filter { $0.status == .waitlist }.count)
        )
    }

    func fetchGuests(groupID: UUID) async throws -> [Guest] {
        try result(data.guests.filter { $0.groupID == groupID })
    }

    func fetchParticipants(matchID: UUID) async throws -> [MatchParticipant] {
        try result(data.participants.filter { $0.matchID == matchID })
    }

    func fetchGoals(matchID: UUID) async throws -> [Goal] {
        try result(data.goals.filter { $0.matchID == matchID })
    }

    func fetchPayments(matchID: UUID) async throws -> [Payment] {
        try result(data.payments.filter { $0.matchID == matchID })
    }

    func fetchVotingState(matchID: UUID) async throws -> VotingState {
        let match = try required(data.matches.first { $0.id == matchID })
        let participants = data.participants.filter { $0.matchID == matchID && $0.userID != nil }
        return VotingState(
            eligibleVoters: Int64(participants.count),
            votesCast: match.mvpClosedAt == nil ? 0 : Int64(participants.count),
            hasVoted: match.mvpClosedAt != nil && participants.contains { $0.userID == data.group.ownerID },
            closesAt: match.mvpVotingClosesAt, closedAt: match.mvpClosedAt
        )
    }

    func fetchMVPResults(matchID: UUID) async throws -> [MVPResult] {
        try result(data.mvpResults.filter { $0.matchID == matchID })
    }

    func fetchStats(userID: UUID, groupID: UUID?) async throws -> PlayerStats {
        try required(data.stats.first { $0.userID == userID && $0.groupID == groupID })
    }

    func fetchRatingHistory(userID: UUID, groupID: UUID) async throws -> [RatingHistoryEntry] {
        try result(data.ratingHistory.filter { $0.userID == userID && $0.groupID == groupID }
            .sorted { $0.recordedAt < $1.recordedAt })
    }

    func fetchBadgeDefinitions() async throws -> [BadgeDefinition] { try result(data.badgeDefinitions) }

    func fetchBadges(userID: UUID, groupID: UUID?) async throws -> [PlayerBadge] {
        try result(data.badges.filter { $0.userID == userID && $0.groupID == groupID })
    }

    func calendarPermission() async throws -> PermissionState { try result(.notDetermined) }
    func addMatchToCalendar(_ match: Match) async throws -> String { throw AppError.unavailable }
    func notificationPermission() async throws -> PermissionState { try result(.notDetermined) }
    func requestNotificationPermission() async throws -> PermissionState { throw AppError.unavailable }

    private func result<Value>(_ value: Value) throws -> Value {
        if let failure { throw failure }
        return value
    }

    private func required<Value>(_ value: Value?) throws -> Value {
        if let failure { throw failure }
        guard let value else { throw AppError.notFound }
        return value
    }
}