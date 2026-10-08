import XCTest
@testable import Sentra

final class ModelDecodingTests: XCTestCase {
    func testAllSupportedCapacitiesAndNewCatalogRows() throws {
        let formats: [MatchFormat] = [.fiveASide, .sevenASide, .eightASide, .elevenASide]
        XCTAssertEqual(formats.map(\.capacity), [10, 14, 16, 22])
        let future = try SentraJSON.decoder().decode(MatchFormat.self, from: Data(
            #"{"code":"6x6","players_per_team":6,"active":true}"#.utf8
        ))
        XCTAssertEqual(future.capacity, 12)
        XCTAssertEqual(future.id, "6x6")
    }

    func testRepresentativeSupabaseRowsDecodeWithoutInventedFields() throws {
        let rows = try fixture()
        XCTAssertEqual(rows.profile.position, .goalkeeper)
        XCTAssertNil(rows.profile.avatarURL)
        XCTAssertEqual(rows.group.ownerID, rows.profile.id)
        XCTAssertEqual(rows.member.role, .owner)
        XCTAssertEqual(rows.match.status, .finished)
        XCTAssertEqual(rows.match.winner, .a)
        XCTAssertEqual(rows.match.capacity, rows.match.playersPerTeam * 2)
        XCTAssertNil(rows.guest.claimedByUserID)
        XCTAssertNil(rows.participant.userID)
        XCTAssertEqual(rows.participant.guestID, rows.guest.id)
        XCTAssertEqual(rows.payment.includesGuestIDs, [rows.guest.id])
        XCTAssertNil(rows.payment.paidAt)
        XCTAssertEqual(rows.vote.votedParticipantID, rows.mvpResult.participantID)
        XCTAssertNil(rows.vote.votedUserID)
        XCTAssertEqual(rows.badgeDefinition.ruleParams["threshold"], .number(5))
        XCTAssertEqual(rows.playerBadge.badgeCode, rows.badgeDefinition.code)
        XCTAssertNil(rows.playerBadge.groupID)
    }

