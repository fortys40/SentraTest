import { boolean, enumOf, integer, string, struct, type CodecType } from '@/core/utilities/SentraJSON';

// Enum values match the PostgreSQL enums exactly.
export const footballPositions = ['GK', 'DEF', 'MID', 'FWD', 'ANY'] as const;
export type FootballPosition = (typeof footballPositions)[number];
export const FootballPositionCodec = enumOf(footballPositions);

export const groupRoles = ['owner', 'admin', 'member'] as const;
export type GroupRole = (typeof groupRoles)[number];
export const GroupRoleCodec = enumOf(groupRoles);

export const matchStatuses = ['scheduled', 'locked', 'finished', 'cancelled'] as const;
export type MatchStatus = (typeof matchStatuses)[number];
export const MatchStatusCodec = enumOf(matchStatuses);

export const rsvpStatuses = ['yes', 'maybe', 'no', 'waitlist'] as const;
export type RSVPStatus = (typeof rsvpStatuses)[number];
export const RSVPStatusCodec = enumOf(rsvpStatuses);

export const teamSides = ['A', 'B'] as const;
export type TeamSide = (typeof teamSides)[number];
export const TeamSideCodec = enumOf(teamSides);

export const matchWinners = ['A', 'B', 'draw'] as const;
export type MatchWinner = (typeof matchWinners)[number];
export const MatchWinnerCodec = enumOf(matchWinners);

export const MatchFormatCodec = struct({
  code: ['code', string],
  playersPerTeam: ['players_per_team', integer],
  active: ['active', boolean],
});
export type MatchFormat = CodecType<typeof MatchFormatCodec>;

/** Formats are catalog rows, so capacity is always derived and never hardcoded. */
export function formatCapacity(format: Pick<MatchFormat, 'playersPerTeam'>): number {
  return format.playersPerTeam * 2;
}

export const fiveASide: MatchFormat = { code: '5x5', playersPerTeam: 5, active: true };
export const sevenASide: MatchFormat = { code: '7x7', playersPerTeam: 7, active: true };
export const eightASide: MatchFormat = { code: '8x8', playersPerTeam: 8, active: true };
export const elevenASide: MatchFormat = { code: '11x11', playersPerTeam: 11, active: true };
