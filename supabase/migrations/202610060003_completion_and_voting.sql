begin;

create function private.guard_participant() returns trigger
language plpgsql security definer set search_path = '' as $$
declare target_match uuid; match_row public.matches; identity_user uuid; guest_row public.guests;
begin
  target_match := case when tg_op = 'DELETE' then old.match_id else new.match_id end;
  select * into match_row from public.matches where id = target_match for update;
  if match_row.status in ('finished', 'cancelled') then raise exception 'PLAYED_ROSTER_FROZEN' using errcode = '55000'; end if;
  if tg_op = 'DELETE' then return old; end if;
  if tg_op = 'UPDATE' and (new.id, new.match_id, new.group_id, new.user_id, new.guest_id)
    is distinct from (old.id, old.match_id, old.group_id, old.user_id, old.guest_id)
    then raise exception 'PARTICIPANT_IDENTITY_IMMUTABLE' using errcode = '23514'; end if;
  if new.guest_id is not null then
    select * into guest_row from public.guests where id = new.guest_id and group_id = new.group_id;
    if not found then raise exception 'GUEST_GROUP_MISMATCH' using errcode = '23503'; end if;
    new.charged_to_user_id := guest_row.invited_by;
  else new.charged_to_user_id := new.user_id; end if;
  identity_user := coalesce(new.user_id, guest_row.claimed_by_user_id);
  if identity_user is not null and exists (
    select 1 from public.match_participants participant left join public.guests guest on guest.id = participant.guest_id
    where participant.match_id = new.match_id and participant.id <> new.id
      and coalesce(participant.user_id, guest.claimed_by_user_id) = identity_user
  ) then raise exception 'DUPLICATE_PLAYER_IDENTITY' using errcode = '23505'; end if;
  return new;
end;
$$;
create trigger guard_participant before insert or update or delete on public.match_participants
for each row execute function private.guard_participant();

create function private.guard_goal() returns trigger
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; participant_team public.team_side; goal_limit integer;
begin
  select * into match_row from public.matches where id = new.match_id for update;
  if match_row.status <> 'finished' or not match_row.goals_recorded or match_row.score_a is null
    then raise exception 'SCORE_REQUIRED_FOR_GOALS' using errcode = '23514'; end if;
  select team into participant_team from public.match_participants where id = new.scorer_participant_id and match_id = new.match_id;
  if not found then raise exception 'SCORER_NOT_IN_MATCH' using errcode = '23503'; end if;
  if participant_team is not null and participant_team <> new.team
    then raise exception 'SCORER_TEAM_MISMATCH' using errcode = '23514'; end if;
  goal_limit := case when new.team = 'A' then match_row.score_a else match_row.score_b end;
  if (select count(*) from public.goals where match_id = new.match_id and team = new.team and id <> new.id) >= goal_limit
    then raise exception 'GOALS_EXCEED_SCORE' using errcode = '23514'; end if;
  return new;
end;
$$;
create trigger guard_goal before insert or update on public.goals for each row execute function private.guard_goal();

