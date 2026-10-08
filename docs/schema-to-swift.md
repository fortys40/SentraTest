# Schema to Swift Contract

Source of truth: the six immutable files in [../supabase/migrations](../supabase/migrations).
The user reports these migrations deployed to EU West / Ireland; Step 2 inspected
the repository and an isolated PGlite instance, **not the hosted database**.

## Schema Summary

- 21 public tables, two private worker tables, six PostgreSQL enums, five
  security-invoker views, and 35 public RPCs. Public tables have RLS enabled.
- Read access is authenticated and group-scoped, except own private data and
  globally readable authenticated format/badge catalogs. Anonymous clients have
  no direct table or RPC access.
- Direct client writes: own profile allowlist (`display_name`, `position`,
  `avatar_url`, `onboarding_completed`) and deletion of own device tokens only.
  Group/match/RSVP/result/payment/voting mutations are authorized database RPCs.
- Composite foreign keys prevent cross-group identities and cross-match scorers.
  RSVP and participant rows require exactly one of user/guest. Group ownership
  agrees with a single active owner membership at transaction commit.
- Capacity is `players_per_team * 2`, with format/team-size pairing enforced by a
  catalog foreign key. Match row locks serialize capacity and waitlist decisions.
- Match completion freezes the roster; scores derive winner. MVP ballots remain
  unreadable, even after close. Results allow shared winners. Guest debts stay
  with the inviter. Payment totals plus signed remainder balance at commit.
- Private `avatars` bucket, owner-path writes and shared-group reads. Only
  `matches`, `rsvps`, `payments`, `mvp_results`, `player_badges` publish Realtime.
- `pg_cron` runs database maintenance once per minute when installed. APNs/HTTP
  delivery is still deferred; SQL queues leased, deduplicated outbox work.

Detailed signatures, RLS scopes, and constraints: [database.md](database.md).

## Mapping Rules

All entity models are `Codable`, `Identifiable`, `Hashable`, `Sendable`. Lists below
give **every column** as `column -> property: SwiftType`. `?` means nullable;
unmarked fields are effectively required. `id` is a UUID unless explicitly shown.
All snake_case mappings use explicit `CodingKeys`, not a global key strategy.

`numeric` uses `Decimal` (including money, lock hours, percentages and audit hours).
`bigint` uses `Int64`. `timestamptz` uses `Date` and `SentraJSON`, accepting fractional
or whole ISO 8601 timestamps with offsets. SQL `date` is a `yyyy-MM-dd` string;
`time` is a local `HH:mm:ss[.fraction]` string, interpreted with the series timezone.
Profile `avatar_url` is optional **text**, not necessarily an absolute URL: private
Storage object paths must be resolved to signed URLs in a later service.

PostgreSQL reports generated capacity and most view columns as nullable in catalog
metadata. `matches.capacity` is nevertheless non-null because both multiplicands
are non-null. View required fields follow their joins/counts/coalesces, as below.
Do not send generated capacity or entire read models in write requests.

## Tables

