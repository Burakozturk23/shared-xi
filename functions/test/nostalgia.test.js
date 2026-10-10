"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {harness} = require("./support/economy_harness");
const {catalog, tasks} = require("../nostalgia");
const all = Object.values(tasks);
const proof = (t) => ({version: 2, taskId: t.id, answers: t.answerKeys});
test("nostalgia catalog: 12 chapters, 24 reviewed unique tasks, five mechanics and runtime parity", () => {
  assert.deepEqual(catalog, require("../../assets/data/turkish_nostalgia_v2.json"));
  assert.equal(catalog.chapters.length, 12);
  assert.equal(all.length, 24);
  const counts = {};
  for (const c of catalog.chapters) {
    assert.equal(c.tasks.length, 2);
    assert.notEqual(c.tasks[0].mechanic, c.tasks[1].mechanic);
    for (const t of c.tasks) {
      counts[t.mechanic] = (counts[t.mechanic] || 0) + 1;
      assert.equal(t.chapterId, c.id);
      assert.equal(t.verification, "A");
      assert.ok(t.spoilerReviewed && t.sources.length && t.hint && t.strongHint && t.explanation);
      assert.equal(new Set(t.options.map((o) => o.id)).size, t.options.length);
      assert.equal(new Set(t.options.map((o) => o.label)).size, t.options.length);
      for (const key of t.answerKeys) {
        const label = t.options.find((o) => o.id === key)?.label;
        assert.ok(label);
        for (const text of [c.title, c.era, c.intro, t.hint]) {
          assert.ok(!text.includes(label), t.id + " leaks " + label);
        }
      }
      if (t.mechanic === "timeline") {
        assert.equal(t.options.length, t.answerKeys.length);
        assert.notDeepEqual(t.options.map((o) => o.id), t.answerKeys);
      } else {
        assert.equal(t.options.length, 4);
      }
      if (t.mechanic === "route") assert.equal(t.slots.length, t.answerKeys.length);
      if (t.mechanic === "squad") assert.ok(t.role);
      for (const source of t.sources) assert.ok(source.url.startsWith("https://") && source.accessed);
    }
  }
  assert.deepEqual(counts, {season: 7, route: 4, squad: 5, legend: 5, timeline: 3});
});
test("24 tasks award exactly 384 coins and 840 XP, including concurrent replay", async () => {
  const h = harness();
  for (const t of all) await h.call("submitTurkishNostalgia", proof(t));
  await Promise.all(all.map((t) => h.call("submitTurkishNostalgia", proof(t))));
  const s = await h.call("getTurkishNostalgia");
  assert.equal(Object.keys(s.completed).length, 24);
  assert.equal(Object.keys(s.rewards).length, 37);
  assert.equal(h.read("economyState/alice/balances/coins"), 384);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 840);
  for (const path of ["uclMomentsState", "whatIfState", "journeyRewardState"]) {
    assert.equal(h.read(path + "/alice"), null);
  }
});
test("reject invalid, reordered and duplicate answers; require first task and auth", async () => {
  const h = harness();
  await assert.rejects(h.call("submitTurkishNostalgia", proof(all[1])));
  await assert.rejects(h.call("submitTurkishNostalgia", proof(all[0]), null));
  for (const id of ["__proto__", "constructor", "unknown"]) {
    await assert.rejects(h.call("submitTurkishNostalgia", {...proof(all[0]), taskId: id}));
  }
  await assert.rejects(h.call("submitTurkishNostalgia", {...proof(all[0]), version: 1}));
  for (const answers of [null, {}, [], ["fake"], [1]]) {
    assert.equal((await h.call("submitTurkishNostalgia", {...proof(all[0]), answers})).correct, false);
  }
  const t = all.find((t) => t.answerKeys.length > 1);
  for (const answers of [[...t.answerKeys].reverse(), Array(t.answerKeys.length).fill(t.answerKeys[0])]) {
    assert.equal((await h.call("submitTurkishNostalgia", {...proof(t), answers})).correct, false);
  }
  assert.equal(h.read("economyState/alice"), null);
});
test("interrupted coin/XP settlement repairs on status and cannot mint twice", async () => {
  const h = harness();
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitTurkishNostalgia", proof(all[0])));
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  await h.call("getTurkishNostalgia");
  await h.call("submitTurkishNostalgia", proof(all[0]));
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 15);
});
test("hint receipt costs six once, survives entitlement-write failure, and rejects insufficient funds", async () => {
  const h = harness();
  await assert.rejects(h.call("buyTurkishNostalgiaHint", proof(all[0])));
  await h.call("submitTurkishNostalgia", proof(all[0]));
  h.failNext("nostalgiaState/alice");
  await assert.rejects(h.call("buyTurkishNostalgiaHint", proof(all[0])));
  await Promise.all([
    h.call("buyTurkishNostalgiaHint", proof(all[0])), h.call("buyTurkishNostalgiaHint", proof(all[0])),
  ]);
  assert.equal(h.read("economyState/alice/balances/coins"), 0);
  assert.equal(h.read("economyState/alice/lifetimeSpent"), 6);
  assert.equal(h.read("nostalgiaState/alice/hints/" + all[0].id), true);
});
test("trusted Pro hint is free; request-pro is not trusted; guests cannot buy", async () => {
  const h = harness();
  await assert.rejects(h.call("buyTurkishNostalgiaHint", {...proof(all[0]), pro: true}));
  h.seed("premiumState/alice", {verified: true, entitled: true, plan: "lifetime", productId: "premium_lifetime"});
  await h.call("buyTurkishNostalgiaHint", proof(all[0]));
  assert.equal(h.read("economyState/alice/lifetimeSpent"), 0);
  const guest = {uid: "guest", token: {}};
  await assert.rejects(h.call("buyTurkishNostalgiaHint", proof(all[0]), guest));
});
test("guest progress waits for linked account, distinct UID cannot inherit rewards", async () => {
  const h = harness();
  const guest = {uid: "guest", token: {}};
  await h.call("submitTurkishNostalgia", proof(all[0]), guest);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["g"]}}}};
  await h.call("getTurkishNostalgia", {}, linked);
  await h.call("getTurkishNostalgia", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 6);
  assert.equal(Object.keys((await h.call("getTurkishNostalgia")).completed).length, 0);
});
test("server-only rules and deletion cover nostalgia namespace", () => {
  const rules = require("../../database.rules.json").rules.nostalgiaState;
  assert.deepEqual(rules, {".read": false, ".write": false});
  const code = fs.readFileSync(require.resolve("../index.js"), "utf8");
  assert.ok(code.includes("updates[\"nostalgiaState/\" + uid] = null;"));
  assert.ok(code.includes("exports.submitTurkishNostalgia = lbNostalgiaCallable(\"submit\")"));
});
