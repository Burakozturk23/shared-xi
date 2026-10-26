"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {harness} = require("./support/economy_harness");
const F = require("../daily_footballer");
const {dayKey} = require("../rewarded_ads");
const root = "economyState/alice"; let seq = 17000; const id = () => (++seq).toString(16).padStart(32, "0");
function setup() {
  return harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {daily_footballer: true}}}, economyState: {alice: {balances: {coins: 1000}}}},
  {omitEmptyObjects: true});
}
const load = (h, extra = {}) => h.call("getDailyFootballer", extra);
const input = (r, action, extra = {}) => ({requestId: id(), day: r.dayKey, sessionId: r.id,
  revision: r.revision, action, ...extra});
const act = async (h, r, action, extra) => (await h.call("actDailyFootballer", input(r, action, extra))).session;
function wrong(h, r, i = 0) {
  const target = h.read(root + "/dailyFootballer/days/" + r.dayKey + "/target/id");
  return F.catalog.players.filter((p) => p.id !== target)[i].id;
}
test("footballer preserves catalog/target permutation and exposes only actual guess clues", async () => {
  const source = fs.readFileSync(__dirname + "/../../assets/data/daily_footballer_catalog.json");
  assert.deepEqual(F.catalog, JSON.parse(source));
  const h = setup(); let {session: r} = await load(h);
  assert.equal(r.target, null); assert.equal(r.guesses.length, 0); assert.equal(r.support.adLimit, 1);
  const p = wrong(h, r); r = await act(h, r, "guess", {playerId: p});
  assert.equal(r.guesses[0].id, p); assert.equal(r.clues[p].length, 6); assert.equal(r.target, null);
  const target = h.read(root + "/dailyFootballer/days/" + r.dayKey + "/target");
  assert.deepEqual(r.clues[p], F.clues(target, F.catalog.players.find((x) => x.id === p), r.dayKey));
  assert.equal(F.targetFor(F.catalog, r.dayKey).id, target.id);
  const days = Array.from({length: F.catalog.players.length}, (_, i) =>
    new Date(Date.parse("2026-01-01T00:00:00Z") + i * 86400000).toISOString().slice(0, 10));
  assert.equal(new Set(days.map((d) => F.targetFor(F.catalog, d).id)).size, F.catalog.players.length);
});
test("footballer hint requires first guess, charges once and separates assisted wins", async () => {
  const h = setup(); let r = (await load(h)).session;
  const payment = {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25};
  await assert.rejects(act(h, r, "hint", payment));
  r = await act(h, r, "guess", {playerId: wrong(h, r)});
  const req = input(r, "hint", payment); h.failNext(""); await assert.rejects(h.call("actDailyFootballer", req));
  const [a, b] = await Promise.all([h.call("actDailyFootballer", req), h.call("actDailyFootballer", req)]);
  assert.deepEqual(a, b); r = a.session; assert.equal(r.assisted, true); assert.ok(r.hint);
  assert.equal(h.read(root + "/balances/coins"), 975);
  await assert.rejects(h.call("actDailyFootballer", {...req, expectedPriceCoins: 1}));
  const target = h.read(root + "/dailyFootballer/days/" + r.dayKey + "/target/id");
  r = await act(h, r, "guess", {playerId: target}); assert.equal(r.won, true); assert.equal(r.target.id, target);
  assert.equal((await load(h)).wins, 0); assert.equal((await load(h)).assistedWins, 1);
  assert.equal(h.read(root + "/balances/coins"), 975);
});
test("footballer hint and extra share one ad; wrong product, guest and stale state reject", async () => {
  const h = setup(); let r = (await load(h)).session; const svc = h.context.lbDailyFootballerService();
  r = await act(h, r, "guess", {playerId: wrong(h, r)});
  await assert.rejects(act(h, r, "hint", {boostId: "boost_strong", paymentSource: "coins", expectedPriceCoins: 60}));
  await assert.rejects(act(h, r, "guess", {playerId: "forged"}));
  await assert.rejects(act(h, r, "guess", {playerId: wrong(h, r, 1), revision: 99}));
  const context = {sessionId: r.id, boostId: "boost_basic", action: "hint"};
  const benefit = await svc.prepareHint("alice", "daily_footballer_hint", context);
  assert.equal(benefit.requireVerifiedAd, true);
  await svc.settleHint("alice", {id: "fa".repeat(24), context: benefit.context});
  assert.equal((await load(h)).session.hintUsed, false);
  for (let i = 1; i < 6; i++) r = await act(h, r, "guess", {playerId: wrong(h, r, i)});
  assert.equal(r.finished, false); assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  await assert.rejects(svc.prepareHint("alice", "daily_footballer_hint", {...context, action: "extra"}),
      {code: "resource-exhausted"});
  h.setLinked("alice", false); await assert.rejects(act(h, r, "reveal"), {code: "permission-denied"});
});
test("verified seventh guess is granted exactly once and finishes as assisted; no client-only extra path", async () => {
  const h = setup(); let r = (await load(h)).session; const svc = h.context.lbDailyFootballerService();
  for (let i = 0; i < 6; i++) r = await act(h, r, "guess", {playerId: wrong(h, r, i)});
  await assert.rejects(act(h, r, "extra"));
  const benefit = await svc.prepareHint("alice", "daily_footballer_hint", {
    sessionId: r.id, boostId: "boost_basic", action: "extra"});
  const receipt = {id: "fb".repeat(24), context: benefit.context};
  await svc.settleHint("alice", receipt); await svc.settleHint("alice", receipt);
  r = (await load(h)).session; assert.equal(r.extraUsed, true); assert.equal(r.assisted, true);
  assert.equal(r.adCredits, 0); assert.equal(r.adGranted, 1);
  r = await act(h, r, "guess", {playerId: wrong(h, r, 6)}); assert.equal(r.finished, true);
  assert.equal(r.guesses.length, 7); assert.equal(r.masteryEligible, false);
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("footballer adoption preserves one already-open local day but cannot grandfather each later day", async () => {
  const h = setup(); const today = dayKey(h.now);
  assert.equal((await load(h, {legacyDay: today})).legacy, true);
  assert.equal((await load(h)).legacy, true); assert.equal(h.read(root + "/dailyFootballer/days"), null);
  h.setTime(h.now + 86400000);
  const next = await load(h, {legacyDay: dayKey(h.now)});
  assert.equal(next.legacy, false); assert.equal(next.session.dayKey, dayKey(h.now));
  assert.equal(next.wins, 0); assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("late footballer SSV after Istanbul rollover recovers stock and cannot change next day's answer", async () => {
  const h = setup(); let r = (await load(h)).session; const svc = h.context.lbDailyFootballerService();
  r = await act(h, r, "guess", {playerId: wrong(h, r)});
  const benefit = await svc.prepareHint("alice", "daily_footballer_hint", {
    sessionId: r.id, boostId: "boost_basic", action: "hint"});
  h.setTime(h.now + 86400000);
  const receipt = {id: "fc".repeat(24), context: benefit.context};
  await svc.settleHint("alice", receipt); await svc.settleHint("alice", receipt);
  const next = (await load(h)).session; assert.notEqual(next.id, r.id); assert.equal(next.hintUsed, false);
  assert.equal(next.guesses.length, 0); assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  await assert.rejects(act(h, r, "guess", {playerId: wrong(h, r, 1)}));
});
