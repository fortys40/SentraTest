# Sentra Design

Visual reference: [mockups/sentra-flow.png](mockups/sentra-flow.png).
Updated 2026-10-07. Current implementation boundary: **Step 2 design alignment only**.

## Authority and Scope

The mockup establishes the visual direction for the whole app, not its data model
or business rules. [The written specification](../.github/copilot-instructions.md)
wins whenever fields, flows, permissions, navigation destinations or rules differ.
The [schema mapping](schema-to-swift.md) remains authoritative for wire contracts.

Ignore the image's copy, dates, scores and typos. App-owned text belongs in
[Localizable.xcstrings](../ios/Sentra/Resources/Localizable.xcstrings), in correct
Greek with English translations. Names and other backend values remain verbatim.
Dates come from model timestamps and locale/time-zone-aware formatters, not artwork.

The Step 2 dashboard is a component preview, not an implementation of these
screens. Its hero has no sign-in buttons; its RSVP/MVP selections are local visual
state; progress does not advance a completion workflow. No new route, permission,
authentication flow, mutation, vote submission or purchase was added.

![Sentra visual reference, screens 1 through 15](mockups/sentra-flow.png)

## Screen-to-Step Mapping

Implement each actual screen only during its assigned, authorized step.

| Screen | Screen | Step |
| --- | --- | --- |
| 1 | Welcome / authentication entry | 3 |
| 2 | Profile | 3 |
| 3 | Organizer / invite choice | 3 |
| 4 | Create group during onboarding | 3 |
| 5 | First match during onboarding | 3 |
| 6 | Invite the group | 3 |
| 7 | Upcoming match and RSVP | 4 |
| 8 | Full match, roster and waitlist | 4 |
| 9 | Add guest | 4 |
| 10 | Finish match / played roster | 5 |
| 11 | Optional result | 5 |
| 12 | Optional cost split | 5 |
| 13 | MVP voting | 5 |
| 14 | Player card | 8 |
| 15 | Badges | 8 |

Screens 1-6 remain Step 3, 7-9 Step 4, 10-13 Step 5, and 14-15 Step 8.
The image does not authorize any of those workflows in Step 2.

### Corrections That Must Survive Implementation

- Screen 11 has **one exclusive result mode**: none, winner only, or full score.
  Only the selected mode's fields are visible. None has no result fields; winner
  only shows A/B/draw; full score shows scores and optional scorer input. The
  database, not a competing client calculation, derives the winner from scores.
- Screen 14 uses **ΤΕΡ / ΑΜΥ / ΜΕΣ / ΕΠΙ**, never CM. The existing ANY value keeps
  its separate localized fallback, ΠΑΝ. Stats are **ΣΥΜ / ΝΙΚ% / MVP / ΓΚΟΛ**.
- Retain the premium dark/gold feeling, but use an **original silhouette, frame
  and typography**. No EA FC/FIFA shield, ornamental frame, proprietary font,
  league/club badge or logo is reproduced.
- Keep written-spec navigation: **Αγώνες, Παρέες, Στατιστικά, Προφίλ**. Do not copy
  the image's alternative bottom labels. Step 2 still uses its placeholder stack.
- Welcome is not a carousel or intro-slide flow. Capacity remains derived from
  format; waitlist remains a database outcome; MVP privacy/eligibility and optional
  result/cost rules remain unchanged.

## Visual Direction

Use restrained, football-focused utility screens: off-white canvas, white list
surfaces, compact bold headings, emerald commands and clear status color coding.
Use dark forest surfaces for MVP and dark metal-accented player cards. Photography
belongs in the Welcome hero; ordinary forms and lists remain quiet and unframed.

The composite is a raster reference, not a point-accurate design file. Native
dimensions below are normalized iOS points, chosen to preserve its proportions
while meeting Dynamic Type, contrast and minimum-target requirements.

## Palette

Bounded flat-control samples from the saved image were approximately green
`#027E46`, amber `#FBCF73`, red `#F44D4D`, and MVP dark `#011311`. Compression,
lighting and antialiasing produce nearby values. The following values are the
implementation contract in [SentraTheme.swift](../ios/Sentra/Core/Theme/SentraTheme.swift).
In particular, the red action fill is intentionally darker for readable white text.

### General Surfaces and Commands

