import { AppConfiguration } from '@/core/configuration/AppConfiguration';

function configuration(url = 'https://example.supabase.co', key = 'sb_publishable_test_only') {
  return new AppConfiguration({ SUPABASE_URL: url, SUPABASE_ANON_KEY: key });
}

function legacyKey(role: string) {
  const payload = btoa(JSON.stringify({ role })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
  return `test-header.${payload}.test-signature`;
}

describe('AppConfiguration', () => {
  test('missing and unexpanded settings fail safely', () => {
    expect(() => new AppConfiguration({})).toThrow();
    expect(() => configuration('$(SUPABASE_URL)')).toThrow();
    expect(() => configuration(undefined, 'YOUR_SUPABASE_ANON_KEY')).toThrow();
  });

  test('only HTTPS or loopback HTTP is accepted', () => {
    expect(() => configuration()).not.toThrow();
    expect(() => configuration('http://127.0.0.1:54321')).not.toThrow();
    expect(() => configuration('http://example.supabase.co')).toThrow();
    expect(() => configuration('https://user:password@example.supabase.co')).toThrow();
    expect(() => configuration('https://example.supabase.co?key=value')).toThrow();
    expect(() => configuration('https://example.supabase.co/rest/v1')).toThrow();
  });

  test('privileged keys are rejected and descriptions are redacted', () => {
    expect(() => configuration(undefined, 'sb_secret_test_only')).toThrow();
    expect(() => configuration(undefined, legacyKey('service_role'))).toThrow();
    expect(() => configuration(undefined, legacyKey('anon'))).not.toThrow();
    const settings = configuration();
    expect(String(settings)).not.toContain(settings.supabaseAnonKey);
    expect(JSON.stringify(settings)).not.toContain(settings.supabaseAnonKey);
    expect(JSON.stringify({ settings })).not.toContain(settings.supabaseURL);
  });

  test('optional values are validated when present', () => {
    const values = { SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'sb_publishable_test_only' };
    expect(new AppConfiguration({ ...values, UNIVERSAL_LINK_DOMAIN: 'sentra.example' }).universalLinkDomain)
      .toBe('sentra.example');
    expect(() => new AppConfiguration({ ...values, UNIVERSAL_LINK_DOMAIN: 'sentra.example/path' })).toThrow();
    expect(() => new AppConfiguration({ ...values, REVENUECAT_PUBLIC_SDK_KEY: 'sk_private' })).toThrow();
    expect(new AppConfiguration({ ...values, REVENUECAT_PUBLIC_SDK_KEY: '' }).revenueCatPublicSDKKey).toBeNull();
  });
});
