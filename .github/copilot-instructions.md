# Sentra Project Instructions

## 0. Project Summary

App: `Sentra`; App Store display name: `Σέντρα`. An iOS app organizing amateur
football among friend groups (5x5, 7x7, 8x8, 11x11). It replaces WhatsApp/Viber
coordination with RSVP, guests, waitlists, recurring matches, optional results,
optional cost splitting, anonymous MVP voting, statistics, an original football
player card, badges, and cosmetic premium card designs. The player card is the
main viral/growth feature.

## 2. Current Status

- Step 1 is DONE. The user reports all six migrations were deployed with
  `supabase db push` to Supabase EU West / Ireland and seed data executed.
- Deployed migrations are the SOURCE OF TRUTH. Never edit, rename, delete, or
  reset them. Propose schema changes first; only then add a NEW additive migration.
- Step 2 is the current implementation/review boundary. Read
  [docs/PROGRESS.md](../docs/PROGRESS.md) for verified status and outstanding gates.
- Steps 3-9 must not start without the user's review and authorization.
- A repository migration describes the deployed contract; do not claim to have
  inspected the remote database without an actual authorized remote inspection.

## 3. Development Environment and Conventions

- Write code in VS Code; build in Xcode on a Mac. Sync through the private GitHub
  repository. Keep the repository clean and reproducible.
- SwiftUI, iOS 17+, Swift 5.9+, MVVM, async/await, `@Observable`, official
  `supabase-swift` via SPM, XcodeGen (`project.yml`), Supabase Postgres/Auth/Realtime/
  Storage, TypeScript Edge Functions, and `pg_cron`.
- Use `Sentra` for project, target, files, and code. Bundle ID:
  `com.sarantos.sentra`. Use `Σέντρα` only as display name and UI branding.
- Greek UI through `Localizable.xcstrings`, ready for English. No hardcoded UI
  strings. User/backend data is not a localization key.
- Ignore `ios/Config/Config.xcconfig`; commit only `Config.xcconfig.example` with
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `UNIVERSAL_LINK_DOMAIN`, and
  `REVENUECAT_PUBLIC_SDK_KEY`. NEVER put a service-role/secret key in the app.
- Enforce business rules in the database, not only in UI. Use authorized RPCs
  for mutations; RLS read access is not write permission.
- Models: `Codable`, `Identifiable`, `Hashable`, `Sendable`; explicit `CodingKeys`
  for snake_case; `Decimal` for money; `Date` for timestamps. Enum raw values must
  match PostgreSQL exactly. Never guess columns: read the migrations.
- Calendar-only SQL `date`/`time` values are not instants: preserve their local
  representations and the series timezone rather than silently treating them as UTC.
- Never claim iOS compiles unless a build actually ran. If unavailable here,
  state that limitation and provide exact Mac build/test commands.
- Work step by step. Stop after each step for review. Never silently implement
  schema-dependent features against tables that do not exist.

## 4. Product Rules

### 4.1 Groups and Formats

- A group (παρέα) has an owner, optional admins, members, and a default format.
- Configurable 5x5, 7x7, 8x8, 11x11; capacity = players_per_team * 2. Never hardcode 10.
- Registered players have display name, position GK/DEF/MID/FWD/ANY, optional avatar.
  Guests have a name and inviting member, without an account.

### 4.2 Onboarding and Auth (Step 3)

- No intro slides. Aim for first RSVP or first match within 60 seconds.
- Sign in with Apple and email magic link. No passwords.
- Profile prompt: "Πώς σε φωνάζουν στο γήπεδο;", position, optional avatar.
- Organizer: create group -> first match (date/time, venue, optional cost, weekly
  toggle) -> invite (share sheet with Greek message, link, QR) -> match screen.
- Invite Universal Link `/i/{code}`: invite card and RSVP buttons BEFORE login,
  quick auth, name/position, then save pending RSVP.
- Just-in-time permissions: push after first RSVP/group creation; calendar on tap;
  photos on avatar selection.
- Empty state: "Μόνος σου δεν βγαίνει 5άρι 😅". First yes:
  "Κλείστηκες! 🔥 Μην γίνεις φάντασμα 👻".

### 4.3 RSVP (Step 4)

- yes / maybe / no / waitlist: Έρχομαι / Ίσως / Δεν έρχομαι / Αναμονή.
- Full capacity sends new yes to time-ordered waitlist; yes -> no auto-promotes
  first waiter and queues push. The deployed DB also promotes on yes -> maybe.
