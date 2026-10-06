# Database Contract

## Identity and Access

All game mutations go through authorized functions, not client table writes.
Public tables have RLS enabled, but read policies never imply write permission.
Clients may update only their own profile's display name, position, avatar field
and onboarding flag, and delete their own device-token registrations.

Every public mutation checks the caller with `auth.uid()` or requires service
role. Every security-definer function has a fixed empty search path and qualified
table references. Private helpers are not in the exposed PostgREST schemas.
Only the specific authorization helpers used by policies are executable by users.

| Surface | Authenticated visibility |
| --- | --- |
| Profiles | Self and people in shared groups, including retained historical members |
| Groups, members, invites, matches, RSVPs, guests, played rosters, goals | Active group members |
| Payments | Group organizers/admins, or the debtor while still a member |
| RSVP audit history | Group members; no client mutation or deletion |
| Individual MVP ballots and voter snapshot | Never readable, even after closure |
| MVP results | Group members, only after closure |
| Personal overall badges | The awarded user only |
| Group badges | Group members |
| Device tokens | Their owner only |
| Web responder records and notification outbox | No client access |

Votes are anonymous to app users, not to the database operator. An organizer
cannot use an application RPC to inspect ballots. No raw-ballot Realtime stream
exists. Overall statistics for peers are limited to shared, visible groups;
`get_my_stats()` returns the caller's own complete historical aggregate, including
their former groups, without revealing another user's private group activity.

The `groups.owner_id` and owner-role membership must agree at commit. There can
be only one owner. Membership rows are retained with `left_at` to preserve past
foreign keys. Old invite codes cannot silently reinstate a removed member.
Role changes and ownership transfers have dedicated owner-only operations.
Account erasure requires a later anonymization workflow; financial and match
history must not be deleted by an unchecked cascading client request.

## RPCs for the Swift Services

All names below are in `public`. PostgreSQL/PostgREST named parameters begin
with `p_`. UUIDs are strings, timestamps are ISO 8601 with offsets, times are local
`HH:mm:ss`, enum values are the exact English codes in the schema, and monetary
arguments must be represented as decimal values, not computed with binary floats.

| RPC | Inputs / behavior |
| --- | --- |
| `create_group` | `p_name`, optional `p_default_format = '5x5'`; returns group UUID |
| `update_group` | `p_group_id`, `p_name`, `p_default_format`; admin/owner |
| `create_invite` | `p_group_id`, optional `p_expires_at`; returns invite row |
| `revoke_invite` | `p_invite_id`; creator or admin/owner |
| `accept_invite` | `p_code`; joins caller as member, never admin |
| `set_member_role` | `p_group_id`, `p_user_id`, `p_role`; owner changes member/admin |
| `transfer_group_ownership` | `p_group_id`, `p_new_owner`; old owner becomes admin |
| `add_guest` | `p_group_id`, `p_name`; inviting member is recorded by the DB |
| `create_match` | `p_group_id`, `p_starts_at`, `p_venue`; optional `p_format`, `p_expected_cost`, `p_rsvp_lock_at` |
| `update_match` | `p_match_id`, `p_starts_at`, `p_venue`, `p_format`, `p_rsvp_lock_at`; optional `p_expected_cost` |
| `cancel_match` | `p_match_id`; cannot cancel a finished match |
| `respond_to_match` | `p_match_id`, `p_status`, optional `p_guest_id`; returns authoritative RSVP row |
| `promote_waitlist` | `p_match_id`; admin repair/recheck, never bypasses cutoff |
| `finish_match` | See atomic completion contract below |
| `record_match_result` | `p_match_id`; optional `p_winner`, `p_score_a`, `p_score_b`, `p_goals`; replaces the result |
| `set_cost_split` | `p_match_id`, `p_enabled`; optional `p_total_cost`, `p_paid_by` (defaults to group owner) |
| `compute_cost_split` | `p_match_id`; validates/reuses saved split, preserves settlement markers |
| `mark_payment_paid` | `p_payment_id`, `p_paid`; organizer/admin only |
| `cast_mvp_vote` | `p_match_id`, `p_participant_id`; voter always comes from the JWT |
| `get_voting_state` | `p_match_id`; eligible count, ballot count, caller's voted flag, deadlines |
| `close_mvp_voting` | `p_match_id`; member may request a due close, cannot force it early |
| `get_my_stats` | No inputs; own per-group rows plus overall row (`group_id = null`) |
| `evaluate_badges` | Optional `p_user_id`, which must be the caller unless service role |
| `register_device` | `p_apns_token`, `p_environment` (`sandbox` or `production`); reassociates a known device on login |

