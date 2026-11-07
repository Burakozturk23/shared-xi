"use strict";
// İpucu v2 routing: runtimeConfig/boosts {version: 2} pins hints, anything else keeps boosts.js.
const test = require("node:test");
const assert = require("node:assert/strict");
const H = require("../hints");
const B = require("../boosts");

const v1 = {enabled: true, betaUids: {alice: true}, readyModes: {transfer: true}};
const v2 = {...v1, version: 2};
const run = (extra = {}) => ({id: "r1", mode: "transfer", expiresAt: Date.now() + 9e6, ...extra});

test("v2 policy pins hints, v1 pins boosts", () => {
  const a = run(); H.pinAny(a, v2, null, 1);
  assert.equal(H.active(a), true);
  assert.equal(B.paid(a), false);
  const b = run(); H.pinAny(b, v1, null, 1);
  assert.equal(H.active(b), false);
  assert.equal(B.paid(b), true);
});

test("boosts.pin ignores a v2 policy", () => {
  const a = run(); B.pin(a, v2);
  assert.equal(B.paid(a), false);
});

test("a v1 run stays v1 after the flag becomes v2", () => {
  const a = run(); H.pinAny(a, v1, null, 1);
  // The flag flips: the open run is never re-pinned, its policy stays.
  assert.equal(B.paid(a), true);
  assert.equal(H.active(a), false);
  assert.equal(H.view(a), null);
});

test("readyModes off for a mode: neither pins", () => {
  const a = run({mode: "mystery"}); H.pinAny(a, v2, null, 1);
  assert.equal(H.active(a), false);
  assert.equal(B.paid(a), false);
});

test("policyFor carries version and live hint prices", async () => {
  const db = {ref: () => ({get: async () => ({val: () => v2})})};
  B.usePrices(async () => ({enabled: true, boosts: require("../price_config").defaults.boosts,
    hints: {light: {single: 30, pack: 80}, strong: {single: 50, pack: 130}}}));
  try {
    const p = await B.policyFor(db, "alice", true);
    assert.equal(p.version, 2);
    assert.deepEqual(p.hintPrices.light, {single: 30, pack: 80});
    const a = run(); H.pinAny(a, p, null, 1);
    assert.equal(H.active(a), true);
    assert.deepEqual(a.hintPolicy.prices.light, {single: 30, pack: 80});
  } finally {
    B.usePrices(async () => null);
  }
});