    func testDatesAcceptSupabaseOffsetsAndFractionalSeconds() throws {
        let rows = try fixture()
        let expected = try XCTUnwrap(SentraJSON.date(from: "2026-10-06T18:00:00.123456Z"))
        XCTAssertEqual(rows.match.startsAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.000001)
        XCTAssertEqual(rows.profile.updatedAt, rows.match.startsAt)
        XCTAssertThrowsError(try SentraJSON.decoder().decode(Date.self, from: Data(#""2026-10-06T21:00:00""#.utf8)))
    }

    func testCalendarOnlyValuesAreNotConvertedToUTCInstants() throws {
        let rows = try fixture()
        XCTAssertEqual(rows.series.startTime, "21:00:00.123456")
        XCTAssertEqual(rows.series.timezone, "Europe/Athens")
        XCTAssertEqual(rows.match.occurrenceDate, "2026-10-06")
        XCTAssertEqual(rows.skip.occurrenceDate, "2026-10-27")
        XCTAssertEqual(rows.series.rsvpLockHours, Decimal(string: "2.50"))
    }

    func testDecimalMoneyRetainsPrecisionAndSignedRemainder() throws {
        let rows = try fixture()
        XCTAssertEqual(rows.moneySamples[0] + rows.moneySamples[1], rows.moneySamples[2])
        XCTAssertEqual(rows.moneySamples[3], Decimal(string: "9999999999.99"))
        XCTAssertEqual(rows.match.expectedCost, Decimal(string: "60.01"))
        XCTAssertEqual(rows.match.roundingRemainder, Decimal(string: "-0.50"))
        let encoded = try SentraJSON.encoder().encode(rows.moneySamples)
        XCTAssertEqual(try SentraJSON.decoder().decode([Decimal].self, from: encoded), rows.moneySamples)
    }

    func testWaitlistProjectionDecodesFlatJSONAndPreservesInt64Tickets() throws {
        let rows = try fixture()
        XCTAssertEqual(rows.waitlistResponse.response, rows.rsvp)
        XCTAssertEqual(rows.rsvp.waitlistOrder, 9_007_199_254_740_993)
        XCTAssertEqual(rows.waitlistResponse.positionInWaitlist, 1)
        let encoded = try SentraJSON.encoder().encode(rows.waitlistResponse)
        let decoded = try SentraJSON.decoder().decode(RSVPWithWaitlistPosition.self, from: encoded)
        XCTAssertEqual(decoded.id, rows.waitlistResponse.id)
        XCTAssertEqual(decoded.response.status, rows.rsvp.status)
        XCTAssertEqual(decoded.response.waitlistOrder, rows.rsvp.waitlistOrder)
        XCTAssertEqual(decoded.positionInWaitlist, rows.waitlistResponse.positionInWaitlist)
        XCTAssertEqual(decoded.response.updatedAt.timeIntervalSince1970, rows.rsvp.updatedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func testOverallStatsPreserveNullGroupAndUnknownWinPercentage() throws {
        let rows = try fixture()
        XCTAssertEqual(rows.stats.winPercentage, Decimal(string: "58.3"))
        XCTAssertNil(rows.statsWithoutResults.winPercentage)
        XCTAssertNil(rows.statsWithoutResults.groupID)
        XCTAssertNotEqual(rows.stats.id, rows.statsWithoutResults.id)
        XCTAssertEqual(rows.votingState.eligibleVoters, 2)
        XCTAssertTrue(rows.votingState.hasVoted)
    }

    func testRoundTripAndMissingRequiredFields() throws {
        let rows = try fixture()
        let encoded = try SentraJSON.encoder().encode(rows.match)
        let decoded = try SentraJSON.decoder().decode(Match.self, from: encoded)
        XCTAssertEqual(decoded.id, rows.match.id)
        XCTAssertEqual(decoded.totalCost, rows.match.totalCost)
        XCTAssertEqual(decoded.startsAt.timeIntervalSince1970, rows.match.startsAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertThrowsError(try SentraJSON.decoder().decode(Profile.self, from: Data(#"{"display_name":"Test"}"#.utf8)))
        XCTAssertThrowsError(try SentraJSON.decoder().decode(RSVPStatus.self, from: Data(#""YES""#.utf8)))
    }

    func testTierBoundariesAreOnlyPresentation() {
        let values = [50, 64, 65, 74, 75, 84, 85, 99]
        XCTAssertEqual(values.map { CardTier(overall: $0) }, [.bronze, .bronze, .silver, .silver, .gold, .gold, .elite, .elite])
    }

    private func fixture() throws -> FixtureRows {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "supabase-rows", withExtension: "json"))
        return try SentraJSON.decoder().decode(FixtureRows.self, from: Data(contentsOf: url))
    }
}

private struct FixtureRows: Decodable {
    let format: MatchFormat
    let profile: Profile
    let group: Group
    let member: GroupMember
    let invite: GroupInvite
    let guest: Guest
    let series: MatchSeries
    let skip: SeriesSkip
    let match: Match
    let rsvp: RSVP
    let waitlistResponse: RSVPWithWaitlistPosition
    let history: RSVPHistoryEntry
    let counts: MatchRSVPCounts
    let participant: MatchParticipant
    let goal: Goal
    let payment: Payment
    let outstandingPayment: OutstandingPayment
    let eligibleVoter: MVPEligibleVoter
    let vote: MVPVote
    let mvpResult: MVPResult
    let votingState: VotingState
    let stats: PlayerStats
    let statsWithoutResults: PlayerStats
    let lateCancellation: LateCancellation
    let badgeDefinition: BadgeDefinition
    let playerBadge: PlayerBadge
    let deviceToken: DeviceToken
    let webResponder: WebResponder
    let moneySamples: [Decimal]
}