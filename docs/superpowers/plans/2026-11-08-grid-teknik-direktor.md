# Grid Teknik Direktör Kriteri Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "teknik direktör" criterion (player was at a club during that coach's tenure there) to bot, friend and online Grid, with 50 famous coaches and 1–2 coach criteria per board.

**Architecture:** A one-off tool fetches the 50 coaches' club tenures from Wikidata into a reviewed JSON file. The PvP catalog builder turns tenures × dated career spells into a per-player `coaches` list and `coach:<id>` criteria, and seeds coach criteria into online boards and random pairs. `pvp_engine.matches` and the bot Grid's criterion index learn the `coach` type, so validation, bot answers, Tersten and hints work unchanged.

**Tech Stack:** Python 3 (`py -3`, sqlite3, urllib), Node Functions (`node --test`, eslint max-len 120), Flutter.

**Spec:** `docs/superpowers/specs/2026-11-08-grid-teknik-direktor-design.md`

## Global Constraints

- Rule: a player matches `coach:<id>` iff one of his career spells at club C overlaps, by at least 1 day, a tenure of that coach at club C (loans count).
- 50 coaches: ~25 known in Turkey + ~25 world famous; list in `tools/pvp/coach_pool.json`.
- Tenures from Wikidata only (no key, no paid plan), fetched once into `tools/pvp/coach_tenures.json`; no network at game time.
- A coach is board-eligible only with ≥15 member players and ≥5 of them with `rank <= 3000`.
- Per board: at most 2 coach criteria; target mix ≈60 % one coach, ≈15 % two, rest none; never coach × coach in one cell.
- Online/ranked: `pvp_engine.RULE` becomes `"PVP_RULES_V2"`; rooms created under V1 finish under V1.
- Criterion shape: `{id: "coach:<coachId>", type: "coach", value: "<coachId>", label: "<name>", avatarKey?: "<key>"}`.
- **Owner gate:** after Task 1 the generated `coach_pool.json` and `coach_tenures.json` (with the unmapped report) are shown to the owner; Tasks 2+ start only after the owner approves or edits them.
- Commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; LF line endings; never commit `pubspec.lock`, `cloud_bootstrap.dart`, `build_local_apk.ps1`, Stitch export folders.

## Review Focus

1. A coach with two spells at the same club (e.g. Terim at Galatasaray several times) → every spell counts; a player between the spells does not match (Task 2 test).
2. A player spell with open end (`end_date` null = still there) → treated as ongoing to today (Task 2 test).
3. A Wikidata tenure with no start date or a club that cannot be mapped → dropped and listed in the report, never guessed (Task 1 test).
4. Bot Grid pool restricted to the player's chosen clubs → coach rows/cols still obey "≤2 coaches, no coach×coach" and the board stays fair (Task 4 test).
5. An open V1 online room after deploy → still validates with V1 rules (Task 3 test).

---

### Task 1: Coach pool and tenure fetch tool

**Files:**
- Create: `tools/pvp/coach_pool.json`, `tools/pvp/fetch_coach_tenures.py`, `tools/pvp/coach_tenures.json` (generated), `tools/pvp/coach_tenures_report.md` (generated), `tools/pvp/test_coach_tenures.py`, `tools/pvp/fixtures/wikidata_terim.json` (saved SPARQL response used by the test)

**Interfaces:**
- Produces `coach_pool.json`: `[{"coachId": "coach_171", "name": "Fatih Terim", "wikidata": "Q312931"}, ...]` (50 rows; `coachId` from the `coaches` table; Wikidata ids looked up by name and recorded).
- Produces `coach_tenures.json`: `{"version": 1, "coaches": {"coach_171": [{"clubId": "141", "start": "1996-07-01", "end": "2000-06-30"}, ...]}}` — club ids are database `clubs.id` as strings; `end` null = ongoing.
- `fetch_coach_tenures.py` functions: `parse_tenures(sparql_json) -> list[dict]` (club QID, label, country, start, end), `map_club(label, country, clubs) -> str | None` (exact normalized name match within country, else alias table, else None), `build(pool, fetch) -> (tenures, report)`.

- [ ] **Step 1:** Write `test_coach_tenures.py` with: `test_parse_reads_start_end_and_club` (fixture → Galatasaray tenures with ISO dates), `test_missing_start_is_dropped` (row without start → not in output, listed in report), `test_unmapped_club_is_reported` (unknown club → report line, not in output), `test_multiple_spells_same_club_kept` (two Galatasaray tenures → two rows).
- [ ] **Step 2:** Run `py -3 -m pytest tools/pvp/test_coach_tenures.py -q`. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement the tool. SPARQL per coach: position held (P39) / employer (P108) or "head coach" on club items (P286) with qualifiers start (P580) / end (P582); restrict to association football clubs (P31/P279* Q476028). Normalize club names with the same `key()` as `build_catalog.py`. `__main__` reads the pool, fetches `https://query.wikidata.org/sparql` with a descriptive User-Agent and 1 s between requests, writes both JSON and the report.
- [ ] **Step 4:** Run the tests. Expected: PASS. Then run the tool for real and inspect the report: Fatih Terim must have Galatasaray tenures; Şenol Güneş must have a Beşiktaş tenure.
- [ ] **Step 5:** Commit `feat(grid-coach): coach pool and Wikidata tenure tool`. **Stop for the owner gate.**

### Task 2: Catalog — coach membership, criteria, online boards and pairs

**Files:**
- Modify: `tools/pvp/build_catalog.py`
- Create: `tools/pvp/test_coach_catalog.py`
- Regenerate: `functions/config/pvp_catalog.json.gz`

