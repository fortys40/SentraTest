begin;

create function private.validate_series() returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone)
    or new.start_time = time '24:00' then raise exception 'INVALID_SERIES_TIMEZONE_OR_TIME' using errcode = '22023'; end if;
  if tg_op = 'UPDATE' and new.group_id <> old.group_id
    then raise exception 'SERIES_GROUP_IMMUTABLE' using errcode = '23514'; end if;
  return new;
end;
$$;
create trigger validate_series before insert or update on public.match_series for each row execute function private.validate_series();

create function public.create_match_series(p_group_id uuid, p_weekday smallint, p_start_time time, p_venue text,
  p_format text default null, p_default_cost numeric default null, p_create_days_before integer default 5,
  p_rsvp_lock_hours numeric default 2, p_timezone text default 'Europe/Athens') returns uuid
language plpgsql security definer set search_path = '' as $$
declare selected_format public.match_formats; series_id uuid;
begin
  perform private.require_member(p_group_id, true);
  select * into selected_format from public.match_formats where active and code = coalesce(p_format,
    (select default_format from public.groups where id = p_group_id));
  if not found then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  insert into public.match_series(group_id, weekday, start_time, venue, format, players_per_team,
    default_cost, create_days_before, rsvp_lock_hours, timezone)
  values (p_group_id, p_weekday, p_start_time, btrim(p_venue), selected_format.code,
    selected_format.players_per_team, p_default_cost, p_create_days_before, p_rsvp_lock_hours, p_timezone)
  returning id into series_id;
  return series_id;
end;
$$;
create function public.update_match_series(p_series_id uuid, p_weekday smallint, p_start_time time, p_venue text,
  p_format text, p_default_cost numeric, p_create_days_before integer, p_rsvp_lock_hours numeric,
  p_timezone text, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare selected_format public.match_formats;
begin
  perform private.require_member((select group_id from public.match_series where id = p_series_id), true);
  select * into selected_format from public.match_formats where active and code = p_format;
  if not found then raise exception 'FORMAT_NOT_AVAILABLE' using errcode = '22023'; end if;
  update public.match_series set weekday = p_weekday, start_time = p_start_time, venue = btrim(p_venue),
    format = selected_format.code, players_per_team = selected_format.players_per_team,
    default_cost = p_default_cost, create_days_before = p_create_days_before, rsvp_lock_hours = p_rsvp_lock_hours,
    timezone = p_timezone, active = p_active where id = p_series_id;
end;
$$;
create function public.set_series_active(p_series_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.match_series where id = p_series_id), true);
  update public.match_series set active = p_active where id = p_series_id;
end;
$$;
create function public.skip_series_occurrence(p_series_id uuid, p_date date) returns void
language plpgsql security definer set search_path = '' as $$
declare series public.match_series;
begin
  perform private.require_member((select group_id from public.match_series where id = p_series_id), true);
  select * into series from public.match_series where id = p_series_id for update;
  if p_date < (clock_timestamp() at time zone series.timezone)::date or extract(dow from p_date) <> series.weekday
    then raise exception 'INVALID_OCCURRENCE_DATE' using errcode = '22023'; end if;
  if exists (select 1 from public.matches where series_id = p_series_id and occurrence_date = p_date and status = 'finished')
    then raise exception 'FINISHED_OCCURRENCE_CANNOT_BE_SKIPPED' using errcode = '55000'; end if;
  insert into public.series_skips(series_id, occurrence_date, created_by) values (p_series_id, p_date, auth.uid()) on conflict do nothing;
  update public.matches set status = 'cancelled' where series_id = p_series_id and occurrence_date = p_date
    and status in ('scheduled', 'locked');
end;
$$;

