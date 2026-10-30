"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
let seq = 100000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice"; const legacy = "dailyQuestionState/alice";
function setup() {
  return harness({runtimeConfig: {dailyQuestion: {enabled: true}, boosts: {enabled: true,
    betaUids: {alice: true}, readyModes: {daily_question: true}}},
  economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
}
const load = (h) => h.call("getDailyQuestion");
const input = (v, extra = {}) => ({sessionId: v.session.id, revision: v.session.revision,
  day: v.question.day, questionId: v.question.id, requestId: id(), boostId: "boost_eliminate",
  paymentSource: "coins", expectedPriceCoins: 35, ...extra});
test("daily quiz elimination is atomic, authoritative and retained after lost projection", async () => {
  const h = setup(); let v = await load(h); const request = input(v);
  assert.equal(v.question.answer, undefined); assert.equal(v.session.support.adLimit, 1);
  h.failNext(legacy); await assert.rejects(h.call("useDailyQuestionHint", request));
  assert.equal(h.read(root + "/balances/coins"), 965);
  const [a, b] = await Promise.all([h.call("useDailyQuestionHint", request), h.call("useDailyQuestionHint", request)]);
  assert.deepEqual(a, b); v = a;
  assert.equal(v.eliminated, (h.read("dailyQuestionPrivate/" + v.question.day).answer + 1) % 3);
  assert.equal(v.session.support.assisted, true); assert.equal(h.read(root + "/balances/coins"), 965);
  await assert.rejects(h.call("useDailyQuestionHint", {...request, expectedPriceCoins: 1}), {code: "invalid-argument"});
  await assert.rejects(h.call("useDailyQuestionHint", input(v)), {code: "failed-precondition"});
  const answer = h.read("dailyQuestionPrivate/" + v.question.day).answer;
  v = await h.call("submitDailyQuestion", {day: v.question.day, questionId: v.question.id, option: answer});
  assert.equal(v.result.assisted, true); assert.equal(v.result.masteryEligible, false); assert.equal(v.result.coins, 8);
  await h.call("submitDailyQuestion", {day: v.question.day, questionId: v.question.id, option: answer});
  assert.equal(h.read(root + "/balances/coins"), 973);
});
test("old quiz Pro ad path, wrong SKU and price, guest, foreign run and stale day cannot spend", async () => {
  const h = setup(); const v = await load(h);
  await assert.rejects(h.call("prepareDailyQuestionHint"), {code: "failed-precondition"});
  for (const patch of [{boostId: "boost_basic"}, {paymentSource: "stock"}, {expectedPriceCoins: 0},
    {sessionId: "foreign"}, {revision: 99}, {day: "2000-01-01"}]) {
    await assert.rejects(h.call("useDailyQuestionHint", input(v, patch)));
  }
  h.setLinked("alice", false);
  await assert.rejects(h.call("useDailyQuestionHint", input(v)), {code: "permission-denied"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("one typed quiz ad is manual-use, survives answered question and cannot duplicate", async () => {
  const h = setup(); const v = await load(h); const service = h.context.lbDailyQuestionService();
  const context = {sessionId: v.session.id, boostId: "boost_eliminate"};
  const benefit = await service.prepareBoostHint("alice", "daily_question_hint", context);
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "d7".repeat(24), context: benefit.context};
  await service.settleBoostHint("alice", receipt);
  assert.equal((await load(h)).eliminated, null);
  await assert.rejects(service.prepareBoostHint("alice", "daily_question_hint", context), {code: "resource-exhausted"});
  await h.call("submitDailyQuestion", {day: v.question.day, questionId: v.question.id, option: 0});
  await service.settleBoostHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_eliminate/quantity"), 1);
});
test("legacy opened quiz hint and participation history migrate without being sold again", async () => {
  const h = setup(); h.seed("runtimeConfig/boosts/enabled", false); const v = await load(h);
  h.seed(legacy, {hints: {[v.question.day]: {eliminated: 0}}, answers: {}, total: 23,
    lastDay: v.question.day, streak: 4});
  h.seed("runtimeConfig/boosts/enabled", true); const migrated = await load(h);
  assert.equal(migrated.eliminated, 0); assert.equal(migrated.session, undefined);
  assert.equal(migrated.total, 23); assert.equal(migrated.streak, 4);
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("verified quiz ad after Istanbul rollover recovers selected stock, no change to next question", async () => {
  const h = setup(); const v = await load(h); const service = h.context.lbDailyQuestionService();
  const benefit = await service.prepareBoostHint("alice", "daily_question_hint", {
    sessionId: v.session.id, boostId: "boost_eliminate"});
  h.setTime(v.nextQuestionAt + 1);
  const receipt = {id: "d8".repeat(24), context: benefit.context};
  await service.settleBoostHint("alice", receipt); await service.settleBoostHint("alice", receipt);
  const next = await load(h); assert.notEqual(next.question.day, v.question.day);
  assert.equal(next.eliminated, null); assert.equal(h.read(root + "/inventory/boost_eliminate/quantity"), 1);
});
