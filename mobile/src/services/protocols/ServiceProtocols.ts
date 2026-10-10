import type { UUID } from '@/core/utilities/SentraJSON';
import type {
  BadgeDefinition,
  Goal,
  Group,
  GroupMember,
  Guest,
  Match,
  MatchFormat,
  MatchParticipant,
  MatchRSVPCounts,
  MVPResult,
  Payment,
  PlayerBadge,
  PlayerStats,
  Profile,
  RatingHistoryEntry,
  RSVPWithWaitlistPosition,
  VotingState,
} from '@/models';

import type { GroupCreation, GroupUpdate, MatchCreation, MatchUpdate, ProfileUpdate } from './ServiceRequests';

export interface AuthService {
  currentUserID(): Promise<UUID | null>;
  signOut(): Promise<void>;
}

export interface ProfileService {
  fetchProfile(id: UUID): Promise<Profile>;
  fetchProfiles(ids: UUID[]): Promise<Profile[]>;
  updateProfile(update: ProfileUpdate): Promise<Profile>;
}

export interface GroupService {
  fetchGroups(): Promise<Group[]>;
  fetchGroup(id: UUID): Promise<Group>;
  fetchMembers(groupID: UUID): Promise<GroupMember[]>;
  createGroup(input: GroupCreation): Promise<UUID>;
  updateGroup(input: GroupUpdate): Promise<void>;
}

export interface MatchService {
  fetchFormats(): Promise<MatchFormat[]>;
  fetchMatches(groupID: UUID): Promise<Match[]>;
  fetchMatch(id: UUID): Promise<Match>;
  createMatch(input: MatchCreation): Promise<UUID>;
  updateMatch(input: MatchUpdate): Promise<void>;
  cancelMatch(id: UUID): Promise<void>;
}

export interface RSVPService {
  fetchResponses(matchID: UUID): Promise<RSVPWithWaitlistPosition[]>;
  fetchCounts(matchID: UUID): Promise<MatchRSVPCounts>;
}

export interface GuestService {
  fetchGuests(groupID: UUID): Promise<Guest[]>;
}

export interface ResultService {
  fetchParticipants(matchID: UUID): Promise<MatchParticipant[]>;
  fetchGoals(matchID: UUID): Promise<Goal[]>;
}

export interface CostSplitService {
  fetchPayments(matchID: UUID): Promise<Payment[]>;
}

export interface VotingService {
  fetchVotingState(matchID: UUID): Promise<VotingState>;
  fetchMVPResults(matchID: UUID): Promise<MVPResult[]>;
}

export interface StatsService {
  fetchStats(userID: UUID, groupID: UUID | null): Promise<PlayerStats>;
}

export interface RatingService {
  fetchRatingHistory(userID: UUID, groupID: UUID): Promise<RatingHistoryEntry[]>;
}

export interface BadgeService {
  fetchBadgeDefinitions(): Promise<BadgeDefinition[]>;
  fetchBadges(userID: UUID, groupID: UUID | null): Promise<PlayerBadge[]>;
}

export type PermissionState = 'notDetermined' | 'authorized' | 'denied';

export interface CalendarService {
  calendarPermission(): Promise<PermissionState>;
  addMatchToCalendar(match: Match): Promise<string>;
}

export interface NotificationService {
  notificationPermission(): Promise<PermissionState>;
  requestNotificationPermission(): Promise<PermissionState>;
}

export interface ServiceContainer {
  readonly auth: AuthService;
  readonly profiles: ProfileService;
  readonly groups: GroupService;
  readonly matches: MatchService;
  readonly rsvps: RSVPService;
  readonly guests: GuestService;
  readonly results: ResultService;
  readonly costs: CostSplitService;
  readonly voting: VotingService;
  readonly stats: StatsService;
  readonly rating: RatingService;
  readonly badges: BadgeService;
  readonly calendar: CalendarService;
  readonly notifications: NotificationService;
}