| Role / token | Light | Dark | Use |
| --- | --- | --- | --- |
| `brand` | `#00864A` | `#00864A` | Primary and yes action fills |
| `darkGreen` | `#00482E` | `#00482E` | Deep brand accent |
| `onBrand` | `#FFFFFF` | `#FFFFFF` | Text/icons on brand and red action fills |
| `primary` | `#007B45` | `#7BDCAE` | Green text, links, selected tabs and yes chips |
| `onPrimary` | `#FFFFFF` | `#08251A` | Contrast companion for adaptive primary surfaces |
| `background` | `#F5F7F5` | `#101A15` | Page canvas and background asset |
| `surface` | `#FFFFFF` | `#1A2720` | List, form and individual match-card surfaces |
| `surfaceMuted` | `#EDF2EE` | `#26382D` | Inactive markers and avatar fallback |
| `ink` | `#17271D` | `#F4F8F5` | Main text |
| `mutedInk` | `#58665D` | `#B6C9BE` | Metadata and secondary text |
| `border` | `#D8E1DA` | `#40564A` | Dividers and quiet outlines |
| `maybeFill` / `onMaybe` | `#FFD16B` / `#473204` | Same | Amber RSVP button with dark text |
| `noFill` | `#D12F46` | `#D12F46` | No RSVP and destructive action fills |

### Status Chips

| Status | Text/icon: light / dark | Background: light / dark |
| --- | --- | --- |
| Yes | `#007B45` / `#7BDCAE` | `#E5F5EB` / `#153D29` |
| Maybe | `#735000` / `#FFD16B` | `#FFF3D6` / `#423519` |
| No | `#B92E43` / `#FFA5B1` | `#FFE8EC` / `#47242C` |
| Waitlist | `#3F5D74` / `#BAD2E4` | `#E6EFF5` / `#273D48` |

Every status has an SF Symbol and localized label; color never carries meaning
alone. The waiting row shows its dense queue position, not the raw ordering ticket.

### MVP and Player Cards

| Token | Hex | Use |
| --- | --- | --- |
| `mvpSurface` | `#061B16` | Full-width dark MVP band; hero text backdrop |
| `mvpRaised` | `#0D2B23` | Available raised dark-surface token |
| `onMVP` | `#F4F8F5` | MVP and hero text |
| `mutedMVP` | `#B6CEC1` | MVP position/guest metadata |
| `mvpAccent` | `#79E2AE` | Selected MVP indicator |
| `premiumSurface` | `#111B18` | Shared dark player-card base |
| `onPremium` | `#FCF6E6` | Main card text |
| `bronze` | `#DBB18A` | Bronze frame, rating and stat values |
| `silver` | `#D3E0E5` | Silver frame, rating and stat values |
| `gold` | `#E5C875` | Gold frame, rating and stat values |
| `elite` | `#F4DB91` | Elite frame, rating and stat values |

MVP/card surfaces remain dark inside either app appearance. Core enabled text
pairs are checked at 4.5:1 or better. Hero text has a full-width, 86%-opaque dark
backdrop whose height follows its text; contrast is also checked over a pure-white
image pixel. The photo below remains unobscured. Disabled-control opacity is not
the normal-text contrast target.

## Type Scale

Use native SF system typography, not the image's unidentified sports font. This
preserves Greek coverage and Dynamic Type. Do not add negative tracking or scale
text with viewport width. Numeric columns use monospaced digits.

| Role | Default size | Weight / treatment | Swift behavior |
| --- | --- | --- | --- |
| Brand wordmark | 34 pt | Heavy, italic | Semantic large title |
| Page / sample title | 22 pt | Bold | Title 2 |
| Section heading | 17 pt | Bold | Headline |
| Body / list name | 17 pt | Regular / semibold | Body |
| Button title | 17 pt | Semibold | Body; wraps vertically |
| Metadata / chip / stat label | 12 pt | Medium | Caption |
| Player-card name | 20 pt | Bold | Title 3; wraps |
| Card OVR | 52 pt | Heavy, straight, monospaced digits | ScaledMetric relative to large title |

Decorative avatar initials and 20-22 pt tool/selection icons stay inside stable
slots. The accessible name/status is supplied separately. Long names, captions and
button text must grow vertically rather than collide with neighbors.

## Spacing, Geometry and Shadows

- Spacing scale: **4, 8, 12, 16, 24, 32, 40 pt**. Use 16 pt screen insets, 12 pt
  row gaps, 24 pt feature/card padding and 32 pt separation between preview samples.
- Command buttons: full available width, **52 pt minimum height**. All interactive
  targets, including icon tools and segments, are at least **44 pt**.
- Controls and ordinary cards: **8 pt radius**. Status chips are capsules; avatars
  are circular. Do not turn entire form sections into floating cards or nest cards.
- Player rows: **60 pt minimum**, 40 pt avatar, 12 pt content gap and 8 pt vertical
  padding. Match-card attendee thumbnails are 28 pt with a small overlap.
