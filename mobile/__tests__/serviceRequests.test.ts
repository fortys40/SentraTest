import Big from 'big.js';

import { AppError, CancellationError } from '@/core/utilities/AppError';
import { DecodingError, timestampFromDate } from '@/core/utilities/SentraJSON';
import { appErrorFrom } from '@/services/live/SupabaseRequest';
import { identifier, referenceDate } from '@/services/mock/MockDataFactory';
import { MatchCreationCodec, ProfileUpdateCodec } from '@/services/protocols/ServiceRequests';

const wire = (payload: unknown) => JSON.parse(JSON.stringify(payload)) as Record<string, unknown>;

describe('service requests', () => {
  test('profile update can clear the avatar and cannot write protected fields', () => {
    const payload = wire(ProfileUpdateCodec.encode({
      displayName: 'Test', position: 'MID', avatarURL: null, onboardingCompleted: true,
    }));
    expect(Object.keys(payload).sort()).toEqual(['avatar_url', 'display_name', 'onboarding_completed', 'position']);
    expect(payload.avatar_url).toBeNull();
    expect(payload.position).toBe('MID');
  });

  test('match creation uses exact RPC keys and decimal without capacity', () => {
    const payload = wire(MatchCreationCodec.encode({
      groupID: identifier(0x30, 1), startsAt: referenceDate, venue: 'Test pitch', format: '7x7',
      expectedCost: new Big('60.01'), rsvpLockAt: new Date(referenceDate.getTime() - 7_200_000),
    }));
    expect(Object.keys(payload).sort()).toEqual(
      ['p_expected_cost', 'p_format', 'p_group_id', 'p_rsvp_lock_at', 'p_starts_at', 'p_venue'],
    );
    expect(payload.p_expected_cost).toBe(60.01);
    expect(payload.p_starts_at).toBe(timestampFromDate(referenceDate));
    expect(payload.p_starts_at).toBe('2026-10-07T12:00:00.000Z');
  });

  test('creation defaults are omitted for the database to decide', () => {
    const payload = wire(MatchCreationCodec.encode({
      groupID: identifier(0x30, 1), startsAt: referenceDate, venue: 'Test pitch',
      format: null, expectedCost: null, rsvpLockAt: null,
    }));
    expect(Object.keys(payload).sort()).toEqual(['p_group_id', 'p_starts_at', 'p_venue']);
  });

  test('Supabase failures map to app errors without leaking database text', () => {
    const code = (error: unknown) => (appErrorFrom(error) as AppError).code;
    expect(code({ message: 'AUTH_REQUIRED', code: 'P0001' })).toBe('notAuthenticated');
    expect(code({ message: 'RSVP_LOCKED', code: 'P0001' })).toBe('rsvpLocked');
    expect(code({ message: 'permission denied for table matches', code: '42501' })).toBe('forbidden');
    expect(code({ message: 'no rows', code: 'PGRST116' })).toBe('notFound');
    expect(code({ message: 'duplicate key', code: '23505' })).toBe('conflict');
    expect(code({ message: 'deadlock detected', code: '40P01' })).toBe('conflict');
    expect(code({ message: 'TypeError: Network request failed', code: '' })).toBe('network');
    expect(code({ name: 'AuthSessionMissingError', message: 'missing', __isAuthError: true })).toBe('notAuthenticated');
    expect(code(new DecodingError('id', 'expected a UUID'))).toBe('unexpected');
    expect(code(new Error('relation "secret" does not exist'))).toBe('unexpected');
    expect(appErrorFrom({ name: 'AbortError' })).toBeInstanceOf(CancellationError);
    const original = new AppError('conflict');
    expect(appErrorFrom(original)).toBe(original);
  });
});
