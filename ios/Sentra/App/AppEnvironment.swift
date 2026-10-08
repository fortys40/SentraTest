import Foundation
import Observation

@MainActor
struct ServiceContainer {
    let auth: any AuthService
    let profiles: any ProfileService
    let groups: any GroupService
    let matches: any MatchService
    let rsvps: any RSVPService
    let guests: any GuestService
    let results: any ResultService
    let costs: any CostSplitService
    let voting: any VotingService
    let stats: any StatsService
    let rating: any RatingService
    let badges: any BadgeService
    let calendar: any CalendarService
    let notifications: any NotificationService

    static func preview(data: MockDataset, failure: AppError? = nil) -> ServiceContainer {
        let mock = MockServices(data: data, failure: failure)
        return ServiceContainer(
            auth: mock, profiles: mock, groups: mock, matches: mock, rsvps: mock,
            guests: mock, results: mock, costs: mock, voting: mock, stats: mock,
            rating: mock, badges: mock, calendar: mock, notifications: mock
        )
    }
}

@MainActor
@Observable
final class AppEnvironment {
    enum Mode { case preview, live }

    let services: ServiceContainer
    let mode: Mode
    let previewData: MockDataset?
    let router: AppRouter
    let deepLinkHandler = DeepLinkHandler()
    private let provider: SupabaseProvider?

    init(services: ServiceContainer, mode: Mode, previewData: MockDataset? = nil,
         provider: SupabaseProvider? = nil) {
        self.services = services
        self.mode = mode
        self.previewData = previewData
        self.provider = provider
        router = AppRouter()
    }

    static func preview(data: MockDataset = MockDataFactory.make(), failure: AppError? = nil) -> AppEnvironment {
        AppEnvironment(services: .preview(data: data, failure: failure), mode: .preview, previewData: data)
    }

    static func live(configuration: AppConfiguration) -> AppEnvironment {
        let provider = SupabaseProvider(configuration: configuration)
        let client = provider.client
        let deferred = UnavailableServices()
        let services = ServiceContainer(
            auth: LiveAuthService(client: client), profiles: LiveProfileService(client: client),
            groups: LiveGroupService(client: client), matches: LiveMatchService(client: client),
            rsvps: LiveRSVPService(client: client), guests: deferred, results: deferred,
            costs: deferred, voting: deferred, stats: deferred, rating: deferred, badges: deferred,
            calendar: deferred, notifications: deferred
        )
        return AppEnvironment(services: services, mode: .live, provider: provider)
    }

    static func live(bundle: Bundle = .main) throws -> AppEnvironment {
        live(configuration: try AppConfiguration.load(bundle: bundle))
    }
}