import { useCallback, useEffect, useRef, useState } from 'react';

import { AppError, asAppError } from '@/core/utilities/AppError';
import type { AppEnvironment } from '@/environment/AppEnvironment';
import type {
  Group,
  Guest,
  Match,
  MatchRSVPCounts,
  PlayerCardExample,
  Profile,
  RSVPWithWaitlistPosition,
} from '@/models';

export interface DashboardSnapshot {
  readonly group: Group;
  readonly match: Match;
  readonly counts: MatchRSVPCounts;
  readonly profiles: Profile[];
  readonly guests: Guest[];
  readonly responses: RSVPWithWaitlistPosition[];
  readonly cards: PlayerCardExample[];
}

export type DashboardState =
  | { status: 'loading' }
  | { status: 'loaded'; snapshot: DashboardSnapshot }
  | { status: 'failed'; error: AppError };

/** Loads the offline dashboard through the injected services, never from the dataset directly. */
export async function loadDashboard(environment: AppEnvironment): Promise<DashboardState> {
  const data = environment.previewData;
  if (environment.mode !== 'preview' || !data) {
    return { status: 'failed', error: new AppError('unavailable') };
  }
  try {
    const { services } = environment;
    const group = await services.groups.fetchGroup(data.group.id);
    const match = await services.matches.fetchMatch(data.upcomingMatch.id);
    const counts = await services.rsvps.fetchCounts(match.id);
    const profiles = await services.profiles.fetchProfiles(data.profiles.map((profile) => profile.id));
    const guests = await services.guests.fetchGuests(group.id);
    const responses = await services.rsvps.fetchResponses(match.id);
    return {
      status: 'loaded',
      snapshot: { group, match, counts, profiles, guests, responses, cards: data.cardExamples },
    };
  } catch (error) {
    return { status: 'failed', error: asAppError(error) };
  }
}

export function useDashboard(environment: AppEnvironment): { state: DashboardState; reload: () => void } {
  const [state, setState] = useState<DashboardState>({ status: 'loading' });
  const latestLoad = useRef(0);

  const reload = useCallback(() => {
    const load = ++latestLoad.current;
    setState({ status: 'loading' });
    void loadDashboard(environment).then((next) => {
      // A newer load or an unmount supersedes this result.
      if (latestLoad.current === load) setState(next);
    });
  }, [environment]);

  useEffect(() => {
    reload();
    return () => {
      latestLoad.current += 1;
    };
  }, [reload]);

  return { state, reload };
}
