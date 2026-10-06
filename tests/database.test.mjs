import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';
import { randomBytes } from 'node:crypto';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';
import { PGlite } from '@electric-sql/pglite';

const root = fileURLToPath(new URL('../', import.meta.url));
const native = process.env.SENTRA_TEST_ENGINE === 'native';
let server;
let admin;
let portable;
let directory;
let connection;
const diagnostics = [];

before(async () => {
  if (!native) {
    portable = new PGlite();
    admin = {
      query: async (sql, parameters) => parameters
        ? portable.query(sql, parameters)
        : (await portable.exec(sql)).at(-1),
      end: () => portable.close(),
    };
  } else {
  const reservation = createServer();
  await new Promise((resolve, reject) => {
    reservation.once('error', reject);
    reservation.listen(0, '127.0.0.1', resolve);
  });
  const port = reservation.address().port;
  await new Promise((resolve) => reservation.close(resolve));
  directory = await mkdtemp(join(tmpdir(), 'sentra-db-'));
  connection = {
    host: '127.0.0.1', port, user: 'postgres',
    password: randomBytes(24).toString('hex'), database: 'postgres',
    connectionTimeoutMillis: 10_000,
  };
  server = new EmbeddedPostgres({
    databaseDir: join(directory, 'data'), port,
    user: connection.user, password: connection.password, persistent: false,
    initdbFlags: ['--encoding=UTF8', '--locale=C'],
    postgresFlags: ['-c', 'listen_addresses=127.0.0.1', '-c', 'wal_level=logical'],
    onLog: (message) => diagnostics.push(String(message)),
    onError: (message) => diagnostics.push(String(message)),
  });
    await server.initialise();
    await server.start();
    admin = new pg.Client(connection);
    await admin.connect();
  }
  try {
    await admin.query(await readFile(join(root, 'tests/bootstrap.sql'), 'utf8'));
    const migrations = (await readdir(join(root, 'supabase/migrations')))
      .filter((name) => name.endsWith('.sql')).sort();
    for (const migration of migrations) {
      try {
        await admin.query(await readFile(join(root, 'supabase/migrations', migration), 'utf8'));
      } catch (error) {
        throw new Error(`Migration ${migration}: ${error.message}`, { cause: error });
      }
    }
  } catch (error) {
    console.error(diagnostics.slice(-12).join('\n'));
    throw error;
  }
});

after(async () => {
  await admin?.end();
  if (server) await server.stop();
  if (directory) await rm(directory, { recursive: true, force: true });
});

test('schema has configurable formats and default-deny tables', async () => {
  const formats = await admin.query('select code, players_per_team from public.match_formats order by players_per_team');
  assert.deepEqual(formats.rows.map((row) => row.players_per_team), [5, 7, 8, 11]);
  const unprotected = await admin.query(`
    select relname from pg_class
    where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity
  `);
  assert.deepEqual(unprotected.rows, []);
});

const users = Array.from({ length: 16 }, (_, index) => `10000000-0000-0000-0000-${String(index + 1).padStart(12, '0')}`);
let groupId;
let invitationCode;

async function asUser(userId, operation, role = 'authenticated', client = admin) {
  await client.query('begin');
  try {
    await client.query(`set local role ${role}`);
    await client.query("select set_config('request.jwt.claims', $1, true)", [JSON.stringify({ sub: userId, role })]);
    const result = await operation(client);
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  }
}

async function rpc(userId, sql, parameters) {
  return asUser(userId, (client) => client.query(sql, parameters));
}

async function newMatch(format = '5x5', owner = users[0], group = groupId) {
  const result = await rpc(owner,
    "select public.create_match($1, now() + interval '3 days', 'Test pitch', $2) as id", [group, format]);
  return result.rows[0].id;
}

async function respond(userId, matchId, status, guestId = null) {
  return rpc(userId, 'select * from public.respond_to_match($1, $2, $3)', [matchId, status, guestId]);
}

