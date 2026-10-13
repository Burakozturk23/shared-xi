"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, scenarios} = require("../what_if");
const {createService} = require("../rewarded_ads");
const {defaults} = require("../economy_config");
const unit = "ca-app-pub-1234567890123456/1234567890";
const proof = (id, routeId = "real") => ({version: 1, scenarioId: id, routeId,
  answers: scenarios[id].routes.find((r) => r.id === routeId).task.answerKeys});
test("What If catalog agrees with app: 24 stories, 48 route tasks, five mechanics", () => {
  assert.deepEqual(catalog, require("../../assets/data/what_if_v2.json"));
  assert.equal(catalog.scenarios.length, 24);
  assert.equal(new Set(catalog.scenarios.flatMap((s) => s.routes.map((r) => r.task.type))).size, 5);
});
test("all 48 endings pay only 420 coins / 900 XP, durable receipts and four badges", async () => {
  const h = harness();
  for (const id of Object.keys(scenarios)) {
    await h.call("submitWhatIf", proof(id));
    await h.call("submitWhatIf", proof(id, "alternate"));
  }
  await Promise.all([h.call("submitWhatIf", proof("messi")), h.call("submitWhatIf", proof("messi"))]);
  assert.equal(h.read("economyState/alice/balances/coins"), 420);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 900);
  for (const id of ["what_if_first", "what_if_eight", "what_if_all", "what_if_dual"]) {
    assert.ok(h.read("userAchievements/alice/" + id));
  }
  const status = await h.call("getWhatIf");
  assert.deepEqual(Array.from(status.chapterCounts), [8, 8, 8]);
  await h.call("setWhatIfShowcase", {ids: ["messi", "gerrard", "neymar"]});
  await assert.rejects(h.call("setWhatIfShowcase", {ids: ["messi", "messi"]}));
  await assert.rejects(h.call("setWhatIfShowcase", {ids: ["messi", "gerrard", "neymar", "zidane"]}));
  assert.equal(h.read("journeyRewardState/alice"), null);
});
test("rejects guests, forged routes, wrong order, unknown versions and unearned showcase", async () => {
  const h = harness();
  await assert.rejects(h.call("getWhatIf", {}, null));
  for (const input of [{...proof("messi"), version: 20}, {...proof("messi"), routeId: "fake"},
    {...proof("messi"), scenarioId: "__proto__"}, {...proof("messi"), answers: ["o1"]},
    {...proof("neymar"), answers: ["o2", "o1", "o0"]}]) {
    await assert.rejects(h.call("submitWhatIf", input));
  }
  await assert.rejects(h.call("setWhatIfShowcase", {ids: ["messi"]}));
  assert.equal(h.read("economyState/alice"), null);
});
test("XP failure repairs reward outbox without paying coin twice or losing journey claims", async () => {
  const h = harness();
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitWhatIf", proof("messi")));
  assert.equal(h.read("economyState/alice/balances/coins"), 10);
  await h.call("getWhatIf");
  await h.call("getMyProgression");
  await h.call("submitWhatIf", proof("messi"));
  assert.equal(h.read("economyState/alice/balances/coins"), 10);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 25);
  const journeys = require("../player_journey").journeys;
  for (const task of journeys.messi.tasks) {
    await h.call("submitPlayerJourney", {version: 1, journeyId: "messi", taskId: task.id,
      answers: task.answerKeys.slice(0, task.requiredCount)});
  }
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 65);
});
test("hint debit recovers after crash; no double debit, solved routes reject purchase", async () => {
  const h = harness();
  const input = {scenarioId: "messi", routeId: "alternate"};
  await assert.rejects(h.call("buyWhatIfHint", input));
  h.seed("economyState/alice", {balances: {coins: 30}});
  h.failNext("whatIfState/alice");
  await assert.rejects(h.call("buyWhatIfHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  await h.call("buyWhatIfHint", input);
  await h.call("buyWhatIfHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  assert.equal(h.read("whatIfState/alice/hints/messi__alternate/coin"), true);
  await h.call("submitWhatIf", proof("messi"));
  await assert.rejects(h.call("buyWhatIfHint", {scenarioId: "messi", routeId: "real"}));
});
test("SSV verifies new placements; replay and mismatch cannot duplicate +180 coin or double XP", async () => {
  const h = harness();
  const service = h.context.lbWhatIfService();
  let seq = 0;
  const ads = createService({db: h.db, now: () => h.now, units: {android: unit},
    getConfig: async () => defaults, isPro: async () => false, isLinked: async () => true,
    grantCoins: () => {
      throw Error("Must use What If receipt");
    },
    prepareWhatIfReward: service.prepareReward, settleWhatIfReward: service.settleReward,
    randomId: () => (++seq).toString(16).padStart(48, "0")});
  const prepare = (p, c, id) => ads.prepare("alice", "android", p,
      id || (++seq).toString(16).padStart(32, "0"), c);
  await assert.rejects(prepare("what_if_double", {chapter: 1}));
  const context = {scenarioId: "messi", routeId: "real"};
  const ticket = (await prepare("what_if_hint", context, "a".repeat(32))).ticket;
  await assert.rejects(prepare("what_if_hint", {...context, routeId: "alternate"}, "a".repeat(32)));
  assert.equal(h.read("whatIfState/alice/hints/messi__real"), null);
  const event = (t) => ({user_id: "alice", custom_data: t.id, timestamp: h.now,
    ad_unit: unit, transaction_id: "tx_" + t.id});
  await ads.accept(event(ticket));
  await ads.accept(event(ticket));
  assert.equal(h.read("whatIfState/alice/hints/messi__real/ad"), true);
  for (const id of Object.keys(scenarios)) await h.call("submitWhatIf", proof(id));
  for (let chapter = 1; chapter <= 3; chapter++) {
    h.setTime(h.now + 31000);
    const t = (await prepare("what_if_double", {chapter})).ticket;
    await ads.accept(event(t));
    await ads.accept(event(t));
    await assert.rejects(prepare("what_if_double", {chapter}));
  }
  assert.equal(h.read("economyState/alice/balances/coins"), 600);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 900);
});
test("Pro grants hints without ad unit; no-fill and cancellation grant nothing", async () => {
  const h = harness();
  const whatIf = h.context.lbWhatIfService();
  const make = (pro, units = {}) => createService({db: h.db, now: () => h.now, units,
    getConfig: async () => defaults, isPro: async () => pro, isLinked: async () => true,
    grantCoins: () => {
      throw Error("Wrong settlement");
    },
    prepareWhatIfReward: whatIf.prepareReward, settleWhatIfReward: whatIf.settleReward});
  const context = {scenarioId: "messi", routeId: "real"};
  await assert.rejects(make(false).prepare("alice", "android", "what_if_hint", "a".repeat(32), context));
  const ads = make(false, {android: unit});
  const t = await ads.prepare("alice", "android", "what_if_hint", "b".repeat(32), context);
  await ads.cancel("alice", t.ticket.id);
  assert.equal(h.read("whatIfState/alice"), null);
  h.setTime(h.now + 31000);
  const p = await make(true).prepare("alice", "android", "what_if_hint", "c".repeat(32), context);
  assert.equal(p.pro, true);
  assert.equal(h.read("whatIfState/alice/hints/messi__real/ad"), true);
  assert.equal(h.read("economyState/alice"), null);
});
