import { createContext, useContext, type ReactNode } from 'react';

import { AppConfiguration } from '@/core/configuration/AppConfiguration';
import { createSupabaseClient } from '@/core/supabase/SupabaseProvider';
import type { AppError } from '@/core/utilities/AppError';
import {
  LiveAuthService,
  LiveGroupService,
  LiveMatchService,
  LiveProfileService,
  LiveRSVPService,
} from '@/services/live/LiveServices';
import { UnavailableServices } from '@/services/live/UnavailableServices';
import { makeMockDataset, type MockDataset } from '@/services/mock/MockDataFactory';
import { MockServices } from '@/services/mock/MockServices';
import type { ServiceContainer } from '@/services/protocols/ServiceProtocols';

import { DeepLinkHandler } from './DeepLinkHandler';

export interface AppEnvironment {
  readonly services: ServiceContainer;
  readonly mode: 'preview' | 'live';
  readonly previewData: MockDataset | null;
  readonly deepLinkHandler: DeepLinkHandler;
}

export function previewServices(data: MockDataset, failure: AppError | null = null): ServiceContainer {
  const mock = new MockServices(data, failure);
  return {
    auth: mock, profiles: mock, groups: mock, matches: mock, rsvps: mock, guests: mock, results: mock,
    costs: mock, voting: mock, stats: mock, rating: mock, badges: mock, calendar: mock, notifications: mock,
  };
}

export function previewEnvironment(
  data: MockDataset = makeMockDataset(),
  failure: AppError | null = null,
): AppEnvironment {
  return {
    services: previewServices(data, failure),
    mode: 'preview',
    previewData: data,
    deepLinkHandler: new DeepLinkHandler(),
  };
}

/** Throws a configuration error when the public settings are missing or unsafe. */
export function liveEnvironment(configuration: AppConfiguration = AppConfiguration.load()): AppEnvironment {
  const client = createSupabaseClient(configuration);
  const deferred = new UnavailableServices();
  return {
    services: {
      auth: new LiveAuthService(client),
      profiles: new LiveProfileService(client),
      groups: new LiveGroupService(client),
      matches: new LiveMatchService(client),
      rsvps: new LiveRSVPService(client),
      guests: deferred, results: deferred, costs: deferred, voting: deferred, stats: deferred,
      rating: deferred, badges: deferred, calendar: deferred, notifications: deferred,
    },
    mode: 'live',
    previewData: null,
    deepLinkHandler: new DeepLinkHandler(),
  };
}

const EnvironmentContext = createContext<AppEnvironment | null>(null);

export function EnvironmentProvider({ environment, children }: { environment: AppEnvironment; children: ReactNode }) {
  return <EnvironmentContext.Provider value={environment}>{children}</EnvironmentContext.Provider>;
}

export function useEnvironment(): AppEnvironment {
  const environment = useContext(EnvironmentContext);
  if (!environment) throw new Error('useEnvironment requires an EnvironmentProvider');
  return environment;
}