test('profiles bootstrap, invites create membership, outsiders cannot read or administer', async () => {
  for (const userId of users) await admin.query('insert into auth.users(id) values ($1)', [userId]);
  groupId = (await rpc(users[0], "select public.create_group('Sentra tests') as id")).rows[0].id;
  invitationCode = (await rpc(users[0], 'select code from public.create_invite($1)', [groupId])).rows[0].code;
  for (const userId of users.slice(1, 14)) await rpc(userId, 'select public.accept_invite($1)', [invitationCode]);
  assert.equal((await rpc(users[14], 'select * from public.groups')).rows.length, 0);
  assert.equal((await rpc(users[14], 'select * from public.profiles')).rows.length, 1);
  await assert.rejects(rpc(users[1], "update public.group_members set role = 'admin' where user_id = $1", [users[1]]), { code: '42501' });
  await assert.rejects(newMatch('5x5', users[1]), { code: '42501' });
  await assert.rejects(asUser(null, (client) => client.query('select * from public.groups'), 'anon'), { code: '42501' });
});

test('capacity and FIFO promotion include guests, preserve history and queue order', async () => {
  const matchId = await newMatch();
  for (const userId of users.slice(0, 10)) assert.equal((await respond(userId, matchId, 'yes')).rows[0].status, 'yes');
  assert.equal((await respond(users[10], matchId, 'yes')).rows[0].status, 'waitlist');
  const guestId = (await rpc(users[2], "select id from public.add_guest($1, 'Guest one')", [groupId])).rows[0].id;
  assert.equal((await respond(users[2], matchId, 'yes', guestId)).rows[0].status, 'waitlist');
  await assert.rejects(respond(users[1], matchId, 'no', guestId), { code: '42501' });
  await respond(users[0], matchId, 'no');
  assert.equal((await admin.query('select status from public.rsvps where match_id = $1 and user_id = $2', [matchId, users[10]])).rows[0].status, 'yes');
  await respond(users[1], matchId, 'maybe');
  assert.equal((await admin.query('select status from public.rsvps where guest_id = $1', [guestId])).rows[0].status, 'yes');
  assert.equal(Number((await admin.query('select yes_count from public.match_rsvp_counts where match_id = $1', [matchId])).rows[0].yes_count), 10);
  assert.equal((await admin.query("select count(*)::int as count from public.rsvp_history where match_id = $1 and old_status = 'waitlist' and new_status = 'yes'", [matchId])).rows[0].count, 2);
  assert.equal((await admin.query("select count(*)::int as count from private.notification_outbox where payload->>'match_id' = $1", [matchId])).rows[0].count, 2);
  await assert.rejects(rpc(users[0], 'delete from public.rsvps where match_id = $1', [matchId]), { code: '42501' });
});

test('RSVP cutoff is enforced before cron runs and rejects direct client writes', async () => {
  const matchId = await newMatch('7x7');
  assert.equal((await admin.query('select capacity from public.matches where id = $1', [matchId])).rows[0].capacity, 14);
  await admin.query("update public.matches set rsvp_lock_at = now() - interval '1 second' where id = $1", [matchId]);
  await assert.rejects(respond(users[1], matchId, 'yes'), /RSVP_LOCKED/);
  await assert.rejects(rpc(users[1], "insert into public.rsvps(match_id, group_id, user_id, status) values ($1,$2,$3,'yes')", [matchId, groupId, users[1]]), { code: '42501' });
});

async function completedMatch({ roster, winner = null, scoreA = null, scoreB = null, goals = null, cost = null } = {}) {
  const matchId = await newMatch();
  const played = roster ?? users.slice(0, 4).map((userId, index) => ({ user_id: userId, team: index % 2 === 0 ? 'A' : 'B' }));
  await admin.query("update public.matches set starts_at = now() - interval '2 hours', rsvp_lock_at = now() - interval '4 hours' where id = $1", [matchId]);
  await rpc(users[0], 'select public.finish_match($1,$2,$3,$4,$5,$6,$7)',
    [matchId, JSON.stringify(played), winner, scoreA, scoreB, goals === null ? null : JSON.stringify(goals), cost]);
  return matchId;
}

