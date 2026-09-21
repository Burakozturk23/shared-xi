"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness, clone} = require("./support/economy_harness");
const engine = require("../squad_challenge");
const {defaults, validateConfig, squadPolicy} = require("../economy_config");
const {wallet, solve} = require("./squad_fixture");
const coinPath = "economyState/alice";
const coins = (h) => h.read(coinPath)?.balances.coins || 0;
const dailyIds = ["daily_ranked_play_3", "daily_ranked_win_1", "daily_challenge_1"];
async function readyMissions(h) {
  await h.call("getMyMissions");
  h.seed("missionState/alice/daily/counters", {rankedPlayed: 3, rankedWins: 1, dailyChallenge: 1});
}

test("economic callables reject missing identity before writing", async () => {
  const h = harness();
  for (const name of ["getEconomyContract", "getStoreCatalog", "claimDailyReward", "claimMissionReward",
    "claimAchievementReward", "purchaseEconomyOffer"]) {
    await assert.rejects(h.call(name, {}, null), {code: "unauthenticated"});
    await assert.rejects(h.call(name, {}, {uid: "alice", token: {}}), {code: "failed-precondition"});
  }
  assert.equal(h.read(coinPath), null);
});

test("ten concurrent daily claims credit coins and XP exactly once, ignoring forged client amounts/time", async () => {
  const h = harness();
  const results = await Promise.all(Array.from({length: 10}, () => h.call("claimDailyReward", {
    amount: 99999, xp: 99999, dateKey: "2099-01-01", premium: true,
  })));
  assert.equal(results.filter((r) => r.granted).length, 1);
  assert.equal(coins(h), 10);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 25);
  assert.equal(Object.keys(h.read(coinPath + "/claims")).length, 1);
  const ledger = h.read("economyLedger/alice/daily_reward__2026-09-20");
  assert.equal(ledger.balanceBefore, 0);
  assert.equal(ledger.balanceAfter, 10);
  assert.equal(ledger.idempotencyKey, "daily_reward__2026-09-20");
  assert.ok(ledger.economyConfigId.startsWith("economy-"));
});

test("daily reward resets at Istanbul midnight, then follows and wraps the seven day schedule", async () => {
  const h = harness();
  h.setTime("2026-09-20T20:59:59.000Z");
  assert.equal((await h.call("claimDailyReward")).amount, 10);
  assert.equal((await h.call("claimDailyReward")).alreadyClaimed, true);
  h.setTime("2026-09-20T21:00:00.000Z");
  assert.equal((await h.call("claimDailyReward")).amount, 12);
  for (const amount of [15, 18, 20, 25, 30, 10]) {
    h.setTime(h.now + 86400000);
    assert.equal((await h.call("claimDailyReward")).amount, amount);
  }
  assert.equal(h.read("progressionState/alice/daily/currentStreak"), 8);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 200);
});

test("config changes affect future rewards but replay and the claimed tile keep the original receipt", async () => {
  const h = harness();
  await h.call("claimDailyReward");
  h.setConfig((c) => c.sources.daily_reward.coinsByDay = [30, 40, 50, 60, 70, 80, 90]);
  const repeat = await h.call("claimDailyReward");
  assert.equal(repeat.amount, 10);
  assert.equal(repeat.profile.dailyReward.scheduleCoins[0], 10);
  assert.equal(repeat.profile.dailyReward.scheduleCoins[1], 40);
  assert.equal(coins(h), 10);
  h.setTime(h.now + 86400000);
  assert.equal((await h.call("claimDailyReward")).amount, 40);
});

test("daily outbox survives a wallet failure, midnight and config change without lost or duplicate coins", async () => {
  const h = harness();
  h.failNext(coinPath);
  await assert.rejects(h.call("claimDailyReward"), /interrupted/);
  assert.equal(coins(h), 0);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 25);
  h.setTime(h.now + 86400000);
  h.setConfig((c) => c.sources.daily_reward.coinsByDay.fill(80));
  await h.call("getMyProgression");
  await h.call("getMyProgression");
  assert.equal(coins(h), 10);
  assert.deepEqual(h.read("progressionState/alice/pendingRewards"), {});
  assert.equal((await h.call("claimDailyReward")).amount, 80);
  assert.equal(coins(h), 90);
});

