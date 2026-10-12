import type { SupabaseClient } from '@supabase/supabase-js';

import { AppError } from '@/core/utilities/AppError';
import { arrayOf, uuid, type UUID } from '@/core/utilities/SentraJSON';
import {
  GroupCodec,
  GroupMemberCodec,
  MatchCodec,
  MatchFormatCodec,
  MatchRSVPCountsCodec,
  ProfileCodec,
  RSVPWithWaitlistPositionCodec,
  type Group,
  type GroupMember,
  type Match,
  type MatchFormat,
  type MatchRSVPCounts,
  type Profile,
  type RSVPWithWaitlistPosition,
} from '@/models';

import type {
  AuthService,
  GroupService,
  MatchService,
  ProfileService,
  RSVPService,
} from '../protocols/ServiceProtocols';
import {
  GroupCreationCodec,
  GroupUpdateCodec,
  MatchCreationCodec,
  MatchIdentifierCodec,
  MatchUpdateCodec,
  ProfileUpdateCodec,
  type GroupCreation,
  type GroupUpdate,
  type MatchCreation,
  type MatchUpdate,
  type ProfileUpdate,
} from '../protocols/ServiceRequests';
import { appErrorFrom, command, request } from './SupabaseRequest';

// Game writes go through the deployed authorized RPCs. Profile writes are limited
// to the own-profile allowlist. RSVP is read-only until its workflow is authorized.

export class LiveAuthService implements AuthService {
  constructor(private readonly client: SupabaseClient) {}

  async currentUserID(): Promise<UUID | null> {
    try {
      const { data, error } = await this.client.auth.getSession();
      if (error) throw error;
      return data.session?.user.id ?? null;
    } catch (error) {
      throw appErrorFrom(error);
    }
  }

  async signOut(): Promise<void> {
    try {
      const { error } = await this.client.auth.signOut({ scope: 'local' });
      if (error) throw error;
    } catch (error) {
      throw appErrorFrom(error);
    }
  }
}

export class LiveProfileService implements ProfileService {
  constructor(private readonly client: SupabaseClient) {}

  fetchProfile(id: UUID): Promise<Profile> {
    return request(this.client.from('profiles').select().eq('id', id).single(), ProfileCodec);
  }

  async fetchProfiles(ids: UUID[]): Promise<Profile[]> {
    if (ids.length === 0) return [];
    return request(this.client.from('profiles').select().in('id', ids).order('id'), arrayOf(ProfileCodec));
  }

  async updateProfile(update: ProfileUpdate): Promise<Profile> {
    const userID = await new LiveAuthService(this.client).currentUserID();
    if (!userID) throw new AppError('notAuthenticated');
    return request(
      this.client.from('profiles').update(ProfileUpdateCodec.encode(update) as object).eq('id', userID).select().single(),
      ProfileCodec,
    );
  }
}

export class LiveGroupService implements GroupService {
  constructor(private readonly client: SupabaseClient) {}

  fetchGroups(): Promise<Group[]> {
    return request(
      this.client.from('groups').select().order('created_at', { ascending: false }).order('id'),
      arrayOf(GroupCodec),
    );
  }

  fetchGroup(id: UUID): Promise<Group> {
    return request(this.client.from('groups').select().eq('id', id).single(), GroupCodec);
  }

  fetchMembers(groupID: UUID): Promise<GroupMember[]> {
    return request(
      this.client.from('group_members').select().eq('group_id', groupID).order('joined_at').order('id'),
      arrayOf(GroupMemberCodec),
    );
  }

  createGroup(input: GroupCreation): Promise<UUID> {
    return request(this.client.rpc('create_group', GroupCreationCodec.encode(input) as object), uuid);
  }

  updateGroup(input: GroupUpdate): Promise<void> {
    return command(this.client.rpc('update_group', GroupUpdateCodec.encode(input) as object));
  }
}

export class LiveMatchService implements MatchService {
  constructor(private readonly client: SupabaseClient) {}

  fetchFormats(): Promise<MatchFormat[]> {
    return request(
      this.client.from('match_formats').select().eq('active', true).order('players_per_team'),
      arrayOf(MatchFormatCodec),
    );
  }

  fetchMatches(groupID: UUID): Promise<Match[]> {
    return request(
      this.client
        .from('matches')
        .select()
        .eq('group_id', groupID)
        .order('starts_at', { ascending: false })
        .order('id', { ascending: false }),
      arrayOf(MatchCodec),
    );
  }

  fetchMatch(id: UUID): Promise<Match> {
    return request(this.client.from('matches').select().eq('id', id).single(), MatchCodec);
  }

  createMatch(input: MatchCreation): Promise<UUID> {
    return request(this.client.rpc('create_match', MatchCreationCodec.encode(input) as object), uuid);
  }

  updateMatch(input: MatchUpdate): Promise<void> {
    return command(this.client.rpc('update_match', MatchUpdateCodec.encode(input) as object));
  }

  cancelMatch(id: UUID): Promise<void> {
    return command(this.client.rpc('cancel_match', MatchIdentifierCodec.encode({ matchID: id }) as object));
  }
}

export class LiveRSVPService implements RSVPService {
  constructor(private readonly client: SupabaseClient) {}

  fetchResponses(matchID: UUID): Promise<RSVPWithWaitlistPosition[]> {
    return request(
      this.client
        .from('rsvps_with_waitlist_position')
        .select()
        .eq('match_id', matchID)
        .order('created_at')
        .order('id'),
      arrayOf(RSVPWithWaitlistPositionCodec),
    );
  }

  fetchCounts(matchID: UUID): Promise<MatchRSVPCounts> {
    return request(
      this.client.from('match_rsvp_counts').select().eq('match_id', matchID).single(),
      MatchRSVPCountsCodec,
    );
  }
}