test('finish derives winners, allows no result, freezes actual roster and is idempotent', async () => {
  const matchId = await completedMatch({ winner: 'B', scoreA: 3, scoreB: 1 });
  assert.equal((await admin.query('select winner from public.matches where id = $1', [matchId])).rows[0].winner, 'A');
  await rpc(users[0], 'select public.finish_match($1, $2)', [matchId, '[]']);
  assert.equal((await admin.query('select count(*)::int as count from public.match_participants where match_id = $1', [matchId])).rows[0].count, 4);
  await rpc(users[0], 'select public.record_match_result($1, null, 2, 2)', [matchId]);
  assert.equal((await admin.query('select winner from public.matches where id = $1', [matchId])).rows[0].winner, 'draw');
  await assert.rejects(admin.query('delete from public.match_participants where match_id = $1', [matchId]), /PLAYED_ROSTER_FROZEN/);
  const noResultId = await completedMatch();
  const noResult = (await admin.query('select winner, cost_split_enabled, mvp_voting_closes_at, mvp_closed_at from public.matches where id = $1', [noResultId])).rows[0];
  assert.equal(noResult.winner, null);
  assert.equal(noResult.cost_split_enabled, false);
  assert.ok(noResult.mvp_voting_closes_at);
  assert.equal(noResult.mvp_closed_at, null);
  assert.equal((await admin.query('select count(*)::int as count from public.payments where match_id = $1', [noResultId])).rows[0].count, 0);
  await assert.rejects(rpc(users[1], 'select public.record_match_result($1, $2)', [matchId, 'A']), { code: '42501' });
});

test('cost split aggregates guests, rounds to EUR 0.50, balances and protects settled payments', async () => {
  const guestId = (await rpc(users[1], "select id from public.add_guest($1, 'Cost guest')", [groupId])).rows[0].id;
  const matchId = await completedMatch({ roster: [{ user_id: users[0] }, { user_id: users[1] }, { guest_id: guestId }], cost: 20 });
  let match = (await admin.query('select share_amount, rounding_remainder from public.matches where id = $1', [matchId])).rows[0];
  assert.equal(Number(match.share_amount), 6.5);
  assert.equal(Number(match.rounding_remainder), 0.5);
  let debt = (await rpc(users[1], 'select * from public.payments where match_id = $1', [matchId])).rows;
  assert.equal(debt.length, 1);
  assert.equal(Number(debt[0].amount), 13);
  assert.deepEqual(debt[0].includes_guest_ids, [guestId]);
  await assert.rejects(rpc(users[1], 'select public.mark_payment_paid($1, true)', [debt[0].id]), { code: '42501' });
  await rpc(users[0], 'select public.set_cost_split($1, true, 20.50)', [matchId]);
  match = (await admin.query('select share_amount, rounding_remainder from public.matches where id = $1', [matchId])).rows[0];
  assert.equal(Number(match.share_amount), 7);
  assert.equal(Number(match.rounding_remainder), -0.5);
  debt = (await rpc(users[1], 'select * from public.payments where match_id = $1', [matchId])).rows;
  await rpc(users[0], 'select public.mark_payment_paid($1, true)', [debt[0].id]);
  await assert.rejects(rpc(users[0], 'select public.set_cost_split($1, true, 30)', [matchId]), /UNMARK_SETTLED_PAYMENTS/);
  await rpc(users[0], 'select public.compute_cost_split($1)', [matchId]);
  assert.equal((await admin.query('select paid from public.payments where id = $1', [debt[0].id])).rows[0].paid, true);
  await rpc(users[0], 'select public.mark_payment_paid($1, false)', [debt[0].id]);
  await rpc(users[0], 'select public.set_cost_split($1, false)', [matchId]);
  assert.equal((await admin.query('select count(*)::int as count from public.payments where match_id = $1', [matchId])).rows[0].count, 0);
  await rpc(users[0], 'select public.set_cost_split($1, true, 20)', [matchId]);
  await assert.rejects(admin.query('update public.payments set amount = amount + 1 where match_id = $1', [matchId]), /COST_SPLIT_NOT_BALANCED/);
});