| Table | Swift Model | Column -> Property: Type |
| --- | --- | --- |
| `match_formats` | `MatchFormat` | `code -> code: String`; `players_per_team -> playersPerTeam: Int`; `active -> active: Bool`. Computed identity = code; capacity = playersPerTeam * 2. |
| `profiles` | `Profile` | `id -> id: UUID`; `display_name -> displayName: String`; `position -> position: FootballPosition`; `avatar_url -> avatarURL: String?`; `onboarding_completed -> onboardingCompleted: Bool`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `groups` | `Group` | `id -> id: UUID`; `name -> name: String`; `owner_id -> ownerID: UUID`; `default_format -> defaultFormat: String`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `group_members` | `GroupMember` | `id -> id: UUID`; `group_id -> groupID: UUID`; `user_id -> userID: UUID`; `role -> role: GroupRole`; `joined_at -> joinedAt: Date`; `left_at -> leftAt: Date?`. |
| `group_invites` | `GroupInvite` | `id -> id: UUID`; `code -> code: String`; `group_id -> groupID: UUID`; `created_by -> createdBy: UUID`; `expires_at -> expiresAt: Date?`; `revoked_at -> revokedAt: Date?`; `created_at -> createdAt: Date`. |
| `guests` | `Guest` | `id -> id: UUID`; `group_id -> groupID: UUID`; `name -> name: String`; `invited_by -> invitedBy: UUID`; `claimed_by_user_id -> claimedByUserID: UUID?`; `claimed_at -> claimedAt: Date?`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `match_series` | `MatchSeries` | `id -> id: UUID`; `group_id -> groupID: UUID`; `weekday -> weekday: Int`; `start_time -> startTime: String`; `timezone -> timezone: String`; `venue -> venue: String`; `format -> format: String`; `players_per_team -> playersPerTeam: Int`; `default_cost -> defaultCost: Decimal?`; `create_days_before -> createDaysBefore: Int`; `rsvp_lock_hours -> rsvpLockHours: Decimal`; `active -> active: Bool`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `series_skips` | `SeriesSkip` | `id -> id: UUID`; `series_id -> seriesID: UUID`; `occurrence_date -> occurrenceDate: String`; `created_by -> createdBy: UUID`; `created_at -> createdAt: Date`. |
| `matches` | `Match` | See expanded table below. |
| `rsvps` | `RSVP` | `id -> id: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `user_id -> userID: UUID?`; `guest_id -> guestID: UUID?`; `status -> status: RSVPStatus`; `waitlisted_at -> waitlistedAt: Date?`; `waitlist_order -> waitlistOrder: Int64?`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `rsvp_history` | `RSVPHistoryEntry` | `id -> id: UUID`; `rsvp_id -> rsvpID: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `user_id -> userID: UUID?`; `guest_id -> guestID: UUID?`; `old_status -> oldStatus: RSVPStatus?`; `new_status -> newStatus: RSVPStatus`; `changed_by -> changedBy: UUID?`; `changed_at -> changedAt: Date`; `hours_before_kickoff -> hoursBeforeKickoff: Decimal`. |
| `web_responders` | `WebResponder` (contract only, no client access) | `id -> id: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `invite_id -> inviteID: UUID`; `guest_id -> guestID: UUID`; `name -> name: String`; `status -> status: RSVPStatus`; `token_hash -> tokenHash: String`; `claimed_by_user_id -> claimedByUserID: UUID?`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `match_participants` | `MatchParticipant` | `id -> id: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `user_id -> userID: UUID?`; `guest_id -> guestID: UUID?`; `team -> team: TeamSide?`; `charged_to_user_id -> chargedToUserID: UUID`; `created_at -> createdAt: Date`. |
| `goals` | `Goal` | `id -> id: UUID`; `match_id -> matchID: UUID`; `scorer_participant_id -> scorerParticipantID: UUID`; `team -> team: TeamSide`; `minute -> minute: Int?`; `created_at -> createdAt: Date`. |
| `payments` | `Payment` | `id -> id: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `debtor_user_id -> debtorUserID: UUID`; `amount -> amount: Decimal`; `includes_guest_ids -> includesGuestIDs: [UUID]`; `paid -> paid: Bool`; `paid_at -> paidAt: Date?`; `updated_by -> updatedBy: UUID?`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `mvp_eligible_voters` | `MVPEligibleVoter` (contract only, no client read) | `id -> id: UUID`; `match_id -> matchID: UUID`; `voter_id -> voterID: UUID`. |
| `mvp_votes` | `MVPVote` (contract only, no client read) | `id -> id: UUID`; `match_id -> matchID: UUID`; `voter_id -> voterID: UUID`; `voted_participant_id -> votedParticipantID: UUID`; `voted_user_id -> votedUserID: UUID?`; `created_at -> createdAt: Date`. |
| `mvp_results` | `MVPResult` | `id -> id: UUID`; `match_id -> matchID: UUID`; `participant_id -> participantID: UUID`; `votes -> votes: Int`; `created_at -> createdAt: Date`. |
| `badge_definitions` | `BadgeDefinition` | `id -> id: UUID`; `code -> code: String`; `name_el -> nameEL: String`; `emoji -> emoji: String`; `description_el -> descriptionEL: String`; `rule_params -> ruleParams: [String: JSONValue]`; `active -> active: Bool`; `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |
| `player_badges` | `PlayerBadge` | `id -> id: UUID`; `user_id -> userID: UUID`; `group_id -> groupID: UUID?`; `badge_code -> badgeCode: String`; `rule_snapshot -> ruleSnapshot: JSONValue`; `awarded_at -> awardedAt: Date`. |
| `device_tokens` | `DeviceToken` | `id -> id: UUID`; `user_id -> userID: UUID`; `apns_token -> apnsToken: String`; `environment -> environment: String` (check: sandbox/production); `created_at -> createdAt: Date`; `updated_at -> updatedAt: Date`. |