test("lost projection response replays the same reward without double credit", async () => {
  const h = harness();
  h.failNext("");
  await assert.rejects(h.call("claimDailyReward"), /interrupted/);
  assert.equal(coins(h), 10);
  const replay = await h.call("claimDailyReward");
  assert.equal(replay.alreadyClaimed, true);
  assert.equal(coins(h), 10);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 25);
});

test("legacy progression migration settles an unpaid old receipt only once", async () => {
  const h = harness();
  const state = h.context.lbProgressionState(null, h.now - 86400000);
  state.version = 1;
  state.lifetimeXp = 25;
  state.daily.lastClaimDay = "2026-09-19";
  state.daily.lastClaim = {dateKey: "2026-09-19", coins: 70, xp: 25, claimedAt: h.now - 86400000};
  h.seed("progressionState/alice", state);
  await h.call("getMyProgression");
  await h.call("getMyProgression");
  assert.equal(coins(h), 70);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 25);
});

test("verified Premium preserves its multiplier and missed-day protection without changing XP", async () => {
  const h = harness();
  h.seed("premiumState/alice", {plan: "monthly", verified: true, expiresAt: h.now + 10 * 86400000});
  const first = await h.call("claimDailyReward");
  assert.equal(first.amount, 20);
  assert.equal(first.xp, 25);
  h.setTime(h.now + 2 * 86400000);
  const next = await h.call("claimDailyReward");
  assert.equal(next.amount, 24);
  assert.equal(next.streakProtected, true);
});

test("missions require trusted progress; daily claims obey configured limits across concurrent requests", async () => {
  const h = harness();
  await assert.rejects(h.call("claimMissionReward", {missionId: dailyIds[0], progress: 999, amount: 999}),
      {code: "failed-precondition"});
  await readyMissions(h);
  h.setConfig((c) => c.sources.daily_mission.dailyLimit = 2);
  const result = await Promise.allSettled(dailyIds.map((missionId) => h.call("claimMissionReward", {missionId})));
  assert.equal(result.filter((r) => r.status === "fulfilled").length, 2);
  assert.equal(coins(h), 40);
  const first = dailyIds.find((id) => h.read("missionState/alice/daily/claims/" + id));
  h.setConfig((c) => c.sources.daily_mission.amount = 80);
  const repeat = await h.call("claimMissionReward", {missionId: first});
  assert.equal(repeat.amount, 20);
  assert.equal(coins(h), 40);
});

test("three daily missions pay 60 and reset progress and limits only on the next server day", async () => {
  const h = harness();
  await readyMissions(h);
  await Promise.all(dailyIds.map((missionId) => h.call("claimMissionReward", {missionId})));
  assert.equal(coins(h), 60);
  h.setTime("2026-09-20T21:00:00Z");
  const profile = (await h.call("getMyMissions")).profile;
  assert.equal(profile.dailyCompletedCount, 0);
  assert.ok(profile.daily.every((m) => m.progress === 0 && !m.claimable));
  await readyMissions(h);
  await h.call("claimMissionReward", {missionId: dailyIds[0]});
  assert.equal(coins(h), 80);
});

test("mission outbox and legacy unpaid claims survive date reset", async () => {
  const h = harness();
  await readyMissions(h);
  const state = h.read("missionState/alice");
  state.version = 1;
  state.daily.claims[dailyIds[0]] = {rewardCoins: 17, claimedAt: h.now};
  state.pendingRewards = {mission_reward__general__recovery: {
    sourceType: "mission_reward", sourceId: "general__recovery", amount: 33, economyConfigId: "legacy",
  }};
  h.seed("missionState/alice", state);
  h.setTime(h.now + 86400000);
  await h.call("getMyMissions");
  await h.call("getMyMissions");
  assert.equal(coins(h), 50);
  assert.equal(h.read("missionState/alice/daily/claims/" + dailyIds[0]), null);
});

