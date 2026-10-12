import { AppError } from '@/core/utilities/AppError';
import type { UUID } from '@/core/utilities/SentraJSON';
import {
  elevenASide,
  eightASide,
  fiveASide,
  sevenASide,
  type BadgeDefinition,
  type Goal,
  type Group,
  type GroupMember,
  type Guest,
  type Match,
  type MatchFormat,
  type MatchParticipant,
  type MatchRSVPCounts,
  type MVPResult,
  type Payment,
  type PlayerBadge,
  type PlayerStats,
  type Profile,
  type RatingHistoryEntry,
  type RSVPStatus,
  type RSVPWithWaitlistPosition,
  type VotingState,
} from '@/models';

import type { PermissionState, ServiceContainer } from '../protocols/ServiceProtocols';
import { datasetMatches, makeMockDataset, type MockDataset } from './MockDataFactory';

type AllServices = {
  [Service in keyof ServiceContainer]: ServiceContainer[Service];
}[keyof ServiceContainer];
type UnionToIntersection<U> = (U extends unknown ? (value: U) => void : never) extends (value: infer I) => void
  ? I
  : never;

/**
 * Deterministic offline reads over one immutable dataset. Commands always fail
 * as unavailable: the preview must not imitate database business rules.
 */
export class MockServices implements UnionToIntersection<AllServices> {
  constructor(
    readonly data: MockDataset = makeMockDataset(),
    private readonly failure: AppError | null = null,
  ) {}

  async currentUserID(): Promise<UUID | null> {
    return this.result(this.data.profiles[0]?.id ?? null);
  }

  async signOut(): Promise<void> {
    throw new AppError('unavailable');
  }

  async fetchProfile(id: UUID): Promise<Profile> {
    return this.required(this.data.profiles.find((profile) => profile.id === id));
  }

  async fetchProfiles(ids: UUID[]): Promise<Profile[]> {
    return this.result(this.data.profiles.filter((profile) => ids.includes(profile.id)));
  }

  async updateProfile(): Promise<Profile> {
    throw new AppError('unavailable');
  }

  async fetchGroups(): Promise<Group[]> {
    return this.result([this.data.group]);
  }

  async fetchGroup(id: UUID): Promise<Group> {
    return this.required(this.data.group.id === id ? this.data.group : undefined);
  }

  async fetchMembers(groupID: UUID): Promise<GroupMember[]> {
    return this.result(this.data.members.filter((member) => member.groupID === groupID));
  }

  async createGroup(): Promise<UUID> {
    throw new AppError('unavailable');
  }

  async updateGroup(): Promise<void> {
    throw new AppError('unavailable');
  }

  async fetchFormats(): Promise<MatchFormat[]> {
    return this.result([fiveASide, sevenASide, eightASide, elevenASide]);
  }

  async fetchMatches(groupID: UUID): Promise<Match[]> {
    return this.result(datasetMatches(this.data).filter((match) => match.groupID === groupID));
  }

  async fetchMatch(id: UUID): Promise<Match> {
    return this.required(datasetMatches(this.data).find((match) => match.id === id));
  }

  async createMatch(): Promise<UUID> {
    throw new AppError('unavailable');
  }

  async updateMatch(): Promise<void> {
    throw new AppError('unavailable');
  }

  async cancelMatch(): Promise<void> {
    throw new AppError('unavailable');
  }

  async fetchResponses(matchID: UUID): Promise<RSVPWithWaitlistPosition[]> {
    return this.result(this.data.responses.filter((entry) => entry.response.matchID === matchID));
  }

  async fetchCounts(matchID: UUID): Promise<MatchRSVPCounts> {
    const match = await this.fetchMatch(matchID);
    const count = (status: RSVPStatus) =>
      this.data.responses.filter(
        (entry) => entry.response.matchID === matchID && entry.response.status === status,
      ).length;
    return {
      matchID: match.id,
      groupID: match.groupID,
      capacity: match.capacity,
      yesCount: count('yes'),
      maybeCount: count('maybe'),
      noCount: count('no'),
      waitlistCount: count('waitlist'),
    };
  }

  async fetchGuests(groupID: UUID): Promise<Guest[]> {
    return this.result(this.data.guests.filter((guest) => guest.groupID === groupID));
  }

  async fetchParticipants(matchID: UUID): Promise<MatchParticipant[]> {
    return this.result(this.data.participants.filter((participant) => participant.matchID === matchID));
  }

  async fetchGoals(matchID: UUID): Promise<Goal[]> {
    return this.result(this.data.goals.filter((goal) => goal.matchID === matchID));
  }

  async fetchPayments(matchID: UUID): Promise<Payment[]> {
    return this.result(this.data.payments.filter((payment) => payment.matchID === matchID));
  }

  async fetchVotingState(matchID: UUID): Promise<VotingState> {
    const match = await this.fetchMatch(matchID);
    const voters = this.data.participants.filter(
      (participant) => participant.matchID === matchID && participant.userID !== null,
    );
    const closed = match.mvpClosedAt !== null;
    return {
      eligibleVoters: voters.length,
      votesCast: closed ? voters.length : 0,
      hasVoted: closed && voters.some((participant) => participant.userID === this.data.group.ownerID),
      closesAt: match.mvpVotingClosesAt,
      closedAt: match.mvpClosedAt,
    };
  }

  async fetchMVPResults(matchID: UUID): Promise<MVPResult[]> {
    return this.result(this.data.mvpResults.filter((result) => result.matchID === matchID));
  }

  async fetchStats(userID: UUID, groupID: UUID | null): Promise<PlayerStats> {
    return this.required(
      this.data.stats.find((stats) => stats.userID === userID && stats.groupID === groupID),
    );
  }

  async fetchRatingHistory(userID: UUID, groupID: UUID): Promise<RatingHistoryEntry[]> {
    return this.result(
      this.data.ratingHistory
        .filter((entry) => entry.userID === userID && entry.groupID === groupID)
        .sort((first, second) => first.recordedAt.getTime() - second.recordedAt.getTime()),
    );
  }

  async fetchBadgeDefinitions(): Promise<BadgeDefinition[]> {
    return this.result(this.data.badgeDefinitions);
  }

  async fetchBadges(userID: UUID, groupID: UUID | null): Promise<PlayerBadge[]> {
    return this.result(
      this.data.badges.filter((badge) => badge.userID === userID && badge.groupID === groupID),
    );
  }

  async calendarPermission(): Promise<PermissionState> {
    return this.result('notDetermined');
  }

  async addMatchToCalendar(): Promise<string> {
    throw new AppError('unavailable');
  }

  async notificationPermission(): Promise<PermissionState> {
    return this.result('notDetermined');
  }

  async requestNotificationPermission(): Promise<PermissionState> {
    throw new AppError('unavailable');
  }

  private result<Value>(value: Value): Value {
    if (this.failure) throw this.failure;
    return value;
  }

  private required<Value>(value: Value | undefined): Value {
    if (this.failure) throw this.failure;
    if (value === undefined) throw new AppError('notFound');
    return value;
  }
}
