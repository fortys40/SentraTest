import Big from 'big.js';

import {
  arrayOf,
  dateFromTimestamp,
  decimal,
  timestamp,
  type Codec,
} from '@/core/utilities/SentraJSON';
import {
  BadgeDefinitionCodec,
  cardTier,
  DeviceTokenCodec,
  eightASide,
  elevenASide,
  fiveASide,
  formatCapacity,
  GoalCodec,
  GroupCodec,
  GroupInviteCodec,
  GroupMemberCodec,
  GuestCodec,
  LateCancellationCodec,
  MatchCodec,
  MatchFormatCodec,
  MatchParticipantCodec,
  MatchRSVPCountsCodec,
  MatchSeriesCodec,
  MVPEligibleVoterCodec,
  MVPResultCodec,
  MVPVoteCodec,
  OutstandingPaymentCodec,
  PaymentCodec,
  PlayerBadgeCodec,
  PlayerStatsCodec,
  playerStatsID,
  ProfileCodec,
  RSVPCodec,
  RSVPHistoryEntryCodec,
  RSVPStatusCodec,
  RSVPWithWaitlistPositionCodec,
  SeriesSkipCodec,
  sevenASide,
  VotingStateCodec,
  WebResponderCodec,
} from '@/models';

import fixture from './fixtures/supabase-rows.json';

const decode = <T>(codec: Codec<T>, value: unknown) => codec.decode(value);

const rows = {
  format: decode(MatchFormatCodec, fixture.format),
  profile: decode(ProfileCodec, fixture.profile),
  group: decode(GroupCodec, fixture.group),
  member: decode(GroupMemberCodec, fixture.member),
  invite: decode(GroupInviteCodec, fixture.invite),
  guest: decode(GuestCodec, fixture.guest),
  series: decode(MatchSeriesCodec, fixture.series),
  skip: decode(SeriesSkipCodec, fixture.skip),
  match: decode(MatchCodec, fixture.match),
  rsvp: decode(RSVPCodec, fixture.rsvp),
  waitlistResponse: decode(RSVPWithWaitlistPositionCodec, fixture.waitlistResponse),
  history: decode(RSVPHistoryEntryCodec, fixture.history),
  counts: decode(MatchRSVPCountsCodec, fixture.counts),
  participant: decode(MatchParticipantCodec, fixture.participant),
  goal: decode(GoalCodec, fixture.goal),
  payment: decode(PaymentCodec, fixture.payment),
  outstandingPayment: decode(OutstandingPaymentCodec, fixture.outstandingPayment),
  eligibleVoter: decode(MVPEligibleVoterCodec, fixture.eligibleVoter),
  vote: decode(MVPVoteCodec, fixture.vote),
  mvpResult: decode(MVPResultCodec, fixture.mvpResult),
  votingState: decode(VotingStateCodec, fixture.votingState),
  stats: decode(PlayerStatsCodec, fixture.stats),
  statsWithoutResults: decode(PlayerStatsCodec, fixture.statsWithoutResults),
  lateCancellation: decode(LateCancellationCodec, fixture.lateCancellation),
  badgeDefinition: decode(BadgeDefinitionCodec, fixture.badgeDefinition),
  playerBadge: decode(PlayerBadgeCodec, fixture.playerBadge),
  deviceToken: decode(DeviceTokenCodec, fixture.deviceToken),
  webResponder: decode(WebResponderCodec, fixture.webResponder),
  moneySamples: decode(arrayOf(decimal), fixture.moneySamples),
};

