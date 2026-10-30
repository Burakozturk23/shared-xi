"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, createService} = require("../three_modes");
const version = catalog.version;
let seq = 0;
const id = () => (++seq).toString(16).padStart(32, "0");
const players = new Map(catalog.players.map((p) => [p.id, p]));
const start = (h, mode, extra = {}) =>
  h.call("startThreeMode", {version, mode, entry: "random", requestId: id(), ...extra});
const act = (h, s, extra) => h.call("actThreeMode", {version, mode: s.mode, sessionId: s.id,
  revision: s.revision, requestId: id(), ...extra});
async function fill(h, s, n = 11) {
  const t = (s.mode === "coach_xi" ? catalog.coaches : catalog.letters).find((x) => x.id === s.targetId);
  const used = new Set();
  for (let slot = 0; slot < n; slot++) {
    const p = catalog.players.find((p) => !used.has(p.id) && p.position === s.slots[slot].position &&
      (s.mode === "coach_xi" ? t.links[p.id] : p.letters.includes(t.letter)));
    used.add(p.id); s = (await act(h, s, {action: "place", slot, playerId: p.id})).session;
  }
  return s;
}
test("every published letter/coach formation and vault is solvable with distinct known positions", () => {
  assert.equal(catalog.players.length, 36391);
  for (const t of [...catalog.coaches, ...catalog.letters]) {
    const pool = catalog.players.filter((p) => t.letter ? p.letters.includes(t.letter) : t.links[p.id]);
    for (const f of t.formations) {
      for (const pos of ["GK", "DEF", "MID", "FWD"]) {
        assert.ok(pool.filter((p) => p.position === pos).length >=
          catalog.formations[f].filter((x) => x === pos).length);
      }
    }
  }
  for (const p of catalog.puzzles) {
    assert.equal(new Set(p.players).size, 11);
    assert.deepEqual(p.players.map((id) => players.get(id).position), catalog.formations[p.formation]);
    assert.equal(new Set(p.initial).size, 3);
    assert.ok(p.quality.compatibleClubs >= 2 && p.quality.compatibleLeagueClubs >= 2);
  }
});
test("tenure pools: every coach has a dated source, every hard tenure fields an XI", () => {
  assert.ok(catalog.coaches.length >= 50);
  const ids = new Set(catalog.coaches.map((c) => c.id));
  // The seven original coaches keep their ids, so medals and avatars survive.
  for (const old of ["statsbomb_coach_94", "statsbomb_coach_56", "statsbomb_coach_790", "statsbomb_coach_36",
    "statsbomb_coach_181", "statsbomb_coach_793", "statsbomb_coach_81"]) assert.ok(ids.has(old), old);
  for (const c of catalog.coaches) {
    for (const ev of Object.values(c.links)) {
      for (const e of ev) {
        assert.ok(e.sources.length && /^\d{4}-\d{2}-\d{2}$/.test(e.date), c.name);
        assert.ok(e.sources.every((x) => catalog.sources[x] || x.startsWith("wikidata:")), c.name);
      }
    }
    for (const spell of c.spells) {
      const pool = catalog.players.filter((p) => (c.links[p.id] || []).some((e) => e.clubId === spell.clubId &&
        e.date <= spell.end && (e.until || e.date) >= spell.start));
      for (const f of spell.formations) {
        for (const pos of ["GK", "DEF", "MID", "FWD"]) {
          assert.ok(pool.filter((p) => p.position === pos).length >=
            catalog.formations[f].filter((x) => x === pos).length, c.name + " " + spell.id);
        }
      }
    }
  }
  assert.ok(catalog.sources["wikidata:tenures"].sha256);
});

test("hard Hoca 11 is one tenure: other-era players of the coach are wrong, the tenure's are right", async () => {
  const h = harness();
  const coach = catalog.coaches.find((c) => c.spells.length >= 2 &&
    c.spells.every((x) => x.formations.includes("433")));
  const spell = coach.spells[0];
  const inside = (e) => e.clubId === spell.clubId && e.date <= spell.end && (e.until || e.date) >= spell.start;
  let s = (await start(h, "coach_xi", {entry: "archive", target: coach.id, difficulty: "hard",
    spell: spell.id})).session;
  assert.equal(s.spell.id, spell.id); assert.match(s.context, new RegExp(spell.period));
  const slot = s.slots.findIndex((x) => x.position !== "GK");
  const pos = s.slots[slot].position;
  const other = catalog.players.find((p) => p.position === pos && coach.links[p.id] &&
    !coach.links[p.id].some(inside));
  const right = catalog.players.find((p) => p.position === pos && (coach.links[p.id] || []).some(inside));
  s = (await act(h, s, {action: "place", slot, playerId: other.id})).session;
  assert.equal(s.wrong, 1); assert.match(s.feedback, /farklı dönem/);
  s = (await act(h, s, {action: "place", slot, playerId: right.id})).session;
  // Feedback names the player's own years inside the tenure.
  assert.equal(s.slots[slot].player.id, right.id);
  assert.ok(s.feedback.includes(coach.links[right.id].find(inside).period || ""));
  assert.ok(s.slots[slot].evidence.every((e) => e.period));
  // Random hard games only draw coaches that have a playable tenure.
  for (let i = 0; i < 3; i++) {
    const r = await start(h, "coach_xi", {difficulty: "hard"}).catch((e) => e);
    if (r.session) assert.ok(r.session.spell);
  }
});

