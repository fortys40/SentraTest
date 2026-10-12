import { nullable, string, struct, timestamp, uuid, type CodecType } from '@/core/utilities/SentraJSON';

import { RSVPStatusCodec } from './FootballTypes';

export const DeviceTokenCodec = struct({
  id: ['id', uuid],
  userID: ['user_id', uuid],
  apnsToken: ['apns_token', string],
  environment: ['environment', string],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type DeviceToken = CodecType<typeof DeviceTokenCodec>;

export const WebResponderCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  inviteID: ['invite_id', uuid],
  guestID: ['guest_id', uuid],
  name: ['name', string],
  status: ['status', RSVPStatusCodec],
  tokenHash: ['token_hash', string],
  claimedByUserID: ['claimed_by_user_id', nullable(uuid)],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type WebResponder = CodecType<typeof WebResponderCodec>;
