import XCTest
@testable import Sentra

final class ServiceRequestTests: XCTestCase {
    func testProfileUpdateCanClearAvatarAndCannotWriteProtectedFields() throws {
        let update = ProfileUpdate(displayName: "Test", position: .midfielder, avatarURL: nil, onboardingCompleted: true)
        let payload = try object(update)
        XCTAssertEqual(Set(payload.keys), Set(["display_name", "position", "avatar_url", "onboarding_completed"]))
        XCTAssertEqual(payload["avatar_url"], .null)
        XCTAssertEqual(payload["position"], .string("MID"))
        XCTAssertNil(payload["id"])
        XCTAssertNil(payload["created_at"])
    }

    func testMatchCreationUsesExactRPCKeysAndDecimalWithoutCapacity() throws {
        let groupID = MockDataFactory.identifier(0x30, 1)
        let date = MockDataFactory.referenceDate
        let input = MatchCreation(
            groupID: groupID, startsAt: date, venue: "Test pitch", format: "7x7",
            expectedCost: Decimal(string: "60.01"), rsvpLockAt: date.addingTimeInterval(-7_200)
        )
        let payload = try object(input)
        XCTAssertEqual(Set(payload.keys), Set(["p_group_id", "p_starts_at", "p_venue", "p_format", "p_expected_cost", "p_rsvp_lock_at"]))
        XCTAssertEqual(payload["p_expected_cost"], .number(try XCTUnwrap(Decimal(string: "60.01"))))
        XCTAssertEqual(payload["p_starts_at"], .string(SentraJSON.timestamp(from: date)))
        XCTAssertNil(payload["capacity"])
        XCTAssertNil(payload["p_owner_id"])
    }

    func testCreationDefaultsAreOmittedForTheDatabaseToDecide() throws {
        let input = MatchCreation(
            groupID: MockDataFactory.identifier(0x30, 1), startsAt: MockDataFactory.referenceDate,
            venue: "Test pitch", format: nil, expectedCost: nil, rsvpLockAt: nil
        )
        let payload = try object(input)
        XCTAssertEqual(Set(payload.keys), Set(["p_group_id", "p_starts_at", "p_venue"]))
    }

    private func object<Value: Encodable>(_ value: Value) throws -> [String: JSONValue] {
        try SentraJSON.decoder().decode([String: JSONValue].self, from: SentraJSON.encoder().encode(value))
    }
}