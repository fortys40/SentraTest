import Foundation
import Observation

struct DashboardSnapshot: Sendable {
    let group: Group
    let match: Match
    let counts: MatchRSVPCounts
    let profiles: [Profile]
    let guests: [Guest]
    let responses: [RSVPWithWaitlistPosition]
    let cards: [PlayerCardExample]
}

@MainActor
@Observable
final class StepTwoDashboardViewModel {
    enum State {
        case loading
        case loaded(DashboardSnapshot)
        case failed(AppError)
    }

    private(set) var state: State = .loading
    private let environment: AppEnvironment

    init(environment: AppEnvironment) { self.environment = environment }

    func load() async {
        guard environment.mode == .preview, let data = environment.previewData else {
            state = .failed(.unavailable)
            return
        }
        state = .loading
        do {
            let services = environment.services
            let group = try await services.groups.fetchGroup(id: data.group.id)
            let match = try await services.matches.fetchMatch(id: data.upcomingMatch.id)
            let counts = try await services.rsvps.fetchCounts(matchID: match.id)
            let profiles = try await services.profiles.fetchProfiles(ids: data.profiles.map(\.id))
            let guests = try await services.guests.fetchGuests(groupID: group.id)
            let responses = try await services.rsvps.fetchResponses(matchID: match.id)
            try Task.checkCancellation()
            state = .loaded(DashboardSnapshot(
                group: group, match: match, counts: counts, profiles: profiles, guests: guests,
                responses: responses, cards: data.cardExamples
            ))
        } catch is CancellationError {
            return
        } catch {
            state = .failed((error as? AppError) ?? .unexpected)
        }
    }
}