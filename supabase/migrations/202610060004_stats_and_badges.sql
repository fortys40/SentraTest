begin;

create function private.validate_badge_rule() returns trigger language plpgsql set search_path = '' as $$
begin
  if coalesce(new.rule_params->>'metric', '') not in ('current_streak', 'mvp_count', 'late_cancellations')
    or coalesce((new.rule_params->>'threshold')::integer, 0) not between 1 and 1000000
    or coalesce(jsonb_typeof(new.rule_params->'scopes'), '') <> 'array'
    then raise exception 'INVALID_BADGE_RULE' using errcode = '23514'; end if;
  if jsonb_array_length(new.rule_params->'scopes') = 0 or exists (
    select 1 from jsonb_array_elements_text(new.rule_params->'scopes') scope(value)
    where value not in ('group', 'overall')) then raise exception 'INVALID_BADGE_SCOPE' using errcode = '23514'; end if;
  if new.rule_params->>'metric' = 'late_cancellations' and (
    coalesce((new.rule_params->>'lookback_matches')::integer, 0) not between 1 and 1000
    or coalesce((new.rule_params->>'late_hours')::numeric, 0) not between 0.01 and 168)
    then raise exception 'INVALID_LATE_CANCELLATION_RULE' using errcode = '23514'; end if;
  return new;
end;
$$;
create trigger validate_badge_rule before insert or update on public.badge_definitions
for each row execute function private.validate_badge_rule();

insert into public.badge_definitions(code, name_el, emoji, description_el, rule_params) values
  ('attendance_streak', 'Σερί', '🔥', 'Έπαιξες σε 10 συνεχόμενους αγώνες της παρέας.',
    '{"metric":"current_streak","threshold":10,"scopes":["group"]}'),
  ('ghost', 'Φάντασμα', '👻', 'Ακύρωσες αργά σε 3 από τους τελευταίους 10 αγώνες.',
    '{"metric":"late_cancellations","threshold":3,"lookback_matches":10,"late_hours":24,"scopes":["group"]}'),
  ('mvp_5', '5x MVP', '🏆', 'Κέρδισες τον τίτλο MVP 5 φορές.',
    '{"metric":"mvp_count","threshold":5,"scopes":["group","overall"]}');

create view public.player_stats_view with (security_invoker = true) as
with goal_counts as (
  select scorer_participant_id, count(*) as goals from public.goals group by scorer_participant_id
), played as (
  select participant.id, participant.match_id, participant.group_id,
    coalesce(participant.user_id, guest.claimed_by_user_id) as user_id,
    match_row.starts_at, participant.team, match_row.winner,
    coalesce(goal_counts.goals, 0) as goals,
    case when result.id is not null and match_row.mvp_closed_at is not null then 1 else 0 end as mvp_count
  from public.match_participants participant join public.matches match_row on match_row.id = participant.match_id
  left join public.guests guest on guest.id = participant.guest_id
  left join goal_counts on goal_counts.scorer_participant_id = participant.id
  left join public.mvp_results result on result.participant_id = participant.id and result.match_id = participant.match_id
  where match_row.status = 'finished' and coalesce(participant.user_id, guest.claimed_by_user_id) is not null
), totals as (
  select membership.user_id, membership.group_id,
    count(played.id) as appearances,
    count(played.id) filter (where played.winner::text = played.team::text) as wins,
    count(played.id) filter (where played.team is not null and played.winner in ('A', 'B') and played.winner::text <> played.team::text) as losses,
    count(played.id) filter (where played.winner = 'draw') as draws,
    coalesce(sum(played.goals), 0)::bigint as goals,
    coalesce(sum(played.mvp_count), 0)::bigint as mvp_count
  from public.group_members membership left join played
    on played.group_id = membership.group_id and played.user_id = membership.user_id
  group by grouping sets ((membership.user_id, membership.group_id), (membership.user_id))
), group_timeline as (
  select membership.user_id, membership.group_id, match_row.id as match_id, match_row.starts_at,
    exists (select 1 from played where played.match_id = match_row.id and played.user_id = membership.user_id) as attended
  from public.group_members membership join public.matches match_row on match_row.group_id = membership.group_id
  where match_row.status = 'finished'
), timelines as (
  select * from group_timeline
  union all
  select user_id, null::uuid, match_id, starts_at, attended from group_timeline
), ranked as (
  select *, row_number() over (partition by user_id, group_id order by starts_at desc, match_id desc) as ordinal
  from timelines
), first_absences as (
  select user_id, group_id, min(ordinal) filter (where not attended) as first_absence from ranked group by user_id, group_id
), streaks as (
  select ranked.user_id, ranked.group_id,
    count(*) filter (where ranked.attended and (first_absences.first_absence is null or ranked.ordinal < first_absences.first_absence)) as current_streak
  from ranked join first_absences on first_absences.user_id = ranked.user_id
    and first_absences.group_id is not distinct from ranked.group_id
  group by ranked.user_id, ranked.group_id
)
select totals.*, round(100.0 * wins / nullif(wins + losses + draws, 0), 1) as win_pct,
  coalesce(streaks.current_streak, 0) as current_streak
from totals left join streaks on streaks.user_id = totals.user_id and streaks.group_id is not distinct from totals.group_id;

