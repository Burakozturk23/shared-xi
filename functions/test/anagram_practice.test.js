"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {harness} = require("./support/economy_harness");
const A = require("../anagram_practice");
const capacity = require("../energy").policy.capacity;
const root = "economyState/alice"; let seq = 13000;
const id = () => (++seq).toString(16).padStart(32, "0");
function setup() {
  return harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {anagram_practice: true}}, energy: {enabled: true, percent: 100, sessionModes: ["anagram"]}},
  economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
}
const load = (h) => h.call("getAnagramPractice");
const startInput = () => ({requestId: id(), action: "start", contentVersion: A.version, expectedEnergyCost: 1});
const start = async (h) => (await h.call("actAnagramPractice", startInput())).session;
const input = (r, action, extra = {}) => ({requestId: id(), action, packId: r.packId,
  contentVersion: r.contentVersion, revision: r.revision, questionId: r.questionId, ...extra});
const act = async (h, r, action, extra) => (await h.call("actAnagramPractice", input(r, action, extra))).session;
test("practice pins eight distinct canonical players, charges energy once and hides future answers", async () => {
  assert.deepEqual(A.catalog, JSON.parse(fs.readFileSync(__dirname + "/../../assets/data/anagram_catalog.json")));
  const h = setup(); const status = await load(h);
  assert.equal(status.session, null); assert.equal(status.energyCost, 1);
  const req = startInput(); h.failNext(""); await assert.rejects(h.call("actAnagramPractice", req));
  const r = (await h.call("actAnagramPractice", req)).session;
  assert.equal(h.read(root + "/energy/balance"), capacity - 1); assert.equal(r.rounds.length, 8);
  const privateRun = h.read(root + "/anagramPractice/sessions/" + r.id);
  assert.equal(new Set(privateRun.questions.map((q) => q.id)).size, 8);
  assert.equal(r.rounds[0].answer, undefined); assert.equal(r.rounds[0].playerId, undefined);
  assert.equal(r.rounds[1].scrambledLetters, undefined); assert.equal(r.support.adLimit, 2);
  await assert.rejects(h.call("actAnagramPractice", startInput()));
  assert.equal(h.read(root + "/energy/balance"), capacity - 1);
});
test("practice paid hints are atomic, have score penalties and cannot replay as another product", async () => {
  const h = setup(); let r = await start(h);
  const req = input(r, "bio", {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25});
  const [a, b] = await Promise.all([h.call("actAnagramPractice", req), h.call("actAnagramPractice", req)]);
  assert.deepEqual(a, b); r = a.session; assert.ok(r.rounds[0].hint); assert.equal(r.assisted, true);
  assert.equal(h.read(root + "/balances/coins"), 975);
  await assert.rejects(h.call("actAnagramPractice", {...req, boostId: "boost_first_letter"}));
  r = await act(h, r, "first", {boostId: "boost_first_letter", paymentSource: "coins", expectedPriceCoins: 25});
  const q = h.read(root + "/anagramPractice/sessions/" + r.id + "/questions/0");
  r = await act(h, r, "guess", {answer: q.name}); assert.equal(r.rounds[0].score, 60);
  assert.equal(h.read(root + "/balances/coins"), 950); assert.equal(h.read(root + "/energy/balance"), capacity - 1);
});
test("all eight practice rounds are server scored, separated from daily rewards and assisted records", async () => {
  const h = setup(); let r = await start(h);
  r = await act(h, r, "first", {boostId: "boost_first_letter", paymentSource: "coins", expectedPriceCoins: 25});
  for (let i = 0; i < 8; i++) {
    const q = h.read(root + "/anagramPractice/sessions/" + r.id + "/questions/" + i);
    r = await act(h, r, "guess", {answer: q.answer});
    if (i < 7) r = await act(h, r, "next");
  }
  assert.equal(r.finished, true); assert.equal(r.score, 775); assert.equal(r.result.coins, 0);
  assert.equal(r.result.xp, 0); assert.equal(r.result.eligibleForDailyBonus, false);
  assert.equal(r.result.masteryEligible, false); assert.equal(r.result.assisted, true);
  assert.equal(h.read(root + "/anagramPractice/assistedRecords/best"), 775);
  assert.equal(h.read(root + "/anagramPractice/records"), null);
  assert.equal(h.read(root + "/dailyWords"), null); assert.equal(h.read(root + "/balances/coins"), 975);
  assert.notEqual((await start(h)).id, r.id);
});
test("free reshuffle/reveal, invalid spend guards and no giveaway reward", async () => {
  const h = setup(); let r = await start(h); const sorted = (s) => [...s].sort().join("");
  const letters = r.rounds[0].scrambledLetters;
  r = await act(h, r, "shuffle"); assert.equal(sorted(r.rounds[0].scrambledLetters), sorted(letters));
  for (const extra of [{revision: 99}, {questionId: "other"}, {boostId: "boost_strong"},
    {paymentSource: "stock"}, {paymentSource: "coins", boostId: "boost_basic", expectedPriceCoins: 1}]) {
    await assert.rejects(act(h, r, "bio", extra));
    assert.equal(h.read(root + "/balances/coins"), 1000);
  }
  h.setLinked("alice", false); await assert.rejects(act(h, r, "guess", {answer: "x"}));
  h.setLinked("alice", true);
  r = await act(h, r, "reveal"); assert.equal(r.rounds[0].score, 0); assert.ok(r.rounds[0].answer);
  r = await act(h, r, "giveup"); assert.equal(r.result.reason, "giveup"); assert.equal(r.result.coins, 0);
});
test("practice typed ad retains its SKU after question changes and respects two per session", async () => {
  const h = setup(); let r = await start(h); const svc = h.context.lbAnagramPracticeService();
  const benefit = await svc.prepareHint("alice", "anagram_practice_hint",
      {sessionId: r.id, boostId: "boost_first_letter"});
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "ac".repeat(24), context: benefit.context};
  await svc.settleHint("alice", receipt);
  assert.equal((await load(h)).session.rounds[0].first, false);
  r = await act(h, r, "reveal"); r = await act(h, r, "next");
  await svc.settleHint("alice", receipt); assert.equal(h.read(root + "/inventory/boost_first_letter/quantity"), 1);
  const next = await svc.prepareHint("alice", "anagram_practice_hint", {sessionId: r.id, boostId: "boost_basic"});
  h.setTime(h.now + 86400001);
  await svc.settleHint("alice", {id: "ad".repeat(24), context: next.context});
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  assert.equal((await load(h)).session.result.reason, "expired");
});

test("changed quote, exhausted energy or foreign catalog cannot charge; rollover keeps the run", async () => {
  const h = setup();
  await assert.rejects(h.call("actAnagramPractice", {...startInput(), expectedEnergyCost: 0}));
  await assert.rejects(h.call("actAnagramPractice", {...startInput(), contentVersion: "old"}));
  h.seed(root + "/energy", {balance: 0, refillAt: h.now});
  await assert.rejects(h.call("actAnagramPractice", startInput()), {code: "resource-exhausted"});
  assert.equal(h.read(root + "/energy/balance"), 0);
  h.seed(root + "/energy/balance", 2); const r = await start(h);
  h.setTime(h.now + 12 * 3600000); assert.equal((await load(h)).session.id, r.id);
  assert.equal((await load(h)).session.finished, false);
});
