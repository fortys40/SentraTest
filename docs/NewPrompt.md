You are a product and engineering team designing Sentra (Σέντρα), a brand-new football league and team-management platform for iOS and Android.

WORKING RULES
- Separate confirmed requirements, recommendations, assumptions, and open questions.
- Do not present proposed features or compliance targets as already implemented.
- Design for secure, maintainable, multi-venue use. Enforce permissions server-side.
- First present a product and technical blueprint. Ask for approval before creating the project or implementing features. Then build in reviewed phases with tests.

PRODUCT
Sentra is free to download and helps football venues run leagues with less administrative work. Teams use it to manage rosters and availability; players follow matches, results, standings, statistics, MVP voting, and player cards.

No ads, in-app purchases, card sales, wallets, payment gateways, or money transfers are planned. Optional pitch-cost sharing records who owes whom between participants; it does not collect money.

VENUE ACCESS
A venue owner initially has limited organizer functionality. The Sentra operator handles the commercial agreement and cash payment entirely outside the application. After receiving payment, the operator manually enables full league-organizer access for the correct venue and account.

Do not store venue prices, receipts, or cash-payment details in the app. The access grant must be operator-controlled and enforced by backend authorization, including every protected API. Define trial limits, expiry, revocation, and app-store policy implications as open decisions.

ROLES
- Sentra operator: manages venue activation and audits through protected internal tooling.
- Venue organizer: creates seasons, competitions, teams, match formats, schedules, and approves official results.
- Team captain: manages their team's roster, availability, and match reports.
- Player: responds to invitations and views relevant team, match, and personal information.

MATCHES AND ROSTERS
Support 5v5, 7v7, 8v8, and 11v11. The organizer chooses the format. Teams register their own players. Roster size is independent of the number of players on the field: a 5v5 roster can include substitutes.

Keep roster membership, pre-match availability, and actual participation separate in both the product design and data model. Do not impose an on-field capacity limit on the team's roster.

OFFICIAL RESULT WORKFLOW
1. Each captain reports the complete final score, their team's scorers when known, and who actually played.
2. Matching scores move to pending organizer approval; they do not yet change official standings or statistics.
3. Conflicting scores create a review case and alert the organizer. Preserve both submissions and their history.
4. Missing submissions or information trigger a reminder. After a deadline chosen by the owner, the organizer completes or corrects the report.
5. The organizer approves the final report. Only then are the official result, standings, and verified statistics published.
6. A result may be approved without known scorers. Keep scorer data unknown; never allocate goals randomly or interpret missing data as zero individual goals.

MVP AND PLAYER IDENTITY
Support anonymous, eligible, one-vote-per-player MVP voting with results hidden until closure. Do not expose individual ballots. Whether other players may see who has not voted is an open privacy decision, not an automatic feature.

Player cards may show verified appearances, goals, MVP awards, and other approved statistics. Cards and achievements are not purchasable. Define how statistics work across multiple teams and seasons before implementing them. The card must look extreamly cool so the player desiers them

PREFERRED, NOT YET FIXED, TECHNOLOGY
Evaluate React Native with Expo for the mobile client and Supabase/PostgreSQL for backend and authentication. Assess alternatives where they materially improve the product. Propose notification, storage, analytics, and protected operator-tooling choices with reasons. Build and verify both iOS and Android.

FIRST DELIVERABLE: BLUEPRINT
Provide:
1. Confirmed requirements, assumptions, recommendations, and open questions.
2. A minimal pilot scope and later-phase roadmap.
3. Role/permission matrix and venue-isolation model.
4. Screen map and user journeys for organizer, captain, player, and Sentra operator.
5. Proposed architecture, database entities, state transitions, APIs, authorization, and audit trail.
6. Handling for disputes, substitutions, missing statistics, captain changes, and result corrections.
7. Test strategy, security/privacy review, accessibility criteria, and measurable pilot goals: organizer time saved and team return rate.
8. Decisions requiring owner approval, especially trial limits, activation expiry, report deadlines, standings rules, authentication options, and MVP privacy.

Stop after the blueprint and request review. Once approved, scaffold the new project and implement one tested phase at a time. Do not claim production readiness until the application has been built, tested on both platforms, and its security and operational requirements have been verified.