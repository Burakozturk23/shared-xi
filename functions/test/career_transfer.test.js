"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, cardsOf, maxChecks, players} = require("../career_transfer");
const version = catalog.version;
let n = 0;
const id = () => (++n).toString(16).padStart(32, "0");
const start = async (h, mode, extra = {}) => (await h.call("startCareerTransfer", {mode, version,
  difficulty: "normal", requestId: id(), ...extra})).session;
const act = async (h, s, extra) => (await h.call("actCareerTransfer", {mode: s.mode, version,
  sessionId: s.id, revision: s.revision, requestId: id(), ...extra})).session;
const privateRun = (h, s) => h.read(`economyState/alice/careerTransfer/sessions/${s.id}`);
const puzzle = (h, s) => (s.mode === "career" ? catalog.careers : catalog.transfers)
    .find((p) => p.id === privateRun(h, s).puzzle);
const solve = async (h, s) => {
  const p = puzzle(h, s);
  s = await act(h, s, {action: "guess", playerId: p.playerId});
  return s.mode === "transfer" ? s : act(h, s, {action: "order", order: cardsOf(p).map((x) => x.id)});
};
test("catalog uses unique events, disjoint difficulties and preserves return periods", () => {
  assert.ok(catalog.careers.length > 700);
  assert.equal(new Set(catalog.careers.map((x) => x.playerId)).size, catalog.careers.length);
  assert.equal(new Set(catalog.transfers.map((x) => `${x.fromClubId}/${x.toClubId}/${x.year}`)).size,
      catalog.transfers.length);
  const ronaldo = catalog.careers.find((x) => x.playerId === 8198);
  assert.equal(ronaldo.stops.filter((x) => x.clubId === 985).length, 2);
  for (const p of catalog.careers) {
    assert.equal(new Set(p.stops.map((x) => x.id)).size, p.stops.length);
    assert.ok(p.stops.length >= 3 && p.stops.length <= 12);
  }
});
test("auth, answer concealment and unknown or ambiguous guesses preserve lives", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  await assert.rejects(h.call("getCareerTransfer", {mode: "career"}, null), {code: "unauthenticated"});
  let s = await start(h, "career");
  assert.equal(s.player, undefined); assert.equal(s.solution, undefined);
  assert.equal((await h.call("getCareerTransfer", {mode: "career"})).collection.length, 0);
  await assert.rejects(act(h, s, {action: "guess", answer: "no_such_player_908"}), {code: "invalid-argument"});
  assert.equal(privateRun(h, s).wrong, 0);
  const p = puzzle(h, s);
  const wrong = p.playerId === 8198 ? 28003 : 8198;
  s = await act(h, s, {action: "guess", playerId: wrong});
  assert.equal(s.wrong, 1);
  await assert.rejects(act(h, s, {action: "guess", playerId: wrong}), {code: "already-exists"});
});
test("career: first order failure retains solution secrecy; second order earns gold only", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  let s = await start(h, "career"); const p = puzzle(h, s); const order = cardsOf(p).map((x) => x.id);
  s = await act(h, s, {action: "guess", playerId: p.playerId});
  assert.equal(h.read("economyState/alice/balances/coins"), 3);
  s = await act(h, s, {action: "order", order: [...order].reverse()});
  assert.equal(s.finished, false); assert.equal(s.checks, 1); assert.equal(s.solution, undefined);
  s = await act(h, s, {action: "order", order});
  assert.equal(s.finished, true); assert.equal(s.score, 100); assert.equal(s.result.coins, 8);
  s = await start(h, "career", {target: p.id}); s = await solve(h, s);
  assert.equal(s.result.coins, 0); assert.equal(s.result.medal, 3);
});
test("career: three wrongs allow reward-free ordering practice", async () => {
  const h = harness(); let s = await start(h, "career"); const p = puzzle(h, s);
  const wrong = catalog.careers.filter((x) => x.playerId !== p.playerId).slice(0, 3);
  for (const x of wrong) s = await act(h, s, {action: "guess", playerId: x.playerId});
  assert.equal(s.phase, "order"); assert.equal(s.found, false);
  s = await act(h, s, {action: "order", order: cardsOf(p).map((x) => x.id)});
  assert.equal(s.result.coins, 0); assert.equal(s.result.practice, true);
});
test("energy is atomic with content and survives lost start response and other normalizers", async () => {
  const h = harness({runtimeConfig: {energy: {enabled: true, percent: 100, sessionModes: ["career", "transfer"]}}},
      {omitEmptyObjects: true});
  const req = {mode: "transfer", version, requestId: id()};
  const [a, b] = await Promise.all([h.call("startCareerTransfer", req), h.call("startCareerTransfer", req)]);
  assert.equal(a.session.id, b.session.id);
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("getEnergyStatus");
  assert.equal((await h.call("getCareerTransfer", {mode: "transfer"})).session.id, a.session.id);
  await assert.rejects(h.call("startCareerTransfer", {...req, mode: "career"}), {code: "invalid-argument"});
  await act(h, a.session, {action: "skip"});
  for (let i = 0; i < 5; i++) await act(h, await start(h, "transfer"), {action: "skip"});
  await assert.rejects(start(h, "transfer"), {code: "resource-exhausted"});
});
test("transfer freezes first economic attempt and uses correct streak multiplier", async () => {
  const h = harness(); let s = await start(h, "transfer"); const p = puzzle(h, s);
  s = await act(h, s, {action: "skip"});
  s = await start(h, "transfer", {target: p.id}); s = await solve(h, s);
  // The archive replay neither extends the streak nor earns its multiplier.
  assert.equal(s.result.coins, 0); assert.equal(s.score, 100); assert.equal(s.streak, 0);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 100);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 120);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 150);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 200);
});
test("transfer: archive replays cannot farm the streak, badges or solved count", async () => {
  const h = harness(); let s = await start(h, "transfer"); const p = puzzle(h, s);
  s = await act(h, s, {action: "skip"});
  for (let i = 0; i < 6; i++) {
    s = await start(h, "transfer", {target: p.id}); s = await solve(h, s);
  }
  const st = await h.call("getCareerTransfer", {mode: "transfer"});
  assert.equal(st.longestStreak, 0);
  assert.ok(st.badges.every((b) => !b.earned));
  assert.equal(st.collection.find((x) => x.id === p.id).solved, false);
});
test("transfer: five first-play finds pay the streak badge once", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let s;
  for (let i = 0; i < 5; i++) s = await solve(h, await start(h, "transfer"));
  assert.equal(s.result.badge, "streak_5"); assert.equal(s.result.coins, 6 + 10);
  const st = await h.call("getCareerTransfer", {mode: "transfer"});
  assert.deepEqual(st.badges.find((b) => b.id === "streak_5"),
      {id: "streak_5", title: "Keskin Dedektif", target: 5, progress: 5, earned: true, coins: 10, xp: 20});
  s = await solve(h, await start(h, "transfer"));
  assert.equal(s.result.badge, undefined);
});
test("player search matches each word, so a full first name finds a short one", async () => {
  const h = harness();
  const names = async (query) => (await h.call("searchCareerTransfer", {mode: "transfer", version, query},
      {uid: "alice"})).results.map((p) => p.name);
  assert.ok((await names("Daniel alves")).includes("Dani Alves"));
  assert.equal((await names("Cristiano Ronaldo"))[0], "Cristiano Ronaldo");
  assert.equal((await names("jose sosa"))[0], "José Sosa");
  assert.deepEqual(await names("zz qq"), []);
});
test("transfer: everyone who made the same move answers it, solo and in duels", async () => {
  const shared = catalog.transfers.find((p) => p.alsoPlayerIds?.some((id) => players.has(id)));
  assert.ok(catalog.transfers.filter((p) => p.alsoPlayerIds).length > 200);
  const h = harness();
  h.seed(`economyState/alice/careerTransfer/collection/transfer__${shared.id}`,
      {firstAt: 1, difficulty: "normal", last: {score: 0}});
  let s = await start(h, "transfer", {target: shared.id});
  const other = shared.alsoPlayerIds.find((id) => players.has(id));
  s = await act(h, s, {action: "guess", playerId: other});
  assert.equal(s.finished, true); assert.equal(s.found, true);
  assert.equal(s.answer.id, other); assert.ok(!s.transfer.alsoBy.includes(players.get(other).name));
  const {questions} = require("../career_transfer_online");
  // Duels keep shared moves and accept every player who made them.
  for (let i = 0; i < 20; i++) {
    for (const q of questions("transfer_duel", "seed" + i)) {
      const move = catalog.transfers.find((p) => p.id === q.id);
      assert.deepEqual(q.accepted, move.alsoPlayerIds ? [move.playerId, ...move.alsoPlayerIds] : undefined);
    }
  }
});
test("transfer: level filter, one player per pick, detailed position and age hint", async () => {
  for (const level of ["easy", "medium", "hard"]) {
    const h = harness(); const s = await start(h, "transfer", {difficulty: level});
    assert.equal(puzzle(h, s).difficulty, level); assert.equal(s.difficulty, level);
  }
  const h = harness(); const seen = new Set();
  for (let i = 0; i < 6; i++) {
    const s = await start(h, "transfer"); seen.add(puzzle(h, s).playerId);
    await act(h, s, {action: "skip"});
  }
  assert.equal(seen.size, 6);
  const withAge = catalog.transfers.find((p) => p.age && p.detailedPosition === "Centre-Forward");
  const h2 = harness();
  h2.seed(`economyState/alice/careerTransfer/collection/transfer__${withAge.id}`,
      {firstAt: 1, difficulty: "normal", last: {score: 0}});
  let s = await start(h2, "transfer", {target: withAge.id});
  h2.seed(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`, 2);
  s = await act(h2, s, {action: "hint", hint: "next"});
  s = await act(h2, s, {action: "hint", hint: "next"});
  assert.equal(s.hints[1].text, `Santrfor · transferde ${withAge.age} yaşında`);
});
test("transfer: today's file is shared and never ambiguous", async () => {
  const a = harness(); const b = harness();
  const s1 = await start(a, "transfer", {daily: true}); const s2 = await start(b, "transfer", {daily: true});
  assert.equal(privateRun(a, s1).puzzle, privateRun(b, s2).puzzle);
  assert.equal(puzzle(a, s1).alsoPlayerIds, undefined); assert.notEqual(puzzle(a, s1).difficulty, "hard");
  assert.ok(s1.daily);
});
test("shared daily cap reserves FIFO pending entitlements and retries idempotently", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  for (let i = 0; i < 3; i++) await solve(h, await start(h, "career"));
  await solve(h, await start(h, "transfer"));
  assert.equal(h.read("economyState/alice/balances/coins"), 36);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 72);
  assert.equal((await h.call("getCareerTransfer", {mode: "career"})).pendingCoins, 6);
  h.setTime("2026-09-21T10:00:00Z");
  await Promise.all([h.call("getCareerTransfer", {mode: "career"}), h.call("getCareerTransfer", {mode: "transfer"})]);
  assert.equal(h.read("economyState/alice/balances/coins"), 42);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 84);
});
test("hints share three slots, preserve stock and reject stale revision / changed request payload", async () => {
  const h = harness({economyState: {alice: {inventory: {boost_first_letter: {quantity: 3, itemType: "boost"}}}}},
      {omitEmptyObjects: true});
  let s = await start(h, "transfer");
  s = await act(h, s, {action: "hint"});
  assert.equal(s.hints[0].kind, "country");
  await assert.rejects(act(h, s, {action: "hint"}), {code: "resource-exhausted"});
  s = await act(h, s, {action: "hint", boost: "boost_first_letter"});
  s = await act(h, s, {action: "hint", boost: "boost_first_letter"});
  assert.equal(s.hints[2].kind, "letter");
  await assert.rejects(act(h, s, {action: "hint", boost: "boost_first_letter"}), {code: "resource-exhausted"});
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 1);
  const req = {mode: s.mode, version, sessionId: s.id, revision: s.revision, requestId: id(), action: "guess",
    playerId: puzzle(h, s).playerId};
  const [a, b] = await Promise.all([h.call("actCareerTransfer", req), h.call("actCareerTransfer", req)]);
  assert.equal(a.session.result.coins, 4); assert.equal(b.session.result.coins, 4);
  await assert.rejects(h.call("actCareerTransfer", {...req, action: "skip"}), {code: "invalid-argument"});
});
test("lost XP projection repairs the outbox without a second Coin payment", async () => {
  const h = harness(); const s = await start(h, "transfer"); const p = puzzle(h, s);
  h.failNext("progressionProfiles/alice");
  const req = {version, mode: "transfer", sessionId: s.id, revision: s.revision, requestId: id(),
    action: "guess", playerId: p.playerId};
  await assert.rejects(h.call("actCareerTransfer", req), /Simulated interrupted write/);
  await h.call("actCareerTransfer", req);
  await h.call("getCareerTransfer", {mode: "transfer"});
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 12);
});
test("SSV cancellation, replay and two credits share one solo hint budget across phases", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  const service = h.context.lbCareerTransferService();
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const ads = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults, units: {android: unit},
    isLinked: async () => false, isPro: async () => false,
    prepareThreeReward: service.prepareHint, settleThreeReward: service.settleHint,
    grantCoins: async () => assert.fail("Hint cannot mint coins"),
  });
  let s = await start(h, "career"); const p = puzzle(h, s);
  const prepare = () => ads.prepare("alice", "android", "career_hint", id(), {sessionId: s.id});
  const event = (t) => ({user_id: "alice", custom_data: t.id, ad_unit: unit, timestamp: h.now,
    transaction_id: id(), reward_amount: "999999"});
  let {ticket} = await prepare(); await ads.cancel("alice", ticket.id);
  await assert.rejects(ads.accept(event(ticket)), {code: "permission-denied"});
  assert.equal(privateRun(h, s).adCredits, 0);
  for (let i = 0; i < 2; i++) {
    h.setTime(h.now + 31000); ({ticket} = await prepare());
    const receipt = event(ticket); await ads.accept(receipt); await ads.accept(receipt);
  }
  s = await act(h, s, {action: "hint", hint: "country"});
  s = await act(h, s, {action: "guess", playerId: p.playerId});
  s = await act(h, s, {action: "hint", hint: "connection"});
  s = await act(h, s, {action: "hint", hint: "years"});
  assert.equal(s.hints.length, 3); assert.equal(s.adCredits, 0);
  await assert.rejects(prepare(), {code: "failed-precondition"});
  await assert.rejects(act(h, s, {action: "hint", hint: "short"}), {code: "resource-exhausted"});
});
test("expired first attempt is archived and cannot regain transfer reward or career mastery", async () => {
  const h = harness(); let s = await start(h, "transfer"); const p = puzzle(h, s);
  h.setTime(h.now + 86400001);
  const status = await h.call("getCareerTransfer", {mode: "transfer"});
  assert.equal(status.session.finished, true); assert.equal(status.collection.length, 1);
  s = await start(h, "transfer", {target: p.id}); s = await solve(h, s);
  assert.equal(s.result.coins, 0);
  s = await start(h, "career"); const c = puzzle(h, s);
  h.setTime(h.now + 86400001);
  await h.call("getCareerTransfer", {mode: "career"});
  s = await start(h, "career", {target: c.id}); s = await solve(h, s);
  assert.equal(s.result.coins, 0); assert.equal(s.result.medal, 0);
});
const careerWhere = (fn) => catalog.careers.find((p) => p.difficulty === "normal" && fn(p));
const startOn = async (h, p) => {
  h.seed(`economyState/alice/careerTransfer/collection/career__${p.id}`,
      {firstAt: 1, difficulty: "normal", last: {score: 0}});
  return start(h, "career", {target: p.id});
};
test("career cards: back-to-back spells merge, returns show a count and never their order", async () => {
  const back = catalog.careers.find((p) => p.stops.some((x, i) => i && p.stops[i - 1].clubId === x.clubId));
  if (back) assert.ok(cardsOf(back).length < back.stops.length);
  for (const p of catalog.careers) {
    const cards = cardsOf(p);
    assert.ok(cards.every((c, i) => !i || cards[i - 1].clubId !== c.clubId));
  }
  const ret = careerWhere((p) => new Set(cardsOf(p).map((c) => c.clubId)).size < cardsOf(p).length);
  const h = harness(); const s = await startOn(h, ret);
  const counts = {};
  for (const c of cardsOf(ret)) counts[c.clubId] = (counts[c.clubId] || 0) + 1;
  for (const v of s.stops) {
    const n = counts[v.club.id];
    assert.equal(v.visit, n > 1 ? n : null);
  }
});
test("career: the starting order is never already solved and checks grow with career length", async () => {
  for (const p of catalog.careers.filter((x) => x.difficulty === "normal").slice(0, 25)) {
    const s = await startOn(harness(), p); const cards = cardsOf(p);
    assert.ok(s.stops.some((v, i) => v.club.id !== cards[i].clubId));
    assert.equal(s.maxChecks, maxChecks(cards.length));
  }
  assert.deepEqual([3, 5, 6, 8, 9, 12].map(maxChecks), [2, 2, 3, 3, 4, 4]);
});
test("career: same-club cards are interchangeable and long careers keep checking", async () => {
  const long = careerWhere((p) => cardsOf(p).length >= 6);
  const h = harness(); let s = await startOn(h, long); const cards = cardsOf(long);
  s = await act(h, s, {action: "guess", playerId: long.playerId});
  const wrong = [...cards.map((c) => c.id)].reverse();
  for (let i = 1; i < maxChecks(cards.length); i++) {
    s = await act(h, s, {action: "order", order: wrong});
    assert.equal(s.finished, false); assert.match(s.feedback, /kontrol hakkın kaldı/);
  }
  s = await act(h, s, {action: "order", order: wrong});
  assert.equal(s.finished, true);
  const ret = careerWhere((p) => {
    const ids = cardsOf(p).map((c) => c.clubId); return ids.some((x, i) => ids.indexOf(x) !== i);
  });
  const h2 = harness(); let r = await startOn(h2, ret); const rc = cardsOf(ret);
  r = await act(h2, r, {action: "guess", playerId: ret.playerId});
  const order = rc.map((c) => c.id);
  const i = rc.findIndex((c, k) => rc.findIndex((d) => d.clubId === c.clubId) !== k);
  const j = rc.findIndex((c) => c.clubId === rc[i].clubId);
  [order[i], order[j]] = [order[j], order[i]];
  r = await act(h2, r, {action: "order", order});
  assert.equal(r.finished, true); assert.equal(r.score, 150);
});
test("career: order hints point at different misplaced cards; guess phase has a first letter", async () => {
  const p = careerWhere((x) => cardsOf(x).length >= 5);
  const credit = (h, s) => h.seed(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`, 2);
  const h = harness(); let s = await startOn(h, p); credit(h, s);
  s = await act(h, s, {action: "hint", hint: "country"});
  s = await act(h, s, {action: "hint", hint: "position"});
  s = await act(h, s, {action: "hint", hint: "letter"});
  assert.match(s.hints.at(-1).text, /^İlk harf: /);
  const h2 = harness(); let r = await startOn(h2, p);
  r = await act(h2, r, {action: "guess", playerId: p.playerId}); credit(h2, r);
  for (const hint of ["years", "short", "connection"]) r = await act(h2, r, {action: "hint", hint});
  const texts = r.hints.map((x) => x.text);
  assert.equal(new Set(texts).size, 3);
  assert.equal(privateRun(h2, r).hints.map((x) => x.card).filter(Boolean).length, 3);
  assert.equal(new Set(privateRun(h2, r).hints.map((x) => x.card)).size, 3);
});
test("career: today's career is shared by everyone", async () => {
  const a = harness(); const b = harness();
  const s1 = await start(a, "career", {daily: true}); const s2 = await start(b, "career", {daily: true});
  assert.equal(privateRun(a, s1).puzzle, privateRun(b, s2).puzzle);
  assert.equal(privateRun(a, s1).daily, privateRun(a, s1).daily && String(privateRun(a, s1).daily));
  assert.equal(puzzle(a, s1).difficulty, "normal");
});