test("the official daily Hoca 11 pays 10 coin / 20 XP at eight correct", () => {
  assert.deepEqual(catalog.policy.daily.coach_xi, {coins: 10, xp: 20});
});

test("all three entrypoints require auth; general search does not leak correct answers via filtering", async () => {
  const h = harness();
  await assert.rejects(h.call("getThreeMode", {mode: "letter11"}, null), {code: "unauthenticated"});
  for (const mode of ["coach_xi", "letter11"]) {
    const r = await h.call("searchThreeMode", {version, mode, query: "Lionel Messi"});
    assert.ok(r.results.some((p) => p.name.includes("Messi")));
  }
  assert.ok((await h.call("searchThreeMode", {version, mode: "squad_vault", query: "Fenerbahce"})).results.length);
});
test("medals settle once across entries and preserve RTDB state", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  const t = catalog.letters[0];
  let s = (await start(h, "letter11", {entry: "archive", target: t.id})).session;
  s = await fill(h, s);
  const request = {version, mode: s.mode, sessionId: s.id, requestId: id(), revision: s.revision, action: "finish"};
  const [a, b] = await Promise.all([h.call("actThreeMode", request), h.call("actThreeMode", request)]);
  assert.equal(a.session.result.coins, 40); assert.equal(b.session.result.xp, 80);
  assert.equal(h.read("economyState/alice/balances/coins"), 40);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 80);
  s = (await start(h, "letter11", {entry: "archive", target: t.id})).session;
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.coins, 0);
  await h.call("getEnergyStatus");
  assert.equal(h.read(`economyState/alice/threeModes/collection/letter11__${t.id}/mastery`), true);
});
test("energy charges once only after valid content, resumes free, daily first free and retry costs one", async () => {
  const h = harness({runtimeConfig: {energy: {enabled: true, percent: 100,
    sessionModes: ["coach_xi", "letter11", "squad_vault"]}}}, {omitEmptyObjects: true});
  const request = {version, mode: "letter11", entry: "daily", requestId: id()};
  let s = (await h.call("startThreeMode", request)).session;
  assert.equal(s.dailyOfficial, true); assert.equal(s.energyCharged, false);
  await h.call("startThreeMode", request);
  await act(h, s, {action: "finish"});
  s = (await start(h, "letter11", {entry: "daily"})).session;
  assert.equal(s.energyCharged, true); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("resumeThreeMode", {version, mode: s.mode, sessionId: s.id});
  await act(h, s, {action: "finish"});
  await assert.rejects(start(h, "coach_xi", {entry: "archive", target: "missing"}), {code: "failed-precondition"});
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  h.setTime("2026-09-20T21:00:01Z");
  s = (await start(h, "letter11", {entry: "daily"})).session;
  assert.equal(s.dailyOfficial, true);
});
test("known wrong letter costs one; unresolved identities and unverified coach links do not", async () => {
  const h = harness(); let s = (await start(h, "coach_xi")).session;
  const coach = catalog.coaches.find((x) => x.id === s.targetId);
  const other = catalog.players.find((p) => p.position && !coach.links[p.id]);
  s = (await act(h, s, {action: "place", slot: 0, playerId: other.id})).session;
  assert.equal(s.wrong, 0); assert.match(s.feedback, /doğrulanmadı/);
  await assert.rejects(act(h, s, {action: "place", slot: 0, playerId: -999999}), {code: "invalid-argument"});
  s = (await start(h, "letter11")).session;
  const t = catalog.letters.find((t) => t.id === s.targetId);
  const wrong = catalog.players.find((p) => p.position && !p.letters.includes(t.letter));
  s = (await act(h, s, {action: "place", slot: 0, playerId: wrong.id})).session;
  assert.equal(s.wrong, 1);
});
test("formation reset is confirmed; daily fixed; free hint consumed once and mastery counts use", async () => {
  const h = harness(); let s = (await start(h, "letter11", {entry: "archive", target: catalog.letters[0].id})).session;
  s = await fill(h, s, 1);
  await assert.rejects(act(h, s, {action: "formation", formation: "442"}), {code: "failed-precondition"});
  s = (await act(h, s, {action: "formation", formation: "442", confirmReset: true})).session;
  assert.equal(s.score, 0);
  s = (await act(h, s, {action: "hint", slot: 0, hint: "country"})).session;
  assert.equal(s.freeHint, false);
  await assert.rejects(act(h, s, {action: "hint", slot: 0, hint: "country"}), {code: "resource-exhausted"});
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.mastery, false); assert.equal(s.result.coins, 30);
});
test("vault: three flags, five guesses, variants share tiers", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let s = (await start(h, "squad_vault")).session;
  assert.equal(s.slots.filter((x) => x.country).length, 3);
  assert.equal(s.club, null); assert.ok(s.slots.every((x) => x.player == null));
  const run = h.read(`economyState/alice/threeModes/sessions/${s.id}`);
  s = (await act(h, s, {action: "guess", clubId: Number(run.target)})).session;
  assert.equal(s.stars, 5); assert.equal(s.result.coins, 25);
  s = (await start(h, "squad_vault", {entry: "archive", target: run.target})).session;
  s = (await act(h, s, {action: "hint", hint: "player"})).session;
  assert.equal(s.stars, 3);
  s = (await act(h, s, {action: "guess", clubId: Number(run.target)})).session;
  assert.equal(s.result.coins, 0);
  s = (await start(h, "squad_vault", {entry: "league", league: "Süper Lig"})).session;
  assert.equal(s.stars, 4); assert.equal(s.league, "Süper Lig");
  await assert.rejects(act(h, s, {action: "hint", hint: "league"}), {code: "failed-precondition"});
  const target = h.read(`economyState/alice/threeModes/sessions/${s.id}/target`);
  const wrong = catalog.clubs.filter((x) => String(x.id) !== target).slice(0, 5);
  s = (await act(h, s, {action: "guess", clubId: wrong[0].id})).session;
  await assert.rejects(act(h, s, {action: "guess", clubId: wrong[0].id}), {code: "already-exists"});
  for (const c of wrong.slice(1)) s = (await act(h, s, {action: "guess", clubId: c.id})).session;
  assert.equal(s.finished, true); assert.equal(s.result.coins, 0); assert.equal(s.remaining, 0);
});
test("coach mastery gives fixed special reward once, later choice cannot duplicate it", async () => {
  const h = harness(); const coach = catalog.coaches.find((c) => c.avatarId);
  let s = (await start(h, "coach_xi", {entry: "archive", target: coach.id})).session;
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.mastery, true);
  await h.call("claimCoachMastery", {version, mode: "coach_xi", target: coach.id, choice: "coins"});
  await h.call("claimCoachMastery", {version, mode: "coach_xi", target: coach.id, choice: "avatar"});
  assert.equal(h.read("economyState/alice/balances/coins"), 40 + coach.avatarCoins);
  assert.equal(h.read("economyState/alice/inventory/" + coach.avatarId), null);
});
test("hint receipts are session bound, at most two and watching alone preserves mastery", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  const service = createService({db: h.db, normalize: (r) => r || {}, project: async () => {},
    isLinked: async () => false, getRollout: async () => ({}), now: () => h.now});
  let s = (await start(h, "letter11")).session;
  for (let credit = 0; credit < 2; credit++) {
    const benefit = await service.prepareHint("alice", "letter11_hint", {sessionId: s.id});
    const receipt = {id: id(), context: benefit.context};
    await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  }
  await assert.rejects(service.prepareHint("alice", "letter11_hint", {sessionId: s.id}), {code: "failed-precondition"});
  s = (await h.call("resumeThreeMode", {version, mode: s.mode, sessionId: s.id})).session;
  assert.equal(s.adCredits, 2); assert.equal(s.hints.length, 0);
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.mastery, true);
});
test("real ad pipeline requires verified receipt; cancellation and late callbacks cannot spend hints", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  const modeService = h.context.lbThreeModesService();
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const ads = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults, units: {android: unit},
    isLinked: async () => false, isPro: async () => false,
    prepareThreeReward: modeService.prepareHint, settleThreeReward: modeService.settleHint,
    grantCoins: async () => assert.fail("Hints cannot turn into coins"),
  });
  const s = (await start(h, "letter11")).session;
  const prepare = () => ads.prepare("alice", "android", "letter11_hint", id(), {sessionId: s.id});
  const event = (t) => ({user_id: "alice", custom_data: t.id, ad_unit: unit, timestamp: h.now,
    transaction_id: id(), reward_amount: "999999"});
  let {ticket} = await prepare();
  assert.equal(h.read(`economyState/alice/threeModes/sessions/${s.id}/adCredits`), 0);
  await ads.cancel("alice", ticket.id);
  await assert.rejects(ads.accept(event(ticket)), {code: "permission-denied"});
  for (let i = 0; i < 2; i++) {
    h.setTime(h.now + 31000); ({ticket} = await prepare());
    const receipt = event(ticket); await ads.accept(receipt); await ads.accept(receipt);
  }
  assert.equal(h.read(`economyState/alice/threeModes/sessions/${s.id}/adCredits`), 2);
  await assert.rejects(prepare(), {code: "failed-precondition"});
  const resumed = (await h.call("resumeThreeMode", {version, mode: s.mode, sessionId: s.id})).session;
  assert.equal(resumed.hints.length, 0);
});
test("daily bonus belongs to first official result, lost wallet projection repairs once", async () => {
  const h = harness(); let s = (await start(h, "letter11", {entry: "daily"})).session;
  s = await fill(h, s, 8);
  const request = {version, mode: s.mode, sessionId: s.id, requestId: id(), revision: s.revision, action: "finish"};
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("actThreeMode", request), /Simulated/);
  const result = await h.call("actThreeMode", request);
  assert.equal(result.session.result.coins, 25);
  assert.equal(h.read("economyState/alice/balances/coins"), 25);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 50);
  s = (await start(h, "letter11", {entry: "daily"})).session; s = await fill(h, s, 8);
  s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.coins, 0);
});
test("stale concurrent picks cannot overwrite a newer revision; late receipt cannot cross runs", async () => {
  const h = harness(); const s = (await start(h, "letter11")).session;
  await act(h, s, {action: "hint", slot: 0, hint: "country"});
  await assert.rejects(act(h, s, {action: "finish"}), {code: "aborted"});
  h.setTime(h.now + 86400001);
  const next = (await start(h, "letter11")).session;
  await h.context.lbThreeModesService().settleHint("alice", {id: id(),
    context: {sessionId: s.id, mode: s.mode, credit: 0}});
  assert.equal(h.read(`economyState/alice/threeModes/sessions/${next.id}/adCredits`), 0);
});
test("already owned coach avatar converts to frozen coins, distinct vault archive bonus is one-time", async () => {
  const h = harness(); const c = catalog.coaches.find((c) => c.avatarId);
  h.seed(`economyState/alice/inventory/${c.avatarId}`, {itemId: c.avatarId, itemType: "avatar", quantity: 1});
  let s = (await start(h, "coach_xi", {entry: "archive", target: c.id})).session;
  s = await fill(h, s); await act(h, s, {action: "finish"});
  await h.call("claimCoachMastery", {version, mode: s.mode, target: c.id, choice: "avatar"});
  assert.equal(h.read("economyState/alice/balances/coins"), 40 + c.avatarCoins);
  let total = 0;
  for (let i = 0; i < 6; i++) {
    s = (await start(h, "squad_vault")).session;
    const target = Number(h.read(`economyState/alice/threeModes/sessions/${s.id}/target`));
    s = (await act(h, s, {action: "guess", clubId: target})).session;
    total += s.result.coins;
  }
  assert.equal(total, 6 * 25 + 30);
});
test("RTDB numeric map/array conversion never counts null slots and preserves partial archives", async () => {
  const h = harness(); let s = (await start(h, "letter11")).session;
  s = await fill(h, s, 6);
  const path = `economyState/alice/threeModes/sessions/${s.id}`;
  const run = h.read(path);
  const sparse = Array.from({length: 11}, (_, i) => run.picks[i] || null);
  h.seed(path + "/picks", sparse);
  s = (await h.call("resumeThreeMode", {version, mode: s.mode, sessionId: s.id})).session;
  assert.equal(s.score, 6);
  s = (await act(h, s, {action: "clear", slot: 0})).session;
  assert.equal(s.score, 5);
  s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.coins, 5);
  const key = `economyState/alice/threeModes/collection/letter11__${s.targetId}`;
  h.seed(key + "/bestLineup", {"3": sparse[3]});
  h.seed(key + "/lastLineup", {"3": sparse[3]});
  const status = await h.call("getThreeMode", {mode: s.mode});
  const record = status.entries.find((e) => e.id === s.targetId).record;
  assert.equal(record.bestLineup.length, 11);
  assert.equal(record.bestLineup.filter(Boolean).length, 1);
  assert.equal(record.bestLineup[3].id, sparse[3]);
});
test("a previous-version daily is closed without blocking normal games and collections", async () => {
  const h = harness();
  h.seed("threeModeDaily/letter11__2026-09-20", {day: "2026-09-20", target: "obsolete",
    formation: "433", version: "old-release"});
  const status = await h.call("getThreeMode", {mode: "letter11"});
  assert.equal(status.dailyUnavailable, true); assert.equal(status.daily, null);
  assert.ok(status.entries.length > 0);
  await assert.rejects(start(h, "letter11", {entry: "daily"}), {code: "failed-precondition"});
  assert.ok((await start(h, "letter11")).session);
});
