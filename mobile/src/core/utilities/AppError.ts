import type { StringKey } from '@/core/i18n';

export const appErrorCodes = [
  'configuration',
  'notAuthenticated',
  'forbidden',
  'notFound',
  'rsvpLocked',
  'conflict',
  'network',
  'unavailable',
  'unexpected',
] as const;

export type AppErrorCode = (typeof appErrorCodes)[number];

export class AppError extends Error {
  readonly code: AppErrorCode;

  constructor(code: AppErrorCode) {
    super(code);
    this.name = 'AppError';
    this.code = code;
  }

  get messageKey(): StringKey {
    return `error.${this.code}`;
  }
}

export class CancellationError extends Error {
  constructor() {
    super('cancelled');
    this.name = 'CancellationError';
  }
}

export function asAppError(error: unknown): AppError {
  return error instanceof AppError ? error : new AppError('unexpected');
}
