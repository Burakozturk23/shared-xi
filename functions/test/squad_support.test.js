"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const S = require("../squad_challenge");
const {solve} = require("./squad_fixture");
let seq = 6000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
function setup() {
  return harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {squad_challenge: true}}}, economyState: {alice: {balances: {coins: 1000}}}},
  {omitEmptyObjects: true});
}
async function open(h, practice = false) {
  const hub = (await h.call("getMySquadChallenge", {catalogVersion: S.catalog.version})).hub;
  const mission = hub.missions[0];
  const run = practice ? null : (await h.call("startSquadChallenge", {catalogVersion: S.catalog.version,
    missionId: mission.id, requestId: mission.day + "__" + id()})).run;
  const context = {catalogVersion: S.catalog.version, themeId: mission.themeId,
    formationId: mission.formationId, ...(run ? {runId: run.id} : {})};
  const view = await h.call("getSquadSupport", context);
  return {mission, run, context, view};
}
function input(v, extra = {}) {
  return {catalogVersion: S.catalog.version, sessionId: v.session.id, revision: v.session.revision,
    slot: 0, playerIds: Array(11).fill(null), requestId: id(), boostId: "boost_basic",
    paymentSource: "coins", expectedPriceCoins: 25, ...extra};
}
test("squad advice is canonical and atomic across cold cache, conflicts and projection failure", async () => {
  const h = setup(); const {view, context, mission} = await open(h); const request = input(view);
  h.failNext("");
  await assert.rejects(h.call("useSquadSupport", request), /Simulated interrupted write/);
  const [a, b] = await Promise.all([h.call("useSquadSupport", request), h.call("useSquadSupport", request)]);
  assert.deepEqual(a, b); assert.equal(h.read(root + "/balances/coins"), 975);
  assert.equal(a.penalty, 10); assert.equal(a.session.support.assisted, true);
  const theme = S.catalog.themes.find((t) => t.id === mission.themeId);
  const formation = S.catalog.formations.find((f) => f.id === mission.formationId);
  for (const row of a.hints.boost_basic.candidates) {
    const p = S.catalog.players.find((p) => p.id === row.id);
    assert.ok(theme.players.includes(row.id)); assert.ok(S.positionFits(p, formation.slots[0]));
    assert.equal(row.cost, theme.costs[row.id]); assert.equal(row.links, 0);
  }
  assert.equal((await h.call("getSquadSupport", context)).hints.boost_basic.candidates[0].id,
      a.hints.boost_basic.candidates[0].id);
  await assert.rejects(h.call("useSquadSupport", {...request, slot: 1}), {code: "invalid-argument"});
});
test("squad advice rejects forged draft, foreign run, stale revision and wrong SKU/price", async () => {
  const h = setup(); const {view, mission} = await open(h);
  for (const patch of [{catalogVersion: "old"}, {sessionId: "other"}, {revision: 99}, {slot: 11},
    {boostId: "boost_eliminate"}, {expectedPriceCoins: 1}, {playerIds: Array(11).fill(-1)},
    {playerIds: [null]}, {paymentSource: "stock"}]) {
    await assert.rejects(h.call("useSquadSupport", input(view, patch)));
    assert.equal(h.read(root + "/balances/coins"), 1000);
  }
  const valid = solve(mission);
  const copy = [...valid]; copy[1] = valid[0];
  await assert.rejects(h.call("useSquadSupport", input(view, {playerIds: copy})));
  h.setLinked("alice", false);
  await assert.rejects(h.call("useSquadSupport", input(view)), {code: "permission-denied"});
});
test("daily assisted squad retains one first-clear reward, applies penalty and separates best score", async () => {
  const h = setup(); const {view, run, mission} = await open(h);
  const helped = await h.call("useSquadSupport", input(view, {boostId: "boost_strong", expectedPriceCoins: 60}));
  assert.equal(helped.hints.boost_strong.candidates.length, 1);
  assert.equal(helped.session.support.products.find((p) => p.id === "boost_strong").ads, false);
  const ids = solve(mission); const raw = S.evaluate(mission.themeId, mission.formationId, ids, mission.budget).score;
  const request = {catalogVersion: S.catalog.version, runId: run.id, playerIds: ids};
  const result = (await h.call("finishSquadChallenge", request)).run.result;
  assert.equal(result.assisted, true); assert.equal(result.masteryEligible, false);
  assert.equal(result.penalty, 20); assert.equal(result.score, Math.max(0, raw - 20));
  assert.equal(result.reward, mission.reward);
  await h.call("finishSquadChallenge", request);
  assert.equal(h.read(root + "/balances/coins"), 940 + mission.reward);
  assert.equal(h.read(root + "/squadChallenge/bestByTheme/" + mission.themeId), null);
  assert.equal(h.read(root + "/squadChallenge/assistedBestByTheme/" + mission.themeId), result.score);
});
test("squad verified ad is manual, one per daily run, recovered on abandon without duplicate", async () => {
  const h = setup(); const {view, run} = await open(h); const service = h.context.lbSquadSupportService();
  const context = {catalogVersion: S.catalog.version, sessionId: view.session.id, boostId: "boost_basic"};
  const benefit = await service.prepareHint("alice", "squad_support_hint", context);
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "ea".repeat(24), context: benefit.context};
  await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/squadChallenge/runs/" + run.id + "/assisted"), false);
  await assert.rejects(service.prepareHint("alice", "squad_support_hint", context), {code: "resource-exhausted"});
  await h.call("abandonSquadChallenge", {catalogVersion: S.catalog.version, runId: run.id});
  await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
});
test("squad practice resumes paid help, isolates records and never spends entries or earns currency", async () => {
  const h = setup(); const {view, context, mission} = await open(h, true);
  assert.equal(view.practice, true); assert.equal(view.session.support.adLimit, 2);
  const helped = await h.call("useSquadSupport", input(view));
  const resumed = await h.call("getSquadSupport", context);
  assert.equal(resumed.session.id, view.session.id); assert.deepEqual(resumed.hints, helped.hints);
  const ids = solve(mission);
  const request = {catalogVersion: S.catalog.version, sessionId: view.session.id, playerIds: ids};
  const result = await h.call("finishSquadPractice", request);
  assert.equal(result.result.assisted, true); assert.equal(result.result.reward, 0);
  await h.call("finishSquadPractice", request);
  assert.equal(h.read(root + "/balances/coins"), 975);
  assert.equal(h.read(root + "/squadChallenge/freeUsed"), 0);
  assert.equal(h.read(root + "/squadChallenge/completedTotal"), 0);
  assert.equal(h.read(root + "/squadChallenge/practiceBest/" + mission.themeId), null);
  assert.equal(h.read(root + "/squadChallenge/assistedPracticeBest/" + mission.themeId), result.result.score);
  assert.notEqual((await h.call("getSquadSupport", context)).session.id, view.session.id);
});
test("late squad SSV becomes stock and full inventory keeps unused right without blocking abandonment", async () => {
  const h = setup(); const {view, run} = await open(h); const service = h.context.lbSquadSupportService();
  const benefit = await service.prepareHint("alice", "squad_support_hint", {
    catalogVersion: S.catalog.version, sessionId: view.session.id, boostId: "boost_basic"});
  const receipt = {id: "eb".repeat(24), context: benefit.context};
  await service.settleHint("alice", receipt);
  h.seed(root + "/inventory/boost_basic", {itemId: "boost_basic", itemType: "boost", quantity: 99});
  await h.call("abandonSquadChallenge", {catalogVersion: S.catalog.version, runId: run.id});
  assert.equal(h.read(root + "/squadChallenge/runs/" + run.id + "/adProducts/boost_basic"), 1);
  h.seed(root + "/inventory/boost_basic/quantity", 98);
  await h.call("getMySquadChallenge", {catalogVersion: S.catalog.version});
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 99);
  assert.equal(h.read(root + "/squadChallenge/runs/" + run.id + "/adProducts/boost_basic"), 0);
});
