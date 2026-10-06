begin;

do $$
declare
  seed_group uuid := '30000000-0000-0000-0000-000000000001';
  seed_guest uuid := '50000000-0000-0000-0000-000000000001';
  seed_users uuid[] := '{}';
  names text[] := array['Γιώργος', 'Κώστας', 'Δημήτρης', 'Μάριος', 'Αλέξης', 'Πέτρος',
    'Στέλιος', 'Αντώνης', 'Χρήστος', 'Βασίλης', 'Σπύρος', 'Θανάσης'];
  player_index integer;
  match_index integer;
  player_id uuid;
  player_email text;
  seed_match_id uuid;
  kickoff timestamptz;
  roster jsonb;
  scorers jsonb;
  voter record;
  candidate uuid;
  payment_id uuid;
begin
  if exists (select 1 from public.groups where id = seed_group) then return; end if;
  for player_index in 1..12 loop
    player_id := ('20000000-0000-0000-0000-' || lpad(player_index::text, 12, '0'))::uuid;
    player_email := 'player' || lpad(player_index::text, 2, '0') || '@sentra.test';
    insert into auth.users(id, instance_id, aud, role, email, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values (player_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', player_email,
      now() - interval '90 days', '{"provider":"email","providers":["email"]}', '{}'::jsonb,
      now() - interval '90 days', now()) on conflict (id) do nothing;
    insert into auth.identities(user_id, provider_id, identity_data, provider)
    values (player_id, player_id::text, jsonb_build_object('sub', player_id, 'email', player_email, 'email_verified', true), 'email')
    on conflict (provider_id, provider) do nothing;
    update public.profiles set display_name = names[player_index], onboarding_completed = true,
      position = case when player_index in (1, 6) then 'GK'::public.player_position
        when player_index in (2, 7, 11) then 'DEF'::public.player_position
        when player_index in (3, 4, 8, 12) then 'MID'::public.player_position else 'FWD'::public.player_position end
      where id = player_id;
    seed_users := array_append(seed_users, player_id);
  end loop;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', seed_users[1], 'role', 'authenticated')::text, true);
  insert into public.groups(id, name, owner_id, default_format, created_at)
    values (seed_group, 'Η παρέα της Τρίτης', seed_users[1], '5x5', now() - interval '90 days');
  insert into public.group_members(group_id, user_id, role, joined_at)
  select seed_group, member.user_id, case when member.ordinal = 1 then 'owner'::public.member_role
    when member.ordinal = 2 then 'admin'::public.member_role else 'member'::public.member_role end,
    now() - interval '90 days' from unnest(seed_users) with ordinality member(user_id, ordinal);
  insert into public.group_invites(group_id, created_by, code)
    values (seed_group, seed_users[1], '0123456789abcdef0123456789abcdef');
  insert into public.guests(id, group_id, name, invited_by)
    values (seed_guest, seed_group, 'Νίκος (+1)', seed_users[3]);

  for match_index in 1..3 loop
    seed_match_id := ('40000000-0000-0000-0000-' || lpad(match_index::text, 12, '0'))::uuid;
    kickoff := now() - (28 - match_index * 7) * interval '1 day';
    insert into public.matches(id, group_id, format, players_per_team, venue, starts_at, rsvp_lock_at, expected_cost, status)
      values (seed_match_id, seed_group, '5x5', 5, 'Γήπεδο της γειτονιάς', kickoff, kickoff - interval '2 hours', 60, 'locked');
    select jsonb_agg((case when match_index = 2 and member.ordinal = 10
      then jsonb_build_object('guest_id', seed_guest) else jsonb_build_object('user_id', member.user_id) end)
      || jsonb_build_object('team', case when member.ordinal <= 5 then 'A' else 'B' end) order by member.ordinal)
      into roster from unnest(seed_users[1:10]) with ordinality member(user_id, ordinal);
    scorers := case when match_index = 2 then null else jsonb_build_array(
      jsonb_build_object('user_id', seed_users[2], 'team', 'A', 'minute', 12),
      jsonb_build_object('user_id', seed_users[3], 'team', 'A', 'minute', 28),
      jsonb_build_object('user_id', seed_users[6], 'team', 'B', 'minute', 35),
      jsonb_build_object('user_id', seed_users[7], 'team', 'B', 'minute', 52)) end;
    perform public.finish_match(seed_match_id, roster,
      case when match_index = 2 then 'B'::public.match_winner end,
      case when match_index = 1 then 3 when match_index = 3 then 2 end,
      case when match_index <> 2 then 2 end, scorers,
      case match_index when 1 then 60 when 2 then 62 else 70 end, seed_users[1]);

    for voter in select eligible.voter_id from public.mvp_eligible_voters eligible where eligible.match_id = seed_match_id order by eligible.voter_id loop
      perform set_config('request.jwt.claims', jsonb_build_object('sub', voter.voter_id, 'role', 'authenticated')::text, true);
      select participant.id into candidate from public.match_participants participant
        where participant.match_id = seed_match_id and participant.user_id = case when voter.voter_id = seed_users[2] then seed_users[1] else seed_users[2] end;
      perform public.cast_mvp_vote(seed_match_id, candidate);
    end loop;
    perform set_config('request.jwt.claims', jsonb_build_object('sub', seed_users[1], 'role', 'authenticated')::text, true);
    for payment_id in select payment.id from public.payments payment where payment.match_id = seed_match_id
      and payment.debtor_user_id = any(seed_users[2:4]) loop
      perform public.mark_payment_paid(payment_id, true);
    end loop;
    update public.matches set finished_at = kickoff + interval '90 minutes',
      mvp_voting_closes_at = kickoff + interval '25 hours 30 minutes', mvp_closed_at = kickoff + interval '2 hours'
      where id = seed_match_id;
    update public.mvp_votes ballot set created_at = kickoff + interval '2 hours' where ballot.match_id = seed_match_id;
    update public.mvp_results result set created_at = kickoff + interval '2 hours' where result.match_id = seed_match_id;
    update public.payments payment set created_at = kickoff + interval '90 minutes',
      paid_at = case when paid then kickoff + interval '3 hours' end where payment.match_id = seed_match_id;
  end loop;
  update private.notification_outbox set delivered_at = now() where recipient_user_id = any(seed_users);
end;
$$;

commit;