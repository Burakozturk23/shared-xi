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
  const t = catalog.letters.find((x) => x.id === s.targetId);
  const used = new Set();
  for (let slot = 0; slot < n; slot++) {
    const p = catalog.players.find((p) => !used.has(p.id) && p.position === s.slots[slot].position &&
      p.letters.includes(t.letter));
    used.add(p.id); s = (await act(h, s, {action: "place", slot, playerId: p.id})).session;
  }
  return s;
}
test("every published letter formation and vault is solvable with distinct known positions", () => {
  assert.equal(catalog.players.length, 36391);
  for (const t of catalog.letters) {
    const pool = catalog.players.filter((p) => p.letters.includes(t.letter));
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
test("Hoca 11 is removed: its mode, catalog and mastery callable are gone", async () => {
  assert.equal(catalog.coaches, undefined);
  assert.equal(catalog.policy.daily.coach_xi, undefined);
  const h = harness();
  await assert.rejects(h.call("getThreeMode", {mode: "coach_xi"}), {code: "invalid-argument"});
  await assert.rejects(start(h, "coach_xi"), {code: "failed-precondition"});
  assert.equal(h.context.exports.claimCoachMastery, undefined);
});
test("all three entrypoints require auth; general search does not leak correct answers via filtering", async () => {
  const h = harness();
  await assert.rejects(h.call("getThreeMode", {mode: "letter11"}, null), {code: "unauthenticated"});
  for (const mode of ["letter11"]) {
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
    sessionModes: ["letter11", "squad_vault"]}}}, {omitEmptyObjects: true});
  const request = {version, mode: "letter11", entry: "daily", requestId: id()};
  let s = (await h.call("startThreeMode", request)).session;
  assert.equal(s.dailyOfficial, true); assert.equal(s.energyCharged, false);
  await h.call("startThreeMode", request);
  await act(h, s, {action: "finish"});
  s = (await start(h, "letter11", {entry: "daily"})).session;
  assert.equal(s.energyCharged, true); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("resumeThreeMode", {version, mode: s.mode, sessionId: s.id});
  await act(h, s, {action: "finish"});
  await assert.rejects(start(h, "letter11", {entry: "archive", target: "missing"}), {code: "failed-precondition"});
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  h.setTime("2026-09-20T21:00:01Z");
  s = (await start(h, "letter11", {entry: "daily"})).session;
  assert.equal(s.dailyOfficial, true);
});
test("known wrong letter costs one; unresolved identities do not", async () => {
  const h = harness(); let s = (await start(h, "letter11")).session;
  // The app's slot-machine reel lands on the letter the server drew.
  const drawn = catalog.letters.find((l) => l.id === s.targetId);
  assert.equal(s.letter, drawn.letter); assert.equal(s.letterDifficulty, drawn.difficulty);
  await assert.rejects(act(h, s, {action: "place", slot: 0, playerId: -999999}), {code: "invalid-argument"});
  assert.equal(s.wrong, 0);
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
test("distinct vault archive bonus is one-time", async () => {
  const h = harness(); let s; let total = 0;
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

test("Kadro Kasası: a duplicate V4 row of the right club wins, and is never listed", async () => {
  const az = catalog.clubs.find((c) => c.canonicalId === 1090);
  assert.ok(az && !az.searchable);
  const h = harness();
  h.seed("economyState/alice/threeModes/collection/squad_vault__1090", {solved: true, best: 1});
  let s = (await start(h, "squad_vault", {entry: "archive", target: "1090"})).session;
  s = (await act(h, s, {action: "guess", clubId: az.id})).session;
  assert.equal(s.finished, true); assert.equal(s.won, true); assert.equal(s.wrong, 0);
  const hits = (await h.call("searchThreeMode", {version, mode: "squad_vault", query: "AZ Alkmaar"})).results;
  assert.deepEqual(hits.map((c) => c.id), [1090]);
});

test("Kadro Kasası search: playable clubs only, best known first, common short names", async () => {
  const h = harness();
  const find = async (query) =>
    (await h.call("searchThreeMode", {version, mode: "squad_vault", query})).results.map((c) => c.name);
  assert.equal((await find("man utd"))[0], "Manchester United");
  assert.equal((await find("real"))[0], "Real Madrid");
  assert.equal((await find("spurs"))[0], "Tottenham Hotspur");
  assert.ok(!(await find("kulupsuz")).length);
  const fc = (await find("fc")).slice(0, 30);
  assert.ok(fc.includes("FC Barcelona"));
});

test("Kadro Kasası random play reaches unsolved clubs first", async () => {
  const h = harness();
  const open = catalog.vaultClubs[0];
  for (const id of catalog.vaultClubs.slice(1)) {
    h.seed(`economyState/alice/threeModes/collection/squad_vault__${id}`, {solved: true, best: 1});
  }
  for (let i = 0; i < 3; i++) {
    const s = (await start(h, "squad_vault")).session;
    assert.equal(Number(h.read(`economyState/alice/threeModes/sessions/${s.id}/target`)), open);
    await act(h, s, {action: "guess", clubId: catalog.clubs.find((c) => c.searchable && c.id !== open).id});
    for (let g = 0; g < 4; g++) {
      const cur = (await h.call("resumeThreeMode", {version, mode: "squad_vault", sessionId: s.id})).session;
      if (cur.finished) break;
      const used = new Set(h.read(`economyState/alice/threeModes/sessions/${s.id}/guesses`));
      const wrong = catalog.clubs.find((c) => c.searchable && c.id !== open && !used.has(c.id));
      await act(h, cur, {action: "guess", clubId: wrong.id});
    }
  }
});

test("Today's vault is one puzzle for everyone, hides the club and pays the daily bonus once", async () => {
  const h = harness();
  const status = await h.call("getThreeMode", {mode: "squad_vault"});
  assert.ok(status.daily.day); assert.equal(status.daily.target, undefined);
  let s = (await start(h, "squad_vault", {entry: "daily"})).session;
  assert.equal(s.dailyOfficial, true); assert.ok(["easy", "medium", "hard"].includes(s.difficulty));
  const target = Number(h.read(`economyState/alice/threeModes/sessions/${s.id}/target`));
  s = (await act(h, s, {action: "guess", clubId: target})).session;
  // 5 stars: 25 vault coins + the daily 10.
  assert.equal(s.result.coins, 25 + catalog.policy.daily.squad_vault.coins);
  const again = (await start(h, "squad_vault", {entry: "daily"})).session;
  assert.equal(again.dailyOfficial, false);
  assert.equal(Number(h.read(`economyState/alice/threeModes/sessions/${again.id}/target`)), target);
});

test("Kadro Kasası variants differ: three formations, at most three shared players per club", () => {
  const byClub = new Map();
  for (const p of catalog.puzzles) byClub.set(p.clubId, [...byClub.get(p.clubId) || [], p]);
  for (const list of byClub.values()) {
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        assert.ok(list[i].players.filter((id) => list[j].players.includes(id)).length <= 3);
      }
    }
  }
  assert.deepEqual(new Set(catalog.puzzles.map((p) => p.formation)), new Set(["433", "4231", "352"]));
  assert.ok(catalog.puzzles.every((p) => ["easy", "medium", "hard"].includes(p.difficulty)));
  for (const p of catalog.puzzles) {
    assert.deepEqual(p.players.map((id) => players.get(id).position), catalog.formations[p.formation]);
  }
});

test("Harf 11 letter rule: the server reads the same letters the catalog was built with", () => {
  const {letterWord} = require("../three_modes");
  const alphabet = catalog.letters.map((l) => l.letter);
  for (const p of catalog.players) {
    for (const letter of alphabet) {
      assert.equal(!!letterWord(p, letter), p.letters.includes(letter), `${p.name} ${letter}`);
    }
  }
  const byName = (n) => catalog.players.find((p) => p.name === n);
  assert.deepEqual(byName("Virgil van Dijk").letters, ["D", "V"]);
  assert.ok(byName("Kevin De Bruyne").letters.includes("D"));
  assert.ok(byName("Selcuk Inan").letters.includes("İ"));
  assert.ok(alphabet.includes("W"));
});

test("Harf 11 says whether the letter or the position was wrong, and why a pick fits", async () => {
  const h = harness();
  const t = catalog.letters.find((l) => l.letter === "K");
  let s = (await start(h, "letter11", {entry: "archive", target: t.id})).session;
  const pos = s.slots[0].position;
  const noLetter = catalog.players.find((p) => p.position === pos && !p.letters.includes("K"));
  s = (await act(h, s, {action: "place", slot: 0, playerId: noLetter.id})).session;
  assert.match(s.feedback, /K ile başlamıyor/);
  const wrongPos = catalog.players.find((p) => p.position && p.position !== pos && p.letters.includes("K"));
  s = (await act(h, s, {action: "place", slot: 0, playerId: wrongPos.id})).session;
  assert.match(s.feedback, /bu yer .* için/);
  const right = catalog.players.find((p) => p.position === pos && p.name.startsWith("K") && p.letters.includes("K"));
  s = (await act(h, s, {action: "place", slot: 0, playerId: right.id})).session;
  assert.match(s.feedback, /^Doğru: .* · ".+" K ile başlıyor\.$/);
  assert.equal(s.wrong, 2);
});

test("Harf 11 daily letter is never a hard one; random play reaches unmastered letters first", async () => {
  const hard = new Set(catalog.letters.filter((l) => l.difficulty === "hard").map((l) => l.id));
  const h = harness();
  for (let d = 0; d < 40; d++) {
    h.setTime(Date.parse("2026-11-01T09:00:00Z") + d * 86400000);
    const status = await h.call("getThreeMode", {mode: "letter11"});
    assert.ok(!hard.has(status.daily.target), status.daily.target);
  }
  const g = harness();
  const open = catalog.letters.find((l) => l.difficulty === "medium");
  for (const l of catalog.letters) {
    if (l.id === open.id) continue;
    g.seed(`economyState/alice/threeModes/collection/letter11__${l.id}`, {mastery: true, best: 11});
  }
  for (let i = 0; i < 3; i++) {
    const s = (await start(g, "letter11")).session;
    assert.equal(s.targetId, open.id);
    await act(g, s, {action: "finish"});
  }
});

test("Harf Pasaportu pays at five completed letters, once", async () => {
  const h = harness();
  const done = catalog.letters.slice(0, 4);
  for (const l of done) h.seed(`economyState/alice/threeModes/collection/letter11__${l.id}`, {best: 11, solved: true});
  const fifth = catalog.letters.find((l) => l.difficulty === "easy" && !done.includes(l));
  let s = (await start(h, "letter11", {entry: "archive", target: fifth.id})).session;
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  const first = catalog.policy.passport[0];
  assert.equal(s.result.passport, 5);
  assert.equal(s.result.coins, 40 + first.coins);
  s = (await start(h, "letter11", {entry: "archive", target: fifth.id})).session;
  s = await fill(h, s); s = (await act(h, s, {action: "finish"})).session;
  assert.equal(s.result.passport, undefined); assert.equal(s.result.coins, 0);
});

test("Harf 11 name-pattern hint shows the matching word's start and length", async () => {
  const h = harness();
  const t = catalog.letters.find((l) => l.letter === "M");
  let s = (await start(h, "letter11", {entry: "archive", target: t.id})).session;
  s = (await act(h, s, {action: "hint", hint: "shape", slot: 0})).session;
  assert.match(s.feedback, /: "M._*" \(\d+ harf\)$/);
});
