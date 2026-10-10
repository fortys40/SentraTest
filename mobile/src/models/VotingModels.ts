import { boolean, integer, nullable, struct, timestamp, uuid, type CodecType } from '@/core/utilities/SentraJSON';

// Individual ballots have no client read grant. A wire model does not imply
// permission to fetch it: the app uses voting state and closed results only.
export const MVPVoteCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  voterID: ['voter_id', uuid],
  votedParticipantID: ['voted_participant_id', uuid],
  votedUserID: ['voted_user_id', nullable(uuid)],
  createdAt: ['created_at', timestamp],
});
export type MVPVote = CodecType<typeof MVPVoteCodec>;

export const MVPEligibleVoterCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  voterID: ['voter_id', uuid],
});
export type MVPEligibleVoter = CodecType<typeof MVPEligibleVoterCodec>;

export const MVPResultCodec = struct({
  id: ['id', uuid],
  matchID: ['match_id', uuid],
  participantID: ['participant_id', uuid],
  votes: ['votes', integer],
  createdAt: ['created_at', timestamp],
});
export type MVPResult = CodecType<typeof MVPResultCodec>;

export const VotingStateCodec = struct({
  eligibleVoters: ['eligible_voters', integer],
  votesCast: ['votes_cast', integer],
  hasVoted: ['has_voted', boolean],
  closesAt: ['closes_at', nullable(timestamp)],
  closedAt: ['closed_at', nullable(timestamp)],
});
export type VotingState = CodecType<typeof VotingStateCodec>;
