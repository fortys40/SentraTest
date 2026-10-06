begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
revoke create on schema public from public, anon, authenticated;
alter default privileges revoke execute on functions from public, anon, authenticated, service_role;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges in schema private revoke execute on functions from public, anon, authenticated;

create type public.player_position as enum ('GK', 'DEF', 'MID', 'FWD', 'ANY');
create type public.member_role as enum ('owner', 'admin', 'member');
create type public.rsvp_status as enum ('yes', 'maybe', 'no', 'waitlist');
create type public.match_status as enum ('scheduled', 'locked', 'finished', 'cancelled');
create type public.team_side as enum ('A', 'B');
create type public.match_winner as enum ('A', 'B', 'draw');

create table public.match_formats (
  code text primary key,
  players_per_team smallint not null check (players_per_team between 2 and 30),
  active boolean not null default true,
  unique (code, players_per_team),
  check (code = players_per_team::text || 'x' || players_per_team::text)
);
insert into public.match_formats (code, players_per_team)
values ('5x5', 5), ('7x7', 7), ('8x8', 8), ('11x11', 11);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  position public.player_position not null default 'ANY',
  avatar_url text check (char_length(avatar_url) <= 2048),
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (not onboarding_completed or char_length(btrim(display_name)) between 1 and 80)
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  owner_id uuid not null references public.profiles(id),
  default_format text not null references public.match_formats(code),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id),
  role public.member_role not null default 'member',
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique (group_id, user_id),
  check (role <> 'owner' or left_at is null),
  check (left_at is null or left_at >= joined_at)
);
create unique index group_members_one_owner on public.group_members(group_id) where role = 'owner';
create index group_members_user on public.group_members(user_id, group_id) where left_at is null;
alter table public.groups add constraint groups_owner_membership
  foreign key (id, owner_id) references public.group_members(group_id, user_id)
  deferrable initially deferred;

create table public.group_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique default replace(gen_random_uuid()::text, '-', ''),
  group_id uuid not null references public.groups(id) on delete cascade,
  created_by uuid not null,
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (id, group_id),
  foreign key (group_id, created_by) references public.group_members(group_id, user_id),
  check (code ~ '^[a-f0-9]{32}$'),
  check (expires_at is null or expires_at > created_at)
);
create index group_invites_group on public.group_invites(group_id);

create table public.guests (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  invited_by uuid not null,
  claimed_by_user_id uuid references public.profiles(id),
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, group_id),
  foreign key (group_id, invited_by) references public.group_members(group_id, user_id),
  foreign key (group_id, claimed_by_user_id) references public.group_members(group_id, user_id),
  check ((claimed_by_user_id is null) = (claimed_at is null))
);
create index guests_group on public.guests(group_id);
create index guests_claimed on public.guests(claimed_by_user_id) where claimed_by_user_id is not null;

create table public.match_series (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  timezone text not null default 'Europe/Athens',
  venue text not null check (char_length(btrim(venue)) between 1 and 200),
  format text not null,
  players_per_team smallint not null,
  default_cost numeric(12,2) check (default_cost between 0 and 9999999999.99),
  create_days_before integer not null default 5 check (create_days_before between 1 and 30),
  rsvp_lock_hours numeric(5,2) not null default 2 check (rsvp_lock_hours between 0 and 168),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, group_id),
  foreign key (format, players_per_team) references public.match_formats(code, players_per_team)
);
create index match_series_group on public.match_series(group_id);

