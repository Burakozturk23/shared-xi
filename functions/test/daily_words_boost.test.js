"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {harness} = require("./support/economy_harness");
const {compiled} = require("../daily_words");
let seq = 95000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
function setup() {
  const h = harness({runtimeConfig: {dailyWords: {enabled: true, rewardsEnabled: true},
    boosts: {enabled: true, betaUids: {alice: true}, readyModes: {
      daily_lingo: true, daily_anagram: true, passa_daily: true, passa_weekly: true,
    }}}, economyState: {alice: {balances: {coins: 1000}, inventory: {
    boost_first_letter: {quantity: 2, itemType: "boost"},
  }}}}, {omitEmptyObjects: true});
  h.setTime(Date.parse("2026-10-19T10:00:00+03:00")); return h;
}
const bucket = (s) => s.mode === "passa_weekly" ? `weeks/${s.period}` : `days/${s.period}/${s.mode}`;
const raw = (h, s) => h.read(`${root}/dailyWords/${bucket(s)}`);
const load = async (h, mode) => (await h.call("getDailyWords", {mode})).session;
const request = (s, extra) => ({mode: s.mode, period: s.period, packId: s.packId,
  contentVersion: s.contentVersion, revision: s.revision, questionId: s.questionId, requestId: id(), ...extra});
const act = async (h, s, extra) => (await h.call("actDailyWords", request(s, extra))).session;
const paid = (action = "hint", extra = {}) => ({action, paymentSource: "coins", boostId: "boost_basic",
  expectedPriceCoins: 25, ...extra});
