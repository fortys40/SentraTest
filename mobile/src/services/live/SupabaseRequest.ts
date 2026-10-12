import { AppError, CancellationError } from '@/core/utilities/AppError';
import { DecodingError, type Codec } from '@/core/utilities/SentraJSON';

interface SupabaseFailure {
  name?: string;
  message?: string;
  code?: string;
  __isAuthError?: boolean;
}

interface SupabaseResponse {
  data: unknown;
  error: SupabaseFailure | null;
}

function isNetworkFailure(error: SupabaseFailure): boolean {
  const description = `${error.name ?? ''} ${error.message ?? ''}`;
  return /network request failed|failed to fetch|fetch failed|AuthRetryableFetchError/i.test(description);
}

/** Maps Supabase failures to app errors so raw database messages never reach the interface. */
export function appErrorFrom(error: unknown): Error {
  if (error instanceof AppError || error instanceof CancellationError) return error;
  if (error instanceof DecodingError || typeof error !== 'object' || error === null) {
    return new AppError('unexpected');
  }
  const failure = error as SupabaseFailure;
  if (failure.name === 'AbortError') return new CancellationError();
  if (isNetworkFailure(failure)) return new AppError('network');
  if (failure.__isAuthError) return new AppError('notAuthenticated');
  if (failure.message === 'AUTH_REQUIRED') return new AppError('notAuthenticated');
  if (failure.message === 'RSVP_LOCKED') return new AppError('rsvpLocked');
  switch (failure.code) {
    case '42501':
      return new AppError('forbidden');
    case 'PGRST116':
      return new AppError('notFound');
    case '23505':
    case '40001':
    case '40P01':
      return new AppError('conflict');
    default:
      return new AppError('unexpected');
  }
}

/** Awaits a Supabase query and decodes its rows. */
export async function request<T>(query: PromiseLike<SupabaseResponse>, codec: Codec<T>): Promise<T> {
  try {
    const { data, error } = await query;
    if (error) throw error;
    return codec.decode(data);
  } catch (error) {
    throw appErrorFrom(error);
  }
}

/** Awaits a Supabase command whose result is not used. */
export async function command(query: PromiseLike<SupabaseResponse>): Promise<void> {
  try {
    const { error } = await query;
    if (error) throw error;
  } catch (error) {
    throw appErrorFrom(error);
  }
}
