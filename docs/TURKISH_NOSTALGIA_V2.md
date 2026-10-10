# Türk Futbolu: Nostalji V2

Implements the 10 October 2026 PDF in an independent namespace. Built on UCL Moments PR #37; Player Journey, What If, UCL answer IDs, progress and implementation files are unchanged.

## Content and sources

12 chapters / 24 stable task IDs: 7 season riddles, 5 season-role selections, 3 timelines, 5 legends and 4 cup routes. Each chapter has two different mechanics. Archive → spoiler-free introduction → two tasks → historical explanations → yearly album card. Categories: championship, Europe, national team, Anatolia. The sepia archive uses original Flutter shapes and typography, no copied newspaper/photo assets.

`tools/nostalgia/build_catalog.py` is the edited content source; it generates a private Functions catalog and an answer-redacted mobile asset. Source URLs, review date and A-status verification accompany every private task. Public assets contain neither answers, explanations, paid hints nor album stories. Historical facts are independently worded; raw archives are not redistributed. IDs are scoped to this mode, preserving Turkish characters and exact entities without fuzzy player matching. No heavy SQLite query is needed to open the mode. Season-role questions explicitly distinguish coaches from players and season squads from starting elevens.

Important corrections: Hamburg withdrew before Göztepe's quarter-final; Fenerbahçe's 103 is the official table total including forfeits; the Avni Aker winner is Aykut Kocaman, not Avdiç; UEFA records Semih's Croatia equalizer in minute 122. Opening headings hide the season/champion/defeat-count answers. Timeline hints describe neutral ordering context rather than printing the answer sequence.

## Progress, payments and support

- `nostalgia.v1.<uid>` local state; `nostalgiaState/<uid>` server state (client read/write denied).
- Offline drafts and up to 24 queued answers persist. Pending means **unverified**, never success. Submit order respects each chapter; a wrong first answer keeps the second queued until the first is corrected. Correct answers, explanations, album cards and receipts come from callable Functions only.
- Per task: 6 coin / 15 XP. Per complete chapter: 15 / 30. Full album: 60 / 120. Total **384 coin / 840 XP**. Retry/replay never pays twice. Coin and XP outbox steps use independent, stable idempotency keys, with recovery after interrupted writes.
- Anonymous users can solve. Rewards settle after Google is linked to the **same UID**; no progress/receipt transfer between unrelated users. Offline-only guests are separate from signed-in users; no implicit transfer.
- Free hint on every task. Optional stronger context costs 6 coins once per task, or is free with verified Pro. Explicit price confirmation and server price ceiling protect against stale Pro state. No mandatory or unverified advertisement pathway is added.
- Server validates version, IDs, exact ordered answers, auth and predecessor completion. App Check enabled on all three europe-west1 callables. Deleting an account deletes the new namespace.
- Completing all chapters unlocks the **Nostalji Arşivcisi** badge in the album; profile and guest profile link to the album. This is a mode collection badge, not a duplicated global achievement reward.
- Original 8-chapter content is retained inactive. The replaced generic journey did not persist progress, so migration does not invent completed tasks. Text revisions keep stable version/IDs; breaking schema changes require deliberate migration.

## Validation

`python3 tools/nostalgia/verify.py` checks counts, source fields, option keys, spoiler-sensitive headings, redaction and economy. Functions tests exercise the actual exported handlers through the existing transaction harness, plus real SDK bootstrap. Flutter tests cover all tasks, retries/replay, a 24-answer offline/restart/ordered sync, a wrong predecessor, UID isolation, failed local storage, five mechanics, source expansion and coin confirmation. Both themes run at 320 px / 180% text with CI preview images. Existing mode regression tests and Android debug APK are included in CI.

Production Firebase deployment, a signed release and physical-device App Check are separate checks, not implied by unit/widget test success. No main merge or production deployment is performed by this PR.

## Windows PowerShell

From the app directory; preserve any local changes shown by `git status` before switching. Stop on the first failed command. Node 24 is required by Functions.

```powershell
git status --short
git fetch origin
git switch codex/turkish-nostalgia-v2
git pull --ff-only origin codex/turkish-nostalgia-v2
flutter pub get
npm.cmd --prefix functions ci
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions,database" --project sharedix
flutter devices
flutter run --no-enable-impeller
```

Open **Oyunlar → Hikâye → Türk Futbolu: Nostalji**. With a Google-linked test account, complete one task, confirm 6 coin/15 XP once, close/reopen, repeat without another payment, finish the second task for the chapter bonus, and open the album from profile. In airplane mode queue answers, restart, reconnect and press Eşitle. Check both free and paid/Pro help; cancelling the confirmation must not debit coins.