test("stale requests cannot reset a newer mission day, daily streak, or Squad attempts backwards", async () => {
  const h = harness();
  await h.call("claimDailyReward");
  await readyMissions(h);
  h.setTime(h.now - 86400000);
  await assert.rejects(h.call("claimDailyReward"), {code: "failed-precondition"});
  await assert.rejects(h.call("claimMissionReward", {missionId: dailyIds[0]}), {code: "failed-precondition"});
  assert.equal(h.read("missionState/alice/daily/dateKey"), "2026-09-20");
  assert.equal(h.read("progressionState/alice/daily/lastClaimDay"), "2026-09-20");
  const state = wallet();
  engine.apply(state, "status", {}, h.now + 86400000, false);
  assert.throws(() => engine.apply(state, "status", {}, h.now, false), {code: "failed-precondition"});
});

test("achievement authority, repricing and concurrent replay preserve a single original receipt", async () => {
  const h = harness();
  await assert.rejects(h.call("claimAchievementReward", {achievementId: "first_whistle", amount: 9999}),
      {code: "failed-precondition"});
  h.seed("userAchievements/alice/first_whistle", {unlockedAt: h.now});
  h.setConfig((c) => c.sources.achievement.rewards.first_whistle = 35);
  const results = await Promise.all([1, 2].map(() => h.call("claimAchievementReward", {
    achievementId: "first_whistle", amount: 9999,
  })));
  assert.equal(results.filter((r) => r.granted).length, 1);
  assert.equal(coins(h), 35);
  h.setConfig((c) => c.sources.achievement.rewards.first_whistle = 80);
  const repeat = await h.call("claimAchievementReward", {achievementId: "first_whistle"});
  assert.equal(repeat.amount, 35);
  assert.equal((await h.call("getEconomyContract")).economy.achievementRewards.first_whistle, 80);
});

test("store guards quotes/funds and concurrent purchases preserve Squad progress", async () => {
  const h = harness({economyState: {alice: wallet(500)}});
  h.seed(coinPath + "/squadChallenge", {day: "2026-09-20", freeUsed: 2});
  h.setConfig((c) => c.sinks.cosmetics.offers.avatar_speedster_bolt.priceCoins = 180);
  const data = {offerId: "avatar_speedster_bolt", priceCoins: 1, expectedPriceCoins: 150};
  await assert.rejects(h.call("purchaseEconomyOffer", data), {code: "failed-precondition"});
  await assert.rejects(h.call("purchaseEconomyOffer", {offerId: data.offerId}), {code: "failed-precondition"});
  assert.equal(coins(h), 500);
  const results = await Promise.all([1, 2, 3].map(() => h.call("purchaseEconomyOffer", {
    ...data, expectedPriceCoins: 180,
  })));
  assert.equal(results.filter((r) => r.purchased).length, 1);
  assert.equal(coins(h), 320);
  assert.equal(h.read(coinPath + "/squadChallenge/freeUsed"), 2);
  h.setConfig((c) => c.sinks.cosmetics.offers.avatar_speedster_bolt.priceCoins = 250);
  const replay = await h.call("purchaseEconomyOffer", data);
  assert.equal(replay.alreadyOwned, true);
  assert.equal(replay.priceCoins, 180);
  await assert.rejects(h.call("purchaseEconomyOffer", {offerId: "avatar_champion_cup", expectedPriceCoins: 600}),
      {code: "failed-precondition"});
  const ledger = h.read("economyLedger/alice/purchase__speedster_bolt");
  assert.equal(ledger.balanceBefore, 500);
  assert.equal(ledger.balanceAfter, 320);
  assert.equal(ledger.amount, -180);
});

test("pausing sources blocks new rewards but keeps valid old receipts", async () => {
  const h = harness();
  await h.call("claimDailyReward");
  h.setConfig((c) => {
    c.sources.daily_reward.enabled = false;
    c.sources.daily_mission.enabled = false;
    c.sources.achievement.enabled = false;
  });
  assert.equal((await h.call("claimDailyReward")).amount, 10);
  assert.deepEqual(clone((await h.call("getEconomyContract")).economy.achievementRewards), {});
  h.setTime(h.now + 86400000);
  await assert.rejects(h.call("claimDailyReward"), {code: "failed-precondition"});
  await readyMissions(h);
  await assert.rejects(h.call("claimMissionReward", {missionId: dailyIds[0]}), {code: "failed-precondition"});
  assert.equal(coins(h), 10);
});

