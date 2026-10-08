# Sentra

App Store display name: **Σέντρα**. Amateur football for friend groups.

## Review Gate: Step 2

Step 2 now contains the iOS foundation: deployed-contract Swift models, injectable
services, a localized design system, deterministic mocks, placeholder navigation,
and an offline component dashboard. It does not implement onboarding, sign-in,
RSVP mutations, or any Step 3+ workflow. Stop here for review.

The user reports that all six migrations and seed data were deployed to Supabase
EU West / Ireland. No remote inspection was performed in Step 2. The migrations,
seed and Supabase configuration were left unchanged; no database was reset.

Read [docs/PROGRESS.md](docs/PROGRESS.md) for the delivery inventory, validation,
known gaps and review checklist. [docs/schema-to-swift.md](docs/schema-to-swift.md)
maps every public table, enum, view and RPC to the Swift boundary. Project rules
are persisted in [.github/copilot-instructions.md](.github/copilot-instructions.md).

The app-wide visual contract and component comparison are in
[docs/DESIGN.md](docs/DESIGN.md), based on the preserved
[docs/mockups/sentra-flow.png](docs/mockups/sentra-flow.png). The written spec wins
over the image. This alignment updates Step 2 previews only, not the later screens.

| Step | Scope | Status |
| --- | --- | --- |
| 1 | Schema, migrations, RLS, database rules and tests | DONE; deployment reported by user |
| 2 | Swift models, services, design system and offline previews | Implemented; Mac build/tests and review pending |
| 3 | Onboarding and Apple/email authentication | Not authorized |
| 4 | Groups, matches, RSVP and guests | Deferred; verified claim also needs a new RPC |
| 5 | Finish match, payments and MVP screens | Deferred |
| 6 | Recurrence UI, Edge workers, APNs and EventKit | Deferred |
| 7 | Web RSVP, Universal Links and AASA | Deferred |
| 8 | Player card, sharing and badge UI | Deferred |
| 9 | Cosmetic purchases and analytics | Deferred |

## Files

```text
Sentra/
  .github/copilot-instructions.md
  ios/
    project.yml
    Config/
      Base.xcconfig
      Config.xcconfig.example
    Sentra/
      App/
      Core/ (Configuration, Supabase, Theme, Components, Utilities)
      Models/
      Services/ (Protocols, Live, Mock)
      Features/Preview/
      Resources/ (Assets.xcassets, Localizable.xcstrings, Info.plist)
    SentraTests/
      Fixtures/supabase-rows.json
  supabase/
    config.toml
    migrations/
      202610060001_schema.sql
      202610060002_access_and_rsvp.sql
      202610060003_completion_and_voting.sql
      202610060004_stats_and_badges.sql
      202610060005_automation_and_web_boundary.sql
      202610060006_supabase_integrations.sql
    seed.sql
  tests/
    bootstrap.sql
    database.test.mjs
    ios-contract.test.mjs
  docs/
    DESIGN.md
    mockups/sentra-flow.png
    database.md
    schema-to-swift.md
    PROGRESS.md
  package.json
  package-lock.json
```

The migration files, not the test bootstrap, are the deployable database source.
There is no Edge Function, web app, or CI workflow in this delivery. Node packages
are development-only validation tools, not the application backend.

## Run the iOS Foundation on Mac

Requirements: macOS, Xcode 15+ with its command-line tools selected, Swift 5.9+,
an installed iPhone simulator with iOS 17+, and XcodeGen 2.42+. Install simulator
runtimes through Xcode Settings if no eligible device is available. Swift uses
language mode 5; this is distinct from the installed compiler version.

From the repository root:

```sh
brew install xcodegen
cd ios
cp -n Config/Config.xcconfig.example Config/Config.xcconfig
xcodegen generate
xcodebuild -resolvePackageDependencies -project Sentra.xcodeproj -scheme Sentra
open Sentra.xcodeproj
```

`cp -n` preserves any existing local configuration. The app always starts in
`AppEnvironment.preview(data:)` and needs no Supabase credentials. The optional local
config can remain unchanged for the preview. Select the `Sentra` scheme and an
iPhone simulator, then Run. The dashboard includes a photo/brand hero,
light/dark/system appearance, match card and stacked RSVP buttons, segmented player
and guest rows, a three-step progress header, a dark MVP sample, four original dark
metallic card tiers, empty/loading/error states, and placeholder destinations.
Demo selection never mutates the roster or submits a vote. The local photo crop
is temporary, low-resolution preview artwork, not a release asset.

