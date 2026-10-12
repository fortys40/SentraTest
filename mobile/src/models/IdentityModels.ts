import { boolean, nullable, string, struct, timestamp, uuid, type CodecType } from '@/core/utilities/SentraJSON';

import { FootballPositionCodec, GroupRoleCodec } from './FootballTypes';

export const ProfileCodec = struct({
  id: ['id', uuid],
  displayName: ['display_name', string],
  position: ['position', FootballPositionCodec],
  avatarURL: ['avatar_url', nullable(string)],
  onboardingCompleted: ['onboarding_completed', boolean],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type Profile = CodecType<typeof ProfileCodec>;

export const GroupCodec = struct({
  id: ['id', uuid],
  name: ['name', string],
  ownerID: ['owner_id', uuid],
  defaultFormat: ['default_format', string],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type Group = CodecType<typeof GroupCodec>;

export const GroupMemberCodec = struct({
  id: ['id', uuid],
  groupID: ['group_id', uuid],
  userID: ['user_id', uuid],
  role: ['role', GroupRoleCodec],
  joinedAt: ['joined_at', timestamp],
  leftAt: ['left_at', nullable(timestamp)],
});
export type GroupMember = CodecType<typeof GroupMemberCodec>;

export const GroupInviteCodec = struct({
  id: ['id', uuid],
  code: ['code', string],
  groupID: ['group_id', uuid],
  createdBy: ['created_by', uuid],
  expiresAt: ['expires_at', nullable(timestamp)],
  revokedAt: ['revoked_at', nullable(timestamp)],
  createdAt: ['created_at', timestamp],
});
export type GroupInvite = CodecType<typeof GroupInviteCodec>;

export const GuestCodec = struct({
  id: ['id', uuid],
  groupID: ['group_id', uuid],
  name: ['name', string],
  invitedBy: ['invited_by', uuid],
  claimedByUserID: ['claimed_by_user_id', nullable(uuid)],
  claimedAt: ['claimed_at', nullable(timestamp)],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type Guest = CodecType<typeof GuestCodec>;
