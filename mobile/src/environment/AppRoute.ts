import type { StringKey } from '@/core/i18n';
import type { UUID } from '@/core/utilities/SentraJSON';

export type AppRoute =
  | { name: 'welcome' }
  | { name: 'profileSetup' }
  | { name: 'groups' }
  | { name: 'groupDetail'; id: UUID }
  | { name: 'createGroup' }
  | { name: 'matchDetail'; id: UUID }
  | { name: 'createMatch'; groupID: UUID }
  | { name: 'invite'; code: string }
  | { name: 'finishMatch'; id: UUID }
  | { name: 'mvpVoting'; id: UUID }
  | { name: 'mvpResult'; id: UUID }
  | { name: 'playerCard'; userID: UUID; groupID: UUID | null }
  | { name: 'profile' }
  | { name: 'settings' };

export type AppRouteName = AppRoute['name'];

export const appRouteNames: readonly AppRouteName[] = [
  'welcome', 'profileSetup', 'groups', 'groupDetail', 'createGroup', 'matchDetail', 'createMatch',
  'invite', 'finishMatch', 'mvpVoting', 'mvpResult', 'playerCard', 'profile', 'settings',
];

export function isAppRouteName(value: unknown): value is AppRouteName {
  return typeof value === 'string' && (appRouteNames as readonly string[]).includes(value);
}

export function routeTitleKey(name: AppRouteName): StringKey {
  return `route.${name}`;
}

/** Every route currently resolves to the shared placeholder screen. */
export function routeHref(route: AppRoute): { pathname: '/route/[name]'; params: Record<string, string> } {
  const { name, ...rest } = route;
  const params: Record<string, string> = { name };
  for (const [key, value] of Object.entries(rest)) {
    if (typeof value === 'string') params[key] = value;
  }
  return { pathname: '/route/[name]', params };
}