test("daily Lingo requires three valid guesses and atomically pays for context", async () => {
  const h = setup(); let s = await load(h, "daily_lingo");
  await assert.rejects(act(h, s, paid()), {code: "failed-precondition"});
  const q = raw(h, s).puzzle;
  for (const word of compiled(s.period, false).dictionary.filter((w) => w.length === q.answer.length &&
    w !== q.answer).slice(0, 3)) s = await act(h, s, {action: "guess", answer: word});
  await assert.rejects(act(h, s, {action: "hint"}));
  const input = request(s, paid()); h.failNext("dailyWordState/alice");
  await assert.rejects(h.call("actDailyWords", input));
  assert.equal(h.read(root + "/balances/coins"), 975); assert.equal(raw(h, s).hint, true);
  s = (await h.call("actDailyWords", input)).session;
  assert.equal(s.hint, q.hint); assert.equal(s.support.assisted, true);
  await h.call("getEnergyStatus"); assert.equal(raw(h, s).hint, true);
  assert.equal(h.read(root + "/balances/coins"), 975);
});
test("Anagram two typed hints charge once each, retain score penalty and never spend on reshuffle", async () => {
  const h = setup(); let s = await load(h, "daily_anagram");
  const input = request(s, paid("bio"));
  const [a, b] = await Promise.all([h.call("actDailyWords", input), h.call("actDailyWords", input)]);
  assert.deepEqual(a, b); s = a.session;
  s = await act(h, s, paid("first", {boostId: "boost_first_letter", paymentSource: "stock"}));
  assert.equal(h.read(root + "/balances/coins"), 975);
  assert.equal(h.read(root + "/inventory/boost_first_letter/quantity"), 1);
  await assert.rejects(act(h, s, paid("first", {boostId: "boost_first_letter"})));
  s = await act(h, s, {action: "shuffle"});
  assert.equal(h.read(root + "/balances/coins"), 975);
  const q = raw(h, s).questions[0]; s = await act(h, s, {action: "guess", answer: q.answer});
  assert.equal(s.score, 60); assert.equal(s.rounds[0].score, 60);
});
for (const mode of ["passa_daily", "passa_weekly"]) {
  test(`${mode}: paid length clue keeps period and running deadline`, async () => {
    const h = setup(); let s;
    if (mode === "passa_weekly") {
      const status = await h.call("getDailyWords", {mode});
      s = (await h.call("actDailyWords", {...status, session: undefined, action: "start", requestId: id()})).session;
    } else s = await load(h, mode);
    const deadline = s.deadline;
    await assert.rejects(act(h, s, {action: "hint"}));
    h.setTime(h.now + 20000); s = await act(h, s, paid());
    assert.match(s.question.hint, /^Cevap \d+ harften oluşur\.$/);
    assert.equal(s.deadline, deadline); assert.equal(h.read(root + "/balances/coins"), 975);
    await assert.rejects(act(h, s, paid()));
    if (mode === "passa_weekly") {
      h.setTime(deadline + 1); s = await load(h, mode); assert.equal(s.finished, true);
      assert.equal(s.result.reason, "timeout"); assert.equal(h.read(root + "/balances/coins"), 975);
    }
  });
}
test("daily ad is typed, capped at one and late question SSV recovers selected stock exactly once", async () => {
  const h = setup(); let s = await load(h, "daily_anagram"); const service = h.context.lbDailyWordsService();
  const context = {sessionId: s.id, mode: s.mode, period: s.period, boostId: "boost_first_letter"};
  const benefit = await service.prepareHint("alice", "daily_words_hint", context);
  assert.equal(benefit.requireVerifiedAd, true);
  const receipt = {id: "a".repeat(48), context: benefit.context};
  const q = raw(h, s).questions[0]; s = await act(h, s, {action: "guess", answer: q.answer});
  s = await act(h, s, {action: "next"});
  await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_first_letter/quantity"), 3);
  assert.equal(raw(h, s).adGranted, 1); assert.equal(raw(h, s).adCredits, 0);
  await assert.rejects(service.prepareHint("alice", "daily_words_hint", context), {code: "resource-exhausted"});
});
test("assisted daily finish cannot earn mastery or increase unassisted streak", async () => {
  const h = setup(); let s = await load(h, "passa_daily"); s = await act(h, s, paid());
  while (!s.finished) s = await act(h, s, {action: "guess", answer: raw(h, s).questions[s.index].answer});
  assert.equal(s.result.medal, "Altın"); assert.equal(s.result.assisted, true);
  assert.equal(s.result.masteryEligible, false); assert.equal(s.result.leaderboardEligible, false);
  const status = await h.call("getDailyWords", {mode: s.mode}); assert.equal(status.archive.streak, 0);
});
test("migration retains legacy hints, history and old request fingerprints without a second reward", async () => {
  const h = setup(); h.seed("runtimeConfig/boosts/enabled", false);
  let s = await load(h, "daily_anagram"); const input = request(s, {action: "bio"});
  s = (await h.call("actDailyWords", input)).session;
  const old = h.read("dailyWordState/alice"); delete old.storageVersion; delete old.projectionRevision;
  old.days[s.period][s.mode].actions[input.requestId] = crypto.createHash("sha256").update(JSON.stringify([
    input.mode, input.period, input.packId, input.contentVersion, input.revision,
    input.questionId, input.action, input.answer,
  ])).digest("hex");
  h.seed("dailyWordState/alice", old); h.seed(root + "/dailyWords", null);
  h.seed("runtimeConfig/boosts/enabled", true);
  const replay = (await h.call("actDailyWords", input)).session;
  assert.equal(replay.rounds[0].bio, true); assert.equal(replay.support, undefined);
  assert.equal(h.read(root + "/balances/coins"), 1000); assert.equal(raw(h, s).revision, s.revision);
});
test("granted daily clue returns to stock after answer even when the SSV arrived before the answer", async () => {
  const h = setup(); let s = await load(h, "daily_anagram"); const service = h.context.lbDailyWordsService();
  const context = {sessionId: s.id, mode: s.mode, period: s.period, boostId: "boost_first_letter"};
  const benefit = await service.prepareHint("alice", "daily_words_hint", context);
  const receipt = {id: "b4".repeat(24), context: benefit.context};
  await service.settleHint("alice", receipt); assert.equal(raw(h, s).adCredits, 1);
  const q = raw(h, s).questions[0]; s = await act(h, s, {action: "guess", answer: q.answer});
  await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_first_letter/quantity"), 3);
  assert.equal(raw(h, s).adCredits, 0); assert.equal(raw(h, s).assisted, false);
});
