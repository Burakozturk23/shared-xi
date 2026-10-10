"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, matches} = require("../ucl_moments");
const proof = (m) => ({version: 1, matchId: m.id, answers: m.answerKeys});
test("UCL: 34 matches, exact mechanic counts, 15 provider references, no answer keys in APK", () => {
  const counts = {};
  for (const m of catalog.matches) counts[m.type] = (counts[m.type] || 0) + 1;
  assert.deepEqual(counts, {timeline: 4, hero: 9, goal: 10, score: 4, xi: 7});
  assert.equal(catalog.matches.filter((m) => m.verification.statsBombMatchId).length, 15);
  assert.equal(new Set(catalog.matches.map((m) => m.date + ":" + m.home.id + ":" + m.away.id)).size, 34);
  const app = require("../../assets/data/ucl_moments_v2.json");
  assert.equal(app.matches.length, 34);
  for (const m of app.matches) {
    assert.ok(!Object.hasOwn(m, "answerKeys") && !Object.hasOwn(m, "result") && !Object.hasOwn(m, "verification"));
    const server = matches[m.id];
    for (const answer of server.answerKeys) {
      const label = server.options.find((o) => o.id === answer).label;
      for (const key of ["title", "intro", "hint"]) assert.ok(!m[key].includes(label));
    }
    assert.equal(m.options.length, m.type === "timeline" ? server.answerKeys.length : 4);
    if (m.type === "xi") {
      assert.equal(m.lineup.rows.flat().length, 11);
      assert.equal(m.lineup.rows.flat().filter((p) => p === "?").length, 1);
    }
  }
});
test("UCL validates all 34 and pays exactly 482 coin / 1005 XP once, including retries", async () => {
  const h = harness();
  for (const m of catalog.matches) await h.call("submitUclMoment", proof(m));
  await Promise.all(catalog.matches.map((m) => h.call("submitUclMoment", proof(m))));
  assert.equal(h.read("economyState/alice/balances/coins"), 482);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 1005);
  const s = await h.call("getUclMoments");
  assert.equal(Object.keys(s.completed).length, 34);
  assert.equal(Object.keys(s.results).length, 34);
  assert.equal(h.read("whatIfState/alice"), null);
  assert.equal(h.read("journeyRewardState/alice"), null);
});
test("UCL rejects wrong answers, versions, IDs and unauthenticated calls without disclosure", async () => {
  const h = harness();
  assert.deepEqual(Object.keys((await h.call("getUclMoments")).results), []);
  await assert.rejects(h.call("submitUclMoment", proof(catalog.matches[0]), null));
  await assert.rejects(h.call("submitUclMoment", {...proof(catalog.matches[0]), version: 88}));
  for (const matchId of ["__proto__", "constructor", "fake"]) {
    await assert.rejects(h.call("submitUclMoment", {...proof(catalog.matches[0]), matchId}));
  }
  for (const answers of [[], ["fake"], [...catalog.matches[0].answerKeys].reverse(), null, 1]) {
    const response = await h.call("submitUclMoment", {...proof(catalog.matches[0]), answers});
    assert.equal(response.correct, false);
    assert.equal(response.results, undefined);
  }
  assert.equal(h.read("economyState/alice"), null);
});
test("UCL durable receipt repairs XP failure without minting coins again; other user has no progress", async () => {
  const h = harness();
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitUclMoment", proof(catalog.matches[0])));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  await h.call("getUclMoments");
  await h.call("submitUclMoment", proof(catalog.matches[0]));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 20);
  assert.equal(Object.keys((await h.call("getUclMoments", {}, "bob")).completed).length, 0);
});
test("UCL guests can solve; rewards wait until eligible and then settle once", async () => {
  const h = harness();
  const service = h.context.lbUclMomentsService();
  const s = await service.submit("guest", proof(catalog.matches[2]), false);
  assert.equal(s.correct, true);
  assert.equal(s.rewardEligible, false);
  assert.equal(h.read("economyState/guest"), null);
  await service.status("guest", true);
  await service.status("guest", true);
  assert.equal(h.read("economyState/guest/balances/coins"), 8);
  assert.equal(h.read("progressionState/guest/lifetimeXp"), 20);
});
