# Sentra Progress

Last updated: 2026-10-09. Current boundary: **Step 2 plus the authorized card-only redesign**.

## Step Ledger

| Step | Scope | Status |
| --- | --- | --- |
| 1 | Schema, migrations, constraints, RLS, RPCs, seed, SQL tests | DONE; deployment and seed execution reported by user |
| 2 | Swift models, services, design system, offline dashboard, tests | Card redesign implemented; Mac validation, crop-schema proposal and user review pending |
| 3 | Onboarding, Apple/email authentication | Not started; requires review |
| 4 | Groups, matches, RSVP, guests and verified claim | Not started |
| 5 | Finish match, results, cost split, MVP voting | Not started |
| 6 | Recurrence, push, EventKit | Not started |
| 7 | Web RSVP, Universal Links, card share pages | Not started |
| 8 | Rating, player card, badges, sharing | Workflows not started; isolated renderer/editor prototype authorized within Step 2 review |
| 9 | Cosmetic purchases and analytics | Not started |

## Deployment and Repository Facts

- User reports six migrations deployed via `supabase db push`, EU West / Ireland,
  and seed executed. No remote database inspection has been performed in Step 2.
- Existing migrations are immutable. Step 2 did not edit/add migrations, reset
  databases, deploy functions, or contact the cloud with credentials.
- Initial working tree was clean. No existing `ios/`, Step 2 files, or Copilot
  instruction file were present. No `supabase/functions/` implementation exists.
- The old README's Step 1-only status and nonexistent CI reference were corrected.
- Dependency artifacts were already tracked under `node_modules`. npm installation
  changed platform artifacts; those install-only changes were restored. The new
  ignore rule prevents new untracked dependencies but cannot untrack existing ones.
  A repository cleanup is a separate review item, not part of Step 2.

## Step 2 Work

- [x] Read database table definitions, all six migrations, existing DB contract,
  README and package/test entry point.
- [x] Preserve product/stack/conventions in
  [copilot-instructions.md](../.github/copilot-instructions.md).
- [x] Complete seed, local config and test inspection. No existing CI workflow was
  present despite the old README's reference to one.
- [x] Publish full mapping of 21 public tables, six enums, five views and 35 RPCs in
  [schema-to-swift.md](schema-to-swift.md), including nullability and discrepancies.
- [x] Add XcodeGen project, ignored local configuration, safe Supabase provider.
- [x] Add exact deployed models, 14 service protocols, five live adapters, mocks.
- [x] Add injectable app environment, 14 placeholder routes, localized dashboard.
- [x] Add design tokens, all 16 requested components, and four preview card tiers.
- [x] Add capacity, decoding, Decimal, deterministic-mock, request/configuration,
  navigation and dashboard XCTest cases. Written, not run on this Windows host.
- [x] Run available checks, document Mac gates, update README and review checklist.

## Step 2 Design Alignment

The user supplied screens 1-15 as the visual reference. The written specification
still wins; this follow-up changes design only and does not authorize Step 3.
The reference and all future screen ownership are recorded in [DESIGN.md](DESIGN.md).
This section records the October 7 pass; its old card appearance is superseded below.

- [x] Preserve the original [sentra-flow.png](mockups/sentra-flow.png) byte-for-byte:
  1152x768, with a verified SHA-256 checksum. No replacement image was substituted.
- [x] Extract palette, native type scale, spacing, radii, shadows, buttons, chips,
  list rows, progress and segmented tabs; document accessibility adjustments and
  a before/after comparison in the design contract.
- [x] Align theme, buttons, chips, match/player rows and card shells. Keep all 16
  original components and add reusable `SentraSegmentedTabs` in the existing
  primitives file; no new feature module or service was created.
- [x] Add the unframed Welcome-style hero, stacked RSVP actions, segmented roster,
  numbered progress header, dark MVP sample and four dark metallic card shells to
  [StepTwoDashboardPreview.swift](../ios/Sentra/Features/Preview/StepTwoDashboardPreview.swift).
