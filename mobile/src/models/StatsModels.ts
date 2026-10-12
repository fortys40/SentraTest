import {
  decimal,
  integer,
  nullable,
  string,
  struct,
  timestamp,
  uuid,
  type CodecType,
} from '@/core/utilities/SentraJSON';

export const PlayerStatsCodec = struct({
  userID: ['user_id', uuid],
  // Null is the overall scope across every group.
  groupID: ['group_id', nullable(uuid)],
  appearances: ['appearances', integer],
  wins: ['wins', integer],
  losses: ['losses', integer],
  draws: ['draws', integer],
  goals: ['goals', integer],
  mvpCount: ['mvp_count', integer],
  winPercentage: ['win_pct', nullable(decimal)],
  currentStreak: ['current_streak', integer],
});
export type PlayerStats = CodecType<typeof PlayerStatsCodec>;

export function playerStatsID(stats: Pick<PlayerStats, 'userID' | 'groupID'>): string {
  return `${stats.userID}:${stats.groupID ?? 'overall'}`;
}

export const LateCancellationCodec = struct({
  badgeCode: ['badge_code', string],
  userID: ['user_id', uuid],
  groupID: ['group_id', uuid],
  matchID: ['match_id', uuid],
  lastCancelledAt: ['last_cancelled_at', timestamp],
});
export type LateCancellation = CodecType<typeof LateCancellationCodec>;
