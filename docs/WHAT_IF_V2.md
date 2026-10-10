# What If V2

Implements the supplied 16-page finalization plan: 24 existing scenario subjects, three chapters, two independently playable routes and endings per scenario. Five task templates use curated real-world answers; selecting an alternative universe is never a wrong answer. Old speculative prose is replaced by short context, separately gated task explanations and explicitly labelled fictional outcomes.

## User experience

- Story hub enters a dedicated What If archive; no database loading or generic StoryJourneyController reset.
- Context → choice → one task → outcome. Three-event timelines use tap-to-order, accessible without dragging. Other tasks use one reviewed choice.
- Every scenario/route, selected answer/order, free hint, discovered ending and device favorite is saved. Replays never delete endings. A failed disk write does not advance the screen.
- Guest play and offline play work without ads. Guests are told that account rewards require playing the route while linked; guest history is not silently imported as payment proof.
- Local saves and pending proofs are UID scoped. Account changes stop writes/rewards until reopening. Cloud-verified endings are merged back into the device archive; pending answers survive network failures.
- Sources and the alternate-history editorial note open after solving. No fictional teammate is used as a correct answer.
- The profile opens the Kader Arşivi and displays up to three server-verified favorite cards. Hearts are device favorites; stars are the cloud showcase.

## Economy and safety

- First completed route per story: 10 coins +25 XP. First complete chapter: 60 coins +100 XP.
- All 24 stories and three chapters: exactly 420 coins and 900 XP. Second endings and replays never mint these again.
- Optional chapter ad bonus: +60 coins once per chapter, maximum +180 coins. XP never doubles.
- One free hint per route; stronger support costs 10 coins or uses an optional SSV-verified ad (Pro follows the existing no-ad benefit).
- New placements `what_if_hint` / `what_if_double` are wired through prepare → verified AdMob SSV → retryable settlement, not client callbacks. Test ads/no fill do not unlock server rewards. Existing global ad limits apply (up to four story bonuses daily).
- Private RTDB `whatIfState/{uid}` stores answer-verified endings, hints, immutable reward entitlements and favorites. Client writes are denied. Callable endpoints require Google-linked auth + App Check.
- Wallet receipts use `what_if_v1__*`; XP receipts use `what_if__*` in the existing retained progression receipt map. Player Journey IDs are not reused. Partial wallet/XP failures repair on status retry.
- Four zero-coin badges integrate into the existing collection: first story, eight stories, all 24, twelve dual endings. Account deletion removes What If server state.

## Content policy

The speculative routes are game fiction, not assertions that negotiations or contracts existed. Removed the old volcano-caused-a-signed-transfer, fixed-fax-only, political-certainty and guaranteed-trophy claims. Zidane's career pivot uses the documented 1996 move instead of an unverified 1995 quote. Actual transfers and career information are linked to club/competition sources in the catalog. Choices are curated; no runtime fetch or roster mutation is required.

`tools/what_if/build_catalog.py` generates identical client/server JSON. `tools/what_if/verify.py` checks identity, five mechanics, 48 endings, pre-solve text and economy totals. Changing answers requires coordinated catalog/version review.

## Deployment and acceptance

Based on the Player Journey finalization plus the dependency fix from PR34; no remote main rewrite or Firebase deployment is performed by this change.

```powershell
git fetch origin
git switch codex/what-if-v2
flutter pub get
npm.cmd --prefix functions ci
$env:FUNCTIONS_DISCOVERY_TIMEOUT="60"
firebase deploy --only "functions,database" --project sharedix
flutter run --no-enable-impeller
```

Run commands separately and stop at errors; never discard local edits to switch branches. This deploy adds getWhatIf, submitWhatIf, buyWhatIfHint and setWhatIfShowcase and updates rewarded ad settlement. Live AdMob needs production ad units, consent eligibility and the existing SSV configuration. Unit/widget/CI coverage does not replace a physical-device smoke test or a real production-ad verification.

Acceptance: both routes per chapter; close/reopen mid-question; offline completion then sync; repeat submission; free/paid/ad hint; cancel/no-fill; chapter bonus; second ending with no additional XP; archive/profile favorite; account switch; 320px/large text and light/dark layouts. Automated validation results are recorded in the PR.