create table public.series_skips (
  id uuid primary key default gen_random_uuid(),
  series_id uuid not null references public.match_series(id) on delete cascade,
  occurrence_date date not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (series_id, occurrence_date)
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id),
  series_id uuid,
  occurrence_date date,
  format text not null,
  players_per_team smallint not null,
  capacity integer generated always as (players_per_team * 2) stored,
  venue text not null check (char_length(btrim(venue)) between 1 and 200),
  starts_at timestamptz not null,
  rsvp_lock_at timestamptz not null,
  expected_cost numeric(12,2) check (expected_cost between 0 and 9999999999.99),
  status public.match_status not null default 'scheduled',
  winner public.match_winner,
  score_a integer check (score_a between 0 and 999),
  score_b integer check (score_b between 0 and 999),
  goals_recorded boolean not null default false,
  finished_at timestamptz,
  mvp_voting_closes_at timestamptz,
  mvp_closed_at timestamptz,
  cost_split_enabled boolean not null default false,
  total_cost numeric(12,2) check (total_cost between 0 and 9999999999.99),
  paid_by uuid,
  share_amount numeric(12,2) check (share_amount between 0 and 9999999999.99),
  rounding_remainder numeric(12,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, group_id),
  unique (series_id, occurrence_date),
  foreign key (format, players_per_team) references public.match_formats(code, players_per_team),
  foreign key (series_id, group_id) references public.match_series(id, group_id),
  foreign key (group_id, paid_by) references public.group_members(group_id, user_id),
  check ((series_id is null) = (occurrence_date is null)),
  check (rsvp_lock_at <= starts_at),
  check ((score_a is null) = (score_b is null)),
  check ((status = 'finished') = (finished_at is not null)),
  check ((status = 'finished') = (mvp_voting_closes_at is not null)),
  check (status = 'finished' or (winner is null and score_a is null and not goals_recorded)),
  check (mvp_closed_at is null or status = 'finished'),
  check (not goals_recorded or score_a is not null),
  check ((cost_split_enabled and status = 'finished' and total_cost is not null
    and paid_by is not null and share_amount is not null and rounding_remainder is not null)
    or (not cost_split_enabled and total_cost is null and paid_by is null
    and share_amount is null and rounding_remainder is null))
);
create index matches_group_start on public.matches(group_id, starts_at desc, id);
create index matches_due_lock on public.matches(rsvp_lock_at) where status = 'scheduled';
create index matches_due_voting on public.matches(mvp_voting_closes_at)
  where status = 'finished' and mvp_closed_at is null;

create sequence private.waitlist_order;
create table public.rsvps (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null,
  group_id uuid not null,
  user_id uuid,
  guest_id uuid,
  status public.rsvp_status not null,
  waitlisted_at timestamptz,
  waitlist_order bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (match_id, group_id) references public.matches(id, group_id),
  foreign key (group_id, user_id) references public.group_members(group_id, user_id),
  foreign key (guest_id, group_id) references public.guests(id, group_id),
  check (num_nonnulls(user_id, guest_id) = 1),
  check ((status = 'waitlist' and waitlisted_at is not null and waitlist_order is not null)
    or (status <> 'waitlist' and waitlisted_at is null and waitlist_order is null))
);
create unique index rsvps_user on public.rsvps(match_id, user_id) where user_id is not null;
create unique index rsvps_guest on public.rsvps(match_id, guest_id) where guest_id is not null;
create index rsvps_queue on public.rsvps(match_id, waitlist_order) where status = 'waitlist';
create index rsvps_count on public.rsvps(match_id, status);

create table public.rsvp_history (
  id uuid primary key default gen_random_uuid(),
  rsvp_id uuid not null references public.rsvps(id),
  match_id uuid not null,
  group_id uuid not null,
  user_id uuid references public.profiles(id),
  guest_id uuid references public.guests(id),
  old_status public.rsvp_status,
  new_status public.rsvp_status not null,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default clock_timestamp(),
  hours_before_kickoff numeric not null,
  foreign key (match_id, group_id) references public.matches(id, group_id),
  check (num_nonnulls(user_id, guest_id) = 1)
);
create index rsvp_history_person on public.rsvp_history(user_id, match_id, changed_at);
create index rsvp_history_guest on public.rsvp_history(guest_id) where guest_id is not null;

create table public.web_responders (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null,
  group_id uuid not null,
  invite_id uuid not null,
  guest_id uuid not null unique,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  status public.rsvp_status not null,
  token_hash text not null check (token_hash ~ '^[a-f0-9]{64}$'),
  claimed_by_user_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, token_hash),
  foreign key (match_id, group_id) references public.matches(id, group_id),
  foreign key (invite_id, group_id) references public.group_invites(id, group_id),
  foreign key (guest_id, group_id) references public.guests(id, group_id)
);