test('MVP ballots are private, one per played user, non-self, and shared ties close early', async () => {
  const guestId = (await rpc(users[1], "select id from public.add_guest($1, 'MVP guest')", [groupId])).rows[0].id;
  const matchId = await completedMatch({ roster: [{ user_id: users[0] }, { user_id: users[1] }, { guest_id: guestId }] });
  const participants = (await admin.query('select * from public.match_participants where match_id = $1', [matchId])).rows;
  const owner = participants.find((participant) => participant.user_id === users[0]);
  const guest = participants.find((participant) => participant.guest_id === guestId);
  await assert.rejects(rpc(users[0], 'select public.cast_mvp_vote($1,$2)', [matchId, owner.id]), /MVP_SELF_VOTE_FORBIDDEN/);
  await assert.rejects(rpc(users[3], 'select public.cast_mvp_vote($1,$2)', [matchId, guest.id]), /PLAYED_VOTER_REQUIRED/);
  await rpc(users[0], 'select public.cast_mvp_vote($1,$2)', [matchId, guest.id]);
  await assert.rejects(rpc(users[0], 'select public.cast_mvp_vote($1,$2)', [matchId, guest.id]), { code: '23505' });
  await assert.rejects(rpc(users[0], 'select * from public.mvp_votes where match_id = $1', [matchId]), { code: '42501' });
  assert.equal((await rpc(users[1], 'select * from public.mvp_results where match_id = $1', [matchId])).rows.length, 0);
  assert.equal((await rpc(users[0], 'select public.close_mvp_voting($1) as closed', [matchId])).rows[0].closed, false);
  await rpc(users[1], 'select public.cast_mvp_vote($1,$2)', [matchId, owner.id]);
  const winners = (await rpc(users[1], 'select * from public.mvp_results where match_id = $1', [matchId])).rows;
  assert.equal(winners.length, 2);
  assert.ok(winners.every((winner) => winner.votes === 1));
  assert.equal((await rpc(users[0], 'select public.close_mvp_voting($1) as closed', [matchId])).rows[0].closed, false);
  await assert.rejects(rpc(users[0], 'select * from public.mvp_votes where match_id = $1', [matchId]), { code: '42501' });
});

test('MVP deadline rejects late votes without cron and empty ballots produce no winners', async () => {
  const matchId = await completedMatch();
  await admin.query("update public.matches set mvp_voting_closes_at = now() - interval '1 second' where id = $1", [matchId]);
  const candidate = (await admin.query('select id from public.match_participants where match_id = $1 and user_id = $2', [matchId, users[1]])).rows[0].id;
  await assert.rejects(rpc(users[0], 'select public.cast_mvp_vote($1,$2)', [matchId, candidate]), /MVP_VOTING_CLOSED/);
  assert.equal((await rpc(users[0], 'select public.close_mvp_voting($1) as closed', [matchId])).rows[0].closed, true);
  assert.equal((await admin.query('select count(*)::int as count from public.mvp_results where match_id = $1', [matchId])).rows[0].count, 0);
});

test('goals require same-match scorers and cannot exceed the entered score', async () => {
  const matchId = await completedMatch({ scoreA: 1, scoreB: 0, goals: [{ user_id: users[0], team: 'A', minute: 10 }] });
  assert.equal((await admin.query('select count(*)::int as count from public.goals where match_id = $1', [matchId])).rows[0].count, 1);
  await assert.rejects(rpc(users[0], 'select public.record_match_result($1, null, 1, 0, $2)', [matchId,
    JSON.stringify([{ user_id: users[0], team: 'A' }, { user_id: users[0], team: 'A' }])]), /GOALS_EXCEED_SCORE/);
  assert.equal((await admin.query('select count(*)::int as count from public.goals where match_id = $1', [matchId])).rows[0].count, 1);
});

let statsGroup;
test('statistics exclude unknown results; consecutive appearances and shared MVPs award badges once', async () => {
  statsGroup = (await rpc(users[12], "select public.create_group('Badge tests', '7x7') as id")).rows[0].id;
  const code = (await rpc(users[12], 'select code from public.create_invite($1)', [statsGroup])).rows[0].code;
  await rpc(users[13], 'select public.accept_invite($1)', [code]);
  for (let matchIndex = 0; matchIndex < 10; matchIndex++) {
    const matchId = await newMatch('7x7', users[12], statsGroup);
    await admin.query("update public.matches set starts_at = now() - ($2 * interval '1 day'), rsvp_lock_at = now() - ($2 * interval '1 day') - interval '2 hours' where id = $1", [matchId, 12 - matchIndex]);
    await rpc(users[12], 'select public.finish_match($1,$2,$3)', [matchId,
      JSON.stringify([{ user_id: users[12], team: 'A' }, { user_id: users[13], team: 'B' }]), matchIndex === 0 ? null : 'A']);
    if (matchIndex < 5) {
      const participants = (await admin.query('select id, user_id from public.match_participants where match_id = $1', [matchId])).rows;
      await rpc(users[12], 'select public.cast_mvp_vote($1,$2)', [matchId, participants.find((player) => player.user_id === users[13]).id]);
      await rpc(users[13], 'select public.cast_mvp_vote($1,$2)', [matchId, participants.find((player) => player.user_id === users[12]).id]);
    }
  }
  const stats = (await rpc(users[12], 'select * from public.get_my_stats() where group_id = $1', [statsGroup])).rows[0];
  assert.equal(Number(stats.appearances), 10);
  assert.equal(Number(stats.wins), 9);
  assert.equal(Number(stats.win_pct), 100);
  assert.equal(Number(stats.current_streak), 10);
  assert.equal(Number(stats.mvp_count), 5);
  const badges = (await rpc(users[12], 'select badge_code from public.player_badges where user_id = $1 and group_id = $2 order by badge_code', [users[12], statsGroup])).rows;
  assert.deepEqual(badges.map((badge) => badge.badge_code), ['attendance_streak', 'mvp_5']);
  assert.equal((await rpc(users[12], 'select public.evaluate_badges() as count')).rows[0].count, 0);
  await assert.rejects(rpc(users[13], 'select public.evaluate_badges($1)', [users[12]]), { code: '42501' });
  assert.equal((await rpc(users[14], 'select * from public.player_stats_view where group_id = $1', [statsGroup])).rows.length, 0);
});

