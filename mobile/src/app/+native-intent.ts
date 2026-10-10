import { routeHref } from '@/environment/AppRoute';
import { DeepLinkHandler } from '@/environment/DeepLinkHandler';

const handler = new DeepLinkHandler();

/**
 * Incoming links are resolved by the deep-link handler instead of being matched
 * against screen files, so a link cannot open a screen the handler did not allow.
 */
export function redirectSystemPath({ path }: { path: string; initial: boolean }): string {
  const route = handler.route(path);
  if (!route) return '/';
  const { params } = routeHref(route);
  const { name, ...query } = params;
  const search = new URLSearchParams(query).toString();
  return `/route/${name}${search ? `?${search}` : ''}`;
}
