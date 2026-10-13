"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {accepts} = require("../dynasties");
const catalog = require("../config/dynasties_catalog.json");
const proof = (t) => ({version: 2, taskId: t.id, answers: t.answerKeys});
const first = catalog.tasks[0];
test("Dynasties has 16 eras, 32 redacted tasks and exact mechanic distribution", () => {
  const counts = {};
  for (const t of catalog.tasks) counts[t.mechanic] = (counts[t.mechanic] || 0) + 1;
  assert.deepEqual(counts, {tactics: 5, trophies: 7, timeline: 7, squad: 8, records: 5});
  const app = require("../../assets/data/dynasties_v2.json");
  assert.equal(app.dynasties.length, 16); assert.equal(app.tasks.length, 32);
  for (const t of app.tasks) for (const k of ["answerKeys", "result", "verification"]) assert.equal(t[k], undefined);
  for (const d of app.dynasties) assert.equal(d.story, undefined);
});
test("Dynasties all 32 tasks grant exactly 456 coin / 1015 XP and 16 seals once", async () => {
  const h = harness();
  for (const t of catalog.tasks) await h.call("submitDynasties", proof(t));
  await Promise.all(catalog.tasks.map((t) => h.call("submitDynasties", proof(t))));
  const s = await h.call("getDynasties");
  assert.equal(Object.keys(s.results).length, 32); assert.equal(Object.keys(s.seals).length, 16);
  assert.equal(s.historian, true); assert.equal(Object.keys(s.rewards).length, 36);
  assert.equal(h.read("economyState/alice/balances/coins"), 456);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 1015);
  for (const ns of ["internationalGloryState", "whatIfState", "uclMomentsState",
    "turkishNostalgiaState", "journeyRewardState"]) {
    assert.equal(h.read(ns + "/alice"), null);
  }
});
test("Dynasties locks summit and private history until the correct prerequisites", async () => {
  const h = harness();
  const initial = await h.call("getDynasties");
  assert.deepEqual(initial.results, {}); assert.deepEqual(initial.seals, {});
  await assert.rejects(h.call("submitDynasties", proof(catalog.tasks[1])));
  await assert.rejects(h.call("buyDynastiesHint", {...proof(catalog.tasks[1]), maxPrice: 6}));
  await h.call("submitDynasties", proof(first));
  const halfway = await h.call("getDynasties");
  assert.equal(Object.keys(halfway.results).length, 1); assert.deepEqual(halfway.seals, {});
  const complete = await h.call("submitDynasties", proof(catalog.tasks[1]));
  assert.equal(Object.keys(complete.seals).length, 1);
});
test("Dynasties validates sets, sequences, duplicate Reims cards and role assignments", () => {
  for (const t of catalog.tasks) {
    assert.equal(accepts(t, t.answerKeys), true);
    for (const invalid of [null, [], 1, ["fake"], [...t.answerKeys, t.answerKeys[0]]]) {
      assert.equal(accepts(t, invalid), false);
    }
    if (t.answerKeys.length > 1) {
      assert.equal(accepts(t, [...t.answerKeys].reverse()), t.interaction === "multi");
      assert.equal(accepts(t, t.answerKeys.map(() => t.answerKeys[0])), false);
    }
  }
  const madrid = catalog.tasks[10]; const reversed = [...madrid.answerKeys];
  [reversed[0], reversed[3]] = [reversed[3], reversed[0]];
  assert.equal(accepts(madrid, reversed), false);
});
test("Dynasties rejects forged IDs, versions, unauthenticated users and wrong answers", async () => {
  const h = harness();
  await assert.rejects(h.call("submitDynasties", proof(first), null));
  await assert.rejects(h.call("submitDynasties", {...proof(first), version: 90}));
  for (const taskId of ["__proto__", "constructor", "DY-99-01"]) {
    await assert.rejects(h.call("submitDynasties", {...proof(first), taskId}));
  }
  assert.deepEqual(await h.call("submitDynasties", {...proof(first), answers: ["wrong"]}), {correct: false});
  assert.equal(h.read("economyState/alice"), null);
});
test("Dynasties repairs coin to XP interruption and isolates accounts", async () => {
  const h = harness(); h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitDynasties", proof(first)));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  await h.call("getDynasties"); await h.call("submitDynasties", proof(first));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 20);
  assert.deepEqual((await h.call("getDynasties", {}, {uid: "bob", token: {}})).results, {});
});
test("Dynasties guests earn sealed progress but wallets settle only after same UID linking", async () => {
  const h = harness(); const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
  await h.call("submitDynasties", proof(first), guest);
  const s = await h.call("submitDynasties", proof(catalog.tasks[1]), guest);
  assert.equal(Object.keys(s.seals).length, 1); assert.equal(s.rewardEligible, false);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["linked"]}}}};
  await h.call("getDynasties", {}, linked); await h.call("getDynasties", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 16);
});
test("Dynasties hints respect confirmed price, verified Pro and idempotent receipts", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0, pro: true};
  await assert.rejects(h.call("buyDynastiesHint", input));
  await assert.rejects(h.call("buyDynastiesHint", {...input, maxPrice: undefined}));
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
  input.maxPrice = 6; h.failNext("dynastiesState/alice");
  await assert.rejects(h.call("buyDynastiesHint", input));
  await Promise.all([h.call("buyDynastiesHint", input), h.call("buyDynastiesHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 44);
  assert.deepEqual((await h.call("getDynasties")).results, {});
});
test("Dynasties interrupted free Pro receipt remains free after expiry", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0};
  h.failNext("dynastiesState/alice"); await assert.rejects(h.call("buyDynastiesHint", input));
  assert.equal(h.read("economyState/alice/purchases/dynasties_v2_hint__" + first.id + "/priceCoins"), 0);
  h.seed("premiumState/alice", null); await h.call("buyDynastiesHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
});
test("Dynasties cannot charge a completed answer, an anonymous player or an empty wallet", async () => {
  const h = harness(); const input = {version: 2, taskId: first.id, maxPrice: 6};
  await assert.rejects(h.call("buyDynastiesHint", input));
  await assert.rejects(h.call("buyDynastiesHint", input,
      {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}}));
  await h.call("submitDynasties", proof(first));
  await assert.rejects(h.call("buyDynastiesHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
});
