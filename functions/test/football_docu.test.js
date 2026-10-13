"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, accepts} = require("../football_docu");
const proof = (t) => ({version: 2, taskId: t.id, answers: t.answerKeys});
const first = catalog.tasks[0];
test("FootballDocu has 24 episodes, 48 redacted tasks and exact mechanic distribution", () => {
  const counts = {};
  for (const t of catalog.tasks) counts[t.mechanic] = (counts[t.mechanic] || 0) + 1;
  assert.deepEqual(counts, {evidence: 14, turning: 9, person: 8, timeline: 9, headline: 8});
  const app = require("../../assets/data/football_docu_v2.json");
  assert.equal(app.episodes.length, 24); assert.equal(app.tasks.length, 48);
  for (const t of app.tasks) for (const k of ["answerKeys", "result", "verification"]) assert.equal(t[k], undefined);
  for (const d of app.episodes) assert.equal(d.story, undefined);
});
test("FootballDocu all 48 tasks grant exactly 564 coin / 1410 XP and 24 files once", async () => {
  const h = harness();
  for (const t of catalog.tasks) await h.call("submitFootballDocu", proof(t));
  await Promise.all(catalog.tasks.map((t) => h.call("submitFootballDocu", proof(t))));
  const s = await h.call("getFootballDocu");
  assert.equal(Object.keys(s.results).length, 48); assert.equal(Object.keys(s.files).length, 24);
  assert.equal(s.archivist, true); assert.equal(Object.keys(s.rewards).length, 51);
  assert.equal(h.read("economyState/alice/balances/coins"), 564);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 1410);
  for (const ns of ["internationalGloryState", "whatIfState", "uclMomentsState",
    "turkishNostalgiaState", "journeyRewardState"]) {
    assert.equal(h.read(ns + "/alice"), null);
  }
});
test("FootballDocu locks second research and private history until the correct prerequisites", async () => {
  const h = harness();
  const initial = await h.call("getFootballDocu");
  assert.deepEqual(initial.results, {}); assert.deepEqual(initial.files, {});
  await assert.rejects(h.call("submitFootballDocu", proof(catalog.tasks[1])));
  await assert.rejects(h.call("buyFootballDocuHint", {...proof(catalog.tasks[1]), maxPrice: 6}));
  await h.call("submitFootballDocu", proof(first));
  const halfway = await h.call("getFootballDocu");
  assert.equal(Object.keys(halfway.results).length, 1); assert.deepEqual(halfway.files, {});
  const complete = await h.call("submitFootballDocu", proof(catalog.tasks[1]));
  assert.equal(Object.keys(complete.files).length, 1);
});
test("FootballDocu validates sets, sequences, boolean claims and role assignments", () => {
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
  const t = catalog.tasks[0];
  assert.equal(accepts(t, [...t.answerKeys].reverse()), false);
});
test("FootballDocu rejects forged IDs, versions, unauthenticated users and wrong answers", async () => {
  const h = harness();
  await assert.rejects(h.call("submitFootballDocu", proof(first), null));
  await assert.rejects(h.call("submitFootballDocu", {...proof(first), version: 90}));
  for (const taskId of ["__proto__", "constructor", "DOC-99-01"]) {
    await assert.rejects(h.call("submitFootballDocu", {...proof(first), taskId}));
  }
  assert.deepEqual(await h.call("submitFootballDocu", {...proof(first), answers: ["wrong"]}), {correct: false});
  assert.equal(h.read("economyState/alice"), null);
});
test("FootballDocu repairs coin to XP interruption and isolates accounts", async () => {
  const h = harness(); h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitFootballDocu", proof(first)));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  await h.call("getFootballDocu"); await h.call("submitFootballDocu", proof(first));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 20);
  assert.deepEqual((await h.call("getFootballDocu", {}, {uid: "bob", token: {}})).results, {});
});
test("FootballDocu guests earn sealed progress but wallets settle only after same UID linking", async () => {
  const h = harness(); const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
  await h.call("submitFootballDocu", proof(first), guest);
  const s = await h.call("submitFootballDocu", proof(catalog.tasks[1]), guest);
  assert.equal(Object.keys(s.files).length, 1); assert.equal(s.rewardEligible, false);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["linked"]}}}};
  await h.call("getFootballDocu", {}, linked); await h.call("getFootballDocu", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 16);
});
test("FootballDocu hints respect confirmed price, verified Pro and idempotent receipts", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0, pro: true};
  await assert.rejects(h.call("buyFootballDocuHint", input));
  await assert.rejects(h.call("buyFootballDocuHint", {...input, maxPrice: undefined}));
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
  input.maxPrice = 6; h.failNext("footballDocuState/alice");
  await assert.rejects(h.call("buyFootballDocuHint", input));
  await Promise.all([h.call("buyFootballDocuHint", input), h.call("buyFootballDocuHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 44);
  assert.deepEqual((await h.call("getFootballDocu")).results, {});
});
test("FootballDocu interrupted free Pro receipt remains free after expiry", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const input = {version: 2, taskId: first.id, maxPrice: 0};
  h.failNext("footballDocuState/alice"); await assert.rejects(h.call("buyFootballDocuHint", input));
  assert.equal(h.read("economyState/alice/purchases/football_docu_v2_hint__" + first.id + "/priceCoins"), 0);
  h.seed("premiumState/alice", null); await h.call("buyFootballDocuHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
});
test("FootballDocu cannot charge a completed answer, an anonymous player or an empty wallet", async () => {
  const h = harness(); const input = {version: 2, taskId: first.id, maxPrice: 6};
  await assert.rejects(h.call("buyFootballDocuHint", input));
  await assert.rejects(h.call("buyFootballDocuHint", input,
      {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}}));
  await h.call("submitFootballDocu", proof(first));
  await assert.rejects(h.call("buyFootballDocuHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
});
test("Docu interlude unlocks one proof; second answers, sources and file stay private", async () => {
  const h = harness();
  const halfway = await h.call("submitFootballDocu", proof(first));
  assert.ok(halfway.results[first.id].interlude.split(/\s+/).length >= 60);
  assert.equal(halfway.results[catalog.tasks[1].id], undefined);
  assert.deepEqual(halfway.results[first.id].sources, []);
  assert.deepEqual(halfway.files, {});
  const complete = await h.call("submitFootballDocu", proof(catalog.tasks[1]));
  assert.ok(complete.results[first.id].sources.length);
  assert.ok(complete.files[first.episodeId].earnedAt > 0);
});
test("Docu true/false claims never sell an answer as extra help", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const t = catalog.tasks.find((t) => t.interaction === "boolean" && t.stage === 1);
  await assert.rejects(h.call("buyFootballDocuHint", {...proof(t), maxPrice: 6}));
  assert.equal(h.read("economyState/alice/balances/coins"), 50);
});
test("Docu server state is private, App Check enforced and deleted with account", () => {
  const fs = require("node:fs");
  const rules = require("../../database.rules.json").rules.footballDocuState;
  assert.equal(rules[".read"], false); assert.equal(rules[".write"], false);
  const source = fs.readFileSync(require.resolve("../index"), "utf8");
  assert.match(source, /updates\["footballDocuState\/" \+ uid\] = null/);
  const adapter = source.slice(source.indexOf("function lbFootballDocuCallable"));
  assert.match(adapter, /enforceAppCheck: true/);
});