Series RPCs: `create_match_series(p_group_id, p_weekday, p_start_time, p_venue,
p_format, p_default_cost, p_create_days_before, p_rsvp_lock_hours, p_timezone)`;
the final five inputs have defaults. `update_match_series` takes `p_series_id`
instead of `p_group_id`, all schedule values and `p_active`, with no defaults.
`set_series_active(p_series_id, p_active)` stops/resumes generation.
`skip_series_occurrence(p_series_id, p_date)` records a durable skip and cancels
an already-generated, unfinished occurrence.

For series creation, `p_format` also defaults to the group's format; default cost
is null, creation lead time is five days, RSVP lock is two hours and timezone is
`Europe/Athens`. Weekday is PostgreSQL's convention: Sunday = 0, Saturday = 6.

Database errors use stable codes/messages such as `RSVP_LOCKED`,
`GROUP_ACCESS_DENIED`, `MVP_SELF_VOTE_FORBIDDEN` and `COST_SPLIT_NOT_BALANCED`.
The Swift service layer should translate them into Greek String Catalog keys.
Do not display raw SQL errors to end users. Retry transaction serialization or
deadlock errors with a bounded backoff. Do not blindly retry non-idempotent
creation RPCs after an ambiguous network result; reconcile first.

## Capacity and RSVP

- `match_formats` is the catalog; 5x5, 7x7, 8x8 and 11x11 are initial rows,
  not branches in the logic. Composite foreign keys enforce the format/team-size
  pairing. The stored generated capacity is always `players_per_team * 2`.
- A match row lock serializes seat decisions, withdrawals, promotions and changes
  to capacity. Oversized capacity reductions fail instead of evicting players.
- A client requests only `yes`, `maybe` or `no`. Full matches turn `yes` into
  `waitlist`. Guests and web guests use the same rows and capacity path.
- Queue tickets are monotonic; `rsvps_with_waitlist_position` exposes a live,
  dense `position_in_waitlist`. Retrying `yes` keeps a waiter's priority. Leaving
  and rejoining the queue gives a new ticket.
- A `yes` changing to either `no` or `maybe` releases the seat and promotes the
  first eligible waiter. The state update, audit and notification commit together.
- No RSVPs or promotions occur at/after `rsvp_lock_at`, even if cron has not yet
  changed the status to `locked`. Organizers can explicitly edit/reopen a future
  match's cutoff; late attendance corrections use the finish roster instead.
- Every initial response and status transition is audited, including automatic
  promotions. A repeated identical status is not a transition. Hard RSVP deletion
  and identity rewrites are forbidden. Hours before kickoff are captured at change
  time and are not rewritten if the match is later rescheduled.
- Exactly one of `user_id` or `guest_id` is required. Composite foreign keys reject
  cross-group guests and cross-match scorers/candidates. A claimed guest and their
  account cannot be inserted twice into the same RSVP/played roster.

The schema reserves guest claim identity and resolves it in statistics. A claim
RPC is deliberately **not exposed yet**: Step 4 must add explicit claimant plus
inviter/organizer verification, conflict handling and concurrent-claim tests.
Clients cannot claim another person's history by updating a UUID field. Historical
guest debts stay with the recorded inviting member, not a later claimant.

## Atomic Completion

`finish_match(p_match_id, p_participants, p_winner?, p_score_a?, p_score_b?,
p_goals?, p_total_cost?, p_paid_by?)` accepts a nonempty JSON roster:

```json
[
  { "user_id": "registered-user-uuid", "team": "A" },
  { "guest_id": "guest-uuid", "team": "B" }
]
```

`team` may be omitted. The roster represents **who actually played**, not merely
who RSVP'd; it may include substitutes beyond RSVP capacity. Guests' debtors are
snapshotted by the database. A finished roster is immutable, keeping billing,
statistics and voter eligibility consistent. Repeating `finish_match` returns the
existing match without reopening voting or replacing its roster. Result and cost
corrections use their explicit RPCs. More extensive roster corrections require a
future audited correction workflow, not table writes.

Both scores are present or neither is. Scores derive A/B/draw automatically.
Winner-only and no-result modes are allowed. Optional scorers use this JSON shape:

```json
[
  { "user_id": "registered-user-uuid", "team": "A", "minute": 12 },
  { "guest_id": "guest-uuid", "team": "B" }
]
```

Scorers must have played in this match, their assigned team must agree, and the
number of recorded goals cannot exceed that team's score. Partial scorer data is
allowed; own-goal attribution is outside this schema. Null `p_goals` means no scorer
recording; an empty array means scorer recording enabled with none recorded yet.

No cost argument means no split and **no payment rows**. A split can be enabled or
edited later. EUR amounts use exact `numeric(12,2)`, and the per-participant share
is rounded to the nearest EUR 0.50, with halfway values rounded upward. Guest
shares aggregate into the inviter's payment, including when that inviter did not
play. The pitch payer's own share is recorded as already settled.

