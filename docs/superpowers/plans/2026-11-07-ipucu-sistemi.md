# İpucu Sistemi v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 7-product support system with 9 typed hints + Pro Joker, a per-mode menu of many hints (2 suggestions + all), once-per-board rule and one shared panel, in all 39 modes at once.

**Architecture:** A new server kernel `functions/hints.js` (types, prices, pin, menu view, payment, ad credit) and one adapter per mode group under `functions/hints/` (static catalog + producible items + reveal). Modules keep their transactions and call the kernel instead of `boosts.js` when the run was pinned with policy `version: 2`; v1 runs keep `boosts.js` untouched until a later cleanup. One Flutter `HintPanel` replaces `PaidHintButton` / `StoreBoostPanel` / `StorySupportPanel` in 22 screens.

**Tech Stack:** Firebase Functions v2 (Node, `node --test`, eslint max-len 120), Realtime Database, Remote Config `linkball_prices_v1`; Flutter (`flutter test --no-pub`, `flutter analyze`).

**Spec:** `docs/superpowers/specs/2026-11-07-ipucu-sistemi-design.md`

## Global Constraints

- Bag types (inventory keys): `hint_milliyet`, `hint_mevki`, `hint_kulup`, `hint_donem`, `hint_harf`, `hint_ele` (light); `hint_isim`, `hint_baglanti`, `hint_aday` (strong); `hint_joker`.
- Titles: Milliyet, Mevki, Kulüp, Dönem, Harf, Ele, İsim, Bağlantı, Aday, Joker.
- Prices: light 25 single / 65 pack of 3; strong 50 / 130. Joker is never sold and never granted by ads. Prices overridable via `linkball_prices_v1` (`price_config.js`).
- Stock cap 99 per type (`MAX_STOCK`).
- Each menu item usable once per board (`boardKey`); new board resets. No other cap.
- Payment order: stock of the item's type → Joker (player taps "Joker kullan"; never automatic) → ad ("Reklam izle · +1"; strong item needs 2 ad credits) → Coin ("Coin ile al", also shown as small link while ads remain). Purchase is spent immediately on the tapped item.
- Ads: 4 per day shared (existing), per run 2 (daily runs 1), no ads in Football Loto, timed clocks never pause.
- Any hint marks the run Yardımlı: `assisted = true`, `masteryEligible = false`, `leaderboardEligible = false`.
- Every hint text comes from server catalog data; an item that cannot be produced on this board is omitted from the menu, and a direct request for it fails with `failed-precondition` and charges nothing.
- Online/ranked PvP gets no hints.
- Joker stays usable after Pro ends; only Pro sources grant it.
- Rollout: `runtimeConfig/boosts` gains `version: 2`; all 39 `readyModes`; accounts whose policy is not v2 stay on `boosts.js`; a run finishes in the system it was pinned with.
- Copy is Turkish; commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; never commit `pubspec.lock`, Stitch export folders, root `DESIGN (1).md`, `code (1) (2).html`, `screen*.png`, `.superpowers/`; normalize CRLF→LF before commit; dart-format only files already formatted at HEAD.

## Review Focus

