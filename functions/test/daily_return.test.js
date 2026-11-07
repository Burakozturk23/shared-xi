"use strict";
// Faz 2: Günlük Dönüş — loop supports, free missed-day cover, all-missions bonus.
const test = require("node:test");
const assert = require("node:assert/strict");
const DR = require("../daily_return");
const {harness} = require("./support/economy_harness");

const ON = {enabled: true, loopSupports: true, streakProtection: true, allMissionsBonus: true};
// Faz 2 supports need typed supports live for the player.
const BOOSTS = {enabled: true, betaUids: {alice: true}, readyModes: {career: true}};
const LIVE = {dailyReturn: ON, boosts: BOOSTS};
const coins = (h) => h.read("economyState/alice")?.balances.coins || 0;
const stock = (h, id) => h.read(`economyState/alice/inventory/${id}/quantity`) || 0;
const nextDay = (h) => h.setTime(h.now + 86400000);
const dailyIds = ["daily_ranked_play_3", "daily_ranked_win_1", "daily_challenge_1"];
async function readyMissions(h) {
  await h.call("getMyMissions");
  h.seed("missionState/alice/daily/counters", {rankedPlayed: 3, rankedWins: 1, dailyChallenge: 1});
}

test("policy is all off unless enabled, and each part has its own switch", () => {
  assert.deepEqual(DR.policy(null), {enabled: false, loopSupports: false, streakProtection: false,
    allMissionsBonus: false});
  assert.equal(DR.policy({loopSupports: true}, true).loopSupports, false);
  // Without typed supports only the missed-day cover can be on.
  assert.deepEqual(DR.policy(ON, false), {enabled: true, loopSupports: false, streakProtection: true,
    allMissionsBonus: false});
  assert.deepEqual(DR.loopSchedule(DR.policy(ON, true)), [null, null, "boost_basic", null, null, null, "boost_strong"]);
  assert.deepEqual(DR.loopSchedule(DR.OFF), [null, null, null, null, null, null, null]);
});

test("free cover: exactly one missed day, at most once in seven days", () => {
  const p = DR.policy(ON, true);
  const daily = {lastClaimDay: "2026-11-01", currentStreak: 4, lastProtectedDay: ""};
  assert.equal(DR.freeProtection(daily, "2026-11-03", p), true);
  assert.equal(DR.freeProtection(daily, "2026-11-02", p), false); // no gap
  assert.equal(DR.freeProtection(daily, "2026-11-04", p), false); // two days missed
  assert.equal(DR.freeProtection(daily, "2026-11-03", DR.OFF), false);
  assert.equal(DR.freeProtection({...daily, lastProtectedDay: "2026-10-28"}, "2026-11-03", p), false);
  assert.equal(DR.freeProtection({...daily, lastProtectedDay: "2026-10-27"}, "2026-11-03", p), true);
  assert.equal(DR.protectionReadyOn({lastProtectedDay: "2026-10-28"}), "2026-11-04");
});

test("flag off: the check-in loop is exactly today's (coins only, no cover)", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 0}}}});
  for (let day = 1; day <= 3; day++) {
    const r = await h.call("claimDailyReward");
    assert.equal(r.support, null);
    nextDay(h);
  }
  assert.equal(stock(h, "boost_basic"), 0);
  nextDay(h); // one day missed
  await h.call("claimDailyReward");
  assert.equal(h.read("progressionState/alice/daily/currentStreak"), 1);
});

test("day 3 adds one Temel bilgi and day 7 one Güçlü bilgi, once each, with the same coins", async () => {
  const h = harness({runtimeConfig: LIVE, economyState: {alice: {balances: {coins: 0}}}});
  const first = await h.call("getMyProgression");
  assert.deepEqual([...first.profile.dailyReward.scheduleSupports], DR.loopSchedule(DR.policy(ON, true)));
  const amounts = [];
  for (let day = 1; day <= 7; day++) {
    const results = await Promise.all([h.call("claimDailyReward"), h.call("claimDailyReward")]);
    amounts.push(results.find((r) => r.granted).amount);
    if (day === 3) assert.equal(results.find((r) => r.granted).support.itemId, "boost_basic");
    nextDay(h);
  }
  assert.deepEqual(amounts, [10, 12, 15, 18, 20, 25, 30]);
  assert.equal(coins(h), 130);
  assert.equal(stock(h, "boost_basic"), 1);
  assert.equal(stock(h, "boost_strong"), 1);
  // A retry of day 7 and a later read never add a second support.
  h.setTime(h.now - 86400000);
  assert.equal((await h.call("claimDailyReward")).alreadyClaimed, true);
  await h.call("getMyProgression");
  assert.equal(stock(h, "boost_strong"), 1);
});