test('Ghost counts distinct late-cancelled matches in the configurable recent window', async () => {
  for (let matchIndex = 0; matchIndex < 3; matchIndex++) {
    const matchId = await newMatch('5x5', users[12], statsGroup);
    await admin.query("update public.matches set starts_at = now() + interval '10 hours', rsvp_lock_at = now() + interval '8 hours' where id = $1", [matchId]);
    for (let changeIndex = 0; changeIndex < 3; changeIndex++) {
      await respond(users[13], matchId, 'yes');
      await respond(users[13], matchId, 'no');
    }
    await admin.query("update public.matches set starts_at = now() - interval '1 hour', rsvp_lock_at = now() - interval '3 hours' where id = $1", [matchId]);
    await rpc(users[13], 'select public.evaluate_badges()');
    const awards = (await admin.query("select count(*)::int as count from public.player_badges where user_id = $1 and group_id = $2 and badge_code = 'ghost'", [users[13], statsGroup])).rows[0].count;
    assert.equal(awards, matchIndex === 2 ? 1 : 0);
  }
  assert.equal((await rpc(users[13], 'select count(*)::int as count from public.late_cancellations_view where user_id = $1 and group_id = $2', [users[13], statsGroup])).rows[0].count, 3);
  await assert.rejects(admin.query("update public.badge_definitions set rule_params = '{\"metric\":\"late_cancellations\",\"threshold\":3,\"scopes\":[\"group\"]}' where code = 'ghost'"), /INVALID_LATE_CANCELLATION_RULE/);
});

async function service(sql, parameters) {
  return asUser(null, (client) => client.query(sql, parameters), 'service_role');
}

test('recurrence respects timezone, skips, stopping and occurrence idempotency', async () => {
  const weekday = (await admin.query("select extract(dow from (now() at time zone 'Europe/Athens')::date + 2)::smallint as weekday")).rows[0].weekday;
  const seriesId = (await rpc(users[0], "select public.create_match_series($1,$2,'21:00','Weekly pitch','8x8') as id", [groupId, weekday])).rows[0].id;
  await service('select public.create_recurring_matches()');
  assert.equal((await service('select public.create_recurring_matches() as count')).rows[0].count, 0);
  const occurrence = (await admin.query("select id, capacity, occurrence_date::text as occurrence_date from public.matches where series_id = $1", [seriesId])).rows;
  assert.equal(occurrence.length, 1);
  assert.equal(occurrence[0].capacity, 16);
  await rpc(users[0], 'select public.skip_series_occurrence($1,$2)', [seriesId, occurrence[0].occurrence_date]);
  await service('select public.create_recurring_matches()');
  assert.equal((await admin.query('select status from public.matches where id = $1', [occurrence[0].id])).rows[0].status, 'cancelled');
  await rpc(users[0], 'select public.set_series_active($1, false)', [seriesId]);
  await assert.rejects(rpc(users[1], 'select public.set_series_active($1, true)', [seriesId]), { code: '42501' });
  await assert.rejects(rpc(users[0], "select public.create_match_series($1,$2,'21:00','Pitch',p_timezone => 'not/a/timezone')", [groupId, weekday]), /INVALID_SERIES_TIMEZONE/);
  const dst = (await admin.query("select extract(hour from ('2027-03-28 03:30'::timestamp at time zone 'Europe/Athens') at time zone 'UTC')::int as spring, extract(hour from ('2026-10-25 03:30'::timestamp at time zone 'Europe/Athens') at time zone 'UTC')::int as autumn")).rows[0];
  assert.equal(dst.spring, 1);
  assert.equal(dst.autumn, 1);
});