### Match Columns

| Column | Match Property | Type |
| --- | --- | --- |
| `id` | `id` | `UUID` |
| `group_id` | `groupID` | `UUID` |
| `series_id` | `seriesID` | `UUID?` |
| `occurrence_date` | `occurrenceDate` | `String?` (local date) |
| `format` | `format` | `String` (catalog code) |
| `players_per_team` | `playersPerTeam` | `Int` |
| `capacity` | `capacity` | `Int` (server generated) |
| `venue` | `venue` | `String` |
| `starts_at` | `startsAt` | `Date` |
| `rsvp_lock_at` | `rsvpLockAt` | `Date` |
| `expected_cost` | `expectedCost` | `Decimal?` |
| `status` | `status` | `MatchStatus` |
| `winner` | `winner` | `MatchWinner?` |
| `score_a` | `scoreA` | `Int?` |
| `score_b` | `scoreB` | `Int?` |
| `goals_recorded` | `goalsRecorded` | `Bool` |
| `finished_at` | `finishedAt` | `Date?` |
| `mvp_voting_closes_at` | `mvpVotingClosesAt` | `Date?` |
| `mvp_closed_at` | `mvpClosedAt` | `Date?` |
| `cost_split_enabled` | `costSplitEnabled` | `Bool` |
| `total_cost` | `totalCost` | `Decimal?` |
| `paid_by` | `paidBy` | `UUID?` |
| `share_amount` | `shareAmount` | `Decimal?` |
| `rounding_remainder` | `roundingRemainder` | `Decimal?` (signed) |
| `created_at` | `createdAt` | `Date` |
| `updated_at` | `updatedAt` | `Date` |

## Enums

| PostgreSQL | Swift | Exact Raw Values |
| --- | --- | --- |
| `player_position` | `FootballPosition` | `GK`, `DEF`, `MID`, `FWD`, `ANY` |
| `member_role` | `GroupRole` | `owner`, `admin`, `member` |
| `rsvp_status` | `RSVPStatus` | `yes`, `maybe`, `no`, `waitlist` |
| `match_status` | `MatchStatus` | `scheduled`, `locked`, `finished`, `cancelled` |
| `team_side` | `TeamSide` | `A`, `B` |
| `match_winner` | `MatchWinner` | `A`, `B`, `draw` |

`MatchFormat` is deliberately a struct, not an enum: new active catalog rows must
decode without an app update. `GroupRole` maps `member_role`, not `group_role`.

## Views and RPC Rows