App and canvas previews inject the current clock once when created so their dates
are dynamic; test fixtures retain the fixed 2026-10-07 default. Mocks contain 12 registered players, one
group, one upcoming 5x5 match with a guest and all RSVP statuses, six completed
matches, statistics, illustrative rating history, MVP results and earned badge
examples. They are independent of the SQL seed, which has three completed matches.

### Build and Test

Run these commands from the `ios` directory. Choose an available iPhone simulator
UUID from the destinations printed by Xcode, then paste it at the prompt:

```sh
xcodebuild -showdestinations -project Sentra.xcodeproj -scheme Sentra
printf 'Available iPhone simulator UUID (iOS 17+): '
read -r SIMULATOR_ID
xcodebuild build -project Sentra.xcodeproj -scheme Sentra \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Sentra.xcodeproj -scheme Sentra \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
```

There are 26 XCTest cases covering formats/capacity, all table/view fixture types,
timestamp offsets, local calendar values, exact money, nullable fields, waitlist
ordering, mock determinism, request allowlists, configuration, routes and dashboard
states. **XcodeGen generation, iOS compilation and XCTest have not run on the
Windows authoring host.** The Node source-contract checks are not a substitute.

Supabase's official SPM package is pinned to `2.20.0`. After successful resolution
on Mac, review and include the generated shared SPM lockfile in the delivery at
`ios/Sentra.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
Its ignore exception is already configured; no transitive lockfile was fabricated.

### Configuration and Service Boundary

The example exposes `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`UNIVERSAL_LINK_DOMAIN`, and `REVENUECAT_PUBLIC_SDK_KEY`, plus `DEVELOPMENT_TEAM`
for automatic device signing. The bundle ID is `com.sarantos.sentra`; the display
name is `Σέντρα`. Select your own signing team before a device build. Simulator
commands above disable signing.

Only set public project values in the ignored local config. Keep the example's
URL slash substitution: a literal `//` starts an xcconfig comment. Never put a
secret or service-role key in the app. Validation rejects placeholders and known
privileged key formats and redacts diagnostic descriptions; it does not verify
JWT signatures. Preview launch does not construct a network client.

`AppEnvironment.live()` creates one shared Supabase client and initially supports
Auth session/sign-out, Profile, Group, Match, and read-only RSVP adapters. Group
and match commands call deployed authorized CRUD RPCs; profile writes are limited
to the own-profile allowlist. No live switch or authentication UI is exposed.
The other services fail explicitly as unavailable. They do not substitute mocks
for real data or request system permissions.

Rating history, card-design ownership, configurable rating weights/titles, the
founding-pack deadline and analytics do not have a deployed contract yet. Their
preview types must not become live queries without separately approved additive
schema work. Individual MVP ballots and service-role-only web RPCs are not queried.

## Test Without Docker

Install Node.js 22 LTS or newer, open this folder in VS Code, and run:

```powershell
npm.cmd ci
npm.cmd run test:all
```

On macOS/Linux use `npm ci` and `npm run test:all`. `npm test` runs only the database
suite; `npm run test:ios-contract` runs only the Step 2 source-contract suite.

Each default suite creates an isolated in-memory PGlite PostgreSQL instance and
applies every migration. The database suite tests actual constraints, triggers,
transactions, RLS, role grants, protected RPCs and seed data. The iOS suite compares
Swift declarations with that schema and checks RPC parameters, project settings,
fixtures, localizations, component presence and token contrast. Neither connects
to a hosted project or executes Swift.

Step 2 result after design alignment: **35 passing checks, zero failures, two native
concurrency checks skipped** (21 database + 14 iOS source-contract checks). The
earlier clean `npm ci` succeeded and reported zero dependency vulnerabilities.
No dependencies were added during design alignment. Native mode was not run in Step 2.

Run the native PostgreSQL 17 mode on a machine that permits the bundled binaries.
It also runs the two independent-session race tests, using a random localhost
port, a temporary database directory and a generated test-only password:

```powershell
$env:SENTRA_TEST_ENGINE = 'native'
npm.cmd test
Remove-Item Env:SENTRA_TEST_ENGINE
```

On macOS or Linux:

```sh
SENTRA_TEST_ENGINE=native npm test
```

Run as a normal user, not root. No CI workflow currently exists. Do not disable
package install scripts: the native runner needs its platform installation step.
The existing repository tracks dependency artifacts under `node_modules`; the new
ignore rule does not untrack them. Platform-specific install churn was restored in
this delivery. Removing those tracked artifacts needs a separate cleanup review.

The bootstrap emulates only the Supabase Auth role helpers, Auth tables, Storage
metadata tables and Realtime publication. It does **not** emulate Auth HTTP flows,
Storage uploads, Realtime delivery, or the cron scheduler. Those integrations and
the native race tests remain release gates on a real Supabase stack.