test('24-hour reminders target only maybe or unanswered members and deduplicate', async () => {
  const matchId = await newMatch();
  await admin.query("update public.matches set starts_at = now() + interval '23 hours', rsvp_lock_at = now() + interval '21 hours' where id = $1", [matchId]);
  await respond(users[0], matchId, 'yes');
  await respond(users[1], matchId, 'no');
  await respond(users[2], matchId, 'maybe');
  await admin.query('select private.queue_rsvp_reminders()');
  await admin.query('select private.queue_rsvp_reminders()');
  const recipients = (await admin.query("select recipient_user_id from private.notification_outbox where kind = 'rsvp_reminder' and payload->>'match_id' = $1", [matchId])).rows.map((row) => row.recipient_user_id);
  assert.equal(recipients.length, 12);
  assert.ok(recipients.includes(users[2]) && recipients.includes(users[3]));
  assert.ok(!recipients.includes(users[0]) && !recipients.includes(users[1]));
});

test('web responses require service role and valid group-scoped invites, share capacity and retry identity', async () => {
  const matchId = await newMatch();
  for (const userId of users.slice(0, 10)) await respond(userId, matchId, 'yes');
  const tokenHash = 'a'.repeat(64);
  await assert.rejects(asUser(null, (client) => client.query('select public.get_invite_preview($1)', [invitationCode]), 'anon'), { code: '42501' });
  await assert.rejects(rpc(users[0], 'select public.get_invite_preview($1)', [invitationCode]), { code: '42501' });
  const response = (await service("select public.submit_web_rsvp($1,$2,'Android friend','yes',$3) as response", [invitationCode, matchId, tokenHash])).rows[0].response;
  assert.equal(response.status, 'waitlist');
  const retried = (await service("select public.submit_web_rsvp($1,$2,'Android friend','yes',$3) as response", [invitationCode, matchId, tokenHash])).rows[0].response;
  assert.equal(retried.response_id, response.response_id);
  await respond(users[0], matchId, 'no');
  assert.equal((await admin.query('select status from public.web_responders where match_id = $1 and token_hash = $2', [matchId, tokenHash])).rows[0].status, 'yes');
  assert.equal((await admin.query('select count(*)::int as count from public.web_responders where match_id = $1', [matchId])).rows[0].count, 1);
  await assert.rejects(rpc(users[0], 'select * from public.web_responders'), { code: '42501' });
  const otherMatch = await newMatch('5x5', users[12], statsGroup);
  await assert.rejects(service("select public.submit_web_rsvp($1,$2,'Friend','yes',$3)", [invitationCode, otherMatch, tokenHash]), /INVITE_MATCH_MISMATCH/);
});

test('notification leases are private, nonoverlapping and reject stale acknowledgements', async () => {
  await assert.rejects(rpc(users[0], 'select * from private.notification_outbox'), { code: '42501' });
  await assert.rejects(rpc(users[0], 'select * from public.claim_notifications()'), { code: '42501' });
  const first = (await service('select * from public.claim_notifications(2, 120)')).rows;
  const second = (await service('select * from public.claim_notifications(2, 120)')).rows;
  assert.equal(first.length, 2);
  assert.equal(second.length, 2);
  assert.ok(second.every((entry) => !first.some((other) => other.id === entry.id)));
  assert.equal((await service('select public.complete_notification($1,$2) as completed', [first[0].id, first[1].lease_token])).rows[0].completed, false);
  assert.equal((await service('select public.complete_notification($1,$2) as completed', [first[0].id, first[0].lease_token])).rows[0].completed, true);
  assert.equal((await service('select public.complete_notification($1,$2) as completed', [first[0].id, first[0].lease_token])).rows[0].completed, false);
  await service("select public.complete_notification($1,$2,'Temporary delivery error')", [first[1].id, first[1].lease_token]);
  const retry = (await admin.query('select attempts, available_at > now() as delayed, lease_token from private.notification_outbox where id = $1', [first[1].id])).rows[0];
  assert.equal(retry.attempts, 1);
  assert.equal(retry.delayed, true);
  assert.equal(retry.lease_token, null);
});

