export type LogEvent = 'preview_started' | 'live_environment_created';

/** Records fixed event names only, so no user data or credentials can reach the log. */
export function record(event: LogEvent): void {
  if (__DEV__) console.info(`[sentra] ${event}`);
}