create view public.late_cancellations_view with (security_invoker = true) as
with ranked_matches as (
  select id, group_id, starts_at, row_number() over (partition by group_id order by starts_at desc, id desc) as recency
  from public.matches where starts_at <= now() and status <> 'cancelled'
)
select definition.code as badge_code, coalesce(history.user_id, guest.claimed_by_user_id) as user_id,
  history.group_id, history.match_id, max(history.changed_at) as last_cancelled_at
from public.rsvp_history history join ranked_matches match_row on match_row.id = history.match_id
left join public.guests guest on guest.id = history.guest_id
cross join public.badge_definitions definition
where definition.active and definition.rule_params->>'metric' = 'late_cancellations'
  and history.old_status = 'yes' and history.new_status = 'no'
  and history.hours_before_kickoff between 0 and (definition.rule_params->>'late_hours')::numeric
  and match_row.recency <= (definition.rule_params->>'lookback_matches')::integer
  and coalesce(history.user_id, guest.claimed_by_user_id) is not null
group by definition.code, coalesce(history.user_id, guest.claimed_by_user_id), history.group_id, history.match_id;

create function private.late_cancellation_count(target_user uuid, target_group uuid, params jsonb) returns bigint
language sql stable security definer set search_path = '' as $$
  with recent_matches as (
    select match_row.id from public.matches match_row
    join public.group_members membership on membership.group_id = match_row.group_id and membership.user_id = target_user
    where (target_group is null or match_row.group_id = target_group)
      and match_row.starts_at <= now() and match_row.status <> 'cancelled'
    order by match_row.starts_at desc, match_row.id desc limit (params->>'lookback_matches')::integer
  )
  select count(distinct history.match_id) from public.rsvp_history history
  join recent_matches on recent_matches.id = history.match_id
  left join public.guests guest on guest.id = history.guest_id
  where coalesce(history.user_id, guest.claimed_by_user_id) = target_user
    and history.old_status = 'yes' and history.new_status = 'no'
    and history.hours_before_kickoff between 0 and (params->>'late_hours')::numeric
$$;

create function private.evaluate_badges(target_user uuid) returns integer
language plpgsql security definer set search_path = '' as $$
declare definition public.badge_definitions; stats record; metric_value bigint; award_id uuid; awards integer := 0;
begin
  for stats in select * from public.player_stats_view where user_id = target_user loop
    for definition in select * from public.badge_definitions where active loop
      continue when not (definition.rule_params->'scopes' ? case when stats.group_id is null then 'overall' else 'group' end);
      metric_value := case definition.rule_params->>'metric'
        when 'current_streak' then stats.current_streak
        when 'mvp_count' then stats.mvp_count
        when 'late_cancellations' then private.late_cancellation_count(target_user, stats.group_id, definition.rule_params) end;
      if metric_value >= (definition.rule_params->>'threshold')::integer then
        insert into public.player_badges(user_id, group_id, badge_code, rule_snapshot)
        values (target_user, stats.group_id, definition.code, definition.rule_params)
        on conflict (user_id, group_id, badge_code) do nothing returning id into award_id;
        if found then
          awards := awards + 1;
          insert into private.notification_outbox(recipient_user_id, kind, payload, dedupe_key)
          values (target_user, 'badge_awarded', jsonb_build_object('badge_id', award_id, 'badge_code', definition.code, 'group_id', stats.group_id),
            'badge:' || award_id) on conflict do nothing;
        end if;
      end if;
    end loop;
  end loop;
  return awards;
end;
$$;

create function public.evaluate_badges(p_user_id uuid default auth.uid()) returns integer
language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id is null or (coalesce(auth.role(), '') <> 'service_role' and p_user_id is distinct from auth.uid())
    then raise exception 'BADGE_ACCESS_DENIED' using errcode = '42501'; end if;
  return private.evaluate_badges(p_user_id);
end;
$$;
create function public.get_my_stats() returns setof public.player_stats_view
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED' using errcode = '42501'; end if;
  return query select * from public.player_stats_view where user_id = auth.uid();
end;
$$;

create function private.evaluate_match_badges() returns trigger
language plpgsql security definer set search_path = '' as $$
declare player_id uuid;
begin
  if new.status = 'finished' and (old.status <> 'finished' or (old.mvp_closed_at is null and new.mvp_closed_at is not null)) then
    for player_id in select distinct coalesce(participant.user_id, guest.claimed_by_user_id)
      from public.match_participants participant left join public.guests guest on guest.id = participant.guest_id
      where participant.match_id = new.id and coalesce(participant.user_id, guest.claimed_by_user_id) is not null loop
      perform private.evaluate_badges(player_id);
    end loop;
  end if;
  return null;
end;
$$;
create trigger evaluate_match_badges after update of status, mvp_closed_at on public.matches
for each row execute function private.evaluate_match_badges();

grant select on public.player_stats_view, public.late_cancellations_view to authenticated;
revoke all on function public.evaluate_badges(uuid), public.get_my_stats() from public, anon, authenticated, service_role;
grant execute on function public.evaluate_badges(uuid), public.get_my_stats() to authenticated;
grant execute on function public.evaluate_badges(uuid) to service_role;

commit;