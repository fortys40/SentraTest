import {
  boolean,
  decimal,
  nullable,
  nullableExplicit,
  string,
  struct,
  timestamp,
  uuid,
  type CodecType,
} from '@/core/utilities/SentraJSON';
import { FootballPositionCodec } from '@/models';

// Request payloads carry exactly the deployed column allowlist or RPC parameter
// names. Optional RPC parameters are omitted so the database applies its defaults.

/** Own-profile columns that are directly writable. A null avatar is sent explicitly to clear it. */
export const ProfileUpdateCodec = struct({
  displayName: ['display_name', string],
  position: ['position', FootballPositionCodec],
  avatarURL: ['avatar_url', nullableExplicit(string)],
  onboardingCompleted: ['onboarding_completed', boolean],
});
export type ProfileUpdate = CodecType<typeof ProfileUpdateCodec>;

export const GroupCreationCodec = struct({
  name: ['p_name', string],
  defaultFormat: ['p_default_format', string],
});
export type GroupCreation = CodecType<typeof GroupCreationCodec>;

export const GroupUpdateCodec = struct({
  groupID: ['p_group_id', uuid],
  name: ['p_name', string],
  defaultFormat: ['p_default_format', string],
});
export type GroupUpdate = CodecType<typeof GroupUpdateCodec>;

export const MatchCreationCodec = struct({
  groupID: ['p_group_id', uuid],
  startsAt: ['p_starts_at', timestamp],
  venue: ['p_venue', string],
  format: ['p_format', nullable(string)],
  expectedCost: ['p_expected_cost', nullable(decimal)],
  rsvpLockAt: ['p_rsvp_lock_at', nullable(timestamp)],
});
export type MatchCreation = CodecType<typeof MatchCreationCodec>;

export const MatchUpdateCodec = struct({
  matchID: ['p_match_id', uuid],
  startsAt: ['p_starts_at', timestamp],
  venue: ['p_venue', string],
  format: ['p_format', string],
  rsvpLockAt: ['p_rsvp_lock_at', timestamp],
  expectedCost: ['p_expected_cost', nullable(decimal)],
});
export type MatchUpdate = CodecType<typeof MatchUpdateCodec>;

export const MatchIdentifierCodec = struct({
  matchID: ['p_match_id', uuid],
});
export type MatchIdentifier = CodecType<typeof MatchIdentifierCodec>;
