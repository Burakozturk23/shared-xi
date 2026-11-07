"use strict";
// Beta lists for the energy rollout and the season Pro avatars (only the owner first).
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const energy = require("../energy");
const A = require("../anagram_practice");

test("energy rollout: a beta uid is in at 0 %, others are not", () => {
  const r = {enabled: true, percent: 0, betaUids: {alice: true}};
  assert.equal(energy.inRollout(r, "alice"), true);
  assert.equal(energy.inRollout(r, "bob"), false);
  assert.equal(energy.inRollout({...r, enabled: false}, "alice"), false);
  assert.equal(energy.inRollout({enabled: true, percent: 100}, "bob"), true);
});

test("energy rollout: a beta uid pays energy in a session mode", async () => {
  const h = harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {anagram_practice: true}}, energy: {enabled: true, percent: 0, betaUids: {alice: true},
    sessionModes: ["anagram"]}}, economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
  assert.equal((await h.call("getAnagramPractice")).energyCost, 1);
  const other = harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {anagram_practice: true}}, energy: {enabled: true, percent: 0, betaUids: {bob: true},
    sessionModes: ["anagram"]}}, economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
  assert.equal((await other.call("getAnagramPractice")).energyCost, 0);
  assert.ok(A.version);
});

test("season avatars: a beta list limits the Pro avatar steps; the old {enabled} shape stays global", async () => {
  const steps = async (cfg) => (await harness({runtimeConfig: {seasonAvatars: cfg}})
      .call("getSeasonPass")).supportSteps;
  assert.deepEqual(await steps({enabled: true, public: false, betaUids: {bob: true}}), []);
  assert.ok((await steps({enabled: true, public: false, betaUids: {alice: true}})).length > 0);
  assert.ok((await steps({enabled: true})).length > 0);
});
