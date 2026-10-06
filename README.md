# Sentra

App Store display name: **Σέντρα**. Amateur football for friend groups.

## Review Gate: Step 1

This delivery contains the database only: six ordered PostgreSQL migrations, RLS,
transactional business functions, Supabase integration configuration, local seed
data, and database tests. No hosted resources were provisioned.

Swift, Edge Function TypeScript, and the web page are intentionally not generated
yet. Stop here for review before Step 2. Node dependencies are development-only
database test tools, not the application backend.

| Step | Scope | Status |
| --- | --- | --- |
| 1 | Schema, migrations, RLS, database rules and tests | Ready for review |
| 2 | Swift models and Supabase services | Awaiting approval |
| 3 | SwiftUI onboarding, Apple/email authentication, Greek String Catalog | Deferred |
| 4 | Groups, matches, RSVP and guest claim workflow | Deferred |
| 5 | Finish match, payments and MVP screens | Deferred |
| 6 | Recurrence UI, Edge workers, APNs and EventKit | Deferred |
| 7 | Web RSVP, Universal Links and AASA | Deferred |
| 8 | Player card, sharing and badge UI | Deferred |

## Files

```text
Sentra/
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
  docs/database.md
  .github/workflows/database.yml
  package.json
  package-lock.json
```

The migration files, not the test bootstrap, are the deployable database source.
The future iOS tree will be `ios/Sentra`, with Xcode setup instructions for Mac;
the future browser implementation will be `web`.

## Test Without Docker

Install Node.js 22 LTS or newer, open this folder in VS Code, and run:

```powershell
npm ci
npm test
```

The default suite creates an isolated in-memory PGlite PostgreSQL instance and
applies every migration. It tests actual SQL, constraints, triggers, transactions,
RLS, role grants, protected RPCs and seed data. It never connects to a hosted project.

Current local result: **21 passing checks; two native concurrency checks skipped**.
The embedded PostgreSQL process could not start on the authoring Windows host
(`spawn EPERM`). No system permissions or security settings were changed.

Run the native PostgreSQL 17 mode on a machine that permits the bundled binaries.
It also runs the two independent-session race tests, using a random localhost
port, a temporary database directory and a generated test-only password:

```powershell
$env:SENTRA_TEST_ENGINE = 'native'
npm test
Remove-Item Env:SENTRA_TEST_ENGINE
```

On macOS or Linux:

```sh
SENTRA_TEST_ENGINE=native npm test
```

Run as a normal user, not root. CI includes portable Windows and native Linux jobs;
those hosted jobs have not been executed in this delivery. Do not disable package
install scripts: the native runner needs its platform package's installation step.

The bootstrap emulates only the Supabase Auth role helpers, Auth tables, Storage
metadata tables and Realtime publication. It does **not** emulate Auth HTTP flows,
Storage uploads, Realtime delivery, or the cron scheduler. Those integrations and
the native race tests remain release gates on a real Supabase stack.

## Local Supabase

Prerequisites: Docker Desktop with Linux containers and a current Supabase CLI.
From this project's root:

```powershell
npx supabase start
npx supabase db reset
```

`db reset` destroys and rebuilds this project's **local development database**.
Do not use a linked/remote reset. The configured seed runs after the migrations.
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

Use a new, dedicated project with PostgreSQL 17. Keep database credentials in the
CLI's credential handling, not source files or chat. After reviewing the migrations:

```powershell
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push --dry-run
npx supabase db push
```

Do not pass `--include-seed`. The migrations use database-side authorization and
explicit execution grants, so clients must call the documented RPCs for mutations.
See [docs/database.md](docs/database.md) for signatures, visibility and policy choices.

The last migration enables `pg_cron` when the extension is available and registers
`sentra-maintenance` once per minute. It generates due recurring occurrences,
queues reminders, locks RSVPs, closes due MVP polls, and rotates through badge
evaluations in batches of 50 users. The row/time checks work even if cron is late.
Inspect the real scheduler after deployment:

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

- Future Swift/browser code receives only the project URL and publishable key
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
  for the APNs key, key ID, team ID and `com.<me>.sentra` topic. No private key is
  needed for Step 1, and none belongs in this repository.
- Before exposing web RSVP in Step 7, implement token hashing, allowed origins,
  input bounds, request throttling and abuse protection in the Edge Function.
  The database RPC validates invite scope, revocation, expiry and capacity; it
  does not replace HTTP rate limiting or proof of possession of the raw token.

## Remaining Platform Setup

After this review, later steps will supply the Xcode-ready Swift files and optional
XcodeGen configuration, the official `supabase-swift` SPM dependency, Apple sign-in
configuration, email redirect handling, Associated Domains/AASA, push entitlements,
Greek calendar permission text, just-in-time permissions, and device testing.
There is no Xcode project to build or website to run at this stage.