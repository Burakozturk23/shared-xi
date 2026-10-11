"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, accepts} = require("../derby_day");
const proof = (t) => ({version: 2, taskId: t.id, answers: t.answerKeys});
const first = catalog.tasks[0];
test("DerbyDay validates sets, sequences, boolean claims and role assignments", () => {
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
  const t = catalog.tasks.find((t) => t.interaction === "order");
  assert.equal(accepts(t, [...t.answerKeys].reverse()), false);
});
test("DerbyDay rejects forged IDs, versions, unauthenticated users and wrong answers", async () => {
  const h = harness();
  await assert.rejects(h.call("submitDerbyDay", proof(first), null));
  await assert.rejects(h.call("submitDerbyDay", {...proof(first), version: 90}));
  for (const taskId of ["__proto__", "constructor", "DER-99"]) {
    await assert.rejects(h.call("submitDerbyDay", {...proof(first), taskId}));
  }
  assert.deepEqual(await h.call("submitDerbyDay", {...proof(first), answers: ["wrong"]}), {correct: false});
  assert.equal(h.read("economyState/alice"), null);
});
test("DerbyDay repairs coin to XP interruption and isolates accounts", async () => {
  const h = harness(); h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitDerbyDay", proof(first)));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  await h.call("getDerbyDay"); await h.call("submitDerbyDay", proof(first));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 20);
  assert.deepEqual((await h.call("getDerbyDay", {}, {uid: "bob", token: {}})).results, {});
});
test("DerbyDay guests earn sealed progress but wallets settle only after same UID linking", async () => {
  const h = harness(); const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
  await h.call("submitDerbyDay", proof(first), guest);
  const s = await h.call("submitDerbyDay", proof(catalog.tasks[1]), guest);
  assert.equal(Object.keys(s.stamps).length, 2); assert.equal(s.rewardEligible, false);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["linked"]}}}};
  await h.call("getDerbyDay", {}, linked); await h.call("getDerbyDay", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 16);
});
test("DerbyDay hints respect confirmed price, verified Pro and idempotent receipts", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0, pro: true};
  await assert.rejects(h.call("buyDerbyDayHint", input));
  await assert.rejects(h.call("buyDerbyDayHint", {...input, maxPrice: undefined}));
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
  input.maxPrice = 6; h.failNext("derbyDayState/alice");
  await assert.rejects(h.call("buyDerbyDayHint", input));
  await Promise.all([h.call("buyDerbyDayHint", input), h.call("buyDerbyDayHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 44);
  assert.deepEqual((await h.call("getDerbyDay")).results, {});
});
test("DerbyDay interrupted free Pro receipt remains free after expiry", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0};
  h.failNext("derbyDayState/alice"); await assert.rejects(h.call("buyDerbyDayHint", input));
  assert.equal(h.read("economyState/alice/purchases/derby_day_v2_hint__" + first.id + "/priceCoins"), 0);
  h.seed("premiumState/alice", null); await h.call("buyDerbyDayHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
});
test("DerbyDay cannot charge a completed answer, an anonymous player or an empty wallet", async () => {
  const h = harness(); const input = {version: 2, taskId: first.id, maxPrice: 6};
  await assert.rejects(h.call("buyDerbyDayHint", input));
  await assert.rejects(h.call("buyDerbyDayHint", input,
      {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}}));
  await h.call("submitDerbyDay", proof(first));
  await assert.rejects(h.call("buyDerbyDayHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
});
test("Derby server state is private, App Check enforced and deleted with account", () => {
  const fs = require("node:fs");
  const rules = require("../../database.rules.json").rules.derbyDayState;
  assert.equal(rules[".read"], false); assert.equal(rules[".write"], false);
  const source = fs.readFileSync(require.resolve("../index"), "utf8");
  assert.match(source, /updates\["derbyDayState\/" \+ uid\] = null/);
  const adapter = source.slice(source.indexOf("function lbDerbyDayCallable"));
  assert.match(adapter, /enforceAppCheck: true/);
});

test("Derby all 48 tasks settle exactly once including concurrent replay and 10/25/48 badges", async () => {
  const h = harness();
  for (const t of catalog.tasks) await h.call("submitDerbyDay", proof(t));
  await Promise.all(catalog.tasks.map((t) => h.call("submitDerbyDay", proof(t))));
  const s = await h.call("getDerbyDay");
  assert.equal(Object.keys(s.stamps).length, 48); assert.equal(s.master, true);
  assert.equal(Object.keys(s.rewards).length, 51);
  assert.equal(h.read("economyState/alice/balances/coins"), 564);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 1410);
  for (const ns of ["footballDocuState", "dynastiesState", "journeyRewardState"]) {
    assert.equal(h.read(ns + "/alice"), null);
  }
});
test("Derby initial response and shipped assets reveal no answers, sources or portrait identity", async () => {
  const h = harness(); const initial = await h.call("getDerbyDay");
  assert.deepEqual(initial.results, {}); assert.deepEqual(initial.stamps, {});
  const app = require("../../assets/data/derby_day_v2.json");
  assert.equal(app.tasks.length, 48); assert.equal(app.countries.length, 16);
  for (const t of app.tasks) {
    for (const k of ["answerKeys", "result", "verification", "playerId"]) assert.equal(t[k], undefined);
  }
  const s = await h.call("submitDerbyDay", proof(first));
  assert.ok(s.results[first.id].sources.length); assert.ok(s.stamps[first.id].earnedAt > 0);
  assert.equal(s.results[catalog.tasks[1].id], undefined);
});
test("Derby milestones open precisely at 10, 25 and 48 stamps", async () => {
  const h = harness();
  for (const [i, t] of catalog.tasks.entries()) {
    const s = await h.call("submitDerbyDay", proof(t));
    for (const count of [10, 25, 48]) assert.equal(!!s.rewards["milestone_" + count], i + 1 >= count);
  }
});
