"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const E = require("../choice_engine");
const {clue} = require("../choice");
let seq = 99000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
const metricId = Object.values(E.catalog.metrics).find((m) => m.gatePassed).id;
function setup() {
  return harness({runtimeConfig: {choice: {enabled: true, rewardsEnabled: true}, boosts: {
    enabled: true, betaUids: {alice: true}, readyModes: {higher_lower_training: true, blind_ranking_training: true}}},
  economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
}
const prepare = async (h, mode, extra = {}) => (await h.call("prepareChoice", {mode, metricId,
  version: E.catalog.version, training: true, size: 5, requestId: id(), ...extra})).session;
const request = (r, extra) => ({mode: r.mode, sessionId: r.id, revision: r.revision, requestId: id(), ...extra});
const act = async (h, r, extra) => (await h.call("actChoice", request(r, extra))).session;
const start = async (h, mode, extra) => act(h, await prepare(h, mode, extra), {action: "confirm"});
const raw = (h, r) => E.hydrate(h.read(root + "/choice/sessions/" + r.id));
const help = (r, extra = {}) => ({action: "hint", questionId: r.question?.id || r.current?.id,
  paymentSource: "coins", boostId: "boost_basic", expectedPriceCoins: 25, ...extra});
for (const mode of ["higher_lower", "blind_ranking"]) {
  test(`${mode}: explicit training, truthful range and atomic purchase without extra secrets`, async () => {
    const h = setup(); let r = await start(h, mode);
    assert.equal(r.training, true); assert.equal(r.practice, true);
    assert.equal(r.support.products[0].priceCoins, 25);
    const info = clue(raw(h, r)); const state = raw(h, r);
    const value = mode === "higher_lower" ?
      state.question[state.question.knownSide === 0 ? "rightValue" : "leftValue"] :
      Object.values(state.values).filter((x) => x > state.values[info.target]).length + 1;
    assert.ok(info.low <= value && value <= info.high);
    const input = request(r, help(r));
    const [a, b] = await Promise.all([h.call("actChoice", input), h.call("actChoice", input)]);
    assert.deepEqual(a, b); r = a.session;
    assert.equal(r.trainingHint, info.text); assert.equal(h.read(root + "/balances/coins"), 975);
    assert.equal(r.values, undefined); assert.equal(r.orderedCandidateIds, undefined);
    assert.equal(r.support.assisted, true);
    await assert.rejects(h.call("actChoice", {...input, paymentSource: "stock"}), {code: "invalid-argument"});
    await assert.rejects(act(h, r, help(r)), {code: "failed-precondition"});
    assert.equal(h.read(root + "/balances/coins"), 975);
  });
}
test("normal games and personal preference cannot receive training support or forge a prepare retry", async () => {
  const h = setup(); const r = await start(h, "higher_lower", {training: false});
  assert.equal(r.support, undefined); await assert.rejects(act(h, r, help(r)), {code: "permission-denied"});
  const other = setup();
  await assert.rejects(prepare(other, "this_or_that", {bracketId: "prime_battles_32", size: 16}),
      {code: "permission-denied"});
  await assert.rejects(prepare(other, "blind_ranking", {type: "personal", themeId: "favorites"}),
      {code: "permission-denied"});
  const requestId = id(); await prepare(other, "higher_lower", {requestId, training: false});
  await assert.rejects(prepare(other, "higher_lower", {requestId}), {code: "invalid-argument"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("perfect assisted training cannot create normal records, rewards, daily claims or mastery", async () => {
  const h = setup(); let r = await start(h, "blind_ranking"); r = await act(h, r, help(r));
  const state = raw(h, r);
  const order = Object.keys(state.values).sort((a, b) => state.values[b] - state.values[a]);
  while (!r.finished) {
    r = await act(h, r, {action: "place", candidateId: r.current.id, slot: order.indexOf(r.current.id)});
  }
  assert.equal(r.score, 100); assert.equal(r.earnedCoins, 0);
  assert.equal(h.read(root + "/choice/records"), null); assert.equal(h.read(root + "/choice/claims"), null);
  assert.equal(h.read(root + "/choice/daily"), null); assert.equal(h.read("progressionState/alice"), null);
  const archive = (await h.call("getChoice", {mode: "blind_ranking"})).archive;
  assert.equal(archive[0].training, true); assert.equal(archive[0].support.assisted, true);
});
test("training verified ad recovers at next question and cannot be used offline or in a normal game", async () => {
  const h = setup(); let r = await start(h, "higher_lower"); const service = h.context.lbChoiceService();
  const benefit = await service.prepareHint("alice", "choice_training_hint", {sessionId: r.id, boostId: "boost_basic"});
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "c6".repeat(24), context: benefit.context}; await service.settleHint("alice", receipt);
  const q = raw(h, r).question;
  const direction = (q.knownSide === 0 ? q.rightValue > q.leftValue : q.leftValue > q.rightValue) ? "higher" : "lower";
  r = await act(h, r, {action: "guess", questionId: q.id, direction});
  await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  await assert.rejects(h.call("replayChoice", {mode: r.mode, events: [request(r, help(r))]}),
      {code: "invalid-argument"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("expired training, wrong price and foreign account preserve wallet", async () => {
  const h = setup(); const r = await start(h, "higher_lower");
  await assert.rejects(act(h, r, help(r, {expectedPriceCoins: 0})), {code: "failed-precondition"});
  await assert.rejects(h.call("actChoice", request(r, help(r)), {uid: "bob"}), {code: "not-found"});
  h.setTime(raw(h, r).expiresAt + 1);
  await assert.rejects(act(h, r, help(r)), {code: "failed-precondition"});
  assert.equal((await h.call("getChoice", {mode: r.mode})).session.finished, true);
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