- Default lock two hours before kickoff, configurable. Remind maybe/no-response
  players 24 hours before, not players who explicitly answered no.
- Log every transition in `rsvp_history` for reliability/Ghost. Realtime counts.
- Clients request yes/maybe/no only; waitlist is an authoritative DB outcome.

### 4.4 Guests (Step 4)

- Name-only +1, occupying a spot or waitlisted. Can receive MVP votes, cannot vote.
- Charge guests to their inviting member. A later verified claim may attach a
  real account. No claim RPC is deployed yet; do not update claim fields directly.

### 4.5 Recurring Matches (Step 6)

- Series: weekday, local time, venue, format, default cost, create_days_before
  (default 5), lock hours. Auto-create next match and notify members.
- Use pg_cron and later Edge workers. Preserve deployed IANA timezone semantics.
- Organizer can edit, skip an occurrence, pause, or stop.

### 4.6 Calendar (Step 6)

- EventKit, one-tap addition, alert two hours before.

### 4.7 Finish Match (Step 5)

- Organizer/admin only. Stage 1: who played, prefilled from yes and guests;
  remove no-shows, add late joiners, optional Team A/B.
- Stage 2: result OPTIONAL: none, winner only (A/B/draw), or full score with
  optional scorers. Derive winner from score in the database.
- Stage 3: cost split OPTIONAL, chosen at the end, can be enabled/edited later.
  Off creates no payments. On uses editable total (prefilled if available), pitch
  payer, total / played participants rounded to EUR 0.50. Guests aggregate to
  inviter. Paid markers and "Ποιος χρωστάει" list.
- Respect deployed signed rounding remainder and settled-payment guards. A finished
  roster is immutable; later audited roster correction requires a new contract.
- Stage 4: MVP voting opens regardless of result or cost splitting.

### 4.8 MVP Voting (Step 5)

- Only registered participants who played vote. One vote each, not for self;
  any participant, including a guest, may receive a vote.
- Anonymous, hidden until closure. Never query individual ballots from the app.
- Close after 24 hours from completion or all eligible votes. Ties are shared MVP.
- Push "🏆 MVP: <name> (<votes> ψήφοι)" and shareable MVP card.

### 4.9 Player Card (Step 8, Core Growth Feature)

- ORIGINAL trading-card design. No EA FC/FIFA frames, fonts, logos, club/league logos.
- Big OVR, position ΤΕΡ/ΑΜΥ/ΜΕΣ/ΕΠΙ, cutout photo, name, fun title, group, stats
  ΣΥΜ / ΝΙΚ% / MVP / ΓΚΟΛ, streak, badge icons, small Σέντρα branding.
- On-device Vision `VNGenerateForegroundInstanceMaskRequest` background removal;
  PNG in Supabase Storage; fallback circular avatar.
- Rating is never purchasable. Under three appearances:
  "Η κάρτα σου ζεσταίνεται 🔥".
- Formula weights belong in central DB configuration with a Swift mirror:
  - win = (wins + 0.5*draws + 2.5) / (decided_matches + 5)
  - mvp = min((mvp_count / appearances) / 0.30, 1)
  - goals = min(goals_per_applicable_match / 2.0, 1); if no scorer data,
    redistribute its weight proportionally.
  - attend = played_last_10 / group_matches_last_10
  - reliab = 1 - late_cancellations_last_10 / 10
  - OVR = clamp(round(50 + 49*(0.30*win + 0.25*mvp + 0.15*goals +
    0.20*attend + 0.10*reliab)), 50, 99)
- `rating_history` after each match; show ▲ +2 / ▼ -1.
- Free tiers: Bronze <65; Silver 65-74; Gold 75-84; Elite 85+.
- Latest MVP: "Παίκτης της Εβδομάδας", special dark/gold animated card.
- Tier-up: full-screen celebration, haptic, confetti,
  "Αναβαθμίστηκες σε Χρυσή! 🥇", "Μοιράσου την κάρτα".
- Config-driven fun titles: Ο Τοίχος, Σκόρερ, Πάντα παρών, Φάντασμα 👻, MVP Machine.
- `ImageRenderer` exports 1080x1920 and 1080x1080, `ShareLink`, branding and link/QR,
  two-card comparison, group leaderboard in Στατιστικά.

### 4.10 Badges (Step 8)

