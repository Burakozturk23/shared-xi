"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {select, bank} = require("../daily_question");
const req = (n) => n.toString(16).padStart(32, "0");
function setup() {
  const h = harness();
  h.seed("runtimeConfig", {energy: {enabled: true, percent: 100, minClientVersion: 1,
    sessionModes: require("../config/energy_v1.json").sessionModes}, dailyQuestion: {enabled: true}});
  return h;
}
async function spend(h, n, mode = "bot_loto", unitId = "session") {
  const r = await h.call("startEnergySession", {requestId: req(n), mode, unitId, clientVersion: 1});
  if (r.unlocked) return r;
  await h.call("confirmEnergySession", {sessionId: r.session.id});
  return r;
}
test("energy is off by default and cannot change existing balances", async () => {
  const h = harness();
  assert.equal((await h.call("getEnergyStatus")).enabled, false);
  assert.equal((await h.call("startEnergySession", {})).enabled, false);
});
test("repeatable modes require their own rollout; rollback cancels unpaid holds", async () => {
  const h = setup();
  h.seed("runtimeConfig/energy", {enabled: true, percent: 100, minClientVersion: 1});
  const input = {requestId: req(1), mode: "anagram", clientVersion: 1};
  assert.equal((await h.call("startEnergySession", input)).enabled, false);
  assert.equal((await h.call("getEnergyStatus")).available, 6);
  h.seed("runtimeConfig/energy/sessionModes", ["anagram"]);
  const started = await h.call("startEnergySession", input);
  assert.equal(started.session.status, "reserved");
  assert.equal((await h.call("startEnergySession", {...input, mode: "bot_loto"})).enabled, false);
  h.seed("runtimeConfig/energy/sessionModes", []);
  assert.equal((await h.call("confirmEnergySession", {sessionId: req(1)})).enabled, false);
  assert.equal((await h.call("getEnergyStatus")).available, 6);
  assert.equal((await h.call("resumeEnergySession", {sessionId: req(1), mode: "anagram"})).enabled, false);
});
test("Anagram uses one idempotent session for all eight questions and no new XP", async () => {
  const h = setup();
  const input = {requestId: req(1), mode: "anagram", clientVersion: 1};
  await Promise.all([1, 2].map(() => h.call("startEnergySession", input)));
  await Promise.all([1, 2].map(() => h.call("confirmEnergySession", {sessionId: req(1)})));
  for (let i = 0; i < 8; i++) {
    const r = await h.call("resumeEnergySession", {sessionId: req(1), mode: "anagram"});
    assert.equal(r.session.id, req(1)); assert.equal(r.serverNow, h.now);
  }
  assert.equal((await h.call("getEnergyStatus")).balance, 5);
  assert.equal(h.read("progressionState/alice"), null);
  h.setTime(h.now + 86400001);
  await assert.rejects(h.call("resumeEnergySession", {sessionId: req(1), mode: "anagram"}), /yok/);
});
test("reservation, idempotent confirmation, hourly refill and Istanbul counters", async () => {
  const h = setup();
  const r = await h.call("startEnergySession", {requestId: req(1), mode: "bot_loto", clientVersion: 1});
  let v = await h.call("getEnergyStatus"); assert.equal(v.balance, 6); assert.equal(v.available, 5);
  await h.call("confirmEnergySession", {sessionId: r.session.id});
  await h.call("confirmEnergySession", {sessionId: r.session.id});
  v = await h.call("getEnergyStatus"); assert.equal(v.balance, 5);
  h.setTime(h.now + 3600000); assert.equal((await h.call("getEnergyStatus")).balance, 6);
  await h.call("startEnergySession", {requestId: req(2), mode: "bot_loto", clientVersion: 1});
  h.setTime(h.now + 120001); assert.equal((await h.call("getEnergyStatus")).available, 6);
  await assert.rejects(h.call("confirmEnergySession", {sessionId: req(2)}), /sona erdi/);
});
test("concurrent purchase retries spend once, share limits and never overflow", async () => {
  const h = setup(); h.seed("economyState/alice", {balances: {coins: 200}});
  await spend(h, 1); await spend(h, 2);
  await Promise.all([1, 2].map(() => h.call("purchaseEnergy", {requestId: req(8), packageId: "small"})));
  assert.equal(h.read("economyState/alice/balances/coins"), 175);
  assert.equal((await h.call("getEnergyStatus")).daily.purchases, 1);
  await assert.rejects(h.call("purchaseEnergy", {requestId: req(9), packageId: "large"}), /alanı/);
  assert.equal(h.read("economyState/alice/balances/coins"), 175);
});
test("story units resolve all eight catalogs, legacy progress and repeated tasks share access", async () => {
  const h = setup();
  for (const [mode, def] of Object.entries(require("../energy_catalog").definitions)) {
    assert.ok(def.rows.every((r) => typeof r.id === "string"), mode);
  }
  const first = await spend(h, 1, "journey", "messi");
  assert.equal(first.session.unitId, "messi");
  assert.equal((await spend(h, 2, "journey", "messi_v2_1")).unlocked, true);
  assert.equal((await h.call("getEnergyStatus")).balance, 5);
  h.seed("uclMomentsState/alice/results/ucl_01", {correct: true});
  assert.equal((await spend(h, 3, "ucl", "ucl_01")).unlocked, true);
  assert.equal((await h.call("getEnergyStatus")).balance, 5);
  await assert.rejects(h.call("submitPlayerJourney", {journeyId: "messi"}), /güncelle/);
  await assert.rejects(h.call("submitPlayerJourney", {journeyId: "ronaldo", energyClientVersion: 1}), /aç/);
});
test("same story on two devices reserves and charges only once", async () => {
  const h = setup();
  const results = await Promise.all([1, 2].map((n) => h.call("startEnergySession", {requestId: req(n),
    mode: "ucl", unitId: "ucl_01", clientVersion: 1})));
  assert.equal(results[0].session.id, results[1].session.id);
  await Promise.all(results.map((r) => h.call("confirmEnergySession", {sessionId: r.session.id})));
  assert.equal((await h.call("getEnergyStatus")).balance, 5);
});
test("confirmed sessions can resume for 24h, never indefinitely", async () => {
  const h = setup(); await spend(h, 1);
  assert.equal((await h.call("resumeEnergySession", {sessionId: req(1), mode: "bot_loto"})).ok, true);
  h.setTime(h.now + 86400001);
  await assert.rejects(h.call("resumeEnergySession", {sessionId: req(1), mode: "bot_loto"}), /yok/);
  await assert.rejects(h.call("confirmEnergySession", {sessionId: req(1)}), /sona erdi/);
});
test("quiz catalog has three distinct answers, sources and no repeat within 90 days", () => {
  assert.ok(bank.questions.length >= 200);
  assert.equal(new Set(bank.questions.map((q) => q.id)).size, bank.questions.length);
  for (const q of bank.questions) {
    assert.equal(new Set(q.options).size, 3); assert.ok(q.answer >= 0 && q.answer < 3);
    assert.ok(q.sources.length && q.explanation);
  }
  const recent = [];
  for (let i = 0; i < 1200; i++) {
    const day = new Date(Date.UTC(2026, 0, 1) + i * 86400000).toISOString().slice(0, 10);
    const q = select(day); assert.ok(!recent.includes(q.id), day);
    recent.push(q.id); if (recent.length >= 90) recent.shift();
  }
});
test("daily quiz hides answers, one answer across devices and exactly one wallet grant", async () => {
  const h = setup();
  const v = await h.call("getDailyQuestion");
  assert.equal(v.result, null); assert.equal(v.question.answer, undefined); assert.equal(v.question.sources, undefined);
  const answer = select(v.question.day).answer;
  const input = {day: v.question.day, questionId: v.question.id, option: answer};
  await Promise.all([1, 2].map(() => h.call("submitDailyQuestion", input)));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 10);
  await assert.rejects(h.call("submitDailyQuestion", {...input, option: (answer + 1) % 3}), /kaydedildi/);
  assert.equal((await h.call("getDailyQuestion")).result.correct, true);
});
test("wrong answers keep a 7-day participation streak and missed days reset it", async () => {
  const h = setup();
  for (let i = 0; i < 7; i++) {
    const v = await h.call("getDailyQuestion"); const q = select(v.question.day);
    const r = await h.call("submitDailyQuestion", {day: v.question.day, questionId: q.id, option: (q.answer + 1) % 3});
    assert.equal(r.streak, i + 1); assert.equal(r.result.coins, i === 6 ? 22 : 2);
    h.setTime(h.now + 86400000);
  }
  assert.equal(h.read("economyState/alice/balances/coins"), 34);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 65);
  h.setTime(h.now + 86400000);
  const v = await h.call("getDailyQuestion");
  const r = await h.call("submitDailyQuestion", {day: v.question.day, questionId: v.question.id, option: 0});
  assert.equal(r.streak, 1);
});