create function private.create_recurring_matches(as_of timestamptz default clock_timestamp()) returns integer
language plpgsql security definer set search_path = '' as $$
declare series public.match_series; local_today date; occurrence date; kickoff timestamptz; created_id uuid; created_count integer := 0;
begin
  for series in select * from public.match_series where active order by id for update skip locked loop
    local_today := (as_of at time zone series.timezone)::date;
    for occurrence in select local_today + offset_days from generate_series(0, series.create_days_before) offset_days
      where extract(dow from local_today + offset_days) = series.weekday loop
      kickoff := (occurrence + series.start_time) at time zone series.timezone;
      continue when kickoff <= as_of or exists (select 1 from public.series_skips where series_id = series.id and occurrence_date = occurrence);
      insert into public.matches(group_id, series_id, occurrence_date, format, players_per_team, venue,
        starts_at, rsvp_lock_at, expected_cost, status)
      values (series.group_id, series.id, occurrence, series.format, series.players_per_team, series.venue,
        kickoff, kickoff - series.rsvp_lock_hours * interval '1 hour', series.default_cost,
        case when kickoff - series.rsvp_lock_hours * interval '1 hour' <= as_of then 'locked'::public.match_status else 'scheduled'::public.match_status end)
      on conflict (series_id, occurrence_date) do nothing returning id into created_id;
      if found then
        created_count := created_count + 1;
        insert into private.notification_outbox(recipient_user_id, kind, payload, dedupe_key)
        select user_id, 'match_created', jsonb_build_object('match_id', created_id, 'group_id', series.group_id),
          'match:' || created_id || ':' || user_id from public.group_members
        where group_id = series.group_id and left_at is null on conflict do nothing;
      end if;
    end loop;
  end loop;
  return created_count;
end;
$$;

create function private.queue_rsvp_reminders(as_of timestamptz default clock_timestamp()) returns integer
language plpgsql security definer set search_path = '' as $$
declare queued integer;
begin
  insert into private.notification_outbox(recipient_user_id, kind, payload, dedupe_key)
  select membership.user_id, 'rsvp_reminder', jsonb_build_object('match_id', match_row.id),
    'reminder:' || match_row.id || ':' || membership.user_id
  from public.matches match_row join public.group_members membership on membership.group_id = match_row.group_id and membership.left_at is null
  where match_row.status = 'scheduled' and match_row.rsvp_lock_at > as_of
    and match_row.starts_at > as_of and match_row.starts_at <= as_of + interval '24 hours'
    and not exists (select 1 from public.rsvps response left join public.guests guest on guest.id = response.guest_id
      where response.match_id = match_row.id and coalesce(response.user_id, guest.claimed_by_user_id) = membership.user_id
        and response.status in ('yes', 'no', 'waitlist'))
  on conflict do nothing;
  get diagnostics queued = row_count;
  return queued;
end;
$$;

create table private.maintenance_state (
  singleton boolean primary key default true check (singleton),
  badge_cursor uuid,
  updated_at timestamptz not null default now()
);
insert into private.maintenance_state(singleton) values (true);
alter table private.maintenance_state enable row level security;
alter table private.notification_outbox enable row level security;

create function private.run_maintenance() returns void
language plpgsql security definer set search_path = '' as $$
declare match_id uuid; player_id uuid; cursor_id uuid; processed integer := 0;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('sentra:maintenance', 0)) then return; end if;
  perform private.create_recurring_matches();
  perform private.queue_rsvp_reminders();
  for match_id in select id from public.matches where status = 'scheduled' and rsvp_lock_at <= clock_timestamp()
    order by id limit 500 for update skip locked loop
    update public.matches set status = 'locked' where id = match_id;
  end loop;
  for match_id in select id from public.matches where status = 'finished' and mvp_closed_at is null
    and mvp_voting_closes_at <= clock_timestamp() order by id limit 500 for update skip locked loop
    perform private.close_mvp_voting(match_id);
  end loop;
  select badge_cursor into cursor_id from private.maintenance_state where singleton for update;
  for player_id in select id from public.profiles where (cursor_id is null or id > cursor_id)
    and exists (select 1 from public.group_members where user_id = profiles.id) order by id limit 50 loop
    perform private.evaluate_badges(player_id);
    processed := processed + 1;
    cursor_id := player_id;
  end loop;
  update private.maintenance_state set badge_cursor = case when processed = 50 then cursor_id end,
    updated_at = clock_timestamp() where singleton;