- Dividers: 0.5-1 pt; secondary-button outline: 1 pt; selected tab underline: 2 pt.
- Match-card shadow: black at **6%**, blur **10 pt**, vertical offset **4 pt**.
  No large drop shadows around whole page sections.
- Step 2 hero: unframed, full width, **360 pt minimum height**, with text allowed
  to increase its height. It leaves room for the next preview section on a small
  standard-size iPhone. Step 3 will own the real Welcome screen layout.
- Player-card grid: **280 pt preferred minimum column width**, one flexible column
  at accessibility sizes. Shells have a **460 pt minimum** at ordinary text sizes,
  not a fixed height; accessibility content can grow freely.
- Card silhouette: a flat-topped, flat-based plate with opposite top-right and
  bottom-left 22 pt cuts, reduced proportionally for small bounds. One 1.5 pt
  metallic outline; no pointed shield base, crest, crown or layered ornamental frame.

## Component Rules

### Buttons and RSVP

Primary actions are emerald with white text/icons in both appearances. Secondary
actions use the current surface, main ink and a quiet border. Destructive actions
use the accessible red. Use SF Symbols for tools, with localized accessibility
labels and help for icon-only commands.

Stack the three RSVP requests vertically: green yes, amber maybe, red no. Preserve
an equal-sized trailing selection slot so changing selection cannot move the text.
Use an inset outline and checkmark in addition to color. Waitlist is displayed as
status, not offered as a fourth requested response. The reusable waitlist button
remains disabled if displayed elsewhere.

Pressed feedback changes opacity without changing geometry. Loading disables the
command and preserves the icon slot; Reduce Motion uses a static loading symbol.
No preview control sends an RSVP mutation.

### Match Card, Rows and Chips

The match card is an individual repeated item: group metadata, calendar/date row,
venue, format/status, compact attendee stack, authoritative occupancy and optional
expected cost. The date uses heading size, not hero-size type. Never bake a date
or fixed capacity into the component.

Rows use a circular avatar, semibold verbatim name, position or guest subtitle,
and a trailing status capsule. They stack at accessibility sizes. Dividers and
shared surfaces organize the roster; each row is not its own floating card.
Chips use explicit foreground/background tokens rather than arbitrary tint opacity.

### Segmented Roster Tabs: Screen 8

Use equal-emphasis text segments over a shared surface with a green selected
underline, a neutral hairline baseline, localized counts and selected accessibility
traits. Segments have 44 pt targets. Use a vertical arrangement at accessibility
sizes or when the labels cannot fit; do not compress labels to illegibility.

The Step 2 sample switches between confirmed players, waitlist and other responses
(maybe/no). These are local filters over the same immutable snapshot. Switching
tabs does not alter counts, queue order or responses. Appearance/state sample
selectors retain native segmented controls, changing to menus at accessibility sizes.

### Progress Header: Screen 10

Show three numbered markers with labels for played roster, result and cost.
Markers are 24 pt at the default caption size and scale with that text style.
Current/completed markers are green; completed markers use a checkmark; future
markers are neutral. Connect them with short lines and provide the localized
current/total summary for VoiceOver. Stack the labeled steps vertically when needed.

These are the three editable completion stages; MVP opens after completion under
the written/database rules. The preview demonstrates step one without implementing
the finish workflow or any next/back mutation behavior.

### Dark MVP List: Screen 13

Use an unframed dark forest band, a compact white title, white names, subdued
position/guest labels, subtle dividers and a green selected-circle indicator.
The whole row is the hit target. The preview shows registered examples and a guest
and allows one local selection, including clearing it; it has no submit action.

This sample is not an eligibility calculation or a real voting roster. Actual
Step 5 must use the authorized participant/voting contract, exclude self-votes,
keep ballots private and never query individual votes from the client.

### Original Player Cards: Screen 14

All four shells use the same original plate geometry and dark surface, with their
own metallic accent. Put the OVR/Greek position at top left, a generous avatar at
right, centered name/title/group, a thin divider, four stat columns, streak/badges
and restrained tier/Sentra footer. At accessibility sizes, stack identity content
and use two stat columns. A missing result is a localized short marker visually
and a complete description for VoiceOver, not a clipped sentence or fake zero.

Use circular monogram fallbacks until suitable profile photos exist. Do not crop
the mockup's portrait/card into the app or imitate its FIFA-style frame. No Vision
cutout pipeline, rating calculation, reward logic, sharing or paid design is added
in Step 2. Tier boundaries and ratings remain independent of purchases.

### Navigation

