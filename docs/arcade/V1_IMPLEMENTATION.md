# Burst / Pyramid / Matching V1 integration

Source requirements: `Burst_V1_Gelistirme.pdf` (14 pages), `Pyramid_V1.pdf` (7), `Matching_V1.pdf` (7), supplied in this task. Base: PR #58 (`codex/daily-word-trio-v1`). No main merge or production deployment is part of this PR.

## Implemented contracts

| Area | Burst | Pyramid | Matching |
|---|---|---|---|
| Setup | Hız Atağı / Dayanıklılık × club/club or club/country, default speed + club/club | Easy/normal/hard; normal default | Easy/normal/hard; normal default |
| Board | >=6 distinct searchable certified answers, 3 found per round | 4 levels/10 slots/5 initial or 5 levels/15 slots/6 initial | 6/8/12 pairs; 3/4/4 columns |
| Rules | 120 total active sec, 30/round; wrong −3 sec; two −5 sec passes. Survival: 5 lives, 12 completed rounds, two free passes | Typed positive edges, unique identities, two filled supports, peak constraints, bounded remaining-solution search, free LIFO undo | Closed memory only, two different flips = one move, 1000ms mismatch lock retained across pause/reopen |
| Scoring | 100×streak multiplier (1/1.5/2), +50 per 3/3; wrong/pass/timeout reset streak | 100 per solved cell, no coin dependence | Fewest moves, active time tie-breaker; independent best time |
| Hints | Speed none. Survival one free + two SSV/Pro verified credits; no paid boost advantage | 2/2/1 per board, facts rather than entire solution | None |
| Permanent reward maxima | 9 Coin / 18 XP per style; 18/36 total, cumulative lower grades; mastery conditions enforced | Independent difficulty awards 2/2/3 plus hard mastery 3 = 10/20 | 1/2/2 plus hard <=24-move mastery 3 = 8/16 |
| Daily | Speed 2 rounds or survival 3: 2 Coin / 4 XP once per Istanbul day | Normal/hard win: 2/4 shared with Matching | Same shared logic mission; concurrent wins cannot double claim |
| Resume | UID/version-scoped; 24h; offline play with durable events, server replay before rewards | UID/version-scoped, 24h; cached read-only during network failure | UID/version-scoped, 24h; unmatched cards close on reopen, mismatch lock preserved |

All new starts validate content before reserving energy. A ready board is explicitly confirmed to debit once; cancellation or reservation expiry releases the hold. Energy rollout off costs zero, on costs one for linked accounts. Guests play free practice and do not retrospectively earn practice rewards on account linking.

## Data and validation

`tools/arcade/build_catalog.py --check` deterministically reproduces the V4 catalog and fingerprints its SQLite source. Current bank: 10,671 eligible players, 1,752 Burst pairs, 48 Pyramid certificates, 693 typed Pyramid entities and 33 usable complete retired-career reviews. Positive links require canonical senior clubs and trust >=2. Country aliases are canonicalized; ambiguous `Korea` is excluded from nationality puzzles/hints.

Matching uses the existing sourced complete-career review in `tools/fake_club/coverage.json` / `fake_club_catalog.json`. Every uncertain V4 career link also excludes a cross pair. Missing partial-career data is never negative evidence. Forty bounded attempts must produce the exact requested pair count or fail before energy. No placeholder players or reduced boards are used.

Pyramid certificates satisfy every triangle edge and contain diverse witnesses; all interior cells cannot be one club clique. Normal/hard equal-size boards are ordered by structural complexity, with distinct hint budgets. The runtime accepts alternative identities only when a full remaining certificate is found within its bounded search. Inconclusive searches do not spend a life. Shared club is labelled as shared career club, never as simultaneous teammates. Country-country and unreviewed club-club links are absent.

Burst suggestions use the entire frozen player universe, ranked by prefix match, then player fame (rank), then name; nothing question-specific is used. The current question does not affect search. The offline kit contains football facts needed for local play, stored once under the UID/version; the UI never renders future answers or missed names before the result.