## Local Supabase (Later Integration)

Prerequisites: Docker Desktop with Linux containers and a current Supabase CLI.
This is not required for Step 2's offline preview or isolated tests. For later
authorized integration, start the local stack from the repository root:

```powershell
npx supabase start
```

Do not reset an existing local or remote database. Initialization and seed execution
on a new disposable stack require a separate decision; inspect the target first.
Open the Studio and local mail viewer URLs printed by the CLI. Use the local mail
viewer when testing magic links later; the seed has no passwords.

Seed data: one group, 12 registered users (`player01@sentra.test` through
`player12@sentra.test`), one guest, three past completed matches, score/winner-only
results, recorded scorers, closed MVP ballots and settled/outstanding payments.
The first user owns the group; the second is an admin. The second match includes
a guest billed to the inviter and a rounding remainder. Seed notifications are
marked delivered so test fixtures cannot later generate real pushes.

The seed is repeatable and intentionally contains a predictable demo invite code.
**Never seed production.** Never apply `tests/bootstrap.sql` to Supabase: Supabase
already owns those roles and schemas.

## Hosted Supabase

The existing deployment is user-reported, not inspected by this implementation.
Do not replay, alter, rename, delete, or reset deployed migrations. Propose schema
changes first; after approval, add a new additive migration and review its dry run
before any authorized deployment. Keep database credentials in the CLI's credential
handling, not source files or chat. Never deploy test bootstrap or production seeds.

The migrations use database-side authorization and explicit execution grants, so
clients must call the documented RPCs for mutations.
See [docs/database.md](docs/database.md) for signatures, visibility and policy choices.

The last migration enables `pg_cron` when the extension is available and registers
`sentra-maintenance` once per minute. It generates due recurring occurrences,
queues reminders, locks RSVPs, closes due MVP polls, and rotates through badge
evaluations in batches of 50 users. The row/time checks work even if cron is late.
During a separately authorized remote check, inspect the real scheduler:

```sql
select jobname, schedule, command, active
from cron.job where jobname = 'sentra-maintenance';

select status, return_message, start_time, end_time
from cron.job_run_details
where jobid in (select jobid from cron.job where jobname = 'sentra-maintenance')
order by start_time desc limit 10;
```

A notice about unavailable `pg_cron` is expected in portable/native unit tests.
It is **not** an acceptable production scheduler setup: enable the extension in
Supabase and register the exact job above if the migration reported that notice.
The service-only `run_maintenance()` RPC is available for a future Edge worker.

## Keys and Integrations

- Swift and future browser code receive only the project URL and publishable key
  (or legacy anon key). A logged-in user's JWT selects their RLS identity.
- The secret/service-role key belongs only in server-side Edge Function secrets.
  Service role is a trusted backend identity and bypasses RLS; never ship it to iOS
  or a browser. Server RPCs are separately execution-restricted and role-checked.
- The `avatars` bucket is private, allows JPEG/PNG/WebP up to 5 MiB, and uses object
  names `<user UUID>/<filename>`. Owners write; shared-group members can read.
  Resolve short-lived signed URLs in the future avatar service; do not persist
  expiring signed URLs as profile data.
- Realtime publishes only `matches`, `rsvps`, `payments`, `mvp_results` and
  `player_badges`. Votes, response tokens, audit history and the outbox are excluded.
- Push delivery is **not active yet**. The outbox is transactional and worker-ready.
  Step 6 will add APNs delivery, device-token cleanup, retry monitoring and secrets
  for the APNs key, key ID, team ID and `com.sarantos.sentra` topic. No private key is
  needed for Step 2, and none belongs in this repository.
- Before exposing web RSVP in Step 7, implement token hashing, allowed origins,
  input bounds, request throttling and abuse protection in the Edge Function.
  The database RPC validates invite scope, revocation, expiry and capacity; it
  does not replace HTTP rate limiting or proof of possession of the raw token.

## Remaining Platform Setup

Before approving Step 2, run the Mac build/XCTest commands and the manual checklist
in [docs/PROGRESS.md](docs/PROGRESS.md): offline launch, Greek/English, light/dark,
Dynamic Type, VoiceOver, Reduce Motion and all placeholder routes. The asset
catalog's AppIcon slot has no artwork yet; release artwork remains a later gate.

Apple sign-in, magic-link redirects, Associated Domains/AASA, push entitlements,
EventKit permissions and actual live HTTP integration belong to later reviewed
steps. No website is present. **Step 3 must not start without user authorization.**