- 🔥 Σερί: 10 consecutive group matches played.
- 👻 Φάντασμα: 3+ yes -> no cancellations within 24 hours in last 10 matches.
- 🏆 5x MVP: five MVP wins.
- Data-driven definitions (code, name_el, emoji, description_el, JSON parameters),
  player awards (awarded_at, optional group), push, celebration, share prompt.
- Actual deployed parameter column is `rule_params`, not `params`; award rows
  store `badge_code` and `rule_snapshot`.

### 4.11 Web RSVP (Step 7)

- Small Next.js page on Vercel `/i/{code}`, calling `web-rsvp` Edge Function;
  invite card, three RSVP buttons, name-only localStorage, App Store link.
- `apple-app-site-association` for Universal Links; `/c/{id}` card page with Open Graph.
- Pre-login DB preview/web RPCs are service-role-only; never call them from iOS
  with a privileged key. Build the authenticated/abuse-protected Edge boundary later.

### 4.12 Monetization (Step 9, Cosmetic Only)

- App is 100% free; no ads, no subscriptions at launch. Purchases NEVER affect
  rating, tiers, statistics, badges earned by play, RSVP, voting, or rankings.
- StoreKit 2 + RevenueCat non-consumables, appUserID = Supabase user UUID:
  - `sentra.card.holo` EUR 0.99, motion shine.
  - `sentra.card.teamcolors` EUR 0.99, two colors, no club names/logos.
  - `sentra.card.legend` EUR 1.99, dark/gold animated.
  - `sentra.pack.founding` EUR 2.99, all three plus exclusive "Ιδρυτικό μέλος"
    design and founder badge. Sold until `app_config.founding_pack_ends_at`;
    existing owners keep it forever.
- RevenueCat webhook -> Edge Function -> server-owned `user_card_designs`.
- Live previews, priced locked states, Restore Purchases, soft upsell at most
  weekly (after MVP, tier-up, before sharing).

### 4.13 Analytics (Step 9)

- TelemetryDeck or PostHog without personal data. Events: group_created,
  match_created, rsvp_set, guest_added, match_finished, cost_split_enabled,
  mvp_vote_cast, card_shared, invite_link_opened, app_installed_from_invite,
  paywall_viewed, design_previewed, purchase_completed. SQL weekly KPI view.

## 5. Design System

- Football green primary; off-white backgrounds, white rounded cards, soft
  shadows, dark premium MVP/card surfaces, bold headings, full-width large buttons,
  SF Symbols. Support light and dark mode.
- RSVP: green yes, amber maybe, red no, gray/blue waitlist; always icon/text too.
- Central tokens for colors, typography, spacing, radius, shadows, animation.
- Dynamic Type, VoiceOver labels, contrast, minimum 44pt targets, Reduce Motion.
- Final tabs: Αγώνες, Παρέες, Στατιστικά, Προφίλ.

## 6. Target iOS Structure

```text
ios/
  project.yml
  Config/Config.xcconfig.example
  Sentra/
    App/ (SentraApp, AppRouter, AppRoute, AppEnvironment, DeepLinkHandler)
    Core/ (Configuration, Supabase/SupabaseProvider, Theme, Components, Utilities)
    Models/
    Services/ (Protocols, Live, Mock)
    Features/ (Onboarding, Invite, Groups, Match, FinishMatch, Payments, Voting,
               Series, PlayerCard, Stats, Profile, Monetization; fill in later steps)
    Resources/ (Assets.xcassets, Localizable.xcstrings, Info.plist)
  SentraTests/
supabase/ (existing)
web/ (Step 7)
```

## 7. Step Plan and Review Discipline

1. Schema, migrations, RLS, seed: DONE.
2. Swift models, services, design system: current review boundary.
3. Onboarding and auth.
4. Groups, matches, RSVP, guests.
5. Finish match, result, cost split, MVP voting.
6. Recurring matches, push, calendar.
7. Web RSVP and Universal Links.
8. Player card, rating, badges, sharing.
9. Cosmetic monetization and analytics.

Before each step read `docs/PROGRESS.md` and nearby existing code. Keep previews
offline through mock services. Add focused unit tests. At each step's end update
the progress ledger with changes, decisions, issues, validation, exact Mac commands,
manual review checklist, and next step, then STOP for review. No deployed migration
changes, no database resets, no auto-commits. Step 2 must not implement auth flows,
RSVP mutation logic, or any Step 3+ workflow.