- [x] Preserve corrected Greek position/stat labels and original card geometry.
  New labels are in the Greek/English catalog; no mockup text or dates are embedded
  in views. Live preview dates use an injected current clock, while test fixtures
  keep the fixed default clock.
- [x] Keep sample selection/filtering local. No authentication, RSVP mutation,
  completion, cost, voting, permissions, rating or purchase workflow was added.
- [x] Verify the local hero crop and original image, rerun focused/source and
  existing isolated database tests, and preserve all protected backend files.
- [ ] Run Mac build/XCTest and visual/accessibility review. The photo crop is only
  134x136; replace it with licensed high-resolution artwork before Step 3 approval.

Actual screen ownership remains **1-6: Step 3; 7-9: Step 4; 10-13: Step 5;
14-15: Step 8**. Screen 11 must eventually use one exclusive result mode with only
its selected fields; no result form was implemented in this pass.

## Card-Only Redesign: Option 1, Θυρεός

The October 9 request authorizes the card renderer and related photo/motion styles,
local editor, samples/tests and documentation only. No other component, screen,
app route, model mapping, shared theme, existing service or dependency was changed.

- [x] Archive the original [card-options reference](mockups/sentra-card-options.png)
  byte-for-byte and document Option 1 as the card-specific visual contract.
- [x] Add original `SentraCardShape` / `SentraPortraitFrame`, double metal borders,
  material grain/marble, lower portrait fade, vignette and football/laurel crest.
- [x] Implement `CardTierStyle` and `PlayerCardView`: four free tiers, weekly MVP,
  provisional precedence/no OVR, three sizes, six/four stats, up to three badges,
  group-initials shield, natural photo grading and Greek/English labels.
- [x] Keep `PlayerCardShell` as a delegate so dashboard/callers stay untouched.
  Unknown ΑΞΙ remains unavailable; no deployed reliability field is invented.
- [x] Add normalized, bounded crop math and actor-based Vision/ImageIO preparation,
  including upright image handling and metadata-free prepared JPEGs.
- [x] Add local `PhotoAdjustView`: system photo selection, pan/pinch, three sliders,
  reset through Vision, live card, disabled/loading/error states and cancel-safe
  draft handling. **Save updates memory only; it does not save a profile remotely.**
- [x] Add shared on-demand CoreMotion, spring drag return, preview light sweep and
  Reduce Motion fallback. Localize the OS motion purpose; no broad library, push
  or onboarding permission workflow was introduced.
- [x] Bundle four licensed stock-photo fixtures and provide nine previews covering
  six appearances, four photos/no photo, sizes, both color schemes, local editor,
  accessibility and original stadium-night share background. No export workflow.
- [x] Add 10 card/crop XCTest cases, including face math, no-face/largest-face,
  pan/zoom bounds, invalid input, size independence, tier/provisional rules and
  orientation/metadata handling. **Written, not executed on Windows.**
- [x] Extend portable source checks, including texture-plus-shine contrast. Weekly
  shine at 30% failed the worst-overlap check; 18% passed and is the new limit.