test("Squad applies configured price and caps while finishing an existing run at its original reward", () => {
  const c = clone(defaults);
  c.sources.squad_challenge.freeAttempts = 1;
  c.sources.squad_challenge.rewards = [25, 35, 45];
  c.sinks.squad_extra_attempt.priceCoins = 15;
  c.sinks.squad_extra_attempt.dailyLimit = 1;
  const policy = squadPolicy(validateConfig(c));
  const now = Date.parse("2026-09-20T10:00:00Z");
  const day = engine.dayKey(now);
  const state = wallet(100);
  const mission = engine.missions(day, policy)[0];
  const input = {missionId: mission.id, requestId: day + "__" + "a".repeat(32)};
  const first = engine.apply(state, "start", input, now, false, policy).run;
  engine.apply(state, "abandon", {runId: first.id}, now, false, policy);
  const paid = {...input, requestId: day + "__" + "b".repeat(32), payment: "coins", expectedPriceCoins: 20};
  assert.throws(() => engine.apply(state, "start", paid, now, false, policy), {code: "failed-precondition"});
  assert.equal(state.balances.coins, 100);
  paid.expectedPriceCoins = 15;
  const run = engine.apply(state, "start", paid, now, false, policy).run;
  assert.equal(state.balances.coins, 85);
  assert.equal(engine.status(state, now, false, policy).extraRemaining, 0);
  const changed = {...policy, enabled: false, rewards: [90, 90, 90]};
  const result = engine.apply(state, "finish", {runId: run.id, playerIds: solve(run.mission)}, now, false, changed);
  assert.equal(result.run.result.reward, 25);
  assert.equal(state.balances.coins, 110);
  const receipt = state.claims["squad__" + mission.id];
  assert.equal(receipt.balanceBefore, 85);
  assert.equal(receipt.economyConfigId, policy.configId);
});

test("trusted mission events count once and cannot leak yesterday's activity into the new day", async () => {
  const h = harness();
  const ctx = h.context;
  await ctx.lbMissionRecordRanked(h.db, "alice", "grid", "match-1", "win", h.now);
  await ctx.lbMissionRecordRanked(h.db, "alice", "grid", "match-1", "win", h.now);
  await ctx.lbMissionRecordDailyChallenge(h.db, "alice", "2026-09-20");
  await ctx.lbMissionRecordDailyChallenge(h.db, "alice", "2026-09-20");
  assert.deepEqual(h.read("missionState/alice/daily/counters"), {
    rankedPlayed: 1, rankedWins: 1, dailyChallenge: 1,
  });
  const oldTime = h.now;
  h.setTime("2026-09-20T21:00:00Z");
  await h.call("getMyMissions");
  await ctx.lbMissionRecordRanked(h.db, "alice", "grid", "late-event", "win", oldTime);
  await ctx.lbMissionRecordDailyChallenge(h.db, "alice", "2026-09-20");
  assert.deepEqual(h.read("missionState/alice/daily/counters"), {
    rankedPlayed: 0, rankedWins: 0, dailyChallenge: 0,
  });
});

test("general mission claims enforce stage order and use remote reward values", async () => {
  const h = harness();
  h.seed("rankedState/profiles/alice", {wins: 25, losses: 0, draws: 0});
  h.setConfig((c) => c.sources.general_mission.rewards.general_ranked_play_5 = 37);
  await assert.rejects(h.call("claimMissionReward", {missionId: "general_ranked_play_25"}),
      {code: "failed-precondition"});
  assert.equal((await h.call("claimMissionReward", {missionId: "general_ranked_play_5"})).amount, 37);
  assert.equal((await h.call("claimMissionReward", {missionId: "general_ranked_play_25"})).amount, 25);
  assert.equal(coins(h), 62);
});
