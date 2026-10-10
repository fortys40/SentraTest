import Big from 'big.js';

import { greek, type StringKey } from '@/core/i18n';
import type { JSONValue, UUID } from '@/core/utilities/SentraJSON';
import {
  cardTier,
  fiveASide,
  formatCapacity,
  type BadgeDefinition,
  type FootballPosition,
  type Goal,
  type Group,
  type GroupMember,
  type Guest,
  type Match,
  type MatchParticipant,
  type MatchWinner,
  type MVPResult,
  type Payment,
  type PlayerBadge,
  type PlayerCardExample,
  type PlayerStats,
  type PreviewPlayerTitle,
  type Profile,
  type RatingHistoryEntry,
  type RSVPStatus,
  type RSVPWithWaitlistPosition,
} from '@/models';

export interface MockDataset {
  readonly referenceDate: Date;
  readonly group: Group;
  readonly profiles: Profile[];
  readonly members: GroupMember[];
  readonly guests: Guest[];
  readonly upcomingMatch: Match;
  readonly pastMatches: Match[];
  readonly responses: RSVPWithWaitlistPosition[];
  readonly participants: MatchParticipant[];
  readonly goals: Goal[];
  readonly payments: Payment[];
  readonly mvpResults: MVPResult[];
  readonly stats: PlayerStats[];
  readonly ratingHistory: RatingHistoryEntry[];
  readonly badgeDefinitions: BadgeDefinition[];
  readonly badges: PlayerBadge[];
  readonly cardExamples: PlayerCardExample[];
}

export function datasetMatches(data: MockDataset): Match[] {
  return [data.upcomingMatch, ...[...data.pastMatches].reverse()];
}

const day = 86_400_000;
const hour = 3_600_000;
const minute = 60_000;

/** The fixed fixture clock. The running app injects the current time instead. */
export const referenceDate = new Date(1_791_374_400_000);

const offset = (date: Date, milliseconds: number) => new Date(date.getTime() + milliseconds);

/** Stable identities: a namespace byte followed by the index. */
export function identifier(namespace: number, index: number): UUID {
  return `${namespace.toString(16).padStart(2, '0')}000000-0000-0000-0000-0000${index
    .toString(16)
    .padStart(8, '0')}`;
}

