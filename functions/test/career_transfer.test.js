"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../career_transfer");
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
  return s.mode === "transfer" ? s : act(h, s, {action: "order", order: p.stops.map((x) => x.id)});
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
  let s = await start(h, "career"); const p = puzzle(h, s); const order = p.stops.map((x) => x.id);
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
  s = await act(h, s, {action: "order", order: p.stops.map((x) => x.id)});
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
  assert.equal(s.result.coins, 0); assert.equal(s.score, 100);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 120);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 150);
  s = await solve(h, await start(h, "transfer")); assert.equal(s.score, 200);
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
  assert.equal(s.result.coins, 8); assert.equal(s.result.medal, 3);
});