create function private.set_match_result(target_match uuid, selected_winner public.match_winner,
  selected_score_a integer, selected_score_b integer, selected_goals jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare goal_row record; scorer uuid;
begin
  if (selected_score_a is null) <> (selected_score_b is null)
    then raise exception 'BOTH_SCORES_REQUIRED' using errcode = '22023'; end if;
  if selected_goals is not null and (jsonb_typeof(selected_goals) <> 'array' or selected_score_a is null)
    then raise exception 'GOALS_REQUIRE_SCORE_AND_ARRAY' using errcode = '22023'; end if;
  delete from public.goals where match_id = target_match;
  update public.matches set winner = selected_winner, score_a = selected_score_a, score_b = selected_score_b,
    goals_recorded = selected_goals is not null where id = target_match;
  if selected_goals is not null then
    for goal_row in select * from jsonb_to_recordset(selected_goals)
      as goal_input(user_id uuid, guest_id uuid, team public.team_side, minute integer) loop
      if num_nonnulls(goal_row.user_id, goal_row.guest_id) <> 1
        then raise exception 'ONE_SCORER_ID_REQUIRED' using errcode = '22023'; end if;
      select id into scorer from public.match_participants where match_id = target_match
        and user_id is not distinct from goal_row.user_id and guest_id is not distinct from goal_row.guest_id;
      if not found then raise exception 'SCORER_NOT_IN_MATCH' using errcode = '23503'; end if;
      insert into public.goals(match_id, scorer_participant_id, team, minute)
        values (target_match, scorer, goal_row.team, goal_row.minute);
    end loop;
  end if;
end;
$$;

create function private.apply_cost_split(target_match uuid, enabled boolean, cost numeric, payer uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; participant_count integer; share numeric(12,2);
begin
  select * into match_row from public.matches where id = target_match for update;
  if not found or match_row.status <> 'finished' then raise exception 'FINISHED_MATCH_REQUIRED' using errcode = '55000'; end if;
  if enabled is null then raise exception 'COST_SPLIT_ENABLED_REQUIRED' using errcode = '22023'; end if;
  if enabled and (cost is null or cost < 0 or cost > 9999999999.99 or cost <> round(cost, 2) or payer is null)
    then raise exception 'VALID_COST_AND_PAYER_REQUIRED' using errcode = '22023'; end if;
  if (enabled, case when enabled then cost end, case when enabled then payer end)
    is not distinct from (match_row.cost_split_enabled, match_row.total_cost, match_row.paid_by) then return; end if;
  if exists (select 1 from public.payments where match_id = target_match and paid and amount > 0
    and debtor_user_id <> match_row.paid_by)
    then raise exception 'UNMARK_SETTLED_PAYMENTS_BEFORE_RECALCULATING' using errcode = '55000'; end if;
  if not enabled then
    delete from public.payments where match_id = target_match;
    update public.matches set cost_split_enabled = false, total_cost = null, paid_by = null,
      share_amount = null, rounding_remainder = null where id = target_match;
    return;
  end if;
  if not exists (select 1 from public.group_members where group_id = match_row.group_id and user_id = payer and left_at is null)
    then raise exception 'PAYER_MUST_BE_MEMBER' using errcode = '23514'; end if;
  select count(*) into participant_count from public.match_participants where match_id = target_match;
  if participant_count = 0 then raise exception 'PLAYED_PARTICIPANTS_REQUIRED' using errcode = '22023'; end if;
  share := round(cost / participant_count / 0.50) * 0.50;
  delete from public.payments where match_id = target_match;
  update public.matches set cost_split_enabled = true, total_cost = cost, paid_by = payer,
    share_amount = share, rounding_remainder = cost - share * participant_count where id = target_match;
  insert into public.payments(match_id, group_id, debtor_user_id, amount, includes_guest_ids, paid, paid_at, updated_by)
  select target_match, match_row.group_id, charged_to_user_id, count(*) * share,
    coalesce(array_agg(guest_id order by guest_id) filter (where guest_id is not null), '{}'::uuid[]),
    charged_to_user_id = payer or share = 0,
    case when charged_to_user_id = payer or share = 0 then clock_timestamp() end, auth.uid()
  from public.match_participants where match_id = target_match group by charged_to_user_id;
end;
$$;

create function private.check_cost_balance() returns trigger
language plpgsql security definer set search_path = '' as $$
declare target_match uuid; match_row public.matches; liability numeric;
begin
  if tg_table_name = 'matches' then target_match := coalesce(new.id, old.id);
  else target_match := coalesce(new.match_id, old.match_id); end if;
  select * into match_row from public.matches where id = target_match;
  if not found then return null; end if;
  select coalesce(sum(amount), 0) into liability from public.payments where match_id = target_match;
  if (not match_row.cost_split_enabled and exists (select 1 from public.payments where match_id = target_match))
    or (match_row.cost_split_enabled and liability + match_row.rounding_remainder <> match_row.total_cost)
    then raise exception 'COST_SPLIT_NOT_BALANCED' using errcode = '23514'; end if;
  return null;
end;
$$;
create constraint trigger match_cost_balance after insert or update on public.matches
deferrable initially deferred for each row execute function private.check_cost_balance();
create constraint trigger payments_cost_balance after insert or update or delete on public.payments
deferrable initially deferred for each row execute function private.check_cost_balance();

create function public.set_cost_split(p_match_id uuid, p_enabled boolean,
  p_total_cost numeric default null, p_paid_by uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  perform private.apply_cost_split(p_match_id, p_enabled, p_total_cost, coalesce(p_paid_by,
    (select owner_id from public.groups where id = (select group_id from public.matches where id = p_match_id))));
end;
$$;
create function public.compute_cost_split(p_match_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches;
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  select * into match_row from public.matches where id = p_match_id for update;
  perform private.apply_cost_split(p_match_id, match_row.cost_split_enabled, match_row.total_cost, match_row.paid_by);
end;
$$;
create function public.mark_payment_paid(p_payment_id uuid, p_paid boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare payment_row public.payments; payer uuid;
begin
  select * into payment_row from public.payments where id = p_payment_id;
  perform private.require_member(payment_row.group_id, true);
  select paid_by into payer from public.matches where id = payment_row.match_id for update;
  if not p_paid and payment_row.debtor_user_id = payer
    then raise exception 'PAYER_OWN_SHARE_IS_SETTLED' using errcode = '22023'; end if;
  update public.payments set paid = p_paid, paid_at = case when p_paid then clock_timestamp() end,
    updated_by = auth.uid() where id = p_payment_id;
end;
$$;

create function private.close_mvp_voting(target_match uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; winners jsonb;
begin
  select * into match_row from public.matches where id = target_match for update;
  if not found or match_row.status <> 'finished' or match_row.mvp_closed_at is not null then return false; end if;
  if clock_timestamp() < match_row.mvp_voting_closes_at
    and (select count(*) from public.mvp_votes where match_id = target_match)
      < (select count(*) from public.mvp_eligible_voters where match_id = target_match) then return false; end if;
  insert into public.mvp_results(match_id, participant_id, votes)
  with tallies as (
    select voted_participant_id, count(*)::integer as votes from public.mvp_votes
    where match_id = target_match group by voted_participant_id
  ) select target_match, voted_participant_id, votes from tallies where votes = (select max(votes) from tallies);
  update public.matches set mvp_closed_at = clock_timestamp() where id = target_match;
  select jsonb_agg(jsonb_build_object('participant_id', result.participant_id, 'votes', result.votes,
    'name', coalesce(profile.display_name, guest.name)) order by result.participant_id) into winners
  from public.mvp_results result join public.match_participants participant on participant.id = result.participant_id
  left join public.profiles profile on profile.id = participant.user_id
  left join public.guests guest on guest.id = participant.guest_id where result.match_id = target_match;
  if winners is not null then
    insert into private.notification_outbox(recipient_user_id, kind, payload, dedupe_key)
    select user_id, 'mvp_closed', jsonb_build_object('match_id', target_match, 'winners', winners),
      'mvp:' || target_match || ':' || user_id from public.group_members
    where group_id = match_row.group_id and left_at is null on conflict do nothing;
  end if;
  return true;
end;
$$;
create function public.close_mvp_voting(p_match_id uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    perform private.require_member((select group_id from public.matches where id = p_match_id));
  end if;
  return private.close_mvp_voting(p_match_id);
end;
$$;

create function private.guard_mvp_vote() returns trigger
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; candidate_user uuid;
begin
  select * into match_row from public.matches where id = new.match_id for update;
  if match_row.status <> 'finished' or match_row.mvp_closed_at is not null or clock_timestamp() >= match_row.mvp_voting_closes_at
    then raise exception 'MVP_VOTING_CLOSED' using errcode = '55000'; end if;
  select coalesce(participant.user_id, guest.claimed_by_user_id) into candidate_user
    from public.match_participants participant left join public.guests guest on guest.id = participant.guest_id
    where participant.id = new.voted_participant_id and participant.match_id = new.match_id;
  if not found then raise exception 'CANDIDATE_NOT_IN_MATCH' using errcode = '23503'; end if;
  if candidate_user = new.voter_id then raise exception 'MVP_SELF_VOTE_FORBIDDEN' using errcode = '23514'; end if;
  new.voted_user_id := candidate_user;
  return new;
end;
$$;
create trigger guard_mvp_vote before insert on public.mvp_votes for each row execute function private.guard_mvp_vote();
create function private.after_mvp_vote() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.close_mvp_voting(new.match_id);
  return null;
end;
$$;
create trigger after_mvp_vote after insert on public.mvp_votes for each row execute function private.after_mvp_vote();

create function public.cast_mvp_vote(p_match_id uuid, p_participant_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id));
  if not exists (select 1 from public.mvp_eligible_voters where match_id = p_match_id and voter_id = auth.uid())
    then raise exception 'PLAYED_VOTER_REQUIRED' using errcode = '42501'; end if;
  insert into public.mvp_votes(match_id, voter_id, voted_participant_id) values (p_match_id, auth.uid(), p_participant_id);
end;
$$;
create function public.get_voting_state(p_match_id uuid)
returns table(eligible_voters bigint, votes_cast bigint, has_voted boolean, closes_at timestamptz, closed_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id));
  return query select
    (select count(*) from public.mvp_eligible_voters where match_id = p_match_id),
    (select count(*) from public.mvp_votes where match_id = p_match_id),
    exists (select 1 from public.mvp_votes where match_id = p_match_id and voter_id = auth.uid()),
    match_row.mvp_voting_closes_at, match_row.mvp_closed_at from public.matches match_row where match_row.id = p_match_id;
end;
$$;

create function public.finish_match(p_match_id uuid, p_participants jsonb,
  p_winner public.match_winner default null, p_score_a integer default null, p_score_b integer default null,
  p_goals jsonb default null, p_total_cost numeric default null, p_paid_by uuid default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare match_row public.matches; participant_row record; completed timestamptz;
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  select * into match_row from public.matches where id = p_match_id for update;
  if match_row.status = 'finished' then return p_match_id; end if;
  if match_row.status = 'cancelled' or match_row.starts_at > clock_timestamp()
    then raise exception 'MATCH_CANNOT_BE_FINISHED' using errcode = '55000'; end if;
  if p_participants is null or jsonb_typeof(p_participants) <> 'array'
    then raise exception 'PARTICIPANTS_ARRAY_REQUIRED' using errcode = '22023'; end if;
  if jsonb_array_length(p_participants) not between 1 and 200
    then raise exception 'PLAYED_PARTICIPANTS_REQUIRED' using errcode = '22023'; end if;
  delete from public.match_participants where match_id = p_match_id;
  for participant_row in select * from jsonb_to_recordset(p_participants)
    as participant_input(user_id uuid, guest_id uuid, team public.team_side) loop
    insert into public.match_participants(match_id, group_id, user_id, guest_id, team, charged_to_user_id)
      values (p_match_id, match_row.group_id, participant_row.user_id, participant_row.guest_id,
        participant_row.team, participant_row.user_id);
  end loop;
  completed := clock_timestamp();
  update public.matches set status = 'finished', finished_at = completed, mvp_voting_closes_at = completed + interval '24 hours'
    where id = p_match_id;
  perform private.set_match_result(p_match_id, p_winner, p_score_a, p_score_b, p_goals);
  insert into public.mvp_eligible_voters(match_id, voter_id)
  select p_match_id, coalesce(participant.user_id, guest.claimed_by_user_id)
  from public.match_participants participant left join public.guests guest on guest.id = participant.guest_id
  where participant.match_id = p_match_id and coalesce(participant.user_id, guest.claimed_by_user_id) is not null;
  if p_total_cost is not null then
    perform private.apply_cost_split(p_match_id, true, p_total_cost,
      coalesce(p_paid_by, (select owner_id from public.groups where id = match_row.group_id)));
  end if;
  perform private.close_mvp_voting(p_match_id);
  return p_match_id;
end;
$$;
create function public.record_match_result(p_match_id uuid, p_winner public.match_winner default null,
  p_score_a integer default null, p_score_b integer default null, p_goals jsonb default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_member((select group_id from public.matches where id = p_match_id), true);
  perform 1 from public.matches where id = p_match_id and status = 'finished' for update;
  if not found then raise exception 'FINISHED_MATCH_REQUIRED' using errcode = '55000'; end if;
  perform private.set_match_result(p_match_id, p_winner, p_score_a, p_score_b, p_goals);
end;
$$;

create view public.outstanding_payments with (security_invoker = true) as
select payment.id, payment.match_id, payment.group_id, payment.debtor_user_id, payment.amount,
  payment.includes_guest_ids, match_row.paid_by as creditor_user_id, creditor.display_name as creditor_name
from public.payments payment join public.matches match_row on match_row.id = payment.match_id
join public.profiles creditor on creditor.id = match_row.paid_by where not payment.paid;
grant select on public.outstanding_payments to authenticated;

revoke all on function public.set_cost_split(uuid,boolean,numeric,uuid), public.compute_cost_split(uuid),
  public.mark_payment_paid(uuid,boolean), public.close_mvp_voting(uuid), public.cast_mvp_vote(uuid,uuid),
  public.get_voting_state(uuid), public.finish_match(uuid,jsonb,public.match_winner,integer,integer,jsonb,numeric,uuid),
  public.record_match_result(uuid,public.match_winner,integer,integer,jsonb) from public, anon, authenticated, service_role;
grant execute on function public.set_cost_split(uuid,boolean,numeric,uuid), public.compute_cost_split(uuid),
  public.mark_payment_paid(uuid,boolean), public.close_mvp_voting(uuid), public.cast_mvp_vote(uuid,uuid),
  public.get_voting_state(uuid), public.finish_match(uuid,jsonb,public.match_winner,integer,integer,jsonb,numeric,uuid),
  public.record_match_result(uuid,public.match_winner,integer,integer,jsonb) to authenticated;
grant execute on function public.close_mvp_voting(uuid) to service_role;

commit;