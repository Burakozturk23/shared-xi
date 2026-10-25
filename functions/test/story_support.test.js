"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {definitions} = require("../mission_story_events");
const {content, help} = require("../story_support");
const B = require("../boosts");
let seq = 98000;
const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
function setup() {
  return harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: Object.fromEntries(definitions.map((d) => [d[1], true]))}},
  economyState: {alice: {balances: {coins: 1000}, inventory: {boost_strong: {itemType: "boost", quantity: 2}}}}},
  {omitEmptyObjects: true});
}
const first = (mode) => Object.values(content(mode).targets)[0];
const load = (h, mode, target = first(mode).task.id) => h.call("getStorySupport", {mode, targetId: target});
const request = (mode, view, extra = {}) => ({mode, targetId: first(mode).task.id,
  contentVersion: view.contentVersion, sessionId: view.session.id, revision: view.session.revision,
  requestId: id(), boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25, ...extra});
for (const [collection, mode] of definitions) {
  test(`${mode}: authoritative paid clue, exact retry, mirror and preserved progress`, async () => {
    const h = setup(); h.seed(collection + "/alice", {favorites: ["saved"], oldReceipt: {settled: true}});
    let v = await load(h, mode); assert.equal(v.legacy, false);
    assert.equal(v.session.support.products[0].priceCoins, 25);
    const input = request(mode, v);
    const [a, b] = await Promise.all([h.call("useStorySupport", input), h.call("useStorySupport", input)]);
    assert.deepEqual(a, b); v = a;
    assert.equal(v.hints.boost_basic, first(mode).task.hint);
    assert.equal(v.session.support.assisted, true);
    assert.equal(h.read(root + "/balances/coins"), 975);
    assert.equal(h.read(collection + "/alice/oldReceipt/settled"), true);
    const section = first(mode).section;
    assert.equal(h.read(root + "/storyStates/" + collection + "/supportAssisted/" + section), true);
    await assert.rejects(h.call("useStorySupport", {...input, expectedPriceCoins: 24}), {code: "invalid-argument"});
    await assert.rejects(h.call("useStorySupport", request(mode, v)), {code: "already-exists"});
    const strong = request(mode, v, {boostId: "boost_strong", paymentSource: "stock", expectedPriceCoins: undefined});
    v = await h.call("useStorySupport", strong);
    assert.equal(v.hints.boost_strong, help(first(mode).task, "boost_strong"));
    assert.equal(h.read(root + "/inventory/boost_strong/quantity"), 1);
    assert.equal(h.read(root + "/balances/coins"), 975);
    await h.call("getEnergyStatus");
    assert.equal(h.read(root + "/storyStates/" + collection + "/supportAssisted/" + section), true);
  });
}
test("story completion, stale revision/content, wrong SKU, account and stock cannot debit", async () => {
  const h = setup(); const mode = "derby_day"; const v = await load(h, mode); const input = request(mode, v);
  for (const patch of [{revision: 99}, {contentVersion: "old"}, {boostId: "boost_connection"},
    {paymentSource: "stock"}, {expectedPriceCoins: 0}]) {
    await assert.rejects(h.call("useStorySupport", {...input, ...patch}));
    assert.equal(h.read(root + "/balances/coins"), 1000);
  }
  h.setLinked("alice", false);
  await assert.rejects(h.call("useStorySupport", input), {code: "permission-denied"});
  h.setLinked("alice", true);
  const p = root + "/storyStates/derbyDayState";
  h.seed(p + "/completed/" + input.targetId, h.now);
  await assert.rejects(h.call("useStorySupport", input), {code: "failed-precondition"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
  const other = {uid: "bob", token: {firebase: {identities: {"google.com": ["bob"]}}}};
  await assert.rejects(h.call("useStorySupport", input, other));
});
test("prior task locks and unavailable strong clue never charge", async () => {
  for (const mode of ["player_journey", "nostalgia", "dynasties", "football_docu"]) {
    const h = setup(); const second = Object.values(content(mode).targets)[1];
    await assert.rejects(load(h, mode, second.task.id), {code: "failed-precondition"});
    assert.equal(h.read(root + "/balances/coins"), 1000);
  }
  const mode = "football_docu"; const h = setup();
  const t = Object.values(content(mode).targets).find((t) => t.task.interaction === "boolean" && t.task.stage === 1);
  assert.ok(t); const v = await load(h, mode, t.task.id);
  assert.equal(v.session.support.products.some((p) => p.id === "boost_strong"), false);
  await assert.rejects(h.call("useStorySupport", request(mode, v, {targetId: t.task.id,
    boostId: "boost_strong", expectedPriceCoins: 60})), {code: "failed-precondition"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("canonical commit survives interrupted compatibility mirror without a second debit", async () => {
  const h = setup(); const mode = "nostalgia"; const v = await load(h, mode); const input = request(mode, v);
  h.failNext("nostalgiaState/alice");
  await assert.rejects(h.call("useStorySupport", input));
  assert.equal(h.read(root + "/balances/coins"), 975);
  const result = await h.call("useStorySupport", input);
  assert.ok(result.hints.boost_basic); assert.equal(h.read(root + "/balances/coins"), 975);
  assert.ok(h.read("nostalgiaState/alice/supportAssisted/" + first(mode).section));
});
test("grandfathered Pro and off-pilot retain old policy; dated new offer requires paid hints", async () => {
  const h = setup(); const pro = {verified: true, plan: "yearly", startedAt: h.now - 1000, expiresAt: h.now + 999999};
  h.seed("premiumState/alice", pro);
  assert.deepEqual(await load(h, "what_if"), {legacy: true});
  h.seed("runtimeConfig/boosts/proOfferCutoverAt", h.now);
  assert.deepEqual(await load(h, "what_if"), {legacy: true});
  h.seed("premiumState/alice/startedAt", h.now);
  assert.equal((await load(h, "what_if")).legacy, false);
  const off = setup(); off.seed("runtimeConfig/boosts/enabled", false);
  assert.deepEqual(await load(off, "what_if"), {legacy: true});
  assert.equal(off.read(root + "/storyStates"), null);
});
test("old unlocked hint and interrupted old purchase remain owned, legacy price cannot bypass new policy", async () => {
  const h = setup(); const mode = "what_if"; const task = first(mode).task;
  h.seed(root + "/purchases/what_if_hint__" + task.id, {priceCoins: 10});
  const v = await load(h, mode);
  assert.equal(v.hints.boost_basic, task.hint); assert.equal(v.hints.boost_strong, task.strongHint);
  assert.equal(h.read(root + "/balances/coins"), 1000);
  const clean = setup();
  const scenario = require("../what_if").catalog.scenarios[0]; const route = scenario.routes[0];
  await assert.rejects(clean.call("buyWhatIfHint", {scenarioId: scenario.id, routeId: route.id}),
      {code: "failed-precondition"});
  assert.equal(clean.read(root + "/balances/coins"), 1000);
});
test("story ad verifies SKU/run, prohibits strong ad and recovers late SSV once", async () => {
  const h = setup(); const mode = "derby_day"; const v = await load(h, mode);
  const input = request(mode, v); const service = h.context.lbStorySupportService();
  const benefit = await service.prepareHint("alice", "story_support_hint", input);
  assert.equal(benefit.requireVerifiedAd, true); assert.equal(benefit.context.boostId, "boost_basic");
  await assert.rejects(service.prepareHint("alice", "story_support_hint", {...input, sessionId: "foreign"}));
  await assert.rejects(service.prepareHint("alice", "story_support_hint", {...input, boostId: "boost_strong"}));
  const receipt = {id: "c".repeat(48), context: benefit.context};
  h.seed(root + "/storyStates/derbyDayState/completed/" + input.targetId, h.now);
  await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  assert.equal(h.read(root + "/inventory/boost_basic/quantity"), 1);
  const run = h.read(root + "/storyStates/derbyDayState/supportRuns/" + v.session.id);
  assert.equal(run.adGranted, 1); assert.equal((B.view(run).adCreditsByProduct.boost_basic || 0), 0);
});
test("story credited hint recovers on authoritative completion and survives a full bag", async () => {
  const h = setup(); const mode = "derby_day"; const v = await load(h, mode);
  const input = request(mode, v); const service = h.context.lbStorySupportService();
  const benefit = await service.prepareHint("alice", "story_support_hint", input);
  const receipt = {id: "b5".repeat(24), context: benefit.context};
  await service.settleHint("alice", receipt);
  const stock = root + "/inventory/boost_basic"; h.seed(stock, {quantity: 99, itemType: "boost"});
  await h.call("submitDerbyDay", {version: require("../derby_day").catalog.version,
    taskId: input.targetId, answers: first(mode).task.answerKeys});
  assert.equal(h.read(root + "/storyStates/derbyDayState/supportRuns/" + v.session.id + "/adCredits"), 1);
  h.seed(stock + "/quantity", 98); await load(h, mode); await load(h, mode);
  assert.equal(h.read(stock + "/quantity"), 99);
  assert.equal(h.read(root + "/storyStates/derbyDayState/supportRuns/" + v.session.id + "/adCredits"), 0);
});