test("ordinary wallet grants preserve energy and purchase limits", async () => {
  const h = setup(); await spend(h, 1);
  await h.context.lbProgressionGrantCoins(h.db, "alice", "energy_test", "daily_question", "test", 30, "v1");
  assert.equal((await h.call("getEnergyStatus")).balance, 5);
  assert.equal(h.read("economyState/alice/balances/coins"), 30);
});

test("rollback cancels a hold without charging", async () => {
  const h = setup();
  await h.call("startEnergySession", {requestId: req(1), mode: "bot_loto", clientVersion: 1});
  h.seed("runtimeConfig/energy/enabled", false);
  await h.call("confirmEnergySession", {sessionId: req(1)});
  assert.equal((await h.call("getEnergyStatus")).balance, 6);
  assert.equal(h.read("economyState/alice/energy/sessions/" + req(1)).status, "cancelled");
});

test("verified energy ads and quiz hints have independent caps; cancelled energy ad cannot pay", async () => {
  const h = setup(); const energy = h.context.lbEnergyService(); const quiz = h.context.lbDailyQuestionService();
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const ads = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults, units: {android: unit},
    isLinked: async () => true, isPro: async () => false, grantCoins: async () => assert.fail("no ad coins"),
    prepareEnergyReward: energy.prepareReward, settleEnergyReward: energy.settleReward,
    prepareQuizReward: quiz.prepareHint, settleQuizReward: quiz.settleHint});
  const event = (t) => ({user_id: "alice", custom_data: t.id, ad_unit: unit,
    transaction_id: t.id, timestamp: h.now});
  await spend(h, 1); await spend(h, 2);
  const cancelled = await ads.prepare("alice", "android", "energy_refill", req(11));
  await ads.cancel("alice", cancelled.ticket.id);
  await assert.rejects(ads.accept(event(cancelled.ticket)), /cancelled/);
  assert.equal((await energy.status("alice")).balance, 4);
  h.setTime(h.now + 31000);
  const a = await ads.prepare("alice", "android", "energy_refill", req(12));
  await Promise.all([ads.accept(event(a.ticket)), ads.accept(event(a.ticket))]);
  assert.equal((await energy.status("alice")).balance, 6);
  await spend(h, 3); await spend(h, 4); h.setTime(h.now + 31000);
  const b = await ads.prepare("alice", "android", "energy_refill", req(13));
  await ads.accept(event(b.ticket));
  await spend(h, 5); await spend(h, 6); h.setTime(h.now + 31000);
  await assert.rejects(ads.prepare("alice", "android", "energy_refill", req(14)), /alınamaz/);
  const hint = await ads.prepare("alice", "android", "quiz_hint", req(15));
  await ads.accept(event(hint.ticket));
  const result = await quiz.status("alice");
  assert.notEqual(result.eliminated, null);
  assert.notEqual(result.eliminated, select(result.question.day).answer);
  assert.equal(h.read("economyState/alice/balances/coins"), 0);
});

