import XCTest
@testable import Sentra

final class AppFoundationTests: XCTestCase {
    @MainActor
    func testAllPlaceholderRoutesCanBePushedPoppedAndReset() {
        let router = AppRouter()
        let identifier = MockDataFactory.identifier(0x20, 1)
        let routes: [AppRoute] = [
            .welcome, .profileSetup, .groups, .groupDetail(identifier), .createGroup,
            .matchDetail(identifier), .createMatch(groupID: identifier), .invite(code: "preview"),
            .finishMatch(identifier), .mvpVoting(identifier), .mvpResult(identifier),
            .playerCard(userID: identifier, groupID: nil), .profile, .settings
        ]
        for route in routes { router.push(route) }
        XCTAssertEqual(router.path, routes)
        router.pop()
        XCTAssertEqual(router.path.count, routes.count - 1)
        router.reset()
        router.pop()
        XCTAssertTrue(router.path.isEmpty)
    }

    func testDeepLinksDoNotStartAuthenticationOrInviteWorkflowsYet() throws {
        let handler = DeepLinkHandler()
        XCTAssertNil(handler.route(for: try XCTUnwrap(URL(string: "sentra://auth/callback?code=test"))))
        XCTAssertNil(handler.route(for: try XCTUnwrap(URL(string: "https://example.test/i/preview"))))
    }

    @MainActor
    func testDashboardLoadsThroughInjectedOfflineServices() async throws {
        let environment = AppEnvironment.preview()
        XCTAssertEqual(environment.mode, .preview)
        let model = StepTwoDashboardViewModel(environment: environment)
        await model.load()
        guard case .loaded(let snapshot) = model.state else {
            XCTFail("Expected an offline snapshot")
            return
        }
        XCTAssertEqual(snapshot.profiles.count, 12)
        XCTAssertEqual(snapshot.responses.count, 13)
        XCTAssertEqual(snapshot.cards.count, 4)
        XCTAssertEqual(snapshot.counts.yesCount, Int64(snapshot.match.capacity))
    }

    @MainActor
    func testDashboardSurfacesInjectedErrors() async {
        let model = StepTwoDashboardViewModel(environment: .preview(failure: .network))
        await model.load()
        guard case .failed(let error) = model.state else {
            XCTFail("Expected the injected error state")
            return
        }
        XCTAssertEqual(error, .network)
    }

    @MainActor
    func testDeferredLiveServicesFailRatherThanPretendToHaveData() async {
        let deferred = UnavailableServices()
        do {
            _ = try await deferred.fetchRatingHistory(
                userID: MockDataFactory.identifier(0x20, 1), groupID: MockDataFactory.identifier(0x30, 1)
            )
            XCTFail("No deployed rating history table exists")
        } catch {
            XCTAssertEqual(error as? AppError, .unavailable)
        }
    }
}