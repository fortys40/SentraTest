import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import type { AppConfiguration } from '@/core/configuration/AppConfiguration';

/** The only place a Supabase client is constructed. The offline preview never calls it. */
export function createSupabaseClient(configuration: AppConfiguration): SupabaseClient {
  return createClient(configuration.supabaseURL, configuration.supabaseAnonKey, {
    db: { schema: 'public' },
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });
}
