# Sentra — Agent Guide

Sentra (App Store name **Σέντρα**) organises amateur football among friend groups:
RSVP, guests, waitlists, recurring matches, optional results and cost splitting,
anonymous MVP voting, statistics, an original player card, badges and cosmetic
card designs. The player card is the main growth feature.

This file is the entry point for anyone (human or agent) working in the repo.
Product rules live in [.github/copilot-instructions.md](.github/copilot-instructions.md);
its sections on product behaviour (§4), design (§5) and the step plan (§7) still
apply. Its SwiftUI stack and file-layout sections (§3, §6) are superseded by this
file.

## What the owner is trying to achieve

Decisions confirmed by the owner on 2026-10-11:

- **React Native with Expo is the only client.** The SwiftUI app is retired and
  kept read-only in `legacy/ios/` as a reference for behaviour and visuals.
- **iOS and Android are both first-class.** Build and check every feature on both.
  An iOS-only API needs an Android equivalent, or an explicit note that it is missing.
- **The app lives in `mobile/`.** The repo root stays a workspace: app, database,
  database tests, legacy code and docs side by side.
- **All existing working rules still apply** (see "Working rules" below): step by
  step, stop for review after each step, nothing from Step 3 onward without
  authorisation, deployed migrations are immutable, no auto-commits.

## Current status

| Step | Scope | Status |
| --- | --- | --- |
| 1 | Schema, migrations, RLS, RPCs, seed, SQL tests | Done; deployment reported by the owner |
| 2 | Models, services, design system, offline dashboard, player card | Ported from Swift to Expo; **awaiting owner review** |
| 3 | Onboarding, Apple and email magic-link authentication | Not authorised |
| 4 | Groups, matches, RSVP, guests | Not authorised |
| 5 | Finish match, result, cost split, MVP voting | Not authorised |
| 6 | Recurring matches, push, calendar | Not authorised |
| 7 | Web RSVP, universal links | Not authorised |
| 8 | Rating, player card workflows, badges, sharing | Not authorised |
| 9 | Cosmetic purchases, analytics | Not authorised |

The app launches into an **offline preview** backed by mock services. It reads no
credentials and constructs no network client. There is no sign-in, no RSVP
mutation and no real navigation destination yet: all 14 routes open one shared
"not available yet" placeholder.

[docs/PROGRESS.md](docs/PROGRESS.md) is the delivery ledger. It still describes the
Swift delivery in detail; add React Native entries there at the end of each step.

## Repository layout

```text
AGENTS.md                 this file
mobile/                   the Expo app (the only client)
supabase/                 config, six deployed migrations (immutable), seed
tests/                    Node tests for the database and the legacy Swift contract
legacy/ios/               retired SwiftUI app, read-only reference
docs/                     DESIGN.md, PROGRESS.md, database.md, schema-to-swift.md, mockups
.github/copilot-instructions.md   product rules and step plan
package.json              root tooling for the database tests only (not the app)
```

### `mobile/`

```text
app.json                  Expo config: name, bundle IDs, scheme, plugins, permission text
.env.example              public Supabase settings; copy to .env.local (ignored)
locales/{el,en}.json      localised OS permission strings
assets/images/            hero image and four card sample photos
__tests__/                Jest tests and the Supabase row fixture
src/
  app/                    Expo Router routes ONLY (every file is a screen)
    _layout.tsx           providers + themed stack; creates the preview environment
    index.tsx             the Step 2 dashboard
    route/[name].tsx      shared placeholder for all 14 app routes
    dev/cards.tsx         card gallery, development builds only
    +native-intent.ts     sends every incoming link through DeepLinkHandler
  environment/            AppEnvironment (service container), AppRoute, DeepLinkHandler
  core/
    configuration/        AppConfiguration: validates public settings, redacts itself
    supabase/             the single place a Supabase client is created
    i18n/                 el.json, en.json, translate(), useTranslation()
    theme/                colour/typography/spacing tokens, ThemeProvider, labels, a11y hooks
    utilities/            SentraJSON (codecs), AppError, DateFormatters, Logger
    components/           design system: buttons, primitives, rows, state views, menu
      PlayerCard/         card renderer, shield shapes, tier styles, crop maths, motion, editor
  models/                 one codec + type per table, view and enum
  services/
    protocols/            14 service interfaces and the request payload codecs
    live/                 Supabase adapters, error mapping, explicit "unavailable" services
    mock/                 deterministic dataset factory and mock services
    local/                on-device photo preparation
  features/preview/       dashboard screen, its loader, the card gallery
```