export function makeMockDataset(now: Date = referenceDate): MockDataset {
  const createdAt = offset(now, -90 * day);
  const positions: FootballPosition[] = [
    'GK', 'DEF', 'MID', 'MID', 'FWD', 'GK', 'DEF', 'MID', 'FWD', 'FWD', 'DEF', 'ANY',
  ];
  const profiles: Profile[] = positions.map((position, index) => ({
    id: identifier(0x20, index + 1),
    displayName: greek(`mock.player.${String(index + 1).padStart(2, '0')}` as StringKey),
    position,
    avatarURL: null,
    onboardingCompleted: true,
    createdAt,
    updatedAt: createdAt,
  }));
  const format = fiveASide;
  const capacity = formatCapacity(format);
  const group: Group = {
    id: identifier(0x30, 1),
    name: greek('mock.group'),
    ownerID: profiles[0].id,
    defaultFormat: format.code,
    createdAt,
    updatedAt: createdAt,
  };
  const members: GroupMember[] = profiles.map((profile, index) => ({
    id: identifier(0x31, index + 1),
    groupID: group.id,
    userID: profile.id,
    role: index === 0 ? 'owner' : index === 1 ? 'admin' : 'member',
    joinedAt: createdAt,
    leftAt: null,
  }));
  const guest: Guest = {
    id: identifier(0x50, 1),
    groupID: group.id,
    name: greek('mock.guest'),
    invitedBy: profiles[2].id,
    claimedByUserID: null,
    claimedAt: null,
    createdAt,
    updatedAt: createdAt,
  };
  const kickoff = offset(now, 6 * day + 6 * hour);
  const upcoming = match(7, group, kickoff, createdAt, false);

  const responses: RSVPWithWaitlistPosition[] = profiles.map((profile, index) => {
    const status: RSVPStatus = index < 9 ? 'yes' : index === 9 ? 'maybe' : index === 10 ? 'no' : 'waitlist';
    const changedAt = offset(now, index * minute - hour);
    const waiting = status === 'waitlist';
    return {
      response: {
        id: identifier(0x60, index + 1),
        matchID: upcoming.id,
        groupID: group.id,
        userID: profile.id,
        guestID: null,
        status,
        waitlistedAt: waiting ? changedAt : null,
        waitlistOrder: waiting ? 42 : null,
        createdAt: changedAt,
        updatedAt: changedAt,
      },
      positionInWaitlist: waiting ? 1 : null,
    };
  });
  responses.push({
    response: {
      id: identifier(0x60, 13),
      matchID: upcoming.id,
      groupID: group.id,
      userID: null,
      guestID: guest.id,
      status: 'yes',
      waitlistedAt: null,
      waitlistOrder: null,
      createdAt: offset(now, -2 * hour),
      updatedAt: now,
    },
    positionInWaitlist: null,
  });

  const pastMatches = Array.from({ length: 6 }, (_, index) =>
    match(index + 1, group, offset(kickoff, -(6 - index) * 7 * day), createdAt, true),
  );
  // Two different players sit out each past match, so every roster is exactly full.
  const participants: MatchParticipant[] = pastMatches.flatMap((played, matchIndex) =>
    profiles
      .filter((_, playerIndex) => playerIndex !== matchIndex * 2 && playerIndex !== matchIndex * 2 + 1)
      .map((profile, rosterIndex) => ({
        id: identifier(0x70, matchIndex * 100 + rosterIndex + 1),
        matchID: played.id,
        groupID: group.id,
        userID: profile.id,
        guestID: null,
        team: rosterIndex < format.playersPerTeam ? 'A' : 'B',
        chargedToUserID: profile.id,
        createdAt: played.finishedAt ?? played.startsAt,
      })),
  );
  const goals: Goal[] = pastMatches.flatMap((played, matchIndex) => {
    if (!played.goalsRecorded) return [];
    const roster = participants.filter((participant) => participant.matchID === played.id);
    return [0, format.playersPerTeam].map((rosterIndex) => ({
      id: identifier(0x80, matchIndex * 100 + rosterIndex + 1),
      matchID: played.id,
      scorerParticipantID: roster[rosterIndex].id,
      team: rosterIndex === 0 ? 'A' : 'B',
      minute: rosterIndex === 0 ? 12 : 35,
      createdAt: played.finishedAt ?? played.startsAt,
    }));
  });
  const payments: Payment[] = pastMatches
    .filter((played) => played.costSplitEnabled)
    .flatMap((played) =>
      participants
        .filter((participant) => participant.matchID === played.id)
        .map((participant, index) => ({
          id: identifier(0x90, index + 1),
          matchID: played.id,
          groupID: group.id,
          debtorUserID: participant.chargedToUserID,
          amount: played.shareAmount ?? new Big(0),
          includesGuestIDs: [],
          paid: index < 2,
          paidAt: index < 2 ? played.finishedAt : null,
          updatedBy: group.ownerID,
          createdAt: played.finishedAt ?? played.startsAt,
          updatedAt: played.finishedAt ?? played.startsAt,
        })),
    );
  const mvpResults: MVPResult[] = pastMatches.flatMap((played, index) => {
    const winnerID = index === 0 ? profiles[2].id : profiles[0].id;
    const candidate = participants.find(
      (participant) => participant.matchID === played.id && participant.userID === winnerID,
    );
    if (!candidate) return [];
    return [{
      id: identifier(0xa0, index + 1),
      matchID: played.id,
      participantID: candidate.id,
      votes: capacity - 1,
      createdAt: played.mvpClosedAt ?? played.startsAt,
    }];
  });

  const winnerOf = (participant: MatchParticipant) =>
    pastMatches.find((played) => played.id === participant.matchID)?.winner ?? null;
  const stats: PlayerStats[] = profiles.flatMap((profile) => {
    const played = participants.filter((participant) => participant.userID === profile.id);
    const playedIDs = new Set(played.map((participant) => participant.id));
    const playedMatchIDs = new Set(played.map((participant) => participant.matchID));
    const wins = played.filter((participant) => winnerOf(participant) === participant.team).length;
    const losses = played.filter((participant) => {
      const winner = winnerOf(participant);
      return (winner === 'A' || winner === 'B') && winner !== participant.team;
    }).length;
    const draws = pastMatches.filter((m) => playedMatchIDs.has(m.id) && m.winner === 'draw').length;
    const decided = wins + losses + draws;
    const recent = [...pastMatches].reverse();
    const firstMissed = recent.findIndex((m) => !playedMatchIDs.has(m.id));
    return [group.id, null].map((scope) => ({
      userID: profile.id,
      groupID: scope,
      appearances: played.length,
      wins,
      losses,
      draws,
      goals: goals.filter((goal) => playedIDs.has(goal.scorerParticipantID)).length,
      mvpCount: mvpResults.filter((result) => playedIDs.has(result.participantID)).length,
      winPercentage: decided === 0 ? null : new Big(wins * 100).div(decided),
      currentStreak: firstMissed === -1 ? recent.length : firstMissed,
    }));
  });

  const definitions = badgeDefinitions(createdAt);
  const badges: PlayerBadge[] = [group.id, null].map((scope, index) => ({
    id: identifier(0xc0, index + 1),
    userID: profiles[0].id,
    groupID: scope,
    badgeCode: 'mvp_5',
    ruleSnapshot: definitions[2].ruleParams,
    awardedAt: pastMatches[5].mvpClosedAt ?? now,
  }));

  const profileIndices = [2, 4, 6, 0];
  const overalls = [63, 71, 82, 90];
  const titles: PreviewPlayerTitle[] = ['everPresent', 'scorer', 'wall', 'mvpMachine'];
  const cardExamples: PlayerCardExample[] = profileIndices.flatMap((profileIndex, index) => {
    const profile = profiles[profileIndex];
    const statistics = stats.find((entry) => entry.userID === profile.id && entry.groupID === group.id);
    if (!statistics) return [];
    const tier = cardTier(overalls[index]);
    return [{
      profile,
      groupName: group.name,
      stats: statistics,
      overall: overalls[index],
      title: titles[index],
      design: { id: `preview.${tier}`, tier },
      badges: profile.id === group.ownerID ? [definitions[2]] : [],
    }];
  });
  // Illustrative history only: this is not the future configurable rating engine.
  const ratingHistory: RatingHistoryEntry[] = cardExamples.flatMap((card, cardIndex) => {
    const playedMatchIDs = new Set(
      participants.filter((participant) => participant.userID === card.profile.id).map((p) => p.matchID),
    );
    const playedMatches = pastMatches.filter((m) => playedMatchIDs.has(m.id));
    return playedMatches.map((played, index) => ({
      id: identifier(0xd0, cardIndex * 100 + index + 1),
      userID: card.profile.id,
      groupID: group.id,
      matchID: played.id,
      overall: card.overall - (playedMatches.length - index - 1) * 2,
      recordedAt: played.finishedAt ?? played.startsAt,
    }));
  });

  return {
    referenceDate: now, group, profiles, members, guests: [guest], upcomingMatch: upcoming, pastMatches,
    responses, participants, goals, payments, mvpResults, stats, ratingHistory,
    badgeDefinitions: definitions, badges, cardExamples,
  };
}