1. Double tap or network retry of the same `requestId` on a hint → exactly one charge and one reveal (test in Task 2).
2. Coin price changes between panel open and tap (`expectedPriceCoins` stale) → `failed-precondition`, nothing charged (Task 2).
3. Flag flips to v2 while a v1 run is open → that run keeps v1 supports to its end; next run is v2 (Task 3).
4. Item shown on one board but not producible on the next (e.g. no league data) → chip absent, stock untouched (Task 2 kernel test + each adapter test's "omits unproducible" case).
5. Verified ad arrives after the run ended or with stock at 99 → credit becomes stock of the tapped type, or stays pending at 99; never lost (Task 2, ported from `boosts.test.js`).

---

### Task 1: Hint types and prices

**Files:**
- Create: `functions/hints.js`
- Modify: `functions/price_config.js` (add `hintPrices(raw)`), `functions/config/linkball_prices.defaults.json`
- Test: `functions/test/hints.test.js`

**Interfaces:**
- Produces: `TYPES` (frozen map `id → {id, key: "hint_"+id, title, strong}` for the 9 types + `joker`), `priceOf(type, prices) → {single, pack}`, `MAX_STOCK = 99`, `price_config.hintPrices(raw) → {light:{single,pack}, strong:{single,pack}} | null`.

- [ ] **Step 1: Write failing tests** `hint types: nine sellable types, strong ones, Joker unsold` — asserts the 9 keys/titles from Global Constraints, `strong` true only for isim/baglanti/aday, `priceOf("milliyet")` = `{single:25, pack:65}`, `priceOf("isim")` = `{single:50, pack:130}`, `priceOf("joker")` throws; and `hint prices come from linkball_prices_v1 when set` (raw `{hints:{light:{single:30,pack:80}}}` → light 30/80, strong default).
- [ ] **Step 2: Run** `cd functions && node --test test/hints.test.js` — FAIL (module missing).
- [ ] **Step 3: Implement** `TYPES`, `priceOf`, `hintPrices` (invalid/missing values fall back to defaults, same validation style as `boostPrices`).
- [ ] **Step 4: Run** tests and `npx eslint hints.js price_config.js` — PASS, no errors.
- [ ] **Step 5: Commit** `feat(hints): hint types and prices`.

### Task 2: Kernel — pin, menu view, use, ads

**Files:**
- Modify: `functions/hints.js`
- Test: `functions/test/hints.test.js`

**Interfaces:**
- Consumes: Task 1.
- Produces (adapter contract, used by Tasks 4–12):
  ```js
  // adapter: {modes: string[], catalog: {[modeId]: [{id, label, type}]},
  //   board(run) -> string, items(run, ctx) -> [{id, label, type, why}],  // producible, priority order
  //   reveal(run, id, ctx) -> {text, apply?(run)}}                          // throws RewardError if not producible
  ```
  Kernel:
  - `pin(run, policy, e?, time?)`: if `policy?.version === 2` and the mode is ready, set `run.hintPolicy = {version: 2, modeId, daily, prices}` and `run.hintUses = {}`, run `convertLegacy(e, time)` when `e` is given, and return true. Otherwise return false, so the caller falls back to `B.pin`.
  - `active(run) → boolean`.
  - `view(run, adapter, ctx) → {version: 2, board, items: [{id, label, type, strong, price, used, result}], suggested: [lightId|null, strongId|null], ads: {remaining, allowed}, assisted}`.
  - `use(e, run, adapter, input, time, ctx) → {itemId, text}`. Input: `{itemId, paymentSource: "stock"|"joker"|"ad"|"coins", expectedPriceCoins?, requestId}`.
  - `adBenefit(run, itemId, benefit)`, `grantAd(run, receipt)`, `recoverAd(e, run, receipt, time, canApply)`, `recoverUnused(e, run, time)`.
  - `paymentFingerprint(input) → [itemId, paymentSource, expectedPriceCoins]`.
  - `convertLegacy(e, time) → {added, converted, gained}`.

- [ ] **Step 1: Write failing tests** (a fake adapter with 3 items: `a` light `milliyet`, `b` light `kulup` that is unproducible when `run.noB`, `c` strong `isim`):
  - `use spends stock of the item type, reveals, marks Yardımlı`: `hint_milliyet` goes 2 → 1, `run.assisted === true`, `masteryEligible === false`, `leaderboardEligible === false`, `run.hintUses[board].a.text` set.
  - `same item twice on one board is refused and charges nothing; a new board allows it` (error code `already-exists`).
  - `different item on the same board is allowed`.
  - `unproducible item is absent from view and refused by use` (`failed-precondition`, stock unchanged).
  - `joker pays for any item only when the player picks joker`: with `hint_isim` 0 and `hint_joker` 1, `paymentSource:"stock"` is refused (`resource-exhausted`), but `"joker"` succeeds.
  - `coins: exact quoted price only`: stale `expectedPriceCoins` → `failed-precondition` with coins unchanged; correct → coins −25 (light) / −50 (strong), and a purchase record is written.
  - `ad credits: light needs 1, strong needs 2; Loto-style adapter can disable ads`.
  - `suggested is first unused producible light and strong, in adapter order`.
  - `late verified ad becomes stock of its type; at 99 it stays pending` (ported cases from `boosts.test.js`).
  - `legacy conversion maps each old item once`: Temel → Milliyet, Tek seçenek ele → Ele, Bağlantı → Bağlantı, Güçlü → İsim, İlk harf → İsim, Son harf → Harf, Harf karışımı → İsim. The 99 cap leaves the remainder as old stock, and a second call adds nothing.
- [ ] **Step 2: Run** `node --test test/hints.test.js` — FAIL.
- [ ] **Step 3: Implement** the kernel. Port receipt, ad and recovery logic from `boosts.js` `consume` / `adBenefit` / `grantAd` / `recoverAd` / `recoverUnused`, keyed by `hint_<type>` instead of the SKU. The receipt key is `digest([run.id, puzzleVersion, board, itemId])`, stored in `run.hintUses[board][itemId]` and `e.storeUses["hint__"+key]`. The ad limit is `run.hintPolicy.daily ? 1 : 2`.
- [ ] **Step 4: Run** tests + eslint — PASS.
- [ ] **Step 5: Commit** `feat(hints): kernel with once-per-board rule, four payment sources, ad credit`.

### Task 3: Policy v2 routing

**Files:**
- Modify: `functions/boosts.js` (`policyFor` passes `version` through; `pin` returns early when `policy.version === 2`), `functions/hints.js` (`pinAny(run, policy, e, time)`: `H.pin` else `B.pin`)
- Test: `functions/test/hints.test.js`

**Interfaces:** Produces `H.pinAny(run, policy, e, time)`. Every module replaces `B.pin(r, policy)` with `H.pinAny(r, policy, e, time)` in its adapter task.

- [ ] **Step 1: Write failing tests:**
  - `v2 policy pins hints, v1 pins boosts`.
  - `a v1 run stays v1 after the flag becomes v2`: `B.paid(run)` stays true, `H.active(run)` stays false.
  - `readyModes off for a mode: neither pins`.
- [ ] **Step 2–4:** Run (FAIL) → implement → run + full `node --test` (all existing tests PASS, because no module calls `pinAny` yet).
- [ ] **Step 5: Commit** `feat(hints): route v2 policy to the hint kernel`.

### Adapter tasks (4–12): common shape

Each adapter task:
- creates `functions/hints/<group>.js` exporting the adapter (Task 2 contract);
- wires the module: start/pin → `H.pinAny`; `action: "hint"` with `H.active(run)` → `H.use`; session view adds `hints: H.view(...)` beside the existing `support` (v1 untouched); `prepareHint`/`settleHint` use `H.adBenefit`/`H.grantAd`/`H.recoverAd` when active; action fingerprint uses `H.paymentFingerprint`;
- writes `functions/test/hints_<group>.test.js` through the harness (`h.seed("runtimeConfig/boosts", {enabled:true, version:2, betaUids:{alice:true}, readyModes:{<modes>:true}})`) with these cases per mode: `menu lists the spec items in order`, `each item reveals text from catalog data` (assert against the catalog record), `once per board, reset on next board`, `omits unproducible item`, `v1 run unchanged` (one existing v1 test still passes);
- runs `node --test` (whole suite) and eslint; commits `feat(hints): <group> menus`.

Item ids, labels, types and board are exactly the spec §4.3 row; ✱ items are new reveal code. If a ✱ item cannot be produced from the catalog for most boards, the implementer leaves it out of `catalog` and lists it in the commit message (spec §8). Every mode except Higher or Lower must keep at least 3 items. If a mode drops below 3, the implementer stops and reports it.

### Task 4: Transfer Dedektifi + Kariyer Bulmacası
- Files: `functions/hints/career_transfer.js`, `functions/career_transfer.js` (`hintFor` stays for v1; v2 removes the fixed `["country","position","letter"][run.hints.length]` order), test `functions/test/hints_career_transfer.test.js`.
- Board: `run.id` (career: `run.id + ":" + run.phase`).
- Transfer items: `milliyet` Milliyet, `mevki_yas` Mevki ve yaş (mevki), `transfer_yili`✱ Transfer yılı (donem, `transfer.year`), `gelinen_lig`✱ Geldiği kulübün ligi (kulup, `fromClubId` league), `kulup_sayisi`✱ Kulüp sayısı (kulup), `ilk_harf` İlk harf (isim), `isim_sekli`✱ İsim şekli (isim, `"D _ _ _ O (5 harf)"`).
- Extra test: `transfer: İlk harf is usable first, before any other hint` (the user's bug).

### Task 5: Gizemli Futbolcu + Kariyer Zinciri
- Files: `functions/hints/mystery_chain.js`, `functions/mystery_chain.js`, test `hints_mystery_chain.test.js`. Board: `r.puzzle.id`.
- Gizemli Futbolcu: `sonraki_durak` Sıradaki durak (kulup; existing `nextHint`), `milliyet`✱, `mevki`✱, `ilk_harf`✱ (isim).
- Kariyer Zinciri: `kopru_kulup`✱ Köprü kulübü (kulup), `kopru_milliyet`✱ Köprü oyuncunun milliyeti (milliyet), `kopru_ad` Köprü oyuncunun adı (baglanti; existing).

### Task 6: Grid (solo + bot, 6 modes)
- Files: `functions/hints/grid.js`, `functions/grid_support.js`, test `hints_grid.test.js`. Board: `r.id`. Items target the selected cell (`input.target`); the once-per-board rule is per item, not per cell.
- Klasik/Rastgele: `milliyet`, `mevki`, `lig`✱ Bir ligi (kulup), `baska_kulup`✱ Başka bir kulübü (kulup), `ilk_harf`✱ (isim). A candidate must satisfy both of the cell's criteria and be unused.
- Tersten: `kriter_turu` Kriter türü (kulup; existing), `yanlis_kriter`✱ Bir yanlış kriteri ele (ele), `kriter_harf`✱ Kriterin ilk harfi (isim).
- Extra test: `bot turn: hint refused while the bot plays` (existing "Sıra botta").

### Task 7: Bot oyunları (Loto, Takım Yarışı, Çinko, Rastgele Beşler)
- Files: `functions/hints/bot.js`, `functions/bot_support.js`, test `hints_bot.test.js`. Board: Loto/Takım Yarışı `r.id`; Çinko and Rastgele Beşler `r.id + ":" + r.round`.
- Items per spec §4.3 rows. Loto adapter sets ads off; extra test `loto: no ad source offered, clock keeps running`.

### Task 8: Kadro (Kadro Kasası, Harf 11, Kadro Mücadelesi)
- Files: `functions/hints/squad.js`, `functions/three_modes.js`, `functions/squad_support.js`, test `hints_squad.test.js`. Board: `run.id`.
- Kadro Mücadelesi keeps the score cost: `aday_listesi` −10, `tek_aday` −20 (both type aday). Extra test asserts the score effect.

### Task 9: Kelime (Lingo, Mini/Haftalık Passaparola, Günün Anagramı, Sekizli Anagram)
- Files: `functions/hints/words.js`, `functions/daily_words.js`, `functions/anagram_practice.js`, test `hints_words.test.js`. Board: question/word id (`q.questionId || q.id`).
- Lingo/Passa: `harf_sayisi` (harf), `harf_yeri`✱ Bir harfin yeri (harf; a letter not yet revealed by the board), `milliyet`✱, `ilk_harf`✱ (isim). Anagram: `milliyet`, `mevki`, `son_harf`✱ (harf), `bir_kulup`✱ (kulup), `ilk_harf` (isim).

### Task 10: Günlük (Günün Sorusu, Günün Maçları, Günün Futbolcusu)
- Files: `functions/hints/daily.js`, `functions/daily_question.js`, `functions/daily_matches.js`, `functions/daily_footballer.js`, test `hints_daily.test.js`. Board: question id / match id / day key. All three are daily runs, so the ad limit is 1.
- Günün Sorusu: `bir_yanlis` (ele), `iki_yanlis`✱ (aday). The two never eliminate the same option. Extra test asserts this.

### Task 11: Arcade + Sahte Kulüp
- Files: `functions/hints/arcade.js`, `functions/arcade.js`, `functions/fake_club.js`, test `hints_arcade.test.js`. Board: Burst question index, Pyramid board id, Matching board id, Fake Club `r.question.questionId`.
- Pyramid and Matching are timed with no ad (existing). Burst: `ek_ipucu` (kulup), `ilk_harf`✱ (isim). Matching: `yanlis_eslesme`✱ (ele), `dogru_cift` (baglanti).

### Task 12: Seçim + Hikâye
- Files: `functions/hints/choice.js`, `functions/hints/story.js`, `functions/choice.js`, `functions/story_support.js`, tests `hints_choice.test.js`, `hints_story.test.js`. Board: choice question id; story task id.
- Story, all 8 modes: `gorev_ipucu` (donem), `bir_yanlis` (ele), `ilk_baglanti` (baglanti). Blind Ranking: `yari` (donem), `sira_dogrula`✱ (baglanti). Higher or Lower: `aralik` (donem).

### Task 13: Store, guide, legacy conversion, rewards, budget
**Files:**
- Modify: `functions/store_collection.js`, `functions/index.js` (`getStoreCatalog`, `purchaseEconomyOffer`), `functions/boost_guide.js` (v2 guide from adapters' `catalog`), `functions/season_pass.js`, `functions/pro_crate.js`, `functions/daily_return.js`, `index.js` daily-streak grant (~line 10414), `functions/config/economy_budget.json`, `functions/tools/economy_report.js` if it lists item ids
- Create: `functions/hints/index.js` (`ADAPTERS`, `modesFor(type) → modeId[]`)
- Test: `functions/test/hints_store.test.js`, update `season_pass.test.js`, `pro_crate.test.js`, `daily_return.test.js`, `store_collection.test.js`

**Interfaces:**
- Consumes: Task 2 `convertLegacy`, every adapter `catalog`.
- Produces: offers `hint_<type>_1` / `hint_<type>_3` with `modes: modesFor(type)` filtered by readyModes. `H.rewardItems(policy)` returns the v2 grant table when `policy.version === 2`, else the v1 table.

- [ ] **Step 1: Write failing tests:**
  - `v2 store sells 9 types × {1,3} at spec prices with game lists, no boost_* or letter packs, no Joker offer`.
  - `v2 store open converts legacy stock once and reports it`.
  - `Joker purchase refused`.
  - `season Pro step 5 grants 2 Joker, step 15 grants 3 Joker on v2`.
  - `Pro crate v2 = 8 Joker + 4 Milliyet + 4 Mevki + 2 Kulüp + 2 Harf`.
  - `Daily Return v2: day 3 Milliyet, day 7 İsim; all-missions bonus and streak Milliyet`.
  - `v1 accounts keep today's grants` (existing tests unchanged).
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Update the budget registry with the new item ids at the spec prices.
- [ ] **Step 4: Run** `node --test`, `npm run economy:check` and eslint. Expected: PASS.
- [ ] **Step 5: Commit** `feat(hints): store, guide, rewards and legacy conversion for v2`.

### Task 14: Flutter HintPanel
**Files:**
- Create: `lib/models/hint_menu.dart`, `lib/widgets/hint_panel.dart`
- Modify: `lib/services/store_gateway.dart` (bag read for `hint_*` keys if missing)
- Test: `test/hint_panel_test.dart`

**Interfaces:**
- Produces:
  - `HintMenu.fromSession(Map session) → HintMenu?`. It is null unless `session['hints']['version'] == 2`. Fields: `board`, `items: List<HintItem>`, `suggested: (String?, String?)`, `adsRemaining`, `adsAllowed`, `assisted`.
  - `HintItem{id, label, type, strong, price, used, result}`.
  - `HintButton(menu, bag, onUse, onWatch)`. It shows "İpucu al" and opens the panel.
  - `Future<void> showHintPanel(BuildContext, {required HintMenu menu, required Map<String,int> bag, required Future<void> Function(String itemId, String source) onUse, required Future<void> Function(String itemId) onWatch})`.

- [ ] **Step 1: Write failing widget tests:**
  - `shows two suggestion cards with why line, then all items as chips with stock or price`.
  - `used item is dimmed and shows its result`.
  - `stock → tap uses stock without a dialog, then AppFeedback pulse fires and the panel closes`.
  - `empty bag shows Reklam izle · +1 and a small Coin ile al link`.
  - `ads exhausted shows Coin ile al as the main action`.
  - `strong item with empty bag says 2 reklam`.
  - `Joker ×N appears only when bag joker > 0 and needs a tap`.
- [ ] **Step 2: Run** `flutter test --no-pub test/hint_panel_test.dart`. Expected: FAIL.
- [ ] **Step 3: Implement.** Use the Midnight Pitch tokens already used in `store_page.dart` and `AppFeedback` for the pulse.
- [ ] **Step 4: Run** the tests and `flutter analyze lib/widgets/hint_panel.dart lib/models/hint_menu.dart`. Expected: PASS, no issues.
- [ ] **Step 5: Commit** `feat(hints): shared hint panel`.

### Task 15: Wire the panel into the 22 screens
**Files:**
- Modify:
  - `lib/screens/`: `career_transfer_page`, `mystery_chain_page`, `supported_grid_page`, `supported_bot_page`, `build_xi_page`, `three_modes_page`, `daily_words_page`, `daily_question_page`, `daily_footballer_page`, `football_calendar_page`, `arcade_page`, `odd_club_page`, `choice_page`, `journey_v2_page`, `what_if_selection_page`, `ucl_moments_page`, `turkish_nostalgia_page`, `international_glory_page`, `dynasties_page`, `football_docu_page`, `derby_day_page` (all `.dart`);
  - the anagram screen. It is the one that calls `anagram_practice`; find it with `grep -rl "anagramPractice\|anagram_practice" lib/screens`.
- Test: update `test/paid_hint_button_test.dart`, `test/supported_grid_test.dart`, `test/supported_bot_test.dart`, `test/story_support_test.dart` with v2 session fixtures; add one `v2 session opens HintPanel and sends {action:"hint", itemId, paymentSource}` test per screen group (grid, bot, career/transfer, mystery, words, daily, arcade, choice, story).

**Rule for each screen:** when `HintMenu.fromSession(session) != null`, render `HintButton`, and the screen's existing act call sends `{'action': 'hint', 'itemId': id, 'paymentSource': source, if coins 'expectedPriceCoins': price}`. Otherwise keep the existing v1 widgets exactly.

- [ ] **Step 1:** Write the per-group failing tests.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Wire the screens group by group. Remove the transfer label bug only in the v2 path.
- [ ] **Step 4:** Run `flutter test --no-pub` (whole suite) and `flutter analyze`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(hints): v2 panel in all hint screens`.

### Task 15b: Store page for hints
**Files:** Modify `lib/screens/store_page.dart`, `lib/models/store_models.dart` (`boostCategory`/icons for `hint_*`: Hafif / Güçlü, `boostModeNames` already covers mode ids); Test `test/store_collection_test.dart`.
- [ ] **Step 1: Failing tests:** `v2 catalog shows 9 hint cards with "N oyunda çalışır" and opens the game list`, `Joker card: Pro sees "Pro'ya özel · ×N", free player sees a teaser that opens the Pro page`, `legacyConverted shows "Desteklerin yeni ipuçlarına çevrildi" once`, `filter chips: Tümü · Hafif · Güçlü · Paketler`.
- [ ] **Step 2–4:** Run (FAIL) → implement → `flutter test --no-pub test/store_collection_test.dart` + analyze PASS.
- [ ] **Step 5: Commit** `feat(hints): store page for typed hints and Joker`.

### Task 16: Rollout config and docs
**Files:**
- Modify: `docs/operations/cost-safety.md` (no change unless the callable count changes), `docs/economy/prices.md` (hint prices), `functions/test/app_check.test.js` (only if a callable was added)
- Create: `docs/operations/hints-v2-rollout.md`

**The rollout doc must contain:**
- the exact `runtimeConfig/boosts` value for the beta: `{enabled:true, version:2, public:false, percent:0, betaUids:{"O7BYGHPKy9T2KA3DIPvsd5xoFge2":true}, readyModes:{<all 39>:true}}`;
- the percent steps (10 → 50 → 100);
- the rollback, which is to remove `version`. v2 runs already open finish as v2.

- [ ] **Step 1:** Write the doc and price table.
- [ ] **Step 2:** Run `node --test`, `npm run economy:check`, `flutter test --no-pub` and `flutter analyze`. Expected: all green.
- [ ] **Step 3:** Commit `docs(hints): v2 rollout guide`. Deploy and the RTDB write are done by the owner.