Import app code through the `@/` alias (`@/core/...`, `@/models`), which maps to
`mobile/src/`.

## Architecture

**Layers, top to bottom:** routes (`src/app`) → features → core components →
services → models → `SentraJSON`. Lower layers never import higher ones.

**Environment and services.** `AppEnvironment` holds a `ServiceContainer` of 14
service interfaces. `previewEnvironment()` wires every interface to `MockServices`;
`liveEnvironment()` wires Auth, Profile, Group, Match and read-only RSVP to
Supabase and the other nine to `UnavailableServices`, which always throws
`AppError('unavailable')`. Screens get services from `useEnvironment()` and never
import a concrete service or the Supabase client. Nothing calls
`liveEnvironment()` yet.

**Wire models.** Supabase rows are snake_case JSON. Each model is declared once as
a codec in `src/models`, mapping camelCase properties to exact column names; the
TypeScript type is inferred from the codec. Decoding is strict: a missing required
column, an unknown enum value or a timestamp without a timezone throws.

- Timestamps (`timestamptz`) decode to `Date`. Calendar-only `date`/`time` columns
  stay strings; never convert them to instants.
- Money and other `numeric` columns decode to `Big` (big.js), never plain floats.
- `bigint` decodes to `number` and **rejects** values above 2^53 rather than
  rounding them. `waitlist_order` is an opaque ticket; show `position_in_waitlist`.
- Request payloads are codecs too. Optional RPC parameters are omitted so the
  database applies its defaults; `ProfileUpdate` sends a null avatar explicitly.

**Errors.** Live services map every Supabase failure to one of nine `AppError`
codes in `services/live/SupabaseRequest.ts`. Raw database messages never reach the
interface; each code has a localised `error.*` string.

**Database rules.** All game writes go through authorised RPCs. Only allow-listed
own-profile columns are written directly. Business rules are enforced in the
database, not re-implemented in the client. Individual MVP ballots are never
queried.

**Text.** No hard-coded interface strings. Add keys to **both**
`core/i18n/el.json` and `en.json` (a test fails if they differ) and use
`t('key', ...values)` with `{0}`, `{1}` placeholders. Greek is the default
language; names and other backend data are shown verbatim, not translated.

**Theme.** Read colours from `useTheme()`; use the `Typography`, `Spacing`,
`Radius`, `Layout` tokens. Light and dark are both supported; `ThemeOverride`
forces a scheme for a subtree. Status is always carried by an icon and a label as
well as colour. Minimum touch target 44 pt. Use `useAccessibilityTextSize()` to
stack layouts at large text sizes and `useReduceMotion()` before animating. Icons
come from the semantic names in `components/Icon.tsx`.

**Player card.** Drawn with `react-native-svg` (shield outline, materials, masked
portrait, photo grading) with React Native text on top. Appearance is chosen by
`playerCardAppearance()`: provisional (< 3 appearances) first, then weekly MVP,
then the tier for the overall rating. Card materials do not follow the app's
light/dark mode. `PhotoCrop.ts` is pure crop maths shared by renderer and editor.
`CardMotion.ts` shares one device-motion subscription across visible cards.

## Dependencies

App runtime (`mobile/package.json`; always add packages with `npx expo install`):

