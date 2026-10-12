import {
  boolean,
  decimal,
  integer,
  nullable,
  string,
  struct,
  timestamp,
  uuid,
  type CodecType,
} from '@/core/utilities/SentraJSON';

import { MatchStatusCodec, MatchWinnerCodec, TeamSideCodec } from './FootballTypes';

// Calendar-only SQL `date` and `time` values stay local strings; they are not instants.
export const MatchCodec = struct({
  id: ['id', uuid],
  groupID: ['group_id', uuid],
  seriesID: ['series_id', nullable(uuid)],
  occurrenceDate: ['occurrence_date', nullable(string)],
  format: ['format', string],
  playersPerTeam: ['players_per_team', integer],
  capacity: ['capacity', integer],
  venue: ['venue', string],
  startsAt: ['starts_at', timestamp],
  rsvpLockAt: ['rsvp_lock_at', timestamp],
  expectedCost: ['expected_cost', nullable(decimal)],
  status: ['status', MatchStatusCodec],
  winner: ['winner', nullable(MatchWinnerCodec)],
  scoreA: ['score_a', nullable(integer)],
  scoreB: ['score_b', nullable(integer)],
  goalsRecorded: ['goals_recorded', boolean],
  finishedAt: ['finished_at', nullable(timestamp)],
  mvpVotingClosesAt: ['mvp_voting_closes_at', nullable(timestamp)],
  mvpClosedAt: ['mvp_closed_at', nullable(timestamp)],
  costSplitEnabled: ['cost_split_enabled', boolean],
  totalCost: ['total_cost', nullable(decimal)],
  paidBy: ['paid_by', nullable(uuid)],
  shareAmount: ['share_amount', nullable(decimal)],
  roundingRemainder: ['rounding_remainder', nullable(decimal)],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type Match = CodecType<typeof MatchCodec>;

export const MatchSeriesCodec = struct({
  id: ['id', uuid],
  groupID: ['group_id', uuid],
  weekday: ['weekday', integer],
  startTime: ['start_time', string],
  timezone: ['timezone', string],
  venue: ['venue', string],
  format: ['format', string],
  playersPerTeam: ['players_per_team', integer],
  defaultCost: ['default_cost', nullable(decimal)],
  createDaysBefore: ['create_days_before', integer],
  rsvpLockHours: ['rsvp_lock_hours', decimal],
  active: ['active', boolean],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type MatchSeries = CodecType<typeof MatchSeriesCodec>;

export const SeriesSkipCodec = struct({
  id: ['id', uuid],
  seriesID: ['series_id', uuid],
  occurrenceDate: ['occurrence_date', string],
  createdBy: ['created_by', uuid],
  createdAt: ['created_at', timestamp],
});
export type SeriesSkip = CodecType<typeof SeriesSkipCodec>;

export const MatchParticipantCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  userID: ['user_id', nullable(uuid)],
  guestID: ['guest_id', nullable(uuid)],
  team: ['team', nullable(TeamSideCodec)],
  chargedToUserID: ['charged_to_user_id', uuid],
  createdAt: ['created_at', timestamp],
});
export type MatchParticipant = CodecType<typeof MatchParticipantCodec>;

export const GoalCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  scorerParticipantID: ['scorer_participant_id', uuid],
  team: ['team', TeamSideCodec],
  minute: ['minute', nullable(integer)],
  createdAt: ['created_at', timestamp],
});
export type Goal = CodecType<typeof GoalCodec>;
