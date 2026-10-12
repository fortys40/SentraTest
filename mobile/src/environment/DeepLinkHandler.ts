import type { AppRoute } from './AppRoute';

/** Deep links are intentionally inert until the invite and authentication steps are authorized. */
export class DeepLinkHandler {
  route(_url: string): AppRoute | null {
    return null;
  }
}
