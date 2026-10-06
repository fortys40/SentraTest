begin;

create function private.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;
do $$
declare table_name text;
begin
  foreach table_name in array array['profiles', 'groups', 'guests', 'match_series', 'matches',
    'rsvps', 'web_responders', 'payments', 'badge_definitions', 'device_tokens'] loop
    execute format('create trigger touch_updated_at before update on public.%I
      for each row execute function private.touch_updated_at()', table_name);
  end loop;
end;
$$;

create function private.create_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger sentra_create_profile after insert on auth.users
for each row execute function private.create_profile();
insert into public.profiles(id) select id from auth.users on conflict do nothing;

create function private.is_member(target_group uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members
    where group_id = target_group and user_id = (select auth.uid()) and left_at is null)
$$;
create function private.is_admin(target_group uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.group_members where group_id = target_group
    and user_id = (select auth.uid()) and left_at is null and role in ('owner', 'admin'))
$$;
create function private.can_read_profile(target_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select target_user = (select auth.uid()) or exists (
    select 1 from public.group_members viewer
    join public.group_members subject on subject.group_id = viewer.group_id
    where viewer.user_id = (select auth.uid()) and viewer.left_at is null and subject.user_id = target_user
  )
$$;
create function private.can_read_match(target_match uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.matches where id = target_match and private.is_member(group_id))
$$;
create function private.require_member(target_group uuid, administrators_only boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.group_members where group_id = target_group
    and user_id = auth.uid() and left_at is null
    and (not administrators_only or role in ('owner', 'admin')) for share;
  if not found then raise exception 'GROUP_ACCESS_DENIED' using errcode = '42501'; end if;
end;
$$;

create function private.check_group_owner() returns trigger language plpgsql security definer set search_path = '' as $$
declare target_group uuid;
begin
  if tg_table_name = 'groups' then target_group := coalesce(new.id, old.id);
  else target_group := coalesce(new.group_id, old.group_id); end if;
  if exists (select 1 from public.groups target where target.id = target_group and not exists (
    select 1 from public.group_members membership where membership.group_id = target.id
      and membership.user_id = target.owner_id and membership.role = 'owner' and membership.left_at is null
  )) then raise exception 'GROUP_OWNER_MEMBERSHIP_REQUIRED' using errcode = '23514'; end if;
  return null;
end;
$$;
create constraint trigger groups_owner_valid after insert or update on public.groups
deferrable initially deferred for each row execute function private.check_group_owner();
create constraint trigger members_owner_valid after insert or update or delete on public.group_members
deferrable initially deferred for each row execute function private.check_group_owner();

create function public.create_group(p_name text, p_default_format text default '5x5') returns uuid
language plpgsql security definer set search_path = '' as $$
declare group_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  if not exists (select 1 from public.match_formats where code = p_default_format and active)
    then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  insert into public.groups(name, owner_id, default_format)
    values (btrim(p_name), auth.uid(), p_default_format) returning id into group_id;
  insert into public.group_members(group_id, user_id, role) values (group_id, auth.uid(), 'owner');
  return group_id;
end;
$$;

create function public.update_group(p_group_id uuid, p_name text, p_default_format text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member(p_group_id, true);
  if not exists (select 1 from public.match_formats where code = p_default_format and active)
    then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  update public.groups set name = btrim(p_name), default_format = p_default_format where id = p_group_id;
end;
$$;

create function public.create_invite(p_group_id uuid, p_expires_at timestamptz default null) returns public.group_invites
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invites;
begin
  perform private.require_member(p_group_id);
  insert into public.group_invites(group_id, created_by, expires_at)
    values (p_group_id, auth.uid(), p_expires_at) returning * into invitation;
  return invitation;
end;
$$;
create function public.revoke_invite(p_invite_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invites;
begin
  select * into invitation from public.group_invites where id = p_invite_id for update;
  if not found or not private.is_member(invitation.group_id)
    or (invitation.created_by <> auth.uid() and not private.is_admin(invitation.group_id))
    then raise exception 'INVITE_ACCESS_DENIED' using errcode = '42501'; end if;
  update public.group_invites set revoked_at = clock_timestamp() where id = p_invite_id;
end;
$$;
create function public.accept_invite(p_code text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invites;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  select * into invitation from public.group_invites where code = p_code for share;
  if not found or invitation.revoked_at is not null
    or invitation.expires_at <= clock_timestamp()
    or not exists (select 1 from public.group_members where group_id = invitation.group_id
      and user_id = invitation.created_by and left_at is null)
    then raise exception 'INVITE_NOT_AVAILABLE' using errcode = '22023'; end if;
  if exists (select 1 from public.group_members where group_id = invitation.group_id
    and user_id = auth.uid() and left_at is not null)
    then raise exception 'REJOIN_REQUIRES_ORGANIZER' using errcode = '42501'; end if;
  insert into public.group_members(group_id, user_id) values (invitation.group_id, auth.uid())
    on conflict (group_id, user_id) do nothing;
  return invitation.group_id;
end;
$$;

create function public.set_member_role(p_group_id uuid, p_user_id uuid, p_role public.member_role) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member(p_group_id, true);
  perform 1 from public.groups where id = p_group_id and owner_id = auth.uid() for update;
  if not found or p_role = 'owner' or p_user_id = auth.uid()
    then raise exception 'OWNER_ROLE_CHANGE_DENIED' using errcode = '42501'; end if;
  update public.group_members set role = p_role where group_id = p_group_id and user_id = p_user_id and left_at is null;
  if not found then raise exception 'MEMBER_NOT_FOUND' using errcode = '22023'; end if;
end;
$$;
create function public.transfer_group_ownership(p_group_id uuid, p_new_owner uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member(p_group_id, true);
  perform 1 from public.groups where id = p_group_id and owner_id = auth.uid() for update;
  if not found then raise exception 'OWNER_REQUIRED' using errcode = '42501'; end if;
  perform 1 from public.group_members where group_id = p_group_id and user_id = p_new_owner and left_at is null for update;
  if not found then raise exception 'MEMBER_NOT_FOUND' using errcode = '22023'; end if;
  update public.group_members set role = 'admin' where group_id = p_group_id and user_id = auth.uid();
  update public.group_members set role = 'owner' where group_id = p_group_id and user_id = p_new_owner;
  update public.groups set owner_id = p_new_owner where id = p_group_id;
end;
$$;

create function public.add_guest(p_group_id uuid, p_name text) returns public.guests
language plpgsql security definer set search_path = '' as $$
declare guest public.guests;
begin
  perform private.require_member(p_group_id);
  insert into public.guests(group_id, name, invited_by) values (p_group_id, btrim(p_name), auth.uid()) returning * into guest;
  return guest;
end;
$$;

create function public.create_match(p_group_id uuid, p_starts_at timestamptz, p_venue text,
  p_format text default null, p_expected_cost numeric default null, p_rsvp_lock_at timestamptz default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare selected_format public.match_formats; new_id uuid;
begin
  perform private.require_member(p_group_id, true);
  if p_starts_at <= clock_timestamp() then raise exception 'KICKOFF_MUST_BE_FUTURE' using errcode = '22023'; end if;
  select * into selected_format from public.match_formats where active and code = coalesce(p_format,
    (select default_format from public.groups where id = p_group_id));
  if not found then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  insert into public.matches(group_id, format, players_per_team, venue, starts_at, rsvp_lock_at, expected_cost)
  values (p_group_id, selected_format.code, selected_format.players_per_team, btrim(p_venue),
    p_starts_at, coalesce(p_rsvp_lock_at, p_starts_at - interval '2 hours'), p_expected_cost) returning id into new_id;
  return new_id;
end;
$$;

create function private.guard_rsvp() returns trigger
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; identity_user uuid; queued_before boolean;
begin
  if tg_op = 'DELETE' then raise exception 'RSVP_DELETE_FORBIDDEN' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' and (new.id, new.match_id, new.group_id, new.user_id, new.guest_id)
    is distinct from (old.id, old.match_id, old.group_id, old.user_id, old.guest_id)
    then raise exception 'RSVP_IDENTITY_IMMUTABLE' using errcode = '23514'; end if;
  select * into match_row from public.matches where id = new.match_id for update;
  if not found or match_row.group_id <> new.group_id then raise exception 'MATCH_NOT_FOUND' using errcode = '23503'; end if;
  if match_row.status <> 'scheduled' or clock_timestamp() >= match_row.rsvp_lock_at
    then raise exception 'RSVP_LOCKED' using errcode = '55000'; end if;
  identity_user := coalesce(new.user_id, (select claimed_by_user_id from public.guests where id = new.guest_id));
  if new.status in ('yes', 'maybe', 'waitlist') and not exists (
    select 1 from public.group_members where group_id = new.group_id and left_at is null
    and user_id = coalesce(new.user_id, (select invited_by from public.guests where id = new.guest_id))
  ) then raise exception 'ACTIVE_MEMBER_REQUIRED' using errcode = '23514'; end if;
  if identity_user is not null and exists (
    select 1 from public.rsvps response left join public.guests guest on guest.id = response.guest_id
    where response.match_id = new.match_id and response.id <> new.id
      and coalesce(response.user_id, guest.claimed_by_user_id) = identity_user
  ) then raise exception 'DUPLICATE_PLAYER_IDENTITY' using errcode = '23505'; end if;
  if new.status = 'yes' then
    select exists (select 1 from public.rsvps where match_id = new.match_id and status = 'waitlist'
      and id <> new.id and (tg_op = 'INSERT' or old.status not in ('yes', 'waitlist')
        or (old.status = 'waitlist' and waitlist_order < old.waitlist_order))) into queued_before;
    if queued_before or (select count(*) from public.rsvps where match_id = new.match_id
      and status = 'yes' and id <> new.id) >= match_row.capacity then new.status := 'waitlist'; end if;
  end if;
  if new.status = 'waitlist' then
    if tg_op = 'UPDATE' and old.status = 'waitlist' then
      new.waitlisted_at := old.waitlisted_at;
      new.waitlist_order := old.waitlist_order;
    else
      new.waitlisted_at := clock_timestamp();
      new.waitlist_order := nextval('private.waitlist_order');
    end if;
  else
    new.waitlisted_at := null;
    new.waitlist_order := null;
  end if;
  return new;
end;
$$;
create trigger guard_rsvp before insert or update or delete on public.rsvps
for each row execute function private.guard_rsvp();

create function private.promote_waitlist(target_match uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; candidate public.rsvps; recipient uuid; promoted integer := 0;
begin
  select * into match_row from public.matches where id = target_match for update;
  if not found or match_row.status <> 'scheduled' or clock_timestamp() >= match_row.rsvp_lock_at then return 0; end if;
  while (select count(*) from public.rsvps where match_id = target_match and status = 'yes') < match_row.capacity loop
    select * into candidate from public.rsvps where match_id = target_match and status = 'waitlist'
      order by waitlist_order, id limit 1 for update;
    exit when not found;
    recipient := coalesce(candidate.user_id, (select invited_by from public.guests where id = candidate.guest_id));
    if not exists (select 1 from public.group_members where group_id = match_row.group_id and user_id = recipient and left_at is null) then
      update public.rsvps set status = 'no' where id = candidate.id;
      continue;
    end if;
    update public.rsvps set status = 'yes' where id = candidate.id;
    insert into private.notification_outbox(recipient_user_id, kind, payload, dedupe_key)
    values (recipient, 'waitlist_promoted', jsonb_build_object('match_id', target_match, 'guest_id', candidate.guest_id),
      'promotion:' || candidate.id || ':' || candidate.waitlist_order) on conflict do nothing;
    promoted := promoted + 1;
  end loop;
  return promoted;
end;
$$;

create function private.audit_rsvp() returns trigger language plpgsql security definer set search_path = '' as $$
declare kickoff timestamptz; changed timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    select starts_at into kickoff from public.matches where id = new.match_id;
    insert into public.rsvp_history(rsvp_id, match_id, group_id, user_id, guest_id,
      old_status, new_status, changed_by, changed_at, hours_before_kickoff)
    values (new.id, new.match_id, new.group_id, new.user_id, new.guest_id,
      case when tg_op = 'UPDATE' then old.status end, new.status, auth.uid(), changed,
      extract(epoch from kickoff - changed) / 3600);
    update public.web_responders set status = new.status where guest_id = new.guest_id and match_id = new.match_id;
  end if;
  if tg_op = 'UPDATE' and old.status = 'yes' and new.status <> 'yes' then
    perform private.promote_waitlist(new.match_id);
  end if;
  return null;
end;
$$;
create trigger audit_rsvp after insert or update on public.rsvps for each row execute function private.audit_rsvp();

create function private.save_rsvp(target_match uuid, target_user uuid, target_guest uuid, requested_status public.rsvp_status)
returns public.rsvps language plpgsql security definer set search_path = '' as $$
declare response public.rsvps; match_group uuid;
begin
  if requested_status is null or requested_status = 'waitlist' then raise exception 'INVALID_RSVP_STATUS' using errcode = '22023'; end if;
  select group_id into match_group from public.matches where id = target_match for update;
  if not found then raise exception 'MATCH_NOT_FOUND' using errcode = '22023'; end if;
  perform private.promote_waitlist(target_match);
  select * into response from public.rsvps where match_id = target_match
    and user_id is not distinct from target_user and guest_id is not distinct from target_guest for update;
  if found then
    update public.rsvps set status = requested_status where id = response.id returning * into response;
  else
    insert into public.rsvps(match_id, group_id, user_id, guest_id, status)
      values (target_match, match_group, target_user, target_guest, requested_status) returning * into response;
  end if;
  return response;
end;
$$;

create function public.respond_to_match(p_match_id uuid, p_status public.rsvp_status, p_guest_id uuid default null)
returns public.rsvps language plpgsql security definer set search_path = '' as $$
declare match_group uuid; resolved_guest uuid := p_guest_id;
begin
  select group_id into match_group from public.matches where id = p_match_id;
  perform private.require_member(match_group);
  if p_guest_id is not null and not exists (select 1 from public.guests where id = p_guest_id and group_id = match_group
    and (invited_by = auth.uid() or claimed_by_user_id = auth.uid()))
    then raise exception 'GUEST_ACCESS_DENIED' using errcode = '42501'; end if;
  if resolved_guest is null then
    select response.guest_id into resolved_guest from public.rsvps response join public.guests guest on guest.id = response.guest_id
      where response.match_id = p_match_id and guest.claimed_by_user_id = auth.uid();
  end if;
  return private.save_rsvp(p_match_id, case when resolved_guest is null then auth.uid() end, resolved_guest, p_status);
end;
$$;
create function public.promote_waitlist(p_match_id uuid) returns integer
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  return private.promote_waitlist(p_match_id);
end;
$$;

create function private.guard_match() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.score_a is not null and new.score_b is not null then
    new.winner := case when new.score_a > new.score_b then 'A'::public.match_winner
      when new.score_b > new.score_a then 'B'::public.match_winner else 'draw'::public.match_winner end;
  end if;
  if tg_op = 'UPDATE' then
    if (new.id, new.group_id, new.series_id, new.occurrence_date) is distinct from (old.id, old.group_id, old.series_id, old.occurrence_date)
      then raise exception 'MATCH_IDENTITY_IMMUTABLE' using errcode = '23514'; end if;
    if old.status in ('finished', 'cancelled') and new.status <> old.status
      then raise exception 'MATCH_STATE_FINAL' using errcode = '23514'; end if;
    if new.players_per_team * 2 < (select count(*) from public.rsvps where match_id = new.id and status = 'yes')
      then raise exception 'CAPACITY_BELOW_CONFIRMED_PLAYERS' using errcode = '23514'; end if;
  end if;
  return new;
end;
$$;
create trigger guard_match before insert or update on public.matches for each row execute function private.guard_match();

create function public.update_match(p_match_id uuid, p_starts_at timestamptz, p_venue text,
  p_format text, p_rsvp_lock_at timestamptz, p_expected_cost numeric default null) returns void
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; selected_format public.match_formats;
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  select * into match_row from public.matches where id = p_match_id for update;
  if match_row.status not in ('scheduled', 'locked') or match_row.starts_at <= clock_timestamp()
    then raise exception 'MATCH_NOT_EDITABLE' using errcode = '55000'; end if;
  if p_starts_at <= clock_timestamp() then raise exception 'KICKOFF_MUST_BE_FUTURE' using errcode = '22023'; end if;
  select * into selected_format from public.match_formats where code = p_format and active;
  if not found then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  update public.matches set starts_at = p_starts_at, venue = btrim(p_venue), format = selected_format.code,
    players_per_team = selected_format.players_per_team, rsvp_lock_at = p_rsvp_lock_at, expected_cost = p_expected_cost,
    status = case when p_rsvp_lock_at <= clock_timestamp() then 'locked'::public.match_status else 'scheduled'::public.match_status end
    where id = p_match_id;
  perform private.promote_waitlist(p_match_id);
end;
$$;
create function public.cancel_match(p_match_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  perform 1 from public.matches where id = p_match_id for update;
  update public.matches set status = 'cancelled' where id = p_match_id and status in ('scheduled', 'locked');
end;
$$;

create function public.register_device(p_apns_token text, p_environment text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  insert into public.device_tokens(user_id, apns_token, environment) values (auth.uid(), lower(p_apns_token), p_environment)
  on conflict (apns_token, environment) do update set user_id = excluded.user_id;
end;
$$;

create view public.rsvps_with_waitlist_position with (security_invoker = true) as
select response.*, case when status = 'waitlist' then row_number() over (
  partition by match_id, status order by waitlist_order, id) end as position_in_waitlist
from public.rsvps response;
create view public.match_rsvp_counts with (security_invoker = true) as
select match_row.id as match_id, match_row.group_id, match_row.capacity,
  count(response.id) filter (where response.status = 'yes') as yes_count,
  count(response.id) filter (where response.status = 'maybe') as maybe_count,
  count(response.id) filter (where response.status = 'no') as no_count,
  count(response.id) filter (where response.status = 'waitlist') as waitlist_count
from public.matches match_row left join public.rsvps response on response.match_id = match_row.id
group by match_row.id;

grant usage on schema public, private to authenticated;
grant select on public.match_formats, public.profiles, public.groups, public.group_members, public.group_invites,
  public.guests, public.match_series, public.series_skips, public.matches, public.rsvps, public.rsvp_history,
  public.match_participants, public.goals, public.payments, public.mvp_results, public.badge_definitions,
  public.player_badges, public.device_tokens, public.rsvps_with_waitlist_position, public.match_rsvp_counts to authenticated;
grant update(display_name, position, avatar_url, onboarding_completed) on public.profiles to authenticated;
grant delete on public.device_tokens to authenticated;

create policy formats_read on public.match_formats for select to authenticated using (true);
create policy profiles_read on public.profiles for select to authenticated using (private.can_read_profile(id));
create policy profiles_update on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy groups_read on public.groups for select to authenticated using (private.is_member(id));
do $$
declare table_name text;
begin
  foreach table_name in array array['group_members', 'group_invites', 'guests', 'match_series', 'matches',
    'rsvps', 'rsvp_history', 'match_participants'] loop
    execute format('create policy members_read on public.%I for select to authenticated using (private.is_member(group_id))', table_name);
  end loop;
end;
$$;
create policy skips_read on public.series_skips for select to authenticated using (
  exists (select 1 from public.match_series where id = series_id and private.is_member(group_id)));
create policy goals_read on public.goals for select to authenticated using (private.can_read_match(match_id));
create policy payments_read on public.payments for select to authenticated using (
  private.is_member(group_id) and (debtor_user_id = (select auth.uid()) or private.is_admin(group_id)));
create policy results_read on public.mvp_results for select to authenticated using (
  exists (select 1 from public.matches where id = match_id and mvp_closed_at is not null and private.is_member(group_id)));
create policy definitions_read on public.badge_definitions for select to authenticated using (true);
create policy badges_read on public.player_badges for select to authenticated using (
  (group_id is null and user_id = (select auth.uid())) or private.is_member(group_id));
create policy tokens_read on public.device_tokens for select to authenticated using (user_id = (select auth.uid()));
create policy tokens_delete on public.device_tokens for delete to authenticated using (user_id = (select auth.uid()));

revoke all on all functions in schema private from public, anon, authenticated, service_role;
grant execute on function private.is_member(uuid), private.is_admin(uuid), private.can_read_profile(uuid), private.can_read_match(uuid) to authenticated;
revoke all on function public.create_group(text,text), public.update_group(uuid,text,text),
  public.create_invite(uuid,timestamptz), public.revoke_invite(uuid), public.accept_invite(text),
  public.set_member_role(uuid,uuid,public.member_role), public.transfer_group_ownership(uuid,uuid),
  public.add_guest(uuid,text), public.create_match(uuid,timestamptz,text,text,numeric,timestamptz),
  public.respond_to_match(uuid,public.rsvp_status,uuid), public.promote_waitlist(uuid),
  public.update_match(uuid,timestamptz,text,text,timestamptz,numeric), public.cancel_match(uuid),
  public.register_device(text,text) from public, anon, authenticated, service_role;
grant execute on function public.create_group(text,text), public.update_group(uuid,text,text),
  public.create_invite(uuid,timestamptz), public.revoke_invite(uuid), public.accept_invite(text),
  public.set_member_role(uuid,uuid,public.member_role), public.transfer_group_ownership(uuid,uuid),
  public.add_guest(uuid,text), public.create_match(uuid,timestamptz,text,text,numeric,timestamptz),
  public.respond_to_match(uuid,public.rsvp_status,uuid), public.promote_waitlist(uuid),
  public.update_match(uuid,timestamptz,text,text,timestamptz,numeric), public.cancel_match(uuid),
  public.register_device(text,text) to authenticated;

commit;