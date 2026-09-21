"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {defaults, DEFAULT_CONFIG, validateConfig, createProvider, publicContract} = require("../economy_config");
const copy = () => JSON.parse(JSON.stringify(defaults));

test("launch catalog keeps one currency, approved prices, source limits and non-spendable XP", () => {
  assert.deepEqual(defaults.sources.daily_reward.coinsByDay, [10, 12, 15, 18, 20, 25, 30]);
  assert.equal(defaults.sources.daily_mission.amount, 20);
  assert.equal(defaults.sources.daily_mission.dailyLimit, 3);
  assert.deepEqual(Object.values(defaults.sinks.cosmetics.offers).map((o) => o.priceCoins), [150, 250, 400, 600]);
  assert.equal(publicContract(DEFAULT_CONFIG).xpSpendable, false);
  assert.equal(DEFAULT_CONFIG.resetTimeZone, "Europe/Istanbul");
  assert.ok(Object.isFrozen(DEFAULT_CONFIG.sources.daily_reward.coinsByDay));
});

test("validator rejects malformed, partial, unsafe and unsupported economic policies", () => {
  const cases = [
    (c) => c.sources.daily_reward.coinsByDay.pop(),
    (c) => c.sources.daily_mission.amount = -10,
    (c) => c.sources.daily_mission.amount = 1.5,
    (c) => c.sources.daily_mission.amount = Number.MAX_SAFE_INTEGER,
    (c) => c.sources.daily_mission.amount = "20",
    (c) => c.sources.daily_mission.dailyLimit = 4,
    (c) => c.resetTimeZone = "UTC",
    (c) => c.sinks.cosmetics.offers.avatar_speedster_bolt.itemId = "other_item",
    (c) => c.sinks.cosmetics.offers.avatar_speedster_bolt.oneTime = false,
    (c) => c.sources.casual_completion.enabled = true,
    (c) => c.sources.weekly_mission.enabled = true,
    (c) => c.sources.special_event.enabled = true,
    (c) => c.sources.rewarded_coin.dailyLimit = 3,
    (c) => c.sinks.squad_extra_attempt.dailyLimit = 4,
    (c) => c.sources.achievement.rewards.unknown = 10,
    (c) => delete c.sources.general_mission,
  ];
  for (const mutate of cases) {
    const c = copy();
    mutate(c);
    assert.throws(() => validateConfig(c));
  }
  assert.throws(() => validateConfig("{broken"));
});

test("snapshot identity changes with values and is independent of object key order", () => {
  const c = copy();
  c.sources.daily_mission.amount = 25;
  assert.notEqual(validateConfig(c).configId, DEFAULT_CONFIG.configId);
  const reordered = Object.fromEntries(Object.entries(copy()).reverse());
  assert.equal(validateConfig(reordered).configId, DEFAULT_CONFIG.configId);
});

test("provider is lazy, single-flight and cached; invalid refresh retains last good value", async () => {
  let calls = 0;
  let clock = 100;
  let bad = false;
  const c = copy();
  c.sources.daily_mission.amount = 30;
  const get = createProvider({now: () => clock, ttlMs: 10, fetch: async () => {
    calls++;
    return bad ? "invalid json" : c;
  }});
  assert.equal(calls, 0);
  const values = await Promise.all([get(), get(), get()]);
  assert.equal(calls, 1);
  assert.equal(values[0].sources.daily_mission.amount, 30);
  await get();
  assert.equal(calls, 1);
  clock += 11;
  bad = true;
  const kept = await get();
  assert.equal(calls, 2);
  assert.equal(kept.configId, values[0].configId);
});

test("unreachable Remote Config falls back within the timeout without blocking discovery", async () => {
  const get = createProvider({timeoutMs: 5, fetch: () => new Promise(() => {})});
  assert.equal((await get()).configId, DEFAULT_CONFIG.configId);
});