test("interrupted quiz reward projection retries coin and XP exactly once", async () => {
  const h = setup(); const v = await h.call("getDailyQuestion");
  const input = {day: v.question.day, questionId: v.question.id, option: select(v.question.day).answer};
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitDailyQuestion", input), /Simulated/);
  await h.call("getDailyQuestion");
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 10);
  assert.equal(Object.keys(h.read("dailyQuestionState/alice/pending")).length, 0);
});


test("old clients cannot open story ad hints before energy access", async () => {
  const h = setup();
  await assert.rejects(h.call("prepareRewardedAd", {platform: "android", placement: "story_hint",
    requestId: req(1), context: {journeyId: "messi", taskId: "messi_v2_1"}}), /güncelle/);
  await assert.rejects(h.call("prepareRewardedAd", {platform: "android", placement: "story_hint",
    energyClientVersion: 1, requestId: req(1), context: {journeyId: "messi", taskId: "messi_v2_1"}}), /aç/);
});

test("midnight resets allowances without refilling energy; Pro bonus is once per Istanbul day", async () => {
  const h = setup(); h.setTime("2026-10-14T20:50:00Z");
  const service = require("../energy").createService({db: h.db, normalize: h.context.lbEconomyState,
    now: () => h.now, isPro: async () => true,
    getRollout: async () => ({enabled: true, percent: 100, minClientVersion: 1})});
  for (let n = 1; n <= 6; n++) await spend(h, n);
  await Promise.all([service.proBonus("alice"), service.proBonus("alice")]);
  assert.equal((await service.status("alice")).balance, 2);
  h.setTime("2026-10-14T21:01:00Z");
  const next = await service.status("alice");
  assert.equal(next.balance, 2); assert.equal(next.daily.pro, false);
  await service.proBonus("alice");
  assert.equal((await service.status("alice")).balance, 4);
  h.setTime("2026-10-14T21:50:00Z");
  assert.equal((await service.status("alice")).balance, 5);
});

