# UCL Moments V2

Scope: the 10 October 2026 UCL PDF. Player Journey and What If code/data are unchanged.
This branch starts from the completed What If PR #35, which includes dependency-security PR #34.

## Gameplay

34 independently curated historical matches. The fixed task distribution is 10 critical goals,
9 measurable match heroes, 7 match-specific starting XIs, 4 goal timelines and 4 score questions.
Archive → spoiler-free introduction → task → verified result → keepsake collection.
Wrong answers can be retried without payment or an advertisement. A free hint is always available.
The pitch is schematic; it represents the match starting XI, never the season squad or bench.
Each Rodrygo goal in the 2022 task has a distinct event card.

## Data and provenance

`functions/config/ucl_catalog.json` is the authoritative question bank. `tools/ucl_moments/build_catalog.py`
reproduces it and exports a redacted `assets/data/ucl_moments_v2.json`. Answer keys, actual scores,
result stories and source URLs that could expose an answer are excluded from the mobile asset.
The obsolete common-player UCL screen is replaced; no full repository/SQLite load is required to play.
All 26 club IDs were checked against the bundled V4 database. Match-specific player names and the
seven starting XIs are self-contained in this mode; no unsupported career links are inserted into
other games' shared database.

The 15 StatsBomb match IDs in verification metadata were checked against competition 16 season
indexes and the existence of both events and lineups files. This is an availability audit, not a
commercial license assertion. No StatsBomb raw event/lineup file, coordinates, or JSON payload is
added to the repository, APK or Firebase. The question bank uses independently curated facts with
UEFA match reports, official starting-XI/finals documents and the Galatasaray club archive as sources.

Historical corrections: Schalke–Galatasaray is 12 March 2013; Roma–Barcelona was a quarter-final;
Roma and Tottenham advanced under the contemporary away-goals rule. The 2005, 2012 and 2016
finals keep shoot-out results separate from the 120-minute score. 1972 is labelled European Champion
Clubs' Cup. Neutral-ground finals and 2020 Barcelona–Bayern use the official designated team order.

## Persistence and economy

Only `submitUclMoment` validates an answer; result disclosures are returned after success.
`getUclMoments` returns the authenticated user's completed-match results and retries pending reward
receipts. The client cannot request a coin/XP amount. Each first match earns 8 coins + 20 XP;
10/20/34 distinct matches earn 40/70/100 coins and 75/100/150 XP. Total: 482 coins, 1005 XP.
Coins and XP use idempotent progression receipt IDs; a failure between them is repaired on sync.
Repeats and concurrent retries do not repay. XP also contributes to the existing season progression.

Anonymous authenticated guests can solve. Their rewards remain pending until they link the same
UID to Google. Switching to a different Google account does not transfer another UID's receipts.
RTDB `uclMomentsState` is server-only and is removed by the existing account deletion flow.

Draft selections, timeline order, free-hint state and pending submissions are stored under a UID-scoped
SharedPreferences key. Reopening offline resumes the task. Without a connection a new answer cannot
be judged or paid; it is queued. Sync verifies it when connectivity returns. Previously earned
keepsakes are available offline. App account changes replace the controller and ignore old responses.
If an offline installation has never established a guest UID, its draft uses a separate offline-guest
key; it is not automatically copied to another account.

## Verification and deployment

```
python3 tools/ucl_moments/verify.py
npm --prefix functions run lint
npm --prefix functions test
flutter analyze --no-fatal-warnings --no-fatal-infos lib test integration_test
flutter test --reporter expanded --dart-define=UPDATE_FIVE_SCREENSHOTS=true
```

CI uploads `ucl-moments-previews` for both themes at 320 px and 180% text scaling.

From a clean Windows checkout, stop after any error:

```powershell
git status --short
git fetch origin
git switch codex/ucl-moments-v2
git pull --ff-only origin codex/ucl-moments-v2
flutter pub get
npm.cmd --prefix functions ci
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions,database" --project sharedix
flutter run --no-enable-impeller
```

Use the repository's Node 24 runtime. Open Oyunlar → Hikâye → UCL Moments.
Verify a guest solve, same-UID Google linking, first payment, replay without repayment, offline resume,
a timeline reorder, a starting XI, and returning from source disclosure. Firebase production deployment,
App Check provisioning and a real-device smoke test must be performed in the user's environment.
No new ad placement is required by this PDF and none is introduced here.
