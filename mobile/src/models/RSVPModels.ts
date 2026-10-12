import {
  decimal,
  integer,
  nullable,
  struct,
  timestamp,
  uuid,
  type Codec,
  type CodecType,
} from '@/core/utilities/SentraJSON';

import { RSVPStatusCodec } from './FootballTypes';

export const RSVPCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  userID: ['user_id', nullable(uuid)],
  guestID: ['guest_id', nullable(uuid)],
  status: ['status', RSVPStatusCodec],
  waitlistedAt: ['waitlisted_at', nullable(timestamp)],
  // An opaque ordering ticket, not the visible queue position.
  waitlistOrder: ['waitlist_order', nullable(integer)],
  createdAt: ['created_at', timestamp],
  updatedAt: ['updated_at', timestamp],
});
export type RSVP = CodecType<typeof RSVPCodec>;

export interface RSVPWithWaitlistPosition {
  readonly response: RSVP;
  readonly positionInWaitlist: number | null;
}

/** The `rsvps_with_waitlist_position` view is flat: the RSVP columns plus the dense position. */
export const RSVPWithWaitlistPositionCodec: Codec<RSVPWithWaitlistPosition> = {
  decode(value, path = '') {
    const response = RSVPCodec.decode(value, path);
    const position = (value as Record<string, unknown>).position_in_waitlist;
    return {
      response,
      positionInWaitlist: nullable(integer).decode(position, `${path}.position_in_waitlist`),
    };
  },
  encode(value) {
    const row = RSVPCodec.encode(value.response) as Record<string, unknown>;
    if (value.positionInWaitlist !== null) row.position_in_waitlist = value.positionInWaitlist;
    return row;
  },
};

export const RSVPHistoryEntryCodec = struct({
  id: ['id', uuid],
  rsvpID: ['rsvp_id', uuid],
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  userID: ['user_id', nullable(uuid)],
  guestID: ['guest_id', nullable(uuid)],
  oldStatus: ['old_status', nullable(RSVPStatusCodec)],
  newStatus: ['new_status', RSVPStatusCodec],
  changedBy: ['changed_by', nullable(uuid)],
  changedAt: ['changed_at', timestamp],
  hoursBeforeKickoff: ['hours_before_kickoff', decimal],
});
export type RSVPHistoryEntry = CodecType<typeof RSVPHistoryEntryCodec>;

export const MatchRSVPCountsCodec = struct({
  matchID: ['match_id', uuid],
  groupID: ['group_id', uuid],
  capacity: ['capacity', integer],
  yesCount: ['yes_count', integer],
  maybeCount: ['maybe_count', integer],
  noCount: ['no_count', integer],
  waitlistCount: ['waitlist_count', integer],
});
export type MatchRSVPCounts = CodecType<typeof MatchRSVPCountsCodec>;
