import { AppError } from '@/core/utilities/AppError';
import { cardTier, cardTiers, rsvpStatuses } from '@/models';
import { makeMockDataset } from '@/services/mock/MockDataFactory';
import { MockServices } from '@/services/mock/MockServices';

describe('mock services', () => {
  test('factory is deterministic including IDs and timestamps', () => {
    expect(makeMockDataset()).toEqual(makeMockDataset());
  });

  test('fixture has all requested scenarios and consistent rosters', () => {
    const data = makeMockDataset();
    expect(data.profiles).toHaveLength(12);
    expect(data.members).toHaveLength(12);
    expect(data.guests).toHaveLength(1);
    expect(data.pastMatches).toHaveLength(6);
    expect(new Set(data.responses.map((entry) => entry.response.status))).toEqual(new Set(rsvpStatuses));
    expect(data.responses.filter((entry) => entry.response.status === 'yes')).toHaveLength(data.upcomingMatch.capacity);
    expect(
      data.responses.filter((entry) => entry.response.guestID !== null && entry.response.status === 'yes'),
    ).toHaveLength(1);
    expect(new Set(data.cardExamples.map((card) => card.design.tier))).toEqual(new Set(cardTiers));
    for (const match of data.pastMatches) {
      const roster = data.participants.filter((participant) => participant.matchID === match.id);
      expect(roster).toHaveLength(match.capacity);
      expect(new Set(roster.map((participant) => participant.userID)).size).toBe(match.capacity);
      expect(match.mvpClosedAt).not.toBeNull();
      expect(data.mvpResults.filter((result) => result.matchID === match.id)).toHaveLength(1);
    }
    expect(data.badgeDefinitions).toHaveLength(3);
    expect(data.badges.filter((badge) => badge.badgeCode === 'mvp_5')).toHaveLength(2);
    expect(data.profiles[0].id).toBe('20000000-0000-0000-0000-000000000001');
    expect(data.profiles[0].displayName).toBe('Γιώργος');
  });

  test('fixed clock can be moved without changing identities', () => {
    const initial = makeMockDataset();
    const moved = makeMockDataset(new Date(initial.referenceDate.getTime() + 86_400_000));
    expect(moved.profiles.map((profile) => profile.id)).toEqual(initial.profiles.map((profile) => profile.id));
    expect(moved.upcomingMatch.startsAt.getTime() - initial.upcomingMatch.startsAt.getTime()).toBe(86_400_000);
  });

  test('mock reads are repeatable and queue position is not the ticket number', async () => {
    const first = new MockServices();
    const second = new MockServices();
    const groups = await first.fetchGroups();
    expect(groups).toEqual(await second.fetchGroups());
    const matches = await first.fetchMatches(groups[0].id);
    expect(matches).toEqual(await first.fetchMatches(groups[0].id));
    const upcoming = matches.find((match) => match.status === 'scheduled')!;
    const counts = await first.fetchCounts(upcoming.id);
    expect(counts.yesCount).toBe(upcoming.capacity);
    expect(counts.maybeCount).toBe(1);
    expect(counts.noCount).toBe(1);
    expect(counts.waitlistCount).toBe(1);
    const responses = await first.fetchResponses(upcoming.id);
    const waiter = responses.find((entry) => entry.response.status === 'waitlist')!;
    expect(waiter.positionInWaitlist).toBe(1);
    expect(waiter.response.waitlistOrder).toBe(42);
  });

  test('mock failure is deterministic and commands do not pretend to persist', async () => {
    const failed = new MockServices(makeMockDataset(), new AppError('network'));
    await expect(failed.fetchGroups()).rejects.toMatchObject({ code: 'network' });
    await expect(new MockServices().createGroup()).rejects.toMatchObject({ code: 'unavailable' });
  });

  test('stats and ratings agree with preview examples', async () => {
    const services = new MockServices();
    for (const card of services.data.cardExamples) {
      const stats = await services.fetchStats(card.profile.id, services.data.group.id);
      const history = await services.fetchRatingHistory(card.profile.id, services.data.group.id);
      expect(stats).toEqual(card.stats);
      expect(history).toHaveLength(stats.appearances);
      expect(history.at(-1)?.overall).toBe(card.overall);
      expect(card.design.tier).toBe(cardTier(card.overall));
    }
  });
});