| Source | Model | Column Mapping |
| --- | --- | --- |
| `rsvps_with_waitlist_position` | `RSVPWithWaitlistPosition` | All `rsvps` columns decode into `response: RSVP` from the **same flat object**; `position_in_waitlist -> positionInWaitlist: Int64?`. Identity = response.id. |
| `match_rsvp_counts` | `MatchRSVPCounts` | `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `capacity -> capacity: Int`; `yes_count -> yesCount: Int64`; `maybe_count -> maybeCount: Int64`; `no_count -> noCount: Int64`; `waitlist_count -> waitlistCount: Int64`. Identity = matchID. |
| `outstanding_payments` | `OutstandingPayment` | `id -> id: UUID`; `match_id -> matchID: UUID`; `group_id -> groupID: UUID`; `debtor_user_id -> debtorUserID: UUID`; `amount -> amount: Decimal`; `includes_guest_ids -> includesGuestIDs: [UUID]`; `creditor_user_id -> creditorUserID: UUID`; `creditor_name -> creditorName: String`. |
| `player_stats_view`, `get_my_stats()` | `PlayerStats` | `user_id -> userID: UUID`; `group_id -> groupID: UUID?`; `appearances -> appearances: Int64`; `wins -> wins: Int64`; `losses -> losses: Int64`; `draws -> draws: Int64`; `goals -> goals: Int64`; `mvp_count -> mvpCount: Int64`; `win_pct -> winPercentage: Decimal?`; `current_streak -> currentStreak: Int64`. Identity = user + group/overall. |
| `late_cancellations_view` | `LateCancellation` | `badge_code -> badgeCode: String`; `user_id -> userID: UUID`; `group_id -> groupID: UUID`; `match_id -> matchID: UUID`; `last_cancelled_at -> lastCancelledAt: Date`. Identity = badge + user + match. |
| `get_voting_state(p_match_id)` | `VotingState` | `eligible_voters -> eligibleVoters: Int64`; `votes_cast -> votesCast: Int64`; `has_voted -> hasVoted: Bool`; `closes_at -> closesAt: Date?`; `closed_at -> closedAt: Date?`. Contextual RPC value, not an identifiable entity. |

`JSONValue` preserves arbitrary JSONB using objects, arrays, strings, `Decimal`
numbers, booleans and null. No `Any`/binary-floating-point JSON intermediary.
Private `notification_outbox` and `maintenance_state` are worker-only and have no
iOS models, endpoints or logs. The existence of a public-table contract model
does not grant access: votes, voter snapshots and web capabilities are never fetched.

## Function Boundaries

| Family | Deployed Public Functions |
| --- | --- |
| Groups and identity | `create_group`, `update_group`, `create_invite`, `revoke_invite`, `accept_invite`, `set_member_role`, `transfer_group_ownership`, `add_guest`, `register_device` |
| Matches and RSVP | `create_match`, `update_match`, `cancel_match`, `respond_to_match`, `promote_waitlist` |
| Completion and cost | `finish_match`, `record_match_result`, `set_cost_split`, `compute_cost_split`, `mark_payment_paid` |
| MVP | `cast_mvp_vote`, `get_voting_state`, `close_mvp_voting` |
| Stats and badges | `get_my_stats`, `evaluate_badges` |
| Series | `create_match_series`, `update_match_series`, `set_series_active`, `skip_series_occurrence` |
| Service-only worker/web | `create_recurring_matches`, `run_maintenance`, `claim_notifications`, `complete_notification`, `get_push_targets`, `get_invite_preview`, `submit_web_rsvp` |

Step 2 only adapts basic group/match CRUD, own-profile update, session lookup/signout,
and RSVP reads. It does not call invite/auth-flow, RSVP-write, finish, voting, cron,
web, push, calendar or purchase operations. There is no client-side cascade delete
for history-bearing groups/matches. Do not retry ambiguous creates automatically.

## Specification Differences and Proposals

| Specification Expectation | Actual Contract / Decision |
| --- | --- |
| Format modeled as a fixed enum | A configurable table. Store format codes as String; fetch catalog rows. |
| Badge `params` | Column is `rule_params`; awards reference `badge_code`, with `rule_snapshot`. |
| Rating history, weights, title rules | Not deployed. `player_stats_view` has no OVR, last-ten attendance/reliability metrics, or scorer-applicability denominator. Do not infer these from win_pct. |
| `RatingHistoryEntry`, `CardDesign` as DB models | No backing tables. Step 2 types are explicitly preview-only; no live endpoints or ownership claims. |
| `card_designs`, `user_card_designs`, `app_config.founding_pack_ends_at` | Not deployed. Propose additive catalog/ownership/config schema in Step 9 before implementation. |
| Rating config/history and title rules in Step 8 | Propose additive, authorized configuration/history storage plus required metrics at that step; no migration added now. |
| Guest claim | Reserved columns, no verified claim RPC. Additive claim workflow proposal required in Step 4. |
| Six past matches plus upcoming mixed RSVP demo | SQL seed has three past matches, no upcoming fixture. The new in-memory factory is separate; seed is untouched. |
| Recurrence via cron plus Edge Function | Cron SQL generation/outbox exists; no Edge Functions or push delivery yet. |
| Analytics weekly KPI view | Not deployed; Step 9 proposal required. |
| Pre-login invite preview | Service-only RPC; requires Step 7 Edge boundary, never a service-role key in iOS. |

No deployed migration, seed, or Supabase configuration changes are part of Step 2.