- [x] Document the missing crop fields and proposed atomic own-profile contract in
  [DESIGN.md](DESIGN.md#crop-persistence-proposal-not-applied). No migration applied
  or created, and no Profile/wire field or grant was silently added.
- [ ] Approve or revise the crop-persistence proposal before any new migration.
- [ ] Complete Mac build/XCTest, actual preview screenshots, Vision/editor behavior,
  VoiceOver/Dynamic Type and physical-device motion review before accepting visuals.

## Delivery Inventory

The table below records the initial 55-file iOS foundation. Design alignment adds
two local image-set files; the card-only pass adds 19 files, bringing the current
iOS inventory to **76 files**. The initial
tracked source changes were [README.md](../README.md), [package.json](../package.json)
and [package-lock.json](../package-lock.json); the design pass adds no dependencies.

Design additions are [DESIGN.md](DESIGN.md), the original reference PNG, and the
[WelcomePitch image set](../ios/Sentra/Resources/Assets.xcassets/WelcomePitch.imageset/Contents.json).
Design edits are confined to the theme, five component files, dashboard, app clock
injection, localization, background asset, source-contract tests, README and ledger.
The detailed component comparison is in the design contract. Existing user edits
to this ledger were read before updating it.
The October 9 changes are confined to the shell/card directory, the local photo
service, card resources/purpose text, focused tests, reference image and these two
design/progress documents. The older dashboard/theme alignment was not reopened.

| Area | Files and behavior |
| --- | --- |
| Persistent context | [copilot-instructions.md](../.github/copilot-instructions.md), this ledger, [schema-to-swift.md](schema-to-swift.md) |
| Project and configuration | [.gitignore](../.gitignore), [project.yml](../ios/project.yml), [Base.xcconfig](../ios/Config/Base.xcconfig), [Config.xcconfig.example](../ios/Config/Config.xcconfig.example); iOS 17 app/tests, automatic signing, exact Supabase 2.20.0 |
| App foundation | [SentraApp.swift](../ios/Sentra/App/SentraApp.swift), [AppEnvironment.swift](../ios/Sentra/App/AppEnvironment.swift), [AppRouter.swift](../ios/Sentra/App/AppRouter.swift), [AppRoute.swift](../ios/Sentra/App/AppRoute.swift), [DeepLinkHandler.swift](../ios/Sentra/App/DeepLinkHandler.swift); offline launch, injection, 14 placeholders, no deep-link processing |
| Core | [AppConfiguration.swift](../ios/Sentra/Core/Configuration/AppConfiguration.swift), [SupabaseProvider.swift](../ios/Sentra/Core/Supabase/SupabaseProvider.swift), [SentraJSON.swift](../ios/Sentra/Core/Utilities/SentraJSON.swift), [DateFormatters.swift](../ios/Sentra/Core/Utilities/DateFormatters.swift), [AppError.swift](../ios/Sentra/Core/Utilities/AppError.swift), [Logger.swift](../ios/Sentra/Core/Utilities/Logger.swift); validation, one client, exact decoding, localization and redacted diagnostics |
| Models | Nine files cover all 21 public tables, six enums and five views; [PreviewCardModels.swift](../ios/Sentra/Models/PreviewCardModels.swift) separately holds local card/history examples. Full field inventory is in the schema map. |
| Contracts | [ServiceProtocols.swift](../ios/Sentra/Services/Protocols/ServiceProtocols.swift), [ServiceRequests.swift](../ios/Sentra/Services/Protocols/ServiceRequests.swift); 14 protocols and precise deployed CRUD payloads |
| Live adapters | Auth, Profile, Group, Match, RSVP, [SupabaseRequest.swift](../ios/Sentra/Services/Live/SupabaseRequest.swift), [UnavailableServices.swift](../ios/Sentra/Services/Live/UnavailableServices.swift); no later workflows or privileged queries |
| Offline fixtures | [MockDataFactory.swift](../ios/Sentra/Services/Mock/MockDataFactory.swift), [MockServices.swift](../ios/Sentra/Services/Mock/MockServices.swift); stable UUIDs/clock, 12 players, guest, seven matches, stats/history/MVP/badges, four tiers, deterministic errors |
| Design system | [SentraTheme.swift](../ios/Sentra/Core/Theme/SentraTheme.swift), six component files listed below; adaptive colors, semantic typography, spacing, radius, shadow, motion and target tokens |
| Card renderer and materials | [PlayerCardView.swift](../ios/Sentra/Core/Components/PlayerCard/PlayerCardView.swift), [CardTierStyle.swift](../ios/Sentra/Core/Components/PlayerCard/CardTierStyle.swift), [SentraCardShape.swift](../ios/Sentra/Core/Components/PlayerCard/SentraCardShape.swift), [CardPortraitView.swift](../ios/Sentra/Core/Components/PlayerCard/CardPortraitView.swift), [CardMotion.swift](../ios/Sentra/Core/Components/PlayerCard/CardMotion.swift); original shield, six appearances, localized stats, three sizes, optional motion |
| Local crop and samples | [PhotoCrop.swift](../ios/Sentra/Core/Components/PlayerCard/PhotoCrop.swift), [PhotoCropService.swift](../ios/Sentra/Services/Local/PhotoCropService.swift), [PhotoAdjustView.swift](../ios/Sentra/Core/Components/PlayerCard/PhotoAdjustView.swift), [PlayerCardPreviews.swift](../ios/Sentra/Core/Components/PlayerCard/PlayerCardPreviews.swift); no profile writes, uploads or feature routing |
| Dashboard | [StepTwoDashboardViewModel.swift](../ios/Sentra/Features/Preview/StepTwoDashboardViewModel.swift), [StepTwoDashboardPreview.swift](../ios/Sentra/Features/Preview/StepTwoDashboardPreview.swift); injectable MVVM, appearance/status/state controls, original cards and placeholder navigation |
| Resources | [Localizable.xcstrings](../ios/Sentra/Resources/Localizable.xcstrings), [Info.plist](../ios/Sentra/Resources/Info.plist), [InfoPlist.xcstrings](../ios/Sentra/Resources/InfoPlist.xcstrings), four card JPEG data sets, existing hero/background and empty app-icon slot; sources/treatments in DESIGN |
| Swift tests | [ConfigurationTests.swift](../ios/SentraTests/ConfigurationTests.swift), [ModelDecodingTests.swift](../ios/SentraTests/ModelDecodingTests.swift), [MockServiceTests.swift](../ios/SentraTests/MockServiceTests.swift), [ServiceRequestTests.swift](../ios/SentraTests/ServiceRequestTests.swift), [AppFoundationTests.swift](../ios/SentraTests/AppFoundationTests.swift), [PlayerCardTests.swift](../ios/SentraTests/PlayerCardTests.swift), [supabase-rows.json](../ios/SentraTests/Fixtures/supabase-rows.json); 36 cases written, not executed |
| Portable validation | [ios-contract.test.mjs](../tests/ios-contract.test.mjs), npm scripts and development-only YAML parser; PostgreSQL/source/resource checks, not Swift compilation |

The 16 requested components are implemented in these grouping files:

- [SentraButtons.swift](../ios/Sentra/Core/Components/SentraButtons.swift):
  `SentraPrimaryButton`, `SentraSecondaryButton`, `SentraDestructiveButton`, `RSVPButton`.
- [SentraPrimitives.swift](../ios/Sentra/Core/Components/SentraPrimitives.swift):
  `SentraCard`, `SentraSectionHeader`, `SentraChip`, `SentraStatusBadge`,
  `SentraAvatar`, `SentraProgressHeader`.
- [PlayerRow.swift](../ios/Sentra/Core/Components/PlayerRow.swift): `PlayerRow`.
- [MatchSummaryCard.swift](../ios/Sentra/Core/Components/MatchSummaryCard.swift): `MatchSummaryCard`.
- [StateViews.swift](../ios/Sentra/Core/Components/StateViews.swift):
  `SentraEmptyState`, `LoadingOverlay`, `ErrorStateView`.
- [PlayerCardShell.swift](../ios/Sentra/Core/Components/PlayerCardShell.swift): compatibility
  delegate to the new `PlayerCardView`; existing caller APIs remain intact.

## Decisions and Known Gaps

- The deployed schema, not product shorthand, determines wire types. Match formats
  are catalog rows, not a PostgreSQL enum; capacity is derived from team size.
- All game writes require RPCs. Only allowlisted own-profile columns are directly
  writable. Step 2 live RSVP is fetch-only; no RSVP workflow or rule duplication.
- Individual MVP ballots/voter snapshots have no client read grant. A wire model
  does not imply permission to fetch it; clients use voting state and closed results.
- `badge_definitions.rule_params` differs from the specification's `params` name.
- No deployed `rating_history`, rating weights/title configuration, `card_designs`,
  `user_card_designs`, `app_config`, or analytics KPI view. `RatingHistoryEntry` and
  `CardDesign` are explicitly preview-only models, never fabricated DB mappings.
  Proposed additive schema work belongs to Steps 8/9 and needs prior approval.
- Crop fields `photo_focus_x`, `photo_focus_y`, `photo_zoom` are also absent from
  deployed profiles. The new `CardPhoto` is local, not a Profile DTO. The proposal
  must address bounds/nulls, image ownership, atomic photo/crop replacement and
  the currently granted direct avatar URL update path before implementation.
- Reliability is not exposed by `PlayerStats`. The six-stat renderer accepts an
  optional value; live callers must show unavailable until a reviewed source exists.
- Guest claim columns exist but a verified claim RPC is deliberately deferred.
- Calendar-only dates/times stay local strings; timestamptz maps to `Date`.
  Monetary and other exact numeric fields map to `Decimal`, not `Double`.
- Match generated capacity is modeled nonoptional: its nonnull team-size expression
  always produces a value despite PostgreSQL's nullable generated-column metadata.
- SQL seed remains at three completed matches. Separate mocks have six completed
  matches plus one upcoming 5x5: nine registered yes responses and one yes guest
  fill ten seats; the remaining registered players are maybe, no and waitlisted.
- Fixture time/UUIDs are stable. Preview totals and history are illustrative,
  not a Swift implementation of the future configurable rating engine.
- All 14 service protocols are injected. Later live services and mock mutation
  commands explicitly throw unavailable. No authentication, push-permission, RSVP,
  completion, voting, payment, recurrence or purchase workflow was implemented.
- Shared SPM dependency resolution has not run. The exact Supabase pin is present;
  its generated transitive lockfile must be resolved, reviewed and tracked on Mac.
- The app-icon catalog slot is intentionally empty. Original release artwork is
  still required. No third-party card frame/branding or runtime remote preview
  asset is used. Four bundled stock photos are documented crop fixtures, not the
  identities in the mock data; release/marketing use needs suitability review.
- This authoring machine is Windows. Xcode/iOS simulator execution is unavailable;
  no claim of an iOS build or visual simulator review is permitted without evidence.

## Validation

- Earlier Step 2 `npm.cmd ci`: clean install succeeded; zero reported dependency vulnerabilities.
  The development-only YAML parser is pinned to 2.9.1. An earlier candidate was
  replaced immediately after its advisory was reported; no forced upgrades used.
- `npm.cmd run test:ios-contract`: **18 passed, zero failed, zero skipped**. Checks
  cover actual PostgreSQL columns/types/nullability, all public mappings and enums,
  XcodeGen configuration, deployed CRUD parameter sets, write allowlists, stable
  fixture source, Greek/English keys and placeholders, required components, one
  client constructor, preview-only features, JSON resources, 46 solid-color contrast
  pairs and worst-case hero text contrast. Added checks cover the requested design
  samples, original PNG checksum, offline photo metadata and corrected Greek labels.
  These inspect source; they do not execute or render Swift.
- The four new source checks cover 108 material/texture/shine combinations, card
  rules/layout guards, local crop/motion boundaries, exact photo/reference checksums
  and nine preview declarations. They cannot establish native rendering correctness.
- `npm.cmd run test:all`: **39 passed, zero failed, two skipped** out of 41 tests.
  This includes 21 existing database checks and the 18 source-contract checks.
  Native independent-session RSVP/MVP race tests were skipped, not verified by
  PGlite. No native PostgreSQL process was attempted during Step 2.
- Plist XML and Git ignore assertions passed. The local credential config is
  ignored; its example and the future shared SPM lockfile remain trackable.
- Editor diagnostics surfaced no errors. This is not evidence of Swift compilation.
- `git diff --exit-code -- supabase tests/bootstrap.sql tests/database.test.mjs`
  passed. Migrations, seed, Supabase settings and existing database tests are unchanged.
- `git diff --exit-code -- node_modules` passed after restoring install-only
  platform artifact changes. YAML 2.9.1 still imports and parses correctly.
- README local links, code fences, current result totals and Mac command presence
  were validated after editing.
- Original reference and derived photo were opened as images. The crop contains
  no UI text, dates, phone chrome or card frame. Actual SwiftUI screenshots are
  still a Mac gate; viewing source artwork is not a simulator review.
- Card fixtures were opened as images and decoded locally for size validation:
  three 1000x1500 JPEGs and one 1000x667 JPEG, 1,065,127 bytes total. The low-light
  fixture is an explicitly documented 45% RGB derivative. The new reference PNG's
  SHA-256 matches the attachment. No mockup portrait/frame was used as an app asset.
- The card pass's protected-file diff also covers App, Models, shared Theme,
  Features/dashboard, existing Live/Mock/Protocols services, other components,
  project/config, README, manifests and tracked dependencies; all are unchanged.
- The design pass performed no installs, database resets, remote inspections,
  migrations, deployments, commits or branch changes.
- No `node` was initially on PATH. A checksum-verified Node 22.20.0 portable runtime
  was unpacked under the Windows temporary directory; no system settings changed.
- XcodeGen generation, Swift compilation, XCTest, simulator layout, VoiceOver and
  actual Supabase HTTP integration remain unverified here.
- Card-specific native gates also include Vision face results, EXIF orientation
  and GPS-removal XCTest, system photo picker, pan/pinch/slider parity, material
  screenshots, transition/Reduce Motion behavior and actual motion sensor lifecycle.

## Mac Build and XCTest Gate

Requirements: Xcode 15+ selected as the command-line toolchain, Swift 5.9+, an
installed iPhone simulator with iOS 17+, and XcodeGen 2.42+. From the repository
root, run the following. The local config is optional for preview; `cp -n` will
not overwrite an existing file. No service-role key belongs there.

```sh
brew install xcodegen
cd ios
cp -n Config/Config.xcconfig.example Config/Config.xcconfig
xcodegen generate
xcodebuild -resolvePackageDependencies -project Sentra.xcodeproj -scheme Sentra
xcodebuild -showdestinations -project Sentra.xcodeproj -scheme Sentra
printf 'Available iPhone simulator UUID (iOS 17+): '
read -r SIMULATOR_ID
xcodebuild build -project Sentra.xcodeproj -scheme Sentra \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Sentra.xcodeproj -scheme Sentra \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
open Sentra.xcodeproj
```

Choose an eligible iPhone UUID from the printed destinations. In Xcode, run the
`Sentra` scheme to inspect the preview. Select your team in the ignored config for
device signing. After package resolution, review and include the shared lockfile
at `ios/Sentra.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

For a focused rerun of the 10 card/crop cases after the full build, from `ios/`:

```sh
xcodebuild test -project Sentra.xcodeproj -scheme Sentra \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -only-testing:SentraTests/PlayerCardTests \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
```

Open [PlayerCardPreviews.swift](../ios/Sentra/Core/Components/PlayerCard/PlayerCardPreviews.swift)
for the card-only matrices and live editor demo. The existing app dashboard still
launches offline; no new feature destination was added to reach this prototype.
Preview motion is sensor-free. A physical-device check must exercise the renderer's
`motion: .device` mode; simulator or automatic sweep alone does not validate CoreMotion.

The native SQL gate is separate and does not access the hosted database. From the
repository root on a supported Mac/Linux host, as a normal non-root user:

```sh
npm ci
SENTRA_TEST_ENGINE=native npm test
```

## Manual Review Checklist

- [ ] Generate the project, resolve SPM, build, and run all 36 XCTest cases on Mac;
  record Xcode/runtime versions, actual totals and any failures here.
- [ ] Launch without real config and with networking unavailable. No auth screen,
  network-dependent images, system permission prompts or credential crash occurs.
- [ ] Review Greek and English in light, dark and system appearance. User/backend
  names remain verbatim; only UI labels and fixture localization are translated.
- [ ] Check a small iPhone and a larger iPhone in standard and accessibility Dynamic
  Type. Cards, names, counters, pickers and toolbars do not clip, overlap or reflow
  unexpectedly; interactive targets are at least 44 points.
- [ ] Use VoiceOver for controls, player rows, status/queue information and cards.
  Status is distinguishable by labels/icons as well as color; focus is coherent.
- [ ] Enable Reduce Motion. Transitions/spinners honor it, and loading prevents
  accidental interaction. Error retry and empty states remain accessible.
- [ ] Inspect the full upcoming roster: nine registered yes plus one guest, one
  maybe, one no, one waiter. Display dense waitlist position, not the raw ticket.
  Demo selection and reset must leave counts and roster data unchanged.
- [ ] Inspect bronze/silver/gold/elite shells, statistics, illustrative history,
  earned badge examples and MVP. Confirm the original design and no live rating
  or cosmetic purchase behavior.
- [ ] Compare the dashboard against [DESIGN.md](DESIGN.md): full-width photo/brand
  hero, compact match card, stacked RSVP colors, status chips, three numbered steps,
  dark MVP list and the new original shield cards. Replace the low-resolution
  photo before accepting a production Welcome screen.
- [ ] Switch roster tabs: players 10 (nine registered plus one guest), waitlist 1,
  other responses 2 (maybe/no). Verify selected states are announced and no action
  changes the underlying snapshot. MVP choice is local and has no submit action.
- [ ] At the largest Dynamic Type sizes, verify vertical tabs/progress, wrapped
  names, stable icon slots, two-column card stats and the full VoiceOver description
  for a missing result. Check the shortest supported iPhone viewport for hero fit.
- [ ] Verify visible navigation links show localized placeholders and back works.
  Run the route test covering all 14 route values; deep links remain no-ops.
- [ ] Verify invalid live configuration fails safely and diagnostics show no keys
  or raw database errors. Real authenticated HTTP checks need separate authorization
  and do not justify implementing Step 3 during this review.
- [ ] Review/track the resolved SPM lockfile; separately schedule original app-icon
  artwork and cleanup of already tracked dependency artifacts.
- [ ] Review this delivery and explicitly authorize any next step.

### Card Redesign Review

- [ ] Capture six appearances and all sizes in Greek/English and both app modes.
  Check a small iPhone, long names, six-column labels/values and largest Dynamic
  Type. Provisional must hide OVR both visually and from VoiceOver, not position.
- [ ] Inspect close-up, outdoor/profile, busy/no-face, low-light and no-photo
  examples. Confirm the shield, eyes near the 40% target where feasible, natural
  skin tones, border/crest/texture, and no empty image edges or unwanted clipping.
- [ ] In the local editor, select a photo, pan and pinch together, use all sliders,
  Reset, Save and Cancel. Test an EXIF-rotated photo, invalid input, cancellation
  while preparing, and recovery. Save must only update the demo's in-memory photo.
- [ ] Review the stadium-night share composition; there is no image export, QR,
  public share URL or share-sheet implementation in this pass.
- [ ] Verify drag spring return, appearance transitions and nine-second preview
  sweep. In device mode on a physical iPhone, test leave/reenter/background and
  multiple cards; sensors stop when unused. Under Reduce Motion nothing tilts or
  sweeps. Confirm the motion purpose is localized and idle launch asks no permission.
- [ ] Approve the proposed crop storage/write contract before adding any migration
  or profile persistence. Do not interpret local Save as a successful backend save.

## Next Action

**STOP at Step 2.** User review and the Mac build/XCTest/manual gates are next.
The whole-app mockup and Option 1 card reference are documented. The authorized
card renderer/editor is isolated; persistence is proposed, not applied. Actual
onboarding, rating, rewards, sharing and purchase workflows remain unimplemented.
Do not start Step 3, change deployed migrations, reset databases or deploy anything
without the required authorization. No commit or branch was created by this work.