end;
$$;

create function private.require_service() returns void language plpgsql set search_path = '' as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'SERVICE_ROLE_REQUIRED' using errcode = '42501'; end if;
end;
$$;
create function public.create_recurring_matches() returns integer
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_service();
  return private.create_recurring_matches();
end;
$$;
create function public.run_maintenance() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_service();
  perform private.run_maintenance();
end;
$$;

create function public.claim_notifications(p_limit integer default 50, p_lease_seconds integer default 120)
returns setof private.notification_outbox language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_service();
  if p_limit is null or p_limit not between 1 and 500 or p_lease_seconds is null or p_lease_seconds not between 5 and 900
    then raise exception 'INVALID_NOTIFICATION_BATCH' using errcode = '22023'; end if;
  return query with claimed as (
    select id from private.notification_outbox where delivered_at is null and attempts < 10
      and available_at <= clock_timestamp() and (leased_until is null or leased_until <= clock_timestamp())
    order by available_at, id limit p_limit for update skip locked
  ) update private.notification_outbox notification
    set attempts = attempts + 1, lease_token = gen_random_uuid(),
      leased_until = clock_timestamp() + p_lease_seconds * interval '1 second'
    from claimed where notification.id = claimed.id returning notification.*;
end;
$$;
create function public.complete_notification(p_id uuid, p_lease_token uuid, p_error text default null) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_service();
  update private.notification_outbox set delivered_at = case when p_error is null then clock_timestamp() end,
    last_error = left(p_error, 1000), lease_token = null, leased_until = null,
    available_at = case when p_error is null then available_at else clock_timestamp()
      + least(3600, power(2, attempts)::integer * 15) * interval '1 second' end
    where id = p_id and lease_token = p_lease_token and leased_until > clock_timestamp() and delivered_at is null;
  return found;
end;
$$;
create function public.get_push_targets(p_user_id uuid) returns table(apns_token text, environment text)
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_service();
  return query select token.apns_token, token.environment from public.device_tokens token where token.user_id = p_user_id;
end;
$$;