describe('model decoding', () => {
  test('all supported capacities and new catalog rows', () => {
    expect([fiveASide, sevenASide, eightASide, elevenASide].map(formatCapacity)).toEqual([10, 14, 16, 22]);
    const future = MatchFormatCodec.decode({ code: '6x6', players_per_team: 6, active: true });
    expect(formatCapacity(future)).toBe(12);
    expect(future.code).toBe('6x6');
  });

  test('representative Supabase rows decode without invented fields', () => {
    expect(rows.profile.position).toBe('GK');
    expect(rows.profile.avatarURL).toBeNull();
    expect(rows.group.ownerID).toBe(rows.profile.id);
    expect(rows.member.role).toBe('owner');
    expect(rows.match.status).toBe('finished');
    expect(rows.match.winner).toBe('A');
    expect(rows.match.capacity).toBe(rows.match.playersPerTeam * 2);
    expect(rows.guest.claimedByUserID).toBeNull();
    expect(rows.participant.userID).toBeNull();
    expect(rows.participant.guestID).toBe(rows.guest.id);
    expect(rows.payment.includesGuestIDs).toEqual([rows.guest.id]);
    expect(rows.payment.paidAt).toBeNull();
    expect(rows.vote.votedParticipantID).toBe(rows.mvpResult.participantID);
    expect(rows.vote.votedUserID).toBeNull();
    expect(rows.badgeDefinition.ruleParams.threshold).toBe(5);
    expect(rows.playerBadge.badgeCode).toBe(rows.badgeDefinition.code);
    expect(rows.playerBadge.groupID).toBeNull();
    expect(Object.keys(rows.profile).sort()).toEqual(
      ['avatarURL', 'createdAt', 'displayName', 'id', 'onboardingCompleted', 'position', 'updatedAt'],
    );
  });

  test('dates accept Supabase offsets and fractional seconds', () => {
    const expected = dateFromTimestamp('2026-10-06T18:00:00.123456Z');
    expect(expected).not.toBeNull();
    expect(rows.match.startsAt.getTime()).toBe(expected!.getTime());
    expect(rows.match.startsAt.getTime()).toBe(Date.UTC(2026, 9, 6, 18, 0, 0, 123));
    expect(rows.profile.updatedAt).toEqual(rows.match.startsAt);
    expect(dateFromTimestamp('2026-10-06 18:00:00+00')?.getTime()).toBe(Date.UTC(2026, 9, 6, 18));
    expect(dateFromTimestamp('2026-10-06T12:30:00-05:30')?.getTime()).toBe(Date.UTC(2026, 9, 6, 18));
    expect(() => timestamp.decode('2026-10-06T21:00:00')).toThrow();
    expect(() => timestamp.decode(1_791_374_400)).toThrow();
  });

  test('calendar-only values are not converted to UTC instants', () => {
    expect(rows.series.startTime).toBe('21:00:00.123456');
    expect(rows.series.timezone).toBe('Europe/Athens');
    expect(rows.match.occurrenceDate).toBe('2026-10-06');
    expect(rows.skip.occurrenceDate).toBe('2026-10-27');
    expect(rows.series.rsvpLockHours.eq('2.50')).toBe(true);
  });

  test('decimal money retains precision and signed remainder', () => {
    const [first, second, sum, large] = rows.moneySamples;
    expect(first.plus(second).eq(sum)).toBe(true);
    expect(large.eq('9999999999.99')).toBe(true);
    expect(rows.match.expectedCost?.eq('60.01')).toBe(true);
    expect(rows.match.roundingRemainder?.eq('-0.50')).toBe(true);
    const encoded = JSON.parse(JSON.stringify(arrayOf(decimal).encode(rows.moneySamples)));
    expect(arrayOf(decimal).decode(encoded)).toEqual(rows.moneySamples);
    expect(decimal.decode('14.00').eq(new Big(14))).toBe(true);
    expect(() => decimal.decode('fourteen')).toThrow();
  });

  test('waitlist projection decodes flat JSON and keeps the ticket separate from the position', () => {
    expect(rows.waitlistResponse.response).toEqual(rows.rsvp);
    expect(rows.rsvp.waitlistOrder).toBe(9_007_199_254_740_991);
    expect(rows.waitlistResponse.positionInWaitlist).toBe(1);
    const encoded = JSON.parse(JSON.stringify(RSVPWithWaitlistPositionCodec.encode(rows.waitlistResponse)));
    expect(RSVPWithWaitlistPositionCodec.decode(encoded)).toEqual(rows.waitlistResponse);
  });

  test('tickets beyond the exact integer range are rejected instead of silently rounded', () => {
    expect(() => RSVPCodec.decode({ ...fixture.rsvp, waitlist_order: 2 ** 53 })).toThrow(/waitlist_order/);
  });

  test('overall stats preserve null group and unknown win percentage', () => {
    expect(rows.stats.winPercentage?.eq('58.3')).toBe(true);
    expect(rows.statsWithoutResults.winPercentage).toBeNull();
    expect(rows.statsWithoutResults.groupID).toBeNull();
    expect(playerStatsID(rows.stats)).not.toBe(playerStatsID(rows.statsWithoutResults));
    expect(rows.votingState.eligibleVoters).toBe(2);
    expect(rows.votingState.hasVoted).toBe(true);
  });

  test('round trip and missing required fields', () => {
    const encoded = JSON.parse(JSON.stringify(MatchCodec.encode(rows.match)));
    expect(MatchCodec.decode(encoded)).toEqual(rows.match);
    expect(() => ProfileCodec.decode({ display_name: 'Test' })).toThrow(/id/);
    expect(() => RSVPStatusCodec.decode('YES')).toThrow();
  });

  test('tier boundaries are only presentation', () => {
    expect([50, 64, 65, 74, 75, 84, 85, 99].map(cardTier)).toEqual(
      ['bronze', 'bronze', 'silver', 'silver', 'gold', 'gold', 'elite', 'elite'],
    );
  });
});
