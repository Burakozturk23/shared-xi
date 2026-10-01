"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {seasonAt, points, reward} = require("../season_pass");
function receipts(days = 10) {
  return Object.fromEntries(Array.from({length: days}, (_, i) => ["d" + i,
    {claimedAt: Date.parse(`2026-09-${String(i + 1).padStart(2, "0")}T12:00:00Z`),
      amount: 20, sourceType: "daily_reward", sourceId: "day" + i}]));
}
test("Istanbul month boundary, leap year and daily SP cap", () => {
  assert.equal(seasonAt(Date.parse("2026-09-30T21:00:00Z")).id, "2026-10");
  assert.equal(seasonAt(Date.parse("2028-02-01T00:00:00Z")).endsOn, "2028-02-29");
  const now = Date.parse("2026-09-20T10:00:00Z");
  const claims = Object.fromEntries(Array.from({length: 10}, (_, i) => [i,
    {claimedAt: now, amount: 20, sourceType: "mission_reward", sourceId: "general__" + i}]));
  assert.deepEqual(points(claims, seasonAt(now), now), {sp: 150, todaySp: 150});
});
test("ads, purchases, season claims, future receipts and past months do not mint SP", () => {
  const now = Date.parse("2026-09-20T10:00:00Z");
  const claims = {};
  for (const type of ["coin_purchase", "rewarded_coin", "season_pass", "achievement"]) {
    claims[type] = {sourceType: type, amount: 100, claimedAt: now};
  }
  claims.double = {sourceType: "daily_match", sourceId: "2026-09-20_1_double", amount: 30, claimedAt: now};
  claims.old = {sourceType: "daily_reward", amount: 10, claimedAt: Date.parse("2026-08-20")};
  claims.future = {sourceType: "daily_reward", amount: 10, claimedAt: now + 86400000};
  assert.equal(points(claims, seasonAt(now), now).sp, 0);
  claims.base = {sourceType: "daily_match", sourceId: "2026-09-20_1_base", amount: 30, claimedAt: now};
  claims.base2 = {...claims.base, sourceId: "2026-09-20_2_base"};
  assert.equal(points(claims, seasonAt(now), now).sp, 50);
});
test("actual callable rejects unauthenticated, forged points, locked Pro and invalid tiers", async () => {
  const h = harness();
  await assert.rejects(h.call("getSeasonPass", {}, null), {code: "unauthenticated"});
  await assert.rejects(h.call("claimSeasonReward", {seasonId: "2026-09", step: 1, lane: "free", sp: 99999}),
      {code: "failed-precondition"});
  h.seed("economyState/alice/claims", receipts());
  const s = await h.call("getSeasonPass");
  assert.equal(s.level, 1);
  assert.equal(s.pro, false);
  await assert.rejects(h.call("claimSeasonReward", {seasonId: s.id, step: 1, lane: "pro", pro: true}),
      {code: "failed-precondition"});
  await assert.rejects(h.call("claimSeasonReward", {seasonId: s.id, step: 0, lane: "free"}),
      {code: "invalid-argument"});
});
test("concurrent reward requests credit once; lost projection recovers; wallet is account scoped", async () => {
  const h = harness({economyState: {alice: {claims: receipts()}}});
  const input = {seasonId: "2026-09", step: 1, lane: "free"};
  const results = await Promise.all([h.call("claimSeasonReward", input), h.call("claimSeasonReward", input)]);
  assert.equal(results.filter((r) => r.granted).length, 1);
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  assert.equal(h.read("economyState/bob"), null);
  assert.equal((await h.call("getSeasonPass")).sp, 100);
  const other = harness({economyState: {alice: {claims: receipts()}}});
  other.failNext("");
  // The wallet's claim record is canonical even if a derived view fails.
  await assert.rejects(other.call("claimSeasonReward", input), /Simulated interrupted write/);
  await other.call("claimSeasonReward", input);
  assert.equal(other.read("economyState/alice/balances/coins"), 20);
});
test("month rollover rejects stale screen; current-season Pro upgrade unlocks earned tiers", async () => {
  const h = harness({economyState: {alice: {claims: receipts()}}});
  h.seed("premiumState/alice", {verified: true, entitled: true, plan: "lifetime", expiresAt: 0});
  // Use the real premium normalizer rather than a client-provided flag.
  const raw = h.context.lbPremiumState(h.read("premiumState/alice"), h.now);
  assert.equal(raw.active, true);
  const input = {seasonId: "2026-09", step: 1, lane: "pro"};
  assert.equal((await h.call("claimSeasonReward", input)).granted, true);
  h.seed("premiumState/alice", null);
  assert.equal((await h.call("claimSeasonReward", input)).granted, false);
  h.setTime("2026-09-30T21:00:00Z");
  const s = await h.call("getSeasonPass");
  assert.equal(s.level, 0);
  assert.equal(s.id, "2026-10");
  await assert.rejects(h.call("claimSeasonReward", input), {code: "failed-precondition"});
  assert.equal(h.read("economyState/alice/balances/coins"), 40);
});
test("published free and Pro reward totals match all 20 stops", () => {
  for (const [lane, total] of [["free", 560], ["pro", 1040]]) {
    assert.equal(Array.from({length: 20}, (_, i) => reward(i + 1, lane)).reduce((a, b) => a + b), total);
  }
});
