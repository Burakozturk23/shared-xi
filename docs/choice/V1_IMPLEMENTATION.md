# Choice trio V1 integration — staged, not release-approved

Reference documents read separately: `This_or_That_V1(1).pdf` (16 pages),
`Higher_or_Lower_V1_Gelistirme(1).pdf` (15 physical pages),
`Blind_Ranking_V1_Gelistirme(1).pdf` (19 pages).

## Implemented behavior

| Mode | Rules and user flow | Rewards |
| --- | --- | --- |
| O mu Bu mu? | 8 themes; 16/32/64/128 conditional formats; clubs max64; fixed season-candidate identities; exactly N−1 decisions; unfinished undo across rounds; tree, champion, final opponent and account collection | 2/3/4/5 coin, double XP; Istanbul day; first2 completions and one per theme×size; 8 lifetime achievement coins; 2/4 central daily mission |
| Higher or Lower | Source-gated metrics, no repeated player in a run, no equal-value pair, easy/normal/hard/master gaps, known-side balance, answer reveal then explicit next, first wrong ends; versioned criterion records | 5/10/20 streak→1/2/3 coins; criterion daily tier difference only; Istanbul day shared6 coin normal cap; 8 lifetime achievement coins |
| Blind Ranking | Objective vs personal, 5/10 formats, stratified sampling, one current player, future/value concealment, empty-slot preview then immutable confirmation; pairwise score excludes ties; tie-aware exact positions; personal lists have no objective score | 2/3 coin, double XP; UTC day first2 lists across all types; 11 lifetime achievement coins |

All mutations use authenticated, App Check enforced callables. A session pins its
catalog version and owner. Revisions reject conflicting device actions. Receipts
bind request IDs to canonical event content. Coin/XP outboxes and central mission
claims survive retries. The client never writes wallet balances. Guest practice is
frozen when created; linking later does not retroactively reward it.

The shared energy rollout remains authoritative: validation precedes reservation,
cancel releases the hold, confirmation consumes once, resume costs zero. No new
24-hour expiry was invented for these untimed active games. Global choice enabled
and rewardsEnabled both default false. No production deployment is included.

Flutter routes replace old local metric/scoring controllers. SharedPreferences
snapshots/journals are UID-scoped and recheck identity after awaits. Tournament
choices and undo can progress offline; replay validates the complete ordered event
sequence atomically. A crash between journal and snapshot is recovered. Other modes
persist the in-flight exact request but require connection for the next hidden
challenge. Android PNG sharing opens the OS chooser only on explicit user action.

## Source and release blockers — do not report full PDF acceptance

`tools/choice/build_catalog.py --check` reproduces the audited catalog from the V4
SQLite SHA and `reviews.json`. Density checks are not source verification.

- All 8 statistical criteria currently fail the source/scope approval gate.
  They remain visibly locked, including Higher or Lower and objective Blind Ranking.
  The existing numeric database columns alone do not establish career/senior/recorded
  scope, snapshot provenance or reliable zero values.
- All 768 original tournament highlights are unreviewed. Unverified season and
  highlight claims are omitted. These themes are free, unrewarded practice only.
  Short manifests preserve legacy matchup pairs but require explicit editorial
  approval in addition to candidate source reviews before rewards can open.
- Some legacy names cannot be mapped unambiguously to V4. The machine audit records
  the exact IDs. No fuzzy first-hit matching or invented source approval is used.
- Full offline progression for Higher or Lower and Blind Ranking is not yet shipped.
- Club crest mappings and reviewed season-club/two-fact cards remain content work.
- Android PNG code needs a real-device chooser/save smoke test. iOS/web native
  sharing is not provided. The in-app card preview is available.
- Firebase emulator rules/concurrency and physical-device acceptance are not
  represented by the in-memory callable contract harness or widget tests.

## Verification

Run `python3 tools/choice/build_catalog.py --check`, Functions lint and `npm test`.
`functions/test/choice.test.js` tests production gates, exact brackets, tie scoring,
statistical pair generation, private projection, caps, UTC/Istanbul, energy,
concurrent retries, guest/account isolation and atomic offline replay. Synthetic
reviewed statistical fixtures are used only in tests, never in the production catalog.

`test/choice_page_test.dart` checks all three setup/prepared/play/result routes,
320px/1.8x text layouts, collection navigation, hidden-value reveal, placement
confirmation, disabled gates and PNG bytes. `test/choice_service_test.dart` checks
lost replies/restart, journal crash recovery, UID changes and offline undo.
GitHub Actions runs Flutter analysis/tests and the Android debug compile gate;
real-font preview PNGs are uploaded as `choice-trio-previews`.

This work is stacked on `codex/arcade-trio-v1` / PR59. Merge/deploy is not performed.
