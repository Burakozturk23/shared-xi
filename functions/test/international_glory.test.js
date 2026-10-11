"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../international_glory");
const proof = (m) => ({version: 2, matchId: m.id, answers: m.answerKeys});
test("International catalog has exact mechanic counts and no private answers in APK", () => {
  const counts = {};
  for (const m of catalog.matches) counts[m.type] = (counts[m.type] || 0) + 1;
  assert.deepEqual(counts, {critical: 12, timeline: 7, penalty: 9, route: 7, xi: 5});
  const app = require("../../assets/data/international_glory_v2.json");
  assert.equal(app.matches.length, 40);
  for (const m of app.matches) {
    assert.equal(m.answerKeys, undefined); assert.equal(m.result, undefined); assert.equal(m.verification, undefined);
  }
});
test("International Glory validates all 40 and pays exactly 640 coin / 1275 XP once, including retries", async () => {
  const h = harness();
  for (const m of catalog.matches) await h.call("submitInternationalGlory", proof(m));
  await Promise.all(catalog.matches.map((m) => h.call("submitInternationalGlory", proof(m))));
  assert.equal(h.read("economyState/alice/balances/coins"), 640);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 1275);
  const s = await h.call("getInternationalGlory");
  assert.equal(Object.keys(s.completed).length, 40);
  assert.equal(Object.keys(s.results).length, 40);
  assert.equal(h.read("whatIfState/alice"), null);
  assert.equal(h.read("journeyRewardState/alice"), null);
});
test("International rejects wrong answers, versions, IDs and unauthenticated calls", async () => {
  const h = harness();
  assert.deepEqual(Object.keys((await h.call("getInternationalGlory")).results), []);
  await assert.rejects(h.call("submitInternationalGlory", proof(catalog.matches[0]), null));
  await assert.rejects(h.call("submitInternationalGlory", {...proof(catalog.matches[0]), version: 88}));
  for (const matchId of ["__proto__", "constructor", "fake"]) {
    await assert.rejects(h.call("submitInternationalGlory", {...proof(catalog.matches[0]), matchId}));
  }
  for (const answers of [[], ["fake"], [...catalog.matches[1].answerKeys].reverse(), null, 1]) {
    const response = await h.call("submitInternationalGlory", {...proof(catalog.matches[0]), answers});
    assert.equal(response.correct, false);
    assert.equal(response.results, undefined);
  }
  assert.equal(h.read("economyState/alice"), null);
});
test("International receipt repairs XP failure without minting twice and isolates users", async () => {
  const h = harness();
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitInternationalGlory", proof(catalog.matches[0])));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  await h.call("getInternationalGlory");
  await h.call("submitInternationalGlory", proof(catalog.matches[0]));
  assert.equal(h.read("economyState/alice/balances/coins"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 20);
  assert.equal(Object.keys((await h.call("getInternationalGlory", {}, {uid: "bob", token: {}})).completed).length, 0);
});
test("International Glory guests can solve; rewards wait until eligible and then settle once", async () => {
  const h = harness();
  const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
  const s = await h.call("submitInternationalGlory", proof(catalog.matches[2]), guest);
  assert.equal(s.correct, true);
  assert.equal(s.rewardEligible, false);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["linked"]}}}};
  await h.call("getInternationalGlory", {}, linked);
  await h.call("getInternationalGlory", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 8);
  assert.equal(h.read("progressionState/guest/lifetimeXp"), 20);
});

test("International hints use canonical receipts and cannot unlock matches", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const input = {version: 2, matchId: catalog.matches[0].id, pro: true};
  await Promise.all([h.call("buyInternationalGloryHint", input), h.call("buyInternationalGloryHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 44);
  const s = await h.call("getInternationalGlory");
  assert.equal(Object.keys(s.hints).length, 1); assert.equal(Object.keys(s.results).length, 0);
  await assert.rejects(h.call("buyInternationalGloryHint", input,
      {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}}));
});
test("International hint crash retry does not charge twice", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 50}}}});
  const input = {version: 2, matchId: catalog.matches[1].id};
  h.failNext("internationalGloryState/alice");
  await assert.rejects(h.call("buyInternationalGloryHint", input));
  await h.call("buyInternationalGloryHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 44);
});
