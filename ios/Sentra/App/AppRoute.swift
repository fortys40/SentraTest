import Foundation

enum AppRoute: Hashable, Sendable {
    case welcome
    case profileSetup
    case groups
    case groupDetail(UUID)
    case createGroup
    case matchDetail(UUID)
    case createMatch(groupID: UUID)
    case invite(code: String)
    case finishMatch(UUID)
    case mvpVoting(UUID)
    case mvpResult(UUID)
    case playerCard(userID: UUID, groupID: UUID?)
    case profile
    case settings

    var title: LocalizedStringResource {
        switch self {
        case .welcome: return "route.welcome"
        case .profileSetup: return "route.profileSetup"
        case .groups: return "route.groups"
        case .groupDetail: return "route.groupDetail"
        case .createGroup: return "route.createGroup"
        case .matchDetail: return "route.matchDetail"
        case .createMatch: return "route.createMatch"
        case .invite: return "route.invite"
        case .finishMatch: return "route.finishMatch"
        case .mvpVoting: return "route.mvpVoting"
        case .mvpResult: return "route.mvpResult"
        case .playerCard: return "route.playerCard"
        case .profile: return "route.profile"
        case .settings: return "route.settings"
        }
    }
}