create function public.get_invite_preview(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invites; next_match public.matches; group_name text; inviter_name text; yes_count bigint;
begin
  perform private.require_service();
  select * into invitation from public.group_invites where code = p_code;
  if not found or invitation.revoked_at is not null or invitation.expires_at <= clock_timestamp()
    or not exists (select 1 from public.group_members where group_id = invitation.group_id
      and user_id = invitation.created_by and left_at is null)
    then raise exception 'INVITE_NOT_AVAILABLE' using errcode = '22023'; end if;
  select name into group_name from public.groups where id = invitation.group_id;
  select display_name into inviter_name from public.profiles where id = invitation.created_by;
  select * into next_match from public.matches where group_id = invitation.group_id and status in ('scheduled', 'locked')
    and starts_at > clock_timestamp() order by starts_at, id limit 1;
  select count(*) into yes_count from public.rsvps where match_id = next_match.id and status = 'yes';
  return jsonb_build_object('group_name', group_name, 'inviter_name', inviter_name,
    'next_match', case when next_match.id is not null then jsonb_build_object(
      'id', next_match.id, 'format', next_match.format, 'venue', next_match.venue, 'starts_at', next_match.starts_at,
      'rsvp_lock_at', next_match.rsvp_lock_at, 'rsvp_open', next_match.status = 'scheduled' and next_match.rsvp_lock_at > clock_timestamp(),
      'confirmed', yes_count, 'capacity', next_match.capacity, 'expected_cost', next_match.expected_cost,
      'estimated_cost_per_person', round(next_match.expected_cost / next_match.capacity, 2)) end);
end;
$$;

create function public.submit_web_rsvp(p_code text, p_match_id uuid, p_name text,
  p_status public.rsvp_status, p_token_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare invitation public.group_invites; match_row public.matches; responder public.web_responders;
  response public.rsvps; guest_id uuid; queue_position bigint;
begin
  perform private.require_service();
  if p_token_hash is null or p_token_hash !~ '^[a-f0-9]{64}$'
    then raise exception 'INVALID_RESPONSE_TOKEN_HASH' using errcode = '22023'; end if;
  select * into invitation from public.group_invites where code = p_code for share;
  if not found or invitation.revoked_at is not null or invitation.expires_at <= clock_timestamp()
    or not exists (select 1 from public.group_members where group_id = invitation.group_id
      and user_id = invitation.created_by and left_at is null)
    then raise exception 'INVITE_NOT_AVAILABLE' using errcode = '22023'; end if;
  select * into match_row from public.matches where id = p_match_id and group_id = invitation.group_id for update;
  if not found then raise exception 'INVITE_MATCH_MISMATCH' using errcode = '42501'; end if;
  if match_row.status <> 'scheduled' or clock_timestamp() >= match_row.rsvp_lock_at
    then raise exception 'RSVP_LOCKED' using errcode = '55000'; end if;
  select * into responder from public.web_responders where match_id = p_match_id and token_hash = p_token_hash for update;
  if found then
    if responder.claimed_by_user_id is not null or exists (select 1 from public.guests where id = responder.guest_id and claimed_by_user_id is not null)
      then raise exception 'WEB_RESPONSE_ALREADY_CLAIMED' using errcode = '42501'; end if;
    guest_id := responder.guest_id;
    update public.guests set name = btrim(p_name) where id = guest_id;
  else
    insert into public.guests(group_id, name, invited_by) values (invitation.group_id, btrim(p_name), invitation.created_by)
      returning id into guest_id;
  end if;
  response := private.save_rsvp(p_match_id, null, guest_id, p_status);
  insert into public.web_responders(match_id, group_id, invite_id, guest_id, name, status, token_hash)
  values (p_match_id, invitation.group_id, invitation.id, guest_id, btrim(p_name), response.status, p_token_hash)
  on conflict (match_id, token_hash) do update set name = excluded.name, status = excluded.status;
  select position_in_waitlist into queue_position from public.rsvps_with_waitlist_position where id = response.id;
  return jsonb_build_object('response_id', response.id, 'status', response.status, 'position_in_waitlist', queue_position);
end;
$$;

revoke all on private.maintenance_state, private.notification_outbox from public, anon, authenticated, service_role;
revoke all on function public.create_match_series(uuid,smallint,time,text,text,numeric,integer,numeric,text),
  public.update_match_series(uuid,smallint,time,text,text,numeric,integer,numeric,text,boolean),
  public.set_series_active(uuid,boolean), public.skip_series_occurrence(uuid,date), public.create_recurring_matches(),
  public.run_maintenance(), public.claim_notifications(integer,integer), public.complete_notification(uuid,uuid,text),
  public.get_push_targets(uuid), public.get_invite_preview(text), public.submit_web_rsvp(text,uuid,text,public.rsvp_status,text)
  from public, anon, authenticated, service_role;
grant execute on function public.create_match_series(uuid,smallint,time,text,text,numeric,integer,numeric,text),
  public.update_match_series(uuid,smallint,time,text,text,numeric,integer,numeric,text,boolean),
  public.set_series_active(uuid,boolean), public.skip_series_occurrence(uuid,date) to authenticated;
grant execute on function public.create_recurring_matches(), public.run_maintenance(), public.claim_notifications(integer,integer),
  public.complete_notification(uuid,uuid,text), public.get_push_targets(uuid), public.get_invite_preview(text),
  public.submit_web_rsvp(text,uuid,text,public.rsvp_status,text) to service_role;

commit;