`sum(payments.amount) + rounding_remainder = total_cost` is checked at commit.
A positive remainder is the payer's uncovered amount; a negative remainder is
overcollection to return/credit. EUR 20 / 3 gives EUR 6.50 and +0.50; EUR 20.50 / 3
gives EUR 7 and -0.50. The later UI must show the signed remainder explicitly.
Changing/disabling a split with other settled positive payments is rejected until
the organizer explicitly unmarks them; recalculation never silently loses receipts.
These are bookkeeping entries, not a payment processor or bank transfer system.

Every completed match opens voting, independent of result or billing. Registered
played identities are snapshotted as eligible voters; unclaimed guests cannot vote
but may be candidates. One immutable non-self ballot per eligible user is allowed.
The deadline is 24 hours after **completion**, not kickoff. The final eligible ballot
closes synchronously; cron handles deadlines. No ballots means no invented MVP.
Zero registered voters closes immediately without a winner. Highest-vote ties
produce multiple `mvp_results` rows and shared awards.

## Statistics and Badges

`player_stats_view` provides appearances, wins/losses/draws, win percentage, goals,
MVP count and the current attendance streak per group and overall. Use
`get_my_stats()` for the caller's full history. No-result matches never enter the
win-percentage denominator. With a known A/B winner but no team assignment, that
player's result is also unknown and excluded; a draw is known for every participant.
Only recorded scorers contribute goals. Streaks follow kickoff order (UUID breaks
ties) among finished matches; no-shows break them, cancellations do not.

`badge_definitions.rule_params` is the single configuration point for thresholds,
lookback, late hours and group/overall scopes. The three supported metric families
are `current_streak`, `mvp_count`, and `late_cancellations`; new thresholds/scopes
need only definition rows. A new metric family requires SQL implementation.
Ghost counts distinct matches, not repeated toggles, in the latest ten already-
started, non-cancelled group matches. The default late window is 0 through 24 hours.

Awards are permanent achievements, unique per user/group/code, with the rule
snapshot and award timestamp retained. Threshold edits do not revoke old awards.
Completion and MVP closure evaluate affected players immediately; maintenance
rechecks users in bounded batches and catches late cancellations. The outbox is
deduplicated by award ID. The later in-app celebration can consume `player_badges`
Realtime events without reading server-only delivery data.

## Recurrence, Jobs and Web Trust Boundary

Weekly recurrence stores an IANA timezone and local time, not a UTC weekday.
Generation uses the local calendar horizon and a unique `(series_id, occurrence_date)`
key. Retries cannot recreate skipped or cancelled occurrences. Series edits affect
only not-yet-generated matches; edit a generated match separately. Stopping a
series does not cancel already-generated matches.

PostgreSQL's DST resolution is intentional: nonexistent spring times shift forward;
an ambiguous autumn time uses the standard-time occurrence. Athens spring/autumn
cases are tested. Reminders enter the outbox on the first maintenance run in the
24-hour window, only while RSVPs are open. Explicit `no`, confirmed and waitlisted
players are excluded; missed scheduler runs catch up before the RSVP cutoff.

Only service-role callers can invoke `create_recurring_matches()`,
`run_maintenance()`, `claim_notifications(p_limit?, p_lease_seconds?)`,
`complete_notification(p_id, p_lease_token, p_error?)`, `get_push_targets(p_user_id)`,
`get_invite_preview(p_code)` and
`submit_web_rsvp(p_code, p_match_id, p_name, p_status, p_token_hash)`.
`close_mvp_voting` and `evaluate_badges` additionally allow authorized user callers.

The web Edge Function must hash a cryptographically random, high-entropy responder
capability; only the 64-character SHA-256 digest is stored. Do not hash a name/email
as identity or accept an unverified browser-supplied hash as proof of ownership.
Reusing the capability for a match updates the same response, not another guest.
The valid invite and match must belong to the same group. Web guests belong to the
invite creator, who bears their guest shares if the organizer enables a split.
Once claimed, an old web capability cannot alter the registered player's response.
Pre-login previews expose group/inviter names, next-match details and aggregate
capacity, not roster identities, tokens or financial debts. Estimated preview cost
uses expected cost divided by full capacity and is not a final debt calculation.

Outbox workers claim bounded batches with `FOR UPDATE SKIP LOCKED` and lease tokens.
Expired leases can be recovered; stale acknowledgements cannot finish a newer claim.
Failures back off, capped at one hour; ten failed claims leave the row for operator
inspection/recovery. Delivery is at-least-once: the later APNs worker should use an
outbox-derived collapse identifier and clients should deduplicate event IDs. Neither
APNs calls nor HTTP calls execute inside a transaction. Define retention and alerting
for the outbox and cron execution logs before production launch.