test("a verified bonus waits at capacity then settles once; no energy or quiz reward mints SP", async () => {
  const h = setup(); const service = h.context.lbEnergyService();
  const receipt = {id: "capacity_receipt", context: {day: "2026-09-20"}};
  await assert.rejects(service.settleReward("alice", receipt), /bekliyor/);
  await spend(h, 1); await spend(h, 2);
  await service.settleReward("alice", receipt); await service.settleReward("alice", receipt);
  assert.equal((await service.status("alice")).balance, 6);
  const q = await h.call("getDailyQuestion");
  await h.call("submitDailyQuestion", {day: q.question.day, questionId: q.question.id, option: 0});
  const engine = require("../season_pass");
  const score = engine.points(h.read("economyState/alice/claims"), engine.seasonAt(h.now), h.now);
  assert.equal(score.sp, 0); assert.equal(score.todaySp, 0);
});

test("30-day participation badge is projected by the quiz, not a client claim", async () => {
  const h = setup();
  h.seed("dailyQuestionState/alice", {total: 29, streak: 2, lastDay: "2026-09-19"});
  const q = await h.call("getDailyQuestion");
  await h.call("submitDailyQuestion", {day: q.question.day, questionId: q.question.id, option: 0});
  assert.ok(h.read("userAchievements/alice/daily_question_30"));
  assert.equal(h.read("userAchievements/alice/daily_question_100"), null);
});


test("publication history prevents a repeat even when a new catalog would select an old question", async () => {
  const h = setup();
  const q = select("2026-09-20");
  h.seed("dailyQuestionPrivate/2026-09-13", {id: q.id});
  const shown = await h.call("getDailyQuestion");
  assert.notEqual(shown.question.id, q.id);
  assert.equal((await h.call("getDailyQuestion")).question.id, shown.question.id);
});