| Package | Used for |
| --- | --- |
| `expo` ~57, `react-native` 0.86, `react` 19.2 | Platform |
| `expo-router` (+ `expo-linking`, `expo-constants`, `react-native-screens`, `react-native-safe-area-context`) | File-based navigation |
| `@supabase/supabase-js` + `@react-native-async-storage/async-storage` | Backend client and session storage |
| `big.js` | Exact decimals for money |
| `react-native-svg` | Player card, shield shapes, stadium backdrop |
| `react-native-reanimated` + `react-native-worklets` | Card tilt and shine |
| `react-native-gesture-handler` | Card drag, photo pan and pinch |
| `expo-sensors` | Device-motion tilt |
| `expo-image-picker`, `expo-image-manipulator`, `expo-asset` | Choosing and preparing card photos |
| `@react-native-community/slider` | Photo editor sliders |
| `@expo/vector-icons` + `expo-font` | Icons |
| `expo-localization` | Device language |
| `expo-status-bar` | Status bar style |

Development: `typescript` ~6, `jest` 29 with `jest-expo` and
`@react-native/jest-preset` (pinned to the React Native version), `@types/*`.

Root `package.json` is separate tooling for the database tests (`pglite`,
`embedded-postgres`, `pg`, `yaml`). Do not add app dependencies there.

Every library above ships in Expo Go, so no native build is required today.

## How to

Requirements: Node 22 or newer, Xcode with an iOS simulator for iOS, Android
Studio with an emulator for Android. All app commands run from `mobile/`.

```sh
cd mobile
npm install --legacy-peer-deps   # first time only

npx expo start                   # dev server; press i (iOS) or a (Android)
npx expo start --ios             # open straight in the booted iOS simulator
npx expo start --android         # open in the running Android emulator
npx expo start --clear           # same, discarding the Metro cache

npm test                         # Jest: 42 tests
npx jest __tests__/playerCard.test.ts      # one file
npx jest -t "waitlist"                      # tests matching a name
npm run typecheck                # tsc --noEmit
npx expo-doctor                  # dependency and config health check
npx expo install --fix           # realign package versions with the SDK
```

Run `npm test`, `npm run typecheck` and `npx expo-doctor` before calling work done.

- **First simulator launch** downloads and installs Expo Go; this can take a few
  minutes. Later launches are quick. On a physical phone, install Expo Go and
  scan the QR code from `npx expo start`.
- **Card gallery:** in a development session open the ⋯ menu on the dashboard and
  choose "Κάρτες παικτών" (`/dev/cards`). It shows all six card appearances, the
  sample photos, three sizes, the stadium backdrop and the photo editor.
- **Language:** the app follows the device language (Greek unless English is
  preferred). **Text size / Reduce Motion:** change them in the simulator's
  Settings → Accessibility to check the stacked layouts and static card.
- **Live configuration (not used yet):** copy `.env.example` to `.env.local` and
  set the public Supabase URL and anon/publishable key. `AppConfiguration`
  rejects placeholders, non-HTTPS hosts and service-role keys.
- **Native build** (needed once a library outside Expo Go is added):
  `npx expo run:ios` or `npx expo run:android`. This generates `mobile/ios` and
  `mobile/android`, which are ignored; never edit them by hand. Configure native
  behaviour in `app.json`. Local iOS builds need CocoaPods, which is not
  installed on the current machine.

Database tests run from the repo root:

```sh
npm ci
npm test                         # SQL constraints, RLS, RPCs, seed (in-memory Postgres)
npm run test:ios-contract        # checks the legacy Swift models against the schema
```

### Adding things

- **A table/view model:** read the migration, add a codec in `src/models`, add a
  row to `__tests__/fixtures/supabase-rows.json` and assert it in
  `modelDecoding.test.ts`. Never guess a column.
- **A service method:** add it to the interface in `ServiceProtocols.ts`, then to
  `MockServices` and to the live adapter or `UnavailableServices`.
- **A screen:** add a file under `src/app`, keep its logic in `src/features/<name>`,
  and resolve its `AppRoute` in `routeHref()`.
- **A string:** add the key to `el.json` and `en.json`.

## Working rules

1. Work one step at a time. At the end of a step update `docs/PROGRESS.md` and
   **stop for the owner's review**. Do not start a later step without authorisation.