## Offline/retry protocol

The client uses `Stopwatch`, not the device wall clock, and persists clock checkpoints once per second. Adjacent unsent clock-only events coalesce, but never across question boundaries and never after a possibly accepted request. Offline reopening conservatively charges the one-second uncheckpointed margin. Resume cannot create a new 120-second budget.

The server replays canonical actions against the frozen V4 bank and existing session revision. Elapsed values must be nonnegative integers and remain within the observed server wall-time envelope. Every answer, pass or hint costs at least 800 ms of active time, and online events use the server clock as a floor (at most 2 s of network/loading per event is not counted), so reporting `elapsedMs: 0` cannot stop the Speed clock. Offline, an answer for a round the clock already closed is dropped instead of rejecting the batch. This is bounded solo replay, not cryptographic attestation of device foreground time. Client scores, medals and currency claims are ignored. Wrong branches, impossible clocks and account/session mismatches reject the entire batch without partially committing earlier events. Original request IDs and fingerprints survive lost replies; two-device branches cannot overwrite one another.

Burst rounds: Speed climbs easy → normal → hard → legend every two rounds (nearest tier when one runs out); Survival has a 75 s round clock that costs a life. A paused run hides the pair. Survival hints are progressive per answer (nationality, then initials) and clear once that player is found. Medals are recorded even while rewards are off; records keep lives only for Survival and answer pace only for Speed. Pyramid: 150 boards (50 easy, 50 normal, 50 hard); the tighter half of the five-level boards by mean candidates per empty cell is hard. New boards come first, and today's normal board is shared. A linked candidate that leaves the board unsolvable costs a life with the same message as any wrong one. The first hint on a cell names only the type, a second adds the link. A win adds 100 × lives left, +200 without hints and −50 per undo; hard mastery also requires no undo. Matching: card ids follow the shuffled layout (`k0…`), so no id reveals its pair; easy boards draw from the 40 most recognisable links by seed; three stars need at most 1.75 moves per pair and two stars 2.5 (tightened from 2 / 3, still to be calibrated with device telemetry); hard mastery needs at most 18 moves; a paused win can set a move record but not a time record; records keep the best stars; today's normal board is shared. Rewards are a durable outbox. Coin and XP grants are independently idempotent; both must settle before the payment is marked complete. Burst and the shared Pyramid/Matching daily mission use the existing central daily-mission transaction/cap. Solo ad hints now share 4/day across eligible placements, including old per-placement counters during migration. Existing lower limits remain lower.

## Verification and release gate

- `npm test --prefix functions`, Functions lint and `git diff --check`.
- `python3 tools/arcade/build_catalog.py --check` and `node tools/arcade/build_vectors.js --check`.
- Dart replays server-generated Burst transcripts step by step, covering both styles, wrong/unknown/duplicate answers, passes, hints, pause, timeout, transitions and the total budget.
- Flutter transport tests cover lost replies, restart replay, clock coalescing, UID isolation and separate kit storage.
- Widget coverage includes setup/ready/game/pause/result/records, 320px/1.8 text, all board sizes, locked mismatches and hidden card semantics. CI captures previews using the bundled Inter/Satoshi fonts.
- CI #291 passed the initial implementation's Functions gate, Flutter analysis/tests and Android debug compilation. The expanded offline implementation must pass its subsequent CI run before review readiness.

Not claimed as completed: physical-device or Firebase emulator acceptance from the PDFs, two physical devices under poor networking, accessibility screen-reader checks, ad-provider live callbacks, production latency measurements or empirical Matching star calibration. The current star thresholds (3 stars <=2×pair count; 2 stars <=3×pair count) are explicit provisional configuration. These are release checks, not silently treated as PASS by unit tests.

`runtimeConfig/arcade` defaults to `{enabled:false,rewardsEnabled:false}`. Deploy the new callables and private `arcadeCatalogs` rules before enabling a test cohort. Preserve historical catalog versions for active sessions. Enable production rewards only after the release checks above. No live flags were changed by this task.
