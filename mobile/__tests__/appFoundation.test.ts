import { appRouteNames, isAppRouteName, routeHref, routeTitleKey, type AppRoute } from '@/environment/AppRoute';
import { previewEnvironment } from '@/environment/AppEnvironment';
import { DeepLinkHandler } from '@/environment/DeepLinkHandler';
import { AppError } from '@/core/utilities/AppError';
import { translate } from '@/core/i18n';
import el from '@/core/i18n/el.json';
import en from '@/core/i18n/en.json';
import { loadDashboard } from '@/features/preview/dashboardModel';
import { UnavailableServices } from '@/services/live/UnavailableServices';
import { identifier, makeMockDataset } from '@/services/mock/MockDataFactory';

describe('app foundation', () => {
  test('all fourteen placeholder routes have a destination and a localized title', () => {
    const id = identifier(0x20, 1);
    const routes: AppRoute[] = [
      { name: 'welcome' }, { name: 'profileSetup' }, { name: 'groups' }, { name: 'groupDetail', id },
      { name: 'createGroup' }, { name: 'matchDetail', id }, { name: 'createMatch', groupID: id },
      { name: 'invite', code: 'preview' }, { name: 'finishMatch', id }, { name: 'mvpVoting', id },
      { name: 'mvpResult', id }, { name: 'playerCard', userID: id, groupID: null }, { name: 'profile' },
      { name: 'settings' },
    ];
    expect(routes.map((route) => route.name)).toEqual(appRouteNames);
    for (const route of routes) {
      const href = routeHref(route);
      expect(href.pathname).toBe('/route/[name]');
      expect(isAppRouteName(href.params.name)).toBe(true);
      expect(translate('el', routeTitleKey(route.name))).not.toBe(routeTitleKey(route.name));
      expect(translate('en', routeTitleKey(route.name))).not.toBe(routeTitleKey(route.name));
    }
    expect(routeHref({ name: 'playerCard', userID: id, groupID: null }).params).toEqual({ name: 'playerCard', userID: id });
    expect(isAppRouteName('admin')).toBe(false);
  });

  test('deep links do not start authentication or invite workflows yet', () => {
    const handler = new DeepLinkHandler();
    expect(handler.route('sentra://auth/callback?code=test')).toBeNull();
    expect(handler.route('https://example.test/i/preview')).toBeNull();
  });

  test('dashboard loads through injected offline services', async () => {
    const environment = previewEnvironment();
    expect(environment.mode).toBe('preview');
    const state = await loadDashboard(environment);
    if (state.status !== 'loaded') throw new Error('Expected an offline snapshot');
    expect(state.snapshot.profiles).toHaveLength(12);
    expect(state.snapshot.responses).toHaveLength(13);
    expect(state.snapshot.cards).toHaveLength(4);
    expect(state.snapshot.counts.yesCount).toBe(state.snapshot.match.capacity);
  });

  test('dashboard surfaces injected errors', async () => {
    const state = await loadDashboard(previewEnvironment(makeMockDataset(), new AppError('network')));
    expect(state).toMatchObject({ status: 'failed', error: { code: 'network' } });
  });

  test('deferred live services fail rather than pretend to have data', async () => {
    const deferred = new UnavailableServices();
    await expect(deferred.fetchRatingHistory()).rejects.toMatchObject({ code: 'unavailable' });
    await expect(deferred.fetchStats()).rejects.toMatchObject({ code: 'unavailable' });
  });

  test('Greek and English catalogs have identical keys and placeholders', () => {
    expect(Object.keys(en).sort()).toEqual(Object.keys(el).sort());
    const placeholders = (value: string) => (value.match(/\{\d+\}/g) ?? []).sort();
    for (const key of Object.keys(el) as (keyof typeof el)[]) {
      expect(placeholders(en[key])).toEqual(placeholders(el[key]));
    }
    expect(translate('el', 'match.confirmed', 9, 10)).toBe('9 από 10 θέσεις');
    expect(translate('en', 'progress.steps', 1, 3)).toBe('Step 1 of 3');
  });
});