2. Deployed migrations are the source of truth. Never edit, rename, delete or
   reset them. Propose schema changes first; after approval add a new additive
   migration. Never claim to have inspected the remote database unless you did.
3. Never put a service-role or secret key in the app, in `.env.example` or in logs.
4. Do not commit, push or change branches unless asked.
5. Do not build features against tables or RPCs that do not exist. Rating history,
   card designs, rating weights, crop fields and analytics have no deployed contract.
6. Do not edit `legacy/ios/`. Read it when you need the original behaviour.
7. Expo changes between SDK releases. Before using an Expo or React Native API,
   check the installed package's types or the versioned docs at
   `https://docs.expo.dev/versions/v57.0.0/` instead of relying on memory.
8. Never claim something works on a device unless it was actually run there. Say
   which platform was checked.
9. The player card must stay an original design: no EA FC/FIFA frames, fonts,
   logos, or club and league marks. Purchases never affect rating or statistics.

## Known gaps in the port

- **No screen has been seen running yet.** Typecheck, 42 Jest tests, `expo-doctor`
  and production iOS and Android bundles (`npx expo export`) all pass, but the
  first simulator launch stopped at iOS's one-time "Open in Expo Go?" prompt.
  Treat every visual detail, especially the SVG player card, as unreviewed until
  someone has looked at it on iOS and Android.
- **Face detection is not implemented.** The Swift app used Apple's Vision
  framework to centre the crop on a face. No equivalent ships in Expo Go, so
  `preparePhoto()` takes an injectable `FaceDetector` that currently finds
  nothing and photos are centre-cropped. A real detector needs a native module
  and a development build, and must cover Android as well.
- **Device-motion tilt is unverified on hardware.** Simulators have no motion
  sensor. Axis signs may need flipping per platform once tested on real phones.
- **Android has not been run.** The code avoids iOS-only APIs, but the card's
  drop shadow uses iOS shadow properties and has no Android equivalent yet.
- **Photo grading** uses an SVG colour-matrix filter and a plain tint instead of
  SwiftUI's soft-light blend; confirm it renders on both platforms.
- **Session storage** would be AsyncStorage (unencrypted) when the live
  environment is first used; the Swift client used the Keychain. Decide on
  encrypted storage before Step 3.
- **Large `bigint` values** above 2^53 are rejected by design (see "Wire models").
- **`tests/ios-contract.test.mjs`** still validates the retired Swift sources. A
  TypeScript equivalent that checks `src/models` against the migrations is not
  written yet.
- **App icon and hero image** are placeholders; the hero is a 134×136 crop.

## Where the Swift code went

| Swift (`legacy/ios/Sentra/`) | React Native (`mobile/src/`) |
| --- | --- |
| `App/AppEnvironment`, `AppRoute`, `DeepLinkHandler` | `environment/` |
| `App/AppRouter`, `SentraApp` | `app/_layout.tsx` (Expo Router owns the stack) |
| `Core/Configuration`, `Core/Supabase` | `core/configuration/`, `core/supabase/` |
| `Core/Theme/SentraTheme` | `core/theme/SentraTheme.tsx`, `labels.ts` |
| `Core/Utilities/*` | `core/utilities/*` |
| `Core/Components/*` | `core/components/*` |
| `Core/Components/PlayerCard/*` | `core/components/PlayerCard/*` |
| `PlayerCardPreviews` (Xcode previews) | `features/preview/CardGallery.tsx` |
| `Models/*` | `models/*` |
| `Services/Protocols`, `Live`, `Mock`, `Local` | `services/protocols`, `live`, `mock`, `local` |
| `Features/Preview/*` | `features/preview/*` |
| `Resources/Localizable.xcstrings` | `core/i18n/el.json`, `en.json` |
| `Resources/Info.plist`, `InfoPlist.xcstrings`, `Config/*.xcconfig` | `app.json`, `locales/`, `.env.example` |
| `SentraTests/*` | `mobile/__tests__/*` |
