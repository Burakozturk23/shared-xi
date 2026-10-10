# Türk Futbolu: Nostalji V2

The PDF's fourth story mode is now a separate archive, two-task chapter flow and album. It replaces the old generic `StoryJourneyPage` entry. The original 8-chapter Dart content remains for reference; its controller had no persisted checkpoint, so V2 does not invent migrated completions. Player Journey, WHAT IF and UCL task IDs, catalogs and state are unchanged.

## Content and mechanics

12 chapters / 24 tasks: 7 Sezonun Şifresi, 5 Efsane Kadro, 3 Tarihi Sırala, 5 Efsaneyi Tanı, 4 Kupa Yolu. Season and legend tasks use four explicit choices; squad tasks show a separate coach/player role; timeline tasks have accessible up/down controls; cup routes assign opponents to named rounds. All chapters are selectable; each chapter's second task requires its first task.

Chapter headings, eras, introductions and basic hints were checked for answer disclosure. Göztepe's quarter-final is explicitly a Hamburg withdrawal, not an on-field win. The 1996 winning scorer is Aykut Kocaman. Exact goal minutes are omitted where unnecessary. Historical membership and coaching roles are never presented as a match starting XI. Turkish/diacritic labels are preserved; opaque choice IDs avoid fuzzy player matching, surname collisions and transfer-database ID assumptions.

`tools/nostalgia/build_catalog.py` is the editorial source. Both small JSON runtime catalogs are generated from it; no raw datasets, photographs or newspaper scans are added. Every task includes a fixed ID, source URLs/access dates, explanation, free hint, strong hint, version and reviewed status. Source records are shown after answering. The content is independently paraphrased; source sites are credited, not copied or treated as a redistribution license.

## Progress and rewards

Local schema `turkish_nostalgia.v2.<uid>` stores stable task IDs, drafts, current phase, completed tasks and a pending answer queue. A different UID gets a different store. Signed-out/offline-only guest saves remain separate rather than being copied to another person's account. The auth listener disposes the old controller; late responses are ignored. Writes use ordered deep snapshots; malformed local JSON shows an explicit retry screen and is not silently overwritten.

Offline answers can advance the story and add a **pending** album card. They cannot mint money. `getTurkishNostalgia`, `submitTurkishNostalgia` and `buyTurkishNostalgiaHint` require authenticated App Check calls. The server validates version, exact answer keys, ordered sequences, task IDs and chapter order. Anonymous accounts may play; rewards settle only once that same UID is Google-linked. Local pending tasks sync in catalog order and survive failed connections. The toolbar's **Eşitle** retries synchronization.

| Event | Coin | XP | Count |
| --- | ---: | ---: | ---: |
| First task completion | 6 | 15 | 24 |
| First chapter completion | 15 | 30 | 12 |
| Full album | 60 | 120 | 1 |
| Total | 384 | 840 | |

`nostalgiaState/<uid>` is server-only. Coin and XP receipts use `nostalgia_v2__*`; hint debits use `nostalgia_v2_hint__*`. Durable outbox receipts repair interrupted settlements without paying twice. Account deletion removes this new namespace. No client-provided reward amount, Pro flag or completed-count is trusted.

Basic hints are always free. The PDF's optional strong-help choice is implemented as a **6 Coin one-time purchase per task**, free for server-verified Pro. A confirmation dialog shows the charge. Hint purchase retries recover using the wallet receipt. There is no nostalgia ad placement or simulated ad reward; no new SSV deployment is required for this selected coin/Pro path. Replays preserve the album and award no additional Coin/XP.

The profile has a Nostalji Albümü shortcut. The album contains twelve period cards and the in-mode Futbol Hafızası completion badge. A pending local card is explicitly distinguished from a server-confirmed card.

## Validation

```powershell
python tools/nostalgia/verify.py
flutter test test/turkish_nostalgia_test.dart
npm.cmd --prefix functions test
npm.cmd --prefix functions run lint
```

The server suite exercises all 24 answers, exact economy totals, concurrent replay, wrong sequence/IDs/versions, unauthorized calls, Pro spoofing, insufficient funds, interrupted hint and XP writes, account isolation and guest linking. Flutter tests exercise all-task offline completion/restart/sync, write failures, bad saves, late account responses, actual answer/retry controls, and all five mechanics at 320 px with 1.8x text in both themes. CI also runs the complete existing Flutter and Functions suites and builds the Android debug APK.

## PowerShell update and device run

Run in the existing project directory, after saving any personal edits:

```powershell
git fetch origin
git switch codex/nostalgia-v2
git pull --ff-only origin codex/nostalgia-v2
flutter pub get
npm.cmd --prefix functions ci
$env:FUNCTIONS_DISCOVERY_TIMEOUT = "60"
firebase deploy --only "functions,database" --project sharedix
flutter run --no-enable-impeller
```

The branch includes the latest UCL V2 base (`6904c83`). Deploying functions/rules is required for online reward and paid-help calls. The task itself does not perform a production deploy. Play a chapter via Hikâye Modu → Türk Futbolu: Nostalji, close/reopen after task one, finish task two, check the album, then replay to confirm the wallet does not increase again. Physical-device and live Firebase smoke remain release acceptance steps; local tests and CI do not represent those checks.