test('maintenance locks overdue matches and closes voting idempotently', async () => {
  const matchId = await newMatch();
  await admin.query("update public.matches set rsvp_lock_at = now() - interval '1 second' where id = $1", [matchId]);
  await service('select public.run_maintenance()');
  await service('select public.run_maintenance()');
  assert.equal((await admin.query('select status from public.matches where id = $1', [matchId])).rows[0].status, 'locked');
});

test('cross-group identities, ambiguous persons, invalid money and capacity reductions are rejected', async () => {
  const guestId = (await rpc(users[12], "select id from public.add_guest($1, 'Other group guest')", [statsGroup])).rows[0].id;
  const matchId = await newMatch('7x7');
  await assert.rejects(admin.query("insert into public.rsvps(match_id,group_id,guest_id,status) values ($1,$2,$3,'yes')", [matchId, groupId, guestId]), { code: '23503' });
  const ownGuest = (await rpc(users[1], "select id from public.add_guest($1, 'Identity guest')", [groupId])).rows[0].id;
  await assert.rejects(admin.query("insert into public.rsvps(match_id,group_id,user_id,guest_id,status) values ($1,$2,$3,$4,'yes')", [matchId, groupId, users[1], ownGuest]), { code: '23514' });
  await assert.rejects(rpc(users[1], 'update public.guests set claimed_by_user_id = $1 where id = $2', [users[1], ownGuest]), { code: '42501' });
  await assert.rejects(admin.query("update public.matches set expected_cost = 'NaN'::numeric where id = $1", [matchId]), { code: '23514' });
  for (const userId of users.slice(0, 14)) await respond(userId, matchId, 'yes');
  await assert.rejects(rpc(users[0], "select public.update_match($1, now() + interval '3 days', 'Pitch', '5x5', now() + interval '2 days')", [matchId]), /CAPACITY_BELOW_CONFIRMED_PLAYERS/);
  assert.equal((await admin.query('select capacity from public.matches where id = $1', [matchId])).rows[0].capacity, 14);
});

test('failed completion rolls back roster, results, payments and voting', async () => {
  const matchId = await newMatch();
  await admin.query("update public.matches set starts_at = now() - interval '2 hours', rsvp_lock_at = now() - interval '4 hours' where id = $1", [matchId]);
  await assert.rejects(rpc(users[0], 'select public.finish_match($1,$2,null,1,null)', [matchId, JSON.stringify([{ user_id: users[0] }])]), /BOTH_SCORES_REQUIRED/);
  assert.equal((await admin.query('select status from public.matches where id = $1', [matchId])).rows[0].status, 'scheduled');
  for (const table of ['match_participants', 'goals', 'payments', 'mvp_eligible_voters', 'mvp_results']) {
    assert.equal((await admin.query(`select count(*)::int as count from public.${table} where match_id = $1`, [matchId])).rows[0].count, 0);
  }
});

test('avatar policies restrict writes to owner paths and reads to shared groups', async () => {
  const path = `${users[0]}/avatar.jpg`;
  await rpc(users[0], "insert into storage.objects(bucket_id,name) values ('avatars',$1)", [path]);
  assert.equal((await rpc(users[1], 'select * from storage.objects where name = $1', [path])).rows.length, 1);
  assert.equal((await rpc(users[14], 'select * from storage.objects where name = $1', [path])).rows.length, 0);
  await assert.rejects(rpc(users[1], "insert into storage.objects(bucket_id,name) values ('avatars',$1)", [`${users[0]}/forged.jpg`]), { code: '42501' });
  await rpc(users[1], 'delete from storage.objects where name = $1', [path]);
  assert.equal((await admin.query('select count(*)::int as count from storage.objects where name = $1', [path])).rows[0].count, 1);
});

test('anonymous RPCs, raw ballots and tokens are closed; Realtime publishes only the allowlist', async () => {
  const anonymousFunctions = await admin.query(`select procedure.proname from pg_proc procedure
    where procedure.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
      and has_function_privilege('anon', procedure.oid, 'execute')`);
  assert.deepEqual(anonymousFunctions.rows, []);
  const unsafeFunctions = await admin.query(`select proname from pg_proc where prosecdef
    and pronamespace in ('public'::regnamespace, 'private'::regnamespace)
    and not coalesce(proconfig @> array['search_path=""'], false)`);
  assert.deepEqual(unsafeFunctions.rows, []);
  const published = (await admin.query("select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by tablename")).rows.map((row) => row.tablename);
  assert.deepEqual(published, ['matches', 'mvp_results', 'payments', 'player_badges', 'rsvps']);
  for (const table of ['mvp_votes', 'mvp_eligible_voters', 'web_responders']) {
    await assert.rejects(rpc(users[0], `select * from public.${table}`), { code: '42501' });
  }
  await assert.rejects(rpc(users[0], 'select * from public.get_push_targets($1)', [users[1]]), { code: '42501' });
});