**Interfaces:**
- Consumes `coach_tenures.json`, `coach_pool.json`.
- Produces in the catalog: each player gains `coaches: [coachId, ...]` (sorted); criteria gain `coach:<id>` entries (shape in Global Constraints; `avatarKey` from `coaches_min.json` when present); `grids` (300 boards) contain coach criteria per the mix; `pairs` gain coach×club pairs (≥6 answers) used by online Grid Rastgele.
- Function: `coach_members(spells_by_player, tenures) -> dict[coachId, set[playerId]]` using full dates from `career_spells.start_date/end_date` (null end = today).

- [ ] **Step 1:** Write tests: `test_overlap_by_one_day_matches`, `test_spell_between_two_tenures_does_not_match`, `test_open_ended_spell_is_ongoing`, `test_ineligible_coach_not_on_boards` (<15 members or <5 known → never in grids/pairs), `test_board_mix_and_no_coach_cross` (over the 300 boards: no board with >2 coach criteria, no row-coach×col-coach, share with ≥1 coach between 0.65 and 0.85), `test_examples` (Hagi ∈ `coach:<Terim>` ∩ `club:<Barcelona>` and Talisca ∈ `coach:<Güneş>` ∩ `club:<Benfica>` when both players have dated spells; otherwise the test asserts and reports which spell is missing).
- [ ] **Step 2:** Run `py -3 -m pytest tools/pvp/test_coach_catalog.py -q`. Expected: FAIL.
- [ ] **Step 3:** Implement. Grid generation: draw the board's coach count from {0: 25 %, 1: 60 %, 2: 15 %}; place coaches as rows or columns (when 2, one row and one column is forbidden — both rows or both columns); keep every existing fairness check (≥3 answers per cell, one known answer, witness). Keep the RNG seed stable so non-coach boards stay reproducible.
- [ ] **Step 4:** Run the tests and `cd functions && node --test test/pvp.test.js test/bot_support.test.js test/grid_support.test.js`. Expected: PASS. Record catalog size before/after in the commit message.
- [ ] **Step 5:** Commit `feat(grid-coach): coach criteria in the PvP catalog`.

### Task 3: Engine — `coach` type, rule version

**Files:**
- Modify: `functions/pvp_engine.js` (`matches`, `RULE`), `functions/mission_events.js` only if it hard-codes the rule string
- Test: `functions/test/grid_coach.test.js`

**Interfaces:** `matches(c, p, id)` returns `p.coaches.includes(k.value)` for `k.type === "coach"`; `RULE = "PVP_RULES_V2"`.

- [ ] **Step 1:** Tests: `coach criterion matches its members only` (a member and a non-member from the catalog), `online grid_classic board with a coach validates a correct coach-cell answer`, `a room stored with PVP_RULES_V1 still settles` (seed a V1 room, finish it).
- [ ] **Step 2–4:** Run (FAIL) → implement → `node --test` whole suite + `npx eslint .` PASS.
- [ ] **Step 5:** Commit `feat(grid-coach): engine matches coach criteria`.

### Task 4: Bot Grid (classic, reverse, random)

**Files:**
- Modify: `functions/grid_support.js` (criterion index, `makePuzzle`, `common`, `fairColumns`), `functions/hints/grid.js` (`TYPE.coach = "Teknik direktör"`)
- Test: `functions/test/grid_coach.test.js`

**Interfaces:** `criterionPlayers` gains `coach:<id>` from `p.coaches`; `makePuzzle(r)` may put ≤2 coach criteria (never one as row and one as column); `common(r, i)` returns coach criteria shared by the three witnesses; reverse answers accept the coach's name (and aliases via `labelKey`).

- [ ] **Step 1:** Tests: `bot classic boards carry at most 2 coaches and never coach×coach` (200 seeds), `bot reverse accepts a shared coach name`, `bot random can draw a coach pair`, `restricted club pool keeps the coach rules and fairness` (Review Focus 4), `Kriter türü hint can say Teknik direktör`.
- [ ] **Step 2–4:** Run (FAIL) → implement → whole suite + eslint PASS.
- [ ] **Step 5:** Commit `feat(grid-coach): bot Grid boards with coaches`.

### Task 5: App — coach criterion card

**Files:**
- Modify: `lib/screens/supported_grid_page.dart` and the online Grid board widget that renders criteria (find with `grep -rn "'label'" lib/online lib/screens | grep -i grid`)
- Test: `test/supported_grid_test.dart`

**Interfaces:** a criterion map with `type == 'coach'` renders the coach name with `CoachAvatar(avatarKey)` when `avatarKey` is present, otherwise the name with a small "TD" tag.

- [ ] **Step 1:** Widget test `coach criterion shows the coach name and TD tag` (fixture criterion `{type: 'coach', label: 'Fatih Terim'}`).
- [ ] **Step 2–4:** Run (FAIL) → implement → `flutter test --no-pub` + `flutter analyze` PASS.
- [ ] **Step 5:** Commit `feat(grid-coach): coach criterion card`.

### Task 6: Rollout notes and memory check

**Files:** Modify `docs/operations/beta-flags.md` (deploy note: catalog + RULE change, functions deploy), measure `require('./grid_support')` and `require('./pvp')` RSS with the new catalog (must stay under 512 MiB with headroom; raise only if needed).

- [ ] **Step 1:** Measure and record. **Step 2:** Full suites (`node --test`, `flutter test --no-pub`). **Step 3:** Commit `docs(grid-coach): rollout note`.