create table public.match_participants (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null,
  group_id uuid not null,
  user_id uuid,
  guest_id uuid,
  team public.team_side,
  charged_to_user_id uuid not null,
  created_at timestamptz not null default now(),
  unique (id, match_id),
  foreign key (match_id, group_id) references public.matches(id, group_id),
  foreign key (group_id, user_id) references public.group_members(group_id, user_id),
  foreign key (guest_id, group_id) references public.guests(id, group_id),
  foreign key (group_id, charged_to_user_id) references public.group_members(group_id, user_id),
  check (num_nonnulls(user_id, guest_id) = 1),
  check (user_id is null or charged_to_user_id = user_id)
);
create unique index participants_user on public.match_participants(match_id, user_id) where user_id is not null;
create unique index participants_guest on public.match_participants(match_id, guest_id) where guest_id is not null;
create index participants_group on public.match_participants(group_id);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id),
  scorer_participant_id uuid not null,
  team public.team_side not null,
  minute integer check (minute between 0 and 300),
  created_at timestamptz not null default now(),
  foreign key (scorer_participant_id, match_id) references public.match_participants(id, match_id)
);
create index goals_match on public.goals(match_id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null,
  group_id uuid not null,
  debtor_user_id uuid not null,
  amount numeric(12,2) not null check (amount between 0 and 9999999999.99),
  includes_guest_ids uuid[] not null default '{}',
  paid boolean not null default false,
  paid_at timestamptz,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (match_id, debtor_user_id),
  foreign key (match_id, group_id) references public.matches(id, group_id),
  foreign key (group_id, debtor_user_id) references public.group_members(group_id, user_id),
  check (paid = (paid_at is not null))
);
create index payments_debtor on public.payments(debtor_user_id) where not paid;

create table public.mvp_eligible_voters (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id),
  voter_id uuid not null references public.profiles(id),
  unique (match_id, voter_id)
);
create table public.mvp_votes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id),
  voter_id uuid not null references public.profiles(id),
  voted_participant_id uuid not null,
  voted_user_id uuid references public.profiles(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (match_id, voter_id),
  foreign key (match_id, voter_id) references public.mvp_eligible_voters(match_id, voter_id),
  foreign key (voted_participant_id, match_id) references public.match_participants(id, match_id),
  check (voter_id is distinct from voted_user_id)
);
create table public.mvp_results (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id),
  participant_id uuid not null,
  votes integer not null check (votes > 0),
  created_at timestamptz not null default now(),
  unique (match_id, participant_id),
  foreign key (participant_id, match_id) references public.match_participants(id, match_id)
);

create table public.badge_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z][a-z0-9_]*$'),
  name_el text not null,
  emoji text not null,
  description_el text not null,
  rule_params jsonb not null check (jsonb_typeof(rule_params) = 'object'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.player_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  group_id uuid references public.groups(id),
  badge_code text not null references public.badge_definitions(code),
  rule_snapshot jsonb not null,
  awarded_at timestamptz not null default now(),
  unique nulls not distinct (user_id, group_id, badge_code)
);
create index player_badges_group on public.player_badges(group_id);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  apns_token text not null check (apns_token ~ '^[a-f0-9]{64,200}$'),
  environment text not null check (environment in ('sandbox', 'production')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (apns_token, environment)
);
create index device_tokens_user on public.device_tokens(user_id);

create table private.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.profiles(id),
  kind text not null check (kind in ('waitlist_promoted', 'match_created', 'rsvp_reminder', 'mvp_closed', 'badge_awarded')),
  payload jsonb not null,
  dedupe_key text not null unique,
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  lease_token uuid,
  leased_until timestamptz,
  delivered_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);
create index notification_outbox_pending on private.notification_outbox(available_at)
  where delivered_at is null;

do $$
declare table_name text;
begin
  foreach table_name in array array['match_formats', 'profiles', 'groups', 'group_members',
    'group_invites', 'guests', 'match_series', 'series_skips', 'matches', 'rsvps', 'rsvp_history',
    'web_responders', 'match_participants', 'goals', 'payments', 'mvp_eligible_voters', 'mvp_votes',
    'mvp_results', 'badge_definitions', 'player_badges', 'device_tokens'] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', table_name);
  end loop;
end;
$$;
revoke all on all tables in schema private from public, anon, authenticated, service_role;
revoke all on all sequences in schema private from public, anon, authenticated, service_role;

commit;