test("a lost support write is settled by the next read, still once", async () => {
  const h = harness({runtimeConfig: LIVE, economyState: {alice: {balances: {coins: 0}}}});
  for (let day = 1; day <= 2; day++) {
    await h.call("claimDailyReward"); nextDay(h);
  }
  await h.call("claimDailyReward");
  // Simulate the support transaction never having run.
  h.seed("economyState/alice/storeUses/daily_reward__" + h.read("progressionState/alice/daily/lastClaimDay"), null);
  h.seed("economyState/alice/inventory/boost_basic", null);
  await h.call("getMyProgression");
  await h.call("getMyProgression");
  assert.equal(stock(h, "boost_basic"), 1);
});

test("a full bag stays at 99 and pays half the store price in coins, once", async () => {
  const h = harness({runtimeConfig: LIVE, economyState: {alice: {balances: {coins: 0},
    inventory: {boost_basic: {itemId: "boost_basic", itemType: "boost", quantity: 99}}}}});
  for (let day = 1; day <= 2; day++) {
    await h.call("claimDailyReward"); nextDay(h);
  }
  const r = await h.call("claimDailyReward");
  assert.deepEqual({...r.support}, {itemId: "boost_basic", granted: false, full: true, coins: 12});
  assert.equal(stock(h, "boost_basic"), 99);
  assert.equal(coins(h), 10 + 12 + 15 + 12);
  await h.call("getMyProgression");
  assert.equal(coins(h), 49);
  const day = h.read("progressionState/alice/daily/lastClaimDay");
  assert.equal(h.read(`economyLedger/alice/support_overflow__daily_reward__${day}`).amount, 12);
});

test("free cover keeps the streak once, then a second miss within seven days resets it", async () => {
  const h = harness({runtimeConfig: LIVE});
  for (let day = 1; day <= 3; day++) {
    await h.call("claimDailyReward"); nextDay(h);
  }
  nextDay(h); // missed one day
  const view = await h.call("getMyProgression");
  assert.equal(view.profile.dailyReward.wouldUseStreakProtection, true);
  const covered = await h.call("claimDailyReward");
  assert.equal(covered.streakProtected, true);
  assert.equal(h.read("progressionState/alice/daily/currentStreak"), 4);
  nextDay(h); await h.call("claimDailyReward");
  nextDay(h); nextDay(h); // missed again, three days after the cover
  const reset = await h.call("claimDailyReward");
  assert.equal(reset.streakProtected, false);
  assert.equal(h.read("progressionState/alice/daily/currentStreak"), 1);
});

test("all-missions bonus: legacy path gives one Temel bilgi on the third claim, at most two a week", async () => {
  const h = harness({runtimeConfig: LIVE});
  h.setTime("2026-11-02T09:00:00Z"); // Monday
  const results = [];
  for (let day = 0; day < 3; day++) {
    await readyMissions(h);
    for (const missionId of dailyIds) results.push(await h.call("claimMissionReward", {missionId}));
    nextDay(h);
  }
  assert.equal(stock(h, "boost_basic"), 2);
  const bonuses = results.filter((r) => r.supportBonus);
  assert.equal(bonuses.length, 3);
  assert.equal(bonuses.filter((r) => r.supportBonus.granted).length, 2);
  assert.equal(bonuses[2].supportBonus.weeklyLimit, true);
  assert.equal(coins(h), 180); // missions still pay their coins, the bonus adds none
  // A new week opens two more.
  h.setTime("2026-11-09T09:00:00Z");
  await readyMissions(h);
  for (const missionId of dailyIds) await h.call("claimMissionReward", {missionId});
  assert.equal(stock(h, "boost_basic"), 3);
});

test("all-missions bonus is off by default", async () => {
  const h = harness({runtimeConfig: {boosts: BOOSTS}});
  await readyMissions(h);
  for (const missionId of dailyIds) await h.call("claimMissionReward", {missionId});
  assert.equal(stock(h, "boost_basic"), 0);
});

test("typed supports off: no Faz 2 supports, the missed-day cover still works", async () => {
  const h = harness({runtimeConfig: {dailyReturn: ON}});
  for (let day = 1; day <= 3; day++) {
    const r = await h.call("claimDailyReward");
    assert.equal(r.support, null);
    nextDay(h);
  }
  assert.equal(stock(h, "boost_basic"), 0);
  nextDay(h);
  assert.equal((await h.call("claimDailyReward")).streakProtected, true);
});

test("bonus receipts are shared: the same day never pays twice whichever path asks", () => {
  const e = {inventory: {}, storeUses: {}, claims: {}, balances: {coins: 0}, lifetimeEarned: 0};
  const p = DR.policy(ON, true);
  assert.equal(DR.grantAllMissionsBonus(e, "2026-11-02", 1, p).granted, true);
  assert.equal(DR.grantAllMissionsBonus(e, "2026-11-02", 2, p).granted, false);
  assert.equal(e.inventory.boost_basic.quantity, 1);
  assert.equal(DR.bonusesThisWeek(e, "2026-11-08"), 1); // Sunday, same week
  assert.equal(DR.bonusesThisWeek(e, "2026-11-09"), 0);
});