Preserve native NavigationStack back behavior, inline titles, and SF Symbol toolbar
commands. Do not add custom bottom destinations based on the mockup. The four
written-spec tabs and actual onboarding/invite routes belong to their later steps.
All 14 existing Step 2 route values still resolve to localized placeholders.

## Comparison with the Initial Step 2 Foundation

| Area | Before alignment | Aligned implementation |
| --- | --- | --- |
| Green | Muted `#12633F`; mint-filled dark-mode commands | Emerald action fill shared by both modes; separate accessible text green |
| Neutrals | Green-tinted canvas and borders | Cleaner off-white/white surfaces, quiet neutral dividers |
| RSVP | Pale outlined buttons in a two-column demo | Three stacked filled actions; waitlist shown in roster/status |
| Secondary button | Green text and 1.5 pt green border | Main ink with 1 pt neutral border |
| Status chips | Foreground tint with 10% opacity background | Explicit light/dark semantic fill pairs |
| Typography | Rounded headings and card numerals | Straight SF headings/numerals; italic heavy brand only |
| Rows | 44 pt minimum, 44 pt avatar | 60 pt minimum, 40 pt avatar, same accessible stacking |
| Match hierarchy | Large date heading, no attendee stack | Compact icon/date row, optional attendee stack and occupancy |
| Progress | Generic continuous progress bar | Labeled numbered three-stage header with scalable markers |
| Roster navigation | One long mixed-status list | Accessible underline segments over immutable filtered rows |
| Hero | No hero or photo asset | Original text-free pitch crop behind localized brand treatment |
| MVP preview | No dark list sample | Dark full-width list with local-only selection |
| Player cards | Pastel Bronze/Silver/Gold; rounded rectangles | All-dark original cut-corner shells with four metallic accents |
| Card stats | Two columns | Four normally, two at accessibility sizes |
| Dates | Fixed clock at app launch and in tests | Current clock injected at launch; deterministic defaults retained for tests |
| Radius / spacing | 8 pt controls; 4 pt spacing scale | Retained; already consistent with the reference |
| Shadow | 6%, blur 8 pt, offset 3 pt | 6%, blur 10 pt, offset 4 pt |

Owners: [theme](../ios/Sentra/Core/Theme/SentraTheme.swift),
[buttons](../ios/Sentra/Core/Components/SentraButtons.swift),
[primitives/tabs/progress](../ios/Sentra/Core/Components/SentraPrimitives.swift),
[rows](../ios/Sentra/Core/Components/PlayerRow.swift),
[match card](../ios/Sentra/Core/Components/MatchSummaryCard.swift),
[player card](../ios/Sentra/Core/Components/PlayerCardShell.swift), and
[dashboard](../ios/Sentra/Features/Preview/StepTwoDashboardPreview.swift).

## Asset Provenance

- The original attachment is stored unchanged at
  [mockups/sentra-flow.png](mockups/sentra-flow.png): **1152x768**, **1,590,314 bytes**.
  SHA-256: `6d30be1471aee7f2b1878219129cf099175b9760c3b03329f2243ebd125d1160`.
- The only bundled photo is [pitch.png](../ios/Sentra/Resources/Assets.xcassets/WelcomePitch.imageset/pitch.png),
  a **134x136** crop at source **x=27, y=148**. It contains the pitch, ball and boot,
  not text, controls, phone chrome or the player-card frame. No remote image fetch
  is needed for previews. The full mockup is documentation only, not an app asset.
- This small crop is **temporary preview artwork**, not release-quality imagery.
  Replace it with a suitably licensed high-resolution football photograph before
  Step 3 visual approval. The app-icon artwork also remains a later release gate.

## Validation and Review

The focused source suite has **14 passing checks**. It includes 46 solid
foreground/background contrast combinations across light/dark, worst-case hero
contrast, localized keys/placeholders, corrected card labels, original PNG checksum,
hero metadata, component presence and absence of later-step commands.

The combined local suite has **35 passing checks, zero failures, two skipped
native concurrency tests**. Neither suite compiles or renders SwiftUI.
Xcode generation, iOS build, 26 XCTest cases, simulator screenshots, VoiceOver,
Dynamic Type and Reduce Motion review remain **unverified on this Windows host**.

Use the exact Mac commands in [README.md](../README.md) and record results against
the checklist in [PROGRESS.md](PROGRESS.md). Review small/large iPhones in Greek
and English, light and dark, with long names and accessibility sizes. Verify hero
framing, text fit, selected states, tab counts, dark-surface readability and all
four card shells. **Stop for review; Step 3 is not authorized.**