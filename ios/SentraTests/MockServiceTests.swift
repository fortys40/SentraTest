import XCTest
@testable import Sentra

final class MockServiceTests: XCTestCase {
    func testFactoryIsDeterministicIncludingIDsAndTimestamps() {
        XCTAssertEqual(MockDataFactory.make(), MockDataFactory.make())
    }

    func testFixtureHasAllRequestedScenariosAndConsistentRosters() {
        let data = MockDataFactory.make()
        XCTAssertEqual(data.profiles.count, 12)
        XCTAssertEqual(data.members.count, 12)
        XCTAssertEqual(data.guests.count, 1)
        XCTAssertEqual(data.pastMatches.count, 6)
        XCTAssertEqual(Set(data.responses.map(\.response.status)), Set(RSVPStatus.allCases))
        XCTAssertEqual(data.responses.filter { $0.response.status == .yes }.count, data.upcomingMatch.capacity)
        XCTAssertEqual(data.responses.filter { $0.response.guestID != nil && $0.response.status == .yes }.count, 1)
        XCTAssertEqual(Set(data.cardExamples.map(\.design.tier)), Set(CardTier.allCases))
        for match in data.pastMatches {
            let roster = data.participants.filter { $0.matchID == match.id }
            XCTAssertEqual(roster.count, match.capacity)
            XCTAssertEqual(Set(roster.compactMap(\.userID)).count, match.capacity)
            XCTAssertNotNil(match.mvpClosedAt)
            XCTAssertEqual(data.mvpResults.filter { $0.matchID == match.id }.count, 1)
        }
        XCTAssertEqual(data.badgeDefinitions.count, 3)
        XCTAssertEqual(data.badges.filter { $0.badgeCode == "mvp_5" }.count, 2)
    }

    func testFixedClockCanBeMovedWithoutChangingIdentities() {
        let initial = MockDataFactory.make()
        let moved = MockDataFactory.make(referenceDate: initial.referenceDate.addingTimeInterval(86_400))
        XCTAssertEqual(initial.profiles.map(\.id), moved.profiles.map(\.id))
        XCTAssertEqual(moved.upcomingMatch.startsAt.timeIntervalSince(initial.upcomingMatch.startsAt), 86_400)
    }

    @MainActor
    func testMockReadsAreRepeatableAndQueuePositionIsNotTicketNumber() async throws {
        let first = MockServices()
        let second = MockServices()
        let firstGroups = try await first.fetchGroups()
        let secondGroups = try await second.fetchGroups()
        XCTAssertEqual(firstGroups, secondGroups)
        let group = try XCTUnwrap(firstGroups.first)
        let matches = try await first.fetchMatches(groupID: group.id)
        let repeated = try await first.fetchMatches(groupID: group.id)
        XCTAssertEqual(matches, repeated)
        let upcoming = try XCTUnwrap(matches.first { $0.status == .scheduled })
        let counts = try await first.fetchCounts(matchID: upcoming.id)
        XCTAssertEqual(counts.yesCount, Int64(upcoming.capacity))
        XCTAssertEqual(counts.maybeCount, 1)
        XCTAssertEqual(counts.noCount, 1)
        XCTAssertEqual(counts.waitlistCount, 1)
        let responses = try await first.fetchResponses(matchID: upcoming.id)
        let waiter = try XCTUnwrap(responses.first { $0.response.status == .waitlist })
        XCTAssertEqual(waiter.positionInWaitlist, 1)
        XCTAssertEqual(waiter.response.waitlistOrder, 42)
    }

    @MainActor
    func testMockFailureIsDeterministicAndCommandsDoNotPretendToPersist() async {
        let failed = MockServices(failure: .network)
        do {
            _ = try await failed.fetchGroups()
            XCTFail("Expected the injected error")
        } catch {
            XCTAssertEqual(error as? AppError, .network)
        }
        let services = MockServices()
        do {
            _ = try await services.createGroup(GroupCreation(name: "Test", defaultFormat: "7x7"))
            XCTFail("Preview writes must not simulate business logic")
        } catch {
            XCTAssertEqual(error as? AppError, .unavailable)
        }
    }

    @MainActor
    func testStatsAndRatingsAgreeWithPreviewExamples() async throws {
        let services = MockServices()
        for card in services.data.cardExamples {
            let stats = try await services.fetchStats(userID: card.profile.id, groupID: services.data.group.id)
            let history = try await services.fetchRatingHistory(userID: card.profile.id, groupID: services.data.group.id)
            XCTAssertEqual(stats, card.stats)
            XCTAssertEqual(history.count, Int(stats.appearances))
            XCTAssertEqual(history.last?.overall, card.overall)
            XCTAssertEqual(card.design.tier, CardTier(overall: card.overall))
        }
    }
}