function match(index: number, group: Group, startsAt: Date, createdAt: Date, finished: boolean): Match {
  const format = fiveASide;
  const capacity = formatCapacity(format);
  const winner: MatchWinner | null =
    !finished || index === 1 ? null : index === 2 ? 'B' : index === 4 ? 'draw' : 'A';
  const hasScore = finished && index >= 3;
  const hasSplit = finished && index === 6;
  const completedAt = finished ? offset(startsAt, 90 * minute) : null;
  return {
    id: identifier(0x40, index),
    groupID: group.id,
    seriesID: null,
    occurrenceDate: null,
    format: format.code,
    playersPerTeam: format.playersPerTeam,
    capacity,
    venue: greek('mock.venue'),
    startsAt,
    rsvpLockAt: offset(startsAt, -2 * hour),
    expectedCost: new Big(60),
    status: finished ? 'finished' : 'scheduled',
    winner,
    scoreA: hasScore ? (winner === 'draw' ? 2 : 3) : null,
    scoreB: hasScore ? 2 : null,
    goalsRecorded: hasScore,
    finishedAt: completedAt,
    mvpVotingClosesAt: completedAt ? offset(completedAt, 24 * hour) : null,
    mvpClosedAt: completedAt ? offset(completedAt, hour) : null,
    costSplitEnabled: hasSplit,
    totalCost: hasSplit ? new Big(60) : null,
    paidBy: hasSplit ? group.ownerID : null,
    shareAmount: hasSplit ? new Big(60).div(capacity) : null,
    roundingRemainder: hasSplit ? new Big(0) : null,
    createdAt,
    updatedAt: completedAt ?? createdAt,
  };
}

function badgeDefinitions(createdAt: Date): BadgeDefinition[] {
  const codes = ['attendance_streak', 'ghost', 'mvp_5'] as const;
  const parameters: { [key: string]: JSONValue }[] = [
    { metric: 'current_streak', threshold: 10, scopes: ['group'] },
    { metric: 'late_cancellations', threshold: 3, lookback_matches: 10, late_hours: 24, scopes: ['group'] },
    { metric: 'mvp_count', threshold: 5, scopes: ['group', 'overall'] },
  ];
  return codes.map((code, index) => ({
    id: identifier(0xb0, index + 1),
    code,
    nameEL: greek(`mock.badge.${code}.name`),
    emoji: greek(`mock.badge.${code}.emoji`),
    descriptionEL: greek(`mock.badge.${code}.description`),
    ruleParams: parameters[index],
    active: true,
    createdAt,
    updatedAt: createdAt,
  }));
}
