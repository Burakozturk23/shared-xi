# Derby Day V2 — eighth story mode

48 independent rivalries, 16 countries, five mechanics, one passport stamp per task.
This branch is based on `codex/football-docu-series-v2` (PR #42), preserving the previous seven modes and V4 data pipeline. It does not merge that chain into main or deploy production.

## Content scope and provenance

`Derby_Day_V2_Final.pdf` (11 October 2026) finalizes **only tasks 41–48**; it proposes mechanics for the original 40. This implementation completes the separate content work for 1–40 with original Turkish questions and primary source references. Those questions are marked `sourced_expansion`, not represented as PDF-approved text. Tasks 41–48 are marked `pdf_final`. Editorial review can happen independently without changing rivalry IDs.

- `tools/derby_day/editorial.py`: all prompts, choices, hints, historical scopes and source URLs.
- `intros.py`: separate, spoiler-free introductions. Questions appear only after Start.
- `legacy_pairs.json`: frozen original 40 ordered club pairs, from the PR #42 base.
- `identities.json`: exact canonical V4 IDs and mode-specific display names/countries.
- `portraits.json`: reviewed existing player identities; unresolved portraits use initials, never guessed photos.
- `functions/config/derby_day_catalog.json`: private answer keys, explanations, periods, source metadata.
- `assets/data/derby_day_v2.json`: public catalog, without answers, results, portrait identity or verification records.

Regenerate with `python tools/derby_day/build_catalog.py`; verify with `python tools/derby_day/verify.py`.

Historical questions explicitly distinguish score order, full time, extra time, penalties and aggregate scores. Chivas is scoped to its 7 November 2012 statement; Betis to the 2023–24 season. The Nacional 35-goal claim follows Nacional's own Clásico archive scope. Free hints were rewritten where the PDF hint effectively supplied the answer. Timeline dates are revealed after success. No live match feed or StatsBomb events/lineups download is required.

## V4 identity review

| Rivalry | V4 IDs | Disambiguation |
|---|---|---|
| Kızılyıldız / Partizan | 159 / 669 | Belgrade career links; existing competition labels are inaccurate and not used by this mode |
| Genoa / Sampdoria | 252 / 1038 | Existing canonical Italian clubs |
| Grêmio / Internacional | 210 / 6600 | Porto Alegre clubs |
| Rosario / Newell’s | 1418 / 1286 | ID 1286 has a truncated DB display name; mode supplies reviewed display name |
| Adana Demirspor / Adanaspor | 3840 / 6 | Reject similarly named 54291, whose career links are Belgian |
| Kocaelispor / Sakaryaspor | 120 / 2463 | Existing canonical Turkish clubs |
| Peñarol / Nacional | 1000000861 / 1000000866 | Uruguay; not Nacional 1000007098 |
| América / Chivas | 3631 / 6711 | Mexico; not Spanish CD Guadalajara 16576 |

No SQLite binary, shared club identity or player pool was rewritten. The reviewed display overrides are confined to this mode. Global metadata cleanup remains a separate V4 reviewed-patch task. Direct player link evidence used for disambiguation includes Valverde/Núñez/Pellistri for Peñarol and Suárez/Muslera/Coates for Nacional; Belgrade career links distinguish IDs 159/669 despite inaccurate competition strings.

## Flow and persistence

Atlas → spoiler-free city/club introduction → task → verified answer/source → dated passport stamp. Five differentiated presentations: scoreboard, city/stadium clues, draggable timeline with accessible arrow buttons, two-shirt career card, hidden legend portrait (revealed only after completion). Search folds Turkish accents/case; country, club, mechanic and progress filters can be combined. Passport is also available from the profile.

Old country/list routes forward into the atlas. The old common-player Derby implementation had no per-rivalry passport state; existing global progression/economy is preserved. New state is isolated under `derbyDayState/{uid}`, local drafts under `derby_day.v1.{uid}`. Correct answers are verified by callable Functions, with authenticated UID and enforced App Check. RTDB client access to private state is denied. `deleteMyAccount` clears the new server state. Signing the same anonymous UID into Google unlocks pending rewards; changing UID never reuses another account's local cache.

Offline drafts and bounded per-task submission queue survive restart. Offline success is not invented. Server replays and interrupted wallet/XP projection retry the same receipt. Premium status and price are server-derived; optional help requires confirmation. No forced advertisement.

## Economy

| Achievement | Coin | XP |
|---|---:|---:|
| Each task, once | 8 | 20 |
| 10 stamps: Derbi Gezgini | 40 | 100 |
| 25 stamps: Rekabet Kaşifi | 60 | 150 |
| 48 stamps: Derbi Ustası | 80 | 200 |
| Complete mode, including milestones | **564** | **1410** |

First hint is free. Extra help costs 6 Coin, or 0 with server-verified Pro; it eliminates two wrong choices or reveals the first timeline card. Repeat purchases and replay never charge/grant twice.

## Verification and release

Local gates: deterministic catalog/V4 verifier; all Functions tests; ESLint. CI gates: all Flutter tests, five mechanics at 320 px / 180% text in light/dark themes, real drag gesture, actual submit/retry controls, passport/search, offline/disk/UID behavior, analyzer and Android debug compile. CI screenshots are uploaded as `derby-day-previews`.

A compiled debug APK and mocked widget tests do not replace an actual device / deployed App Check smoke test. After deployment, validate anonymous→Google linking, wallet sync, reload, source copy and both paid/free Pro help on your configured Android device. The agent does not deploy production.

See `powershell.md` for exact commands. Keep this branch on top of the previous mode branch until the PR chain is merged in order.
