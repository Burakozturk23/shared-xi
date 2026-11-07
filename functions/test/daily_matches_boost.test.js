"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {dayKey} = require("../rewarded_ads");
const catalog = require("../config/daily_catalog.json");
const root = "economyState/alice";
let seq = 8000; const id = () => (++seq).toString(16).padStart(32, "0");
function setup() {
  const h = harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true}, readyModes: {daily_match: true}}},
    economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
  const day = dayKey(h.now);
  h.seed("daily_fixtures/" + day, {updatedAt: h.now, matches: [1, 2, 3, 4].map((fixtureId) => ({fixtureId,
    homeName: "Fenerbahce", awayName: "Besiktas", kickoff: day + "T20:00:00+03:00", leagueId: 203,
    isDerby: true, leagueName: "Süper Lig", status: "NS"}))});
  return h;
}
const input = (r, extra = {}) => ({key: r.key, action: "hint", revision: r.revision, requestId: id(),
  boostId: "boost_basic", expectedPriceCoins: 25, paymentSource: "coins", ...extra});
async function start(h, fixtureId = 1) {
  return (await h.call("startDailyMatch", {fixtureId})).session;
}
test("daily match hint and debit survive mirror failure, stay private and replay exactly once", async () => {
  const h = setup(); const r = await start(h); const req = input(r);
  assert.equal(r.answers, undefined); assert.equal(r.boostPolicy, undefined); assert.equal(r.support.adLimit, 1);
  h.failNext("dailyMatchState/alice"); await assert.rejects(h.call("playDailyMatch", req));
  assert.equal(h.read(root + "/balances/coins"), 975);
  const [a, b] = await Promise.all([h.call("playDailyMatch", req), h.call("playDailyMatch", req)]);
  assert.deepEqual(a, b); assert.ok(a.session.hint); assert.equal(a.session.found.length, 0);
  assert.equal(a.session.support.assisted, true); assert.equal(a.session.actions, undefined);
  assert.equal(h.read(root + "/balances/coins"), 975);
  await assert.rejects(h.call("playDailyMatch", {...req, expectedPriceCoins: 1}));
  await assert.rejects(h.call("playDailyMatch", input(a.session)));
});
test("new daily matches reject free/Pro/wrong product paths and stale or foreign state", async () => {
  const h = setup(); const r = await start(h); const svc = h.context.lbDailyMatchesService();
  await assert.rejects(h.call("playDailyMatch", {key: r.key, action: "hint"}));
  await assert.rejects(svc.prepareReward("alice", "daily_hint", {key: r.key}));
  for (const patch of [{boostId: "boost_strong"}, {revision: 99}, {expectedPriceCoins: 0}, {paymentSource: "stock"}]) {
    await assert.rejects(h.call("playDailyMatch", input(r, patch)));
  }
  await assert.rejects(h.call("playDailyMatch", input(r), {uid: "bob", token: {}}));
  assert.equal(h.read(root + "/balances/coins"), 1000);
  h.setLinked("alice", false); await assert.rejects(h.call("playDailyMatch", input(r)));
  h.setLinked("alice", true);
  h.setTime(h.now + 86400000); await assert.rejects(h.call("playDailyMatch", input(r)));
});
test("assisted daily win preserves its base/double receipt but never grants unassisted streak or mastery", async () => {
  const h = setup(); const r = await start(h); await h.call("playDailyMatch", input(r));
  for (const player of catalog.pairs["36-114"].slice(0, 3)) {
    await h.call("playDailyMatch", {key: r.key, action: "answer", answer: catalog.players[player].name});
  }
  const finished = await h.call("playDailyMatch", {key: r.key, action: "finish"});
  assert.equal(finished.session.reward, 30); assert.equal(finished.session.masteryEligible, false);
  assert.equal(finished.streak, 0); assert.equal(h.read(root + "/balances/coins"), 1005);
  // No mode win or mastery; only the shared play streak, which counts assisted days by design.
  assert.deepEqual(h.read("achievementState/alice/signals"), {best_daily_streak: 1});
  assert.equal(h.read("achievementState/alice/dailyDates"), null);
  const svc = h.context.lbDailyMatchesService();
  const bonus = await svc.prepareReward("alice", "daily_double", {key: r.key});
  const receipt = {id: "f1".repeat(24), placement: "daily_double", context: bonus.context};
  await svc.settleReward("alice", receipt); await svc.settleReward("alice", receipt);
  assert.equal(h.read(root + "/balances/coins"), 1035);
});
test("verified match hint is manually consumed, one per fixed run and retained after midnight", async () => {
  const h = setup(); const r = await start(h); const svc = h.context.lbDailyMatchesService();
  const benefit = await svc.prepareHint("alice", "daily_match_hint", {key: r.key, boostId: "boost_basic"});
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "f2".repeat(24), context: benefit.context};
  await svc.settleHint("alice", receipt);
  assert.equal((await start(h)).hintUsed, false);
  await assert.rejects(svc.prepareHint("alice", "daily_match_hint", {key: r.key, boostId: "boost_basic"}));
  h.setTime(h.now + 86400000); await svc.status("alice"); await svc.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("opened legacy match preserves old free help, unfinished answers and daily entry quota", async () => {
  const h = setup(); h.seed("runtimeConfig/boosts/enabled", false); const r = await start(h);
  await h.call("playDailyMatch", {key: r.key, action: "hint"});
  h.seed("runtimeConfig/boosts/enabled", true);
  const old = await start(h); assert.equal(old.support, undefined); assert.ok(old.hint);
  const fresh = await start(h, 2); assert.equal(fresh.support.version, 1);
  assert.equal((await start(h)).hint, old.hint);
  await start(h, 3); await assert.rejects(start(h, 4));
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
