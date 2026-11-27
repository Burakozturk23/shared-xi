"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const F = require("../daily_footballer");
const root = "economyState/alice"; let seq = 18000; const id = () => (++seq).toString(16).padStart(32, "0");
function setup(rewardsEnabled = true) {
  return harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {daily_footballer: true}}, dailyFootballer: {rewardsEnabled}},
  economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
}
const load = (h) => h.call("getDailyFootballer", {});
const input = (r, action, extra = {}) => ({requestId: id(), day: r.dayKey, sessionId: r.id,
  revision: r.revision, action, ...extra});
const act = async (h, r, action, extra) => (await h.call("actDailyFootballer", input(r, action, extra))).session;
const coins = (h) => h.read(root + "/balances/coins");
const xp = (h) => h.read("progressionState/alice/lifetimeXp") || 0;
const target = (h, r) => h.read(root + "/dailyFootballer/days/" + r.dayKey + "/target/id");
const wrong = (h, r) => F.catalog.players.find((p) => p.id !== target(h, r)).id;

test("a solved footballer pays 3 coin / 8 XP exactly once", async () => {
  const h = setup(); let r = (await load(h)).session;
  r = await act(h, r, "guess", {playerId: target(h, r)});
  assert.equal(r.won, true); assert.deepEqual(r.reward, {coins: 3, xp: 8, rewardEnabled: true});
  assert.equal(coins(h), 1003); assert.equal(xp(h), 8);
  await load(h); await load(h);
  assert.equal(coins(h), 1003); assert.equal(xp(h), 8);
});

test("an assisted solve keeps the coin but halves the XP", async () => {
  const h = setup(); let r = (await load(h)).session;
  r = await act(h, r, "guess", {playerId: wrong(h, r)});
  r = await act(h, r, "hint", {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25});
  r = await act(h, r, "guess", {playerId: target(h, r)});
  assert.equal(r.assisted, true); assert.deepEqual(r.reward, {coins: 3, xp: 4, rewardEnabled: true});
  assert.equal(coins(h), 978); assert.equal(xp(h), 4);
});

test("rewards stay off until the runtime flag opens them", async () => {
  const h = setup(false); let r = (await load(h)).session;
  r = await act(h, r, "guess", {playerId: target(h, r)});
  assert.deepEqual(r.reward, {coins: 0, xp: 0, rewardEnabled: false});
  assert.equal(coins(h), 1000); assert.equal(xp(h), 0);
});

test("an unsolved footballer earns nothing", async () => {
  const h = setup(); let r = (await load(h)).session;
  const others = F.catalog.players.filter((p) => p.id !== target(h, r)).slice(0, 6);
  for (const p of others) r = await act(h, r, "guess", {playerId: p.id});
  r = await act(h, r, "reveal");
  assert.equal(r.won, false); assert.equal(r.reward, null);
  assert.equal(coins(h), 1000); assert.equal(xp(h), 0);
});
