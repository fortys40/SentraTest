import { AppError } from '@/core/utilities/AppError';

export type ConfigurationValues = Partial<
  Record<'SUPABASE_URL' | 'SUPABASE_ANON_KEY' | 'UNIVERSAL_LINK_DOMAIN' | 'REVENUECAT_PUBLIC_SDK_KEY', string>
>;

const loopbackHosts = ['localhost', '127.0.0.1', '[::1]', '::1'];

export class AppConfiguration {
  readonly supabaseURL: string;
  readonly supabaseAnonKey: string;
  readonly universalLinkDomain: string | null;
  readonly revenueCatPublicSDKKey: string | null;

  constructor(values: ConfigurationValues) {
    const urlValue = present(values.SUPABASE_URL);
    const parts = urlValue ? /^(https?):\/\/([^/?#]*)(\/?)$/i.exec(urlValue) : null;
    if (!parts) throw new AppError('configuration');
    const [, scheme, authority] = parts;
    const host = authority.replace(/:\d+$/, '').toLowerCase();
    if (!host || authority.includes('@') || /\s/.test(authority)) throw new AppError('configuration');
    if (scheme.toLowerCase() !== 'https' && !loopbackHosts.includes(host)) throw new AppError('configuration');

    const key = present(values.SUPABASE_ANON_KEY);
    if (!key || /\s/.test(key) || !isPublicKey(key)) throw new AppError('configuration');

    const domain = present(values.UNIVERSAL_LINK_DOMAIN);
    if (domain && !/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/i.test(domain)) {
      throw new AppError('configuration');
    }

    const revenueCatKey = present(values.REVENUECAT_PUBLIC_SDK_KEY);
    if (revenueCatKey && !revenueCatKey.startsWith('appl_') && !revenueCatKey.startsWith('test_')) {
      throw new AppError('configuration');
    }

    this.supabaseURL = `${scheme.toLowerCase()}://${authority}`;
    this.supabaseAnonKey = key;
    this.universalLinkDomain = domain;
    this.revenueCatPublicSDKKey = revenueCatKey;
  }

  /** Expo inlines `EXPO_PUBLIC_*` at build time, so each variable is referenced statically. */
  static load(): AppConfiguration {
    return new AppConfiguration({
      SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
      SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
      UNIVERSAL_LINK_DOMAIN: process.env.EXPO_PUBLIC_UNIVERSAL_LINK_DOMAIN,
      REVENUECAT_PUBLIC_SDK_KEY: process.env.EXPO_PUBLIC_REVENUECAT_PUBLIC_SDK_KEY,
    });
  }

  // Keys and URLs must never appear in logs or error reports.
  toString(): string {
    return 'AppConfiguration(<redacted>)';
  }

  toJSON(): string {
    return this.toString();
  }
}

function present(value: string | undefined): string | null {
  const trimmed = value?.trim();
  if (!trimmed || trimmed.includes('$(') || trimmed.toUpperCase().includes('YOUR_')) return null;
  return trimmed;
}

/** Accepts publishable keys and legacy JWTs whose role claim is `anon`. Signatures are not verified. */
function isPublicKey(key: string): boolean {
  if (key.startsWith('sb_publishable_')) return key.length > 'sb_publishable_'.length;
  const segments = key.split('.');
  if (segments.length !== 3 || segments.some((segment) => segment.length === 0)) return false;
  try {
    const payload = segments[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = payload + '='.repeat((4 - (payload.length % 4)) % 4);
    return JSON.parse(atob(padded))?.role === 'anon';
  } catch {
    return false;
  }
}