test('concurrent RSVP sessions never oversubscribe and cancellations preserve FIFO', { skip: !native }, async () => {
  const matchId = await newMatch();
  const clients = users.slice(0, 14).map(() => new pg.Client(connection));
  try {
    await Promise.all(clients.map((client) => client.connect()));
    await Promise.all(clients.map((client, index) => asUser(users[index],
      (session) => session.query("select * from public.respond_to_match($1,'yes')", [matchId]), 'authenticated', client)));
    const responses = (await admin.query('select * from public.rsvps where match_id = $1 order by waitlist_order nulls first', [matchId])).rows;
    assert.equal(responses.filter((row) => row.status === 'yes').length, 10);
    const waiters = responses.filter((row) => row.status === 'waitlist');
    assert.equal(waiters.length, 4);
    const withdrawals = responses.filter((row) => row.status === 'yes').slice(0, 2);
    await Promise.all(withdrawals.map((row, index) => asUser(row.user_id,
      (session) => session.query("select * from public.respond_to_match($1,'no')", [matchId]), 'authenticated', clients[index])));
    const promoted = (await admin.query("select user_id from public.rsvps where match_id = $1 and status = 'yes'", [matchId])).rows.map((row) => row.user_id);
    assert.equal(promoted.length, 10);
    assert.ok(waiters.slice(0, 2).every((row) => promoted.includes(row.user_id)));
    assert.ok(waiters.slice(2).every((row) => !promoted.includes(row.user_id)));
  } finally {
    await Promise.all(clients.map((client) => client.end()));
  }
});

test('concurrent final MVP ballots close exactly once', { skip: !native }, async () => {
  const matchId = await completedMatch({ roster: [{ user_id: users[0] }, { user_id: users[1] }] });
  const participants = (await admin.query('select id, user_id from public.match_participants where match_id = $1', [matchId])).rows;
  const clients = [new pg.Client(connection), new pg.Client(connection)];
  try {
    await Promise.all(clients.map((client) => client.connect()));
    await Promise.all(clients.map((client, index) => asUser(users[index],
      (session) => session.query('select public.cast_mvp_vote($1,$2)',
        [matchId, participants.find((row) => row.user_id === users[1 - index]).id]), 'authenticated', client)));
    assert.equal((await admin.query('select count(*)::int as count from public.mvp_results where match_id = $1', [matchId])).rows[0].count, 2);
    assert.equal((await admin.query("select count(*)::int as count from private.notification_outbox where kind = 'mvp_closed' and payload->>'match_id' = $1", [matchId])).rows[0].count, 14);
  } finally {
    await Promise.all(clients.map((client) => client.end()));
  }
});

test('local seed is repeatable: one group, 12 players, three finished matches with results, votes and payments', async () => {
  const seed = await readFile(join(root, 'supabase/seed.sql'), 'utf8');
  await admin.query(seed);
  await admin.query(seed);
  const seedGroup = '30000000-0000-0000-0000-000000000001';
  assert.equal((await admin.query('select count(*)::int as count from public.group_members where group_id = $1', [seedGroup])).rows[0].count, 12);
  assert.equal((await admin.query('select count(*)::int as count from public.matches where group_id = $1 and status = $2 and winner is not null and mvp_closed_at is not null', [seedGroup, 'finished'])).rows[0].count, 3);
  assert.equal((await admin.query('select count(*)::int as count from public.payments where group_id = $1', [seedGroup])).rows[0].count, 29);
  assert.equal((await admin.query('select count(*)::int as count from public.mvp_votes vote join public.matches match_row on match_row.id = vote.match_id where match_row.group_id = $1', [seedGroup])).rows[0].count, 29);
  assert.equal((await admin.query('select count(*)::int as count from public.mvp_results result join public.matches match_row on match_row.id = result.match_id where match_row.group_id = $1', [seedGroup])).rows[0].count, 3);
  assert.equal((await admin.query("select count(*)::int as count from private.notification_outbox where recipient_user_id::text like '20000000-%' and delivered_at is null")).rows[0].count, 0);
});