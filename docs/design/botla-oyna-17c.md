# 17C.1 — Botla Oyna entry review

Started on 2026-09-14 at the user's request. The approved Ortak Saha palette and
Satoshi/Inter hierarchy remain the design foundation.

## This increment

- Five main choices remain in the existing order: Football Loto, Takım Yarışı,
  Grid, Futbol Çinko and Rastgele Beşler.
- Grid opens its three variants: Klasik, Tersten and Rastgele.
- Menu cards use shared surfaces, cyan icons, readable descriptions and compact
  rule labels. They support light/dark themes and scroll with enlarged text.
- Every playable variant has a pre-game page: goal, three short steps, scoring
  and an explicit action. Reading rules creates no board or timer.
- Loto's action says **Lig ve zorluk seç**; Takım Yarışı says **Takımını seç**.
  They open the existing configuration screens. The other variants say
  **Oyuna başla**.
- Menu/rules browsing no longer waits for the player database. Each actual
  play entry still passes through GameLauncher and its repository preparation.
  Existing bot entries require no authenticated or persistent account.
- Back returns from rules to the correct menu, then from Botla Oyna to Oyunlar.

## Rules verified against the existing controllers

| Game | Current scoring and objective |
| --- | --- |
| Football Loto | 16 players on separate 4×4 boards; +10 per correct placement, checked at the end. Player clocks are 20/15/12 seconds. |
| Takım Yarışı | Shared-player race; +1 per player. First to three round wins takes the match; drawn rounds award no win. |
| Klasik Grid | +1 per owned cell. A horizontal, vertical or diagonal triple wins immediately; otherwise a full board is scored. |
| Tersten Grid | +1 for a valid common criterion of a row/column. All three players must match; valid alternative answers are accepted. Six axes in total. |
| Rastgele Grid | Club-pair creation and placement; +1 per owned cell, with the same triple/full-board win rule. |
| Futbol Çinko | Orthogonally connected cells, including L shapes. Correct cell +1, wrong cell −1. No diagonal connection. |
| Rastgele Beşler | The human and bot share five clubs within a round. After both turns, clubs are selected again. Five turns each; each matched club is +1. |

The old Beşler menu implied one fixed club set for the whole match; the new copy
explains the per-round renewal. Team-race copy does not promise a never-repeated
opponent. Reverse Grid copy reflects acceptance of alternative valid criteria.

## Gameplay fixes included

1. The three bot Grid wrappers now subscribe to their underlying controllers.
   Asynchronous puzzle readiness and subsequent grid changes reach the screen,
   instead of leaving the screen on its initial loading state.
2. The human turn closes immediately after a scored or incorrect attempt.
   The existing short visual handover delay no longer permits a second move.
3. Wrappers detach listeners on disposal. Underlying Grid initializers discard
   completion after disposal, avoiding late initialization notifications.

These changes preserve the current score values and win conditions.

## Validation

Nine new tests cover deferred readiness, immediate turn locking for valid and
invalid answers, disposal during a bot handover, data-gate preservation, all seven
pre-game routes, explicit single launch, light-theme restoration and responsive
layouts. The layout cases are 416×896 normal text in both themes, 320×568 at 200%,
and 700×400 at 200%.

The previous 17 tests remain in the suite. The current commit's analysis, tests
and Android debug compilation are reported on the integration PR. This increment
uses GitHub CI because the local execution environment is unavailable; no new
emulator screenshots or live device result are claimed.

## Remaining mode review

This is the entry-flow increment, not closure of the whole bot category.

1. **Football Loto:** match layout and result review, readiness/error recovery,
   timer and pass behavior, difficulty balance.
2. **Takım Yarışı:** modern club selection and match screens; opponent coverage,
   suggestion fairness, selected-player identity, and round/result handling.
3. **Grid variants:** complete board UX, solvable generation/fallbacks, player
   identity, random-grid placement validation, and bot decision quality.
4. **Futbol Çinko:** cell readability, selection/feedback, remaining valid moves,
   pass/end behavior and bot balance.
5. **Rastgele Beşler:** club/answer presentation, editable rejected answers,
   round progression, replay and bot balance.

Inspect and settle these one mode at a time before marking Botla Oyna complete.
The other six catalog groups retain the user's approved membership and order.

## Football Çinko follow-up — 2026-09-15

The bot Çinko route now prepares its own V4 answer session and uses the Ortak
Saha match interface. It adds explicit difficulty selection, pass, exhausted-board
termination, connected-component bot decisions, pause/replay handling, readable
zoomable cells and per-move feedback. See [the Çinko review](football-cinko-bot.md)
for exact rules, data semantics and validation coverage. This does not close the
remaining Grid variants or Rastgele Beşler review.
