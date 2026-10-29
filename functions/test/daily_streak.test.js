"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {createService, GAMES} = require("../daily_streak");
const {dayKey} = require("../rewarded_ads");
function setup({enabled = true, legacy = [], linked = true} = {}) {
  const h = harness({}); const paid = []; const boosts = [];
  const service = createService({db: h.db, now: () => h.now, isLinked: async () => linked,
    getPolicy: async () => ({rewardsEnabled: enabled}), legacy: async () => legacy,
    grantCoins: async (uid, id, type, day, coins) => paid.push({id, coins}),
    grantXp: async (uid, id, xp) => paid.push({id, xp}), grantBoost: async (uid, id) => boosts.push(id)});
  const next = () => h.setTime(h.now + 86400000);
  const play = (game = "daily_question") => service.mark("alice", dayKey(h.now), game);
  return {h, service, paid, boosts, next, play, status: () => service.status("alice")};
}

test("any one of the six daily games counts the day, once", async () => {
  const s = setup();
  await s.play("daily_lingo"); await s.play("daily_lingo"); await s.play("daily_footballer");
  let st = await s.status();
  assert.equal(st.streak, 1); assert.equal(st.playedToday, true);
  assert.deepEqual(st.today.played, ["daily_lingo", "daily_footballer"]);
  s.next(); st = await s.status();
  assert.equal(st.streak, 1); assert.equal(st.playedToday, false);
  await s.play("daily_match"); assert.equal((await s.status()).streak, 2);
  s.next(); s.next(); assert.equal((await s.status()).streak, 0);
  await s.play(); assert.equal((await s.status()).streak, 1);
});

test("marks for another day or an unknown game are ignored", async () => {
  const s = setup();
  await s.service.mark("alice", "2026-01-01", "daily_question");
  await s.play("passa_weekly");
  assert.equal((await s.status()).streak, 0);
});

test("every seventh day pays 20 coin / 30 XP; only the first week adds a support", async () => {
  const s = setup();
  for (let i = 0; i < 14; i++) {
    await s.play(); s.next();
  }
  assert.deepEqual(s.paid.filter((x) => x.coins).map((x) => x.coins), [20, 20]);
  assert.deepEqual(s.paid.filter((x) => x.xp).map((x) => x.xp), [30, 30]);
  assert.equal(s.boosts.length, 1);
});

test("all six games in one day add the Günlük 6 bonus once", async () => {
  const s = setup();
  for (const g of GAMES) await s.play(g);
  await s.play(GAMES[0]);
  const st = await s.status();
  assert.equal(st.today.full, true); assert.equal(st.today.played.length, 6);
  assert.deepEqual(s.paid, [{id: "daily_six__" + dayKey(s.h.now), coins: 5},
    {id: "daily_six__" + dayKey(s.h.now), xp: 10}]);
});

test("rewards stay off until the flag opens; the streak still counts", async () => {
  const s = setup({enabled: false});
  for (let i = 0; i < 7; i++) {
    for (const g of GAMES) await s.play(g);
    s.next();
  }
  assert.equal((await s.status()).streak, 7); assert.deepEqual(s.paid, []); assert.deepEqual(s.boosts, []);
});

test("guest rewards wait in the outbox until the account is linked", async () => {
  let linked = false;
  const s = setup(); const h = s.h;
  const service = createService({db: h.db, now: () => h.now, isLinked: async () => linked,
    getPolicy: async () => ({rewardsEnabled: true}),
    grantCoins: async (uid, id, type, day, coins) => s.paid.push({id, coins}),
    grantXp: async () => {}, grantBoost: async () => {}});
  for (const g of GAMES) await service.mark("alice", dayKey(h.now), g);
  assert.deepEqual(s.paid, []);
  linked = true; await service.status("alice"); await service.status("alice");
  assert.equal(s.paid.length, 1);
});

test("the longest live legacy streak carries over once", async () => {
  const today = dayKey(Date.parse("2026-09-20T10:00:00Z"));
  const yesterday = "2026-09-19";
  const s = setup({legacy: [{streak: 4, lastDay: yesterday}, {streak: 9, lastDay: "2026-09-10"},
    {streak: 2, lastDay: today}]});
  assert.equal((await s.status()).streak, 4);
  await s.play(); assert.equal((await s.status()).streak, 5);
  assert.equal(s.h.read("dailyStreakState/alice/seeded"), true);
});

test("one missed day can be repaired once a week, before or after playing", async () => {
  const s = setup();
  for (let i = 0; i < 3; i++) {
    await s.play(); s.next();
  }
  s.next(); // missed one day
  assert.equal((await s.status()).repairStreak, 3);
  const ad = await s.service.prepareRepair("alice");
  await s.service.settleRepair("alice", {placement: "daily_streak", context: ad.context});
  let st = await s.status(); assert.equal(st.streak, 3); assert.equal(st.repairStreak, 0);
  await s.play(); assert.equal((await s.status()).streak, 4);
  // Played first, then repaired on the same day: the broken run comes back.
  for (let i = 0; i < 6; i++) {
    s.next(); await s.play();
  }
  s.next(); s.next(); await s.play();
  st = await s.status(); assert.equal(st.streak, 1); assert.equal(st.repairStreak, 10);
  const again = await s.service.prepareRepair("alice");
  await s.service.settleRepair("alice", {placement: "daily_streak", context: again.context});
  assert.equal((await s.status()).streak, 11);
});

test("repair is refused for two missed days, inside the weekly cooldown and after midnight", async () => {
  const s = setup();
  await s.play(); s.next(); s.next(); s.next();
  await assert.rejects(s.service.prepareRepair("alice"));
  const t = setup();
  await t.play(); t.next(); t.next();
  const ad = await t.service.prepareRepair("alice");
  t.next();
  await t.service.settleRepair("alice", {placement: "daily_streak", context: ad.context});
  assert.equal((await t.status()).streak, 0);
  const u = setup();
  await u.play(); u.next(); u.next();
  const first = await u.service.prepareRepair("alice");
  await u.service.settleRepair("alice", {placement: "daily_streak", context: first.context});
  await u.play(); u.next(); u.next();
  await assert.rejects(u.service.prepareRepair("alice"));
});

test("finishing Günün Futbolcusu through index marks the shared streak and pays the support once", async () => {
  const h = harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
    readyModes: {daily_footballer: true}}, dailyStreak: {rewardsEnabled: true}},
  economyState: {alice: {balances: {coins: 1000}}},
  dailyMatchState: {alice: {streak: 6, lastWin: "2026-09-19"}}}, {omitEmptyObjects: true});
  let r = (await h.call("getDailyFootballer", {})).session;
  const target = h.read("economyState/alice/dailyFootballer/days/" + r.dayKey + "/target/id");
  r = (await h.call("actDailyFootballer", {requestId: "f".repeat(32), day: r.dayKey, sessionId: r.id,
    revision: r.revision, action: "guess", playerId: target})).session;
  const st = await h.call("getDailyStreak", {});
  assert.equal(st.streak, 7); assert.deepEqual(st.today.played, ["daily_footballer"]);
  assert.equal(h.read("economyState/alice/balances/coins"), 1020);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 1);
  await h.call("getDailyFootballer", {}); await h.call("getDailyStreak", {});
  assert.equal(h.read("economyState/alice/balances/coins"), 1020);
  assert.equal(h.read("achievementState/alice/signals/best_daily_streak"), 7);
});

test("with the shared streak on, Günün Sorusu stops paying its own seventh-day bonus", async () => {
  const h = harness({runtimeConfig: {dailyQuestion: {enabled: true}, dailyStreak: {rewardsEnabled: true}},
    economyState: {alice: {balances: {coins: 1000}}},
    dailyQuestionState: {alice: {streak: 6, lastDay: "2026-09-19"}}}, {omitEmptyObjects: true});
  const v = await h.call("getDailyQuestion");
  const after = await h.call("submitDailyQuestion", {day: v.question.day, questionId: v.question.id, option: 0});
  assert.equal(after.result.bonus, false); assert.equal(after.streak, 7); assert.equal(after.playStreak, 7);
  const st = await h.call("getDailyStreak", {});
  assert.equal(st.streak, 7); assert.deepEqual(st.today.played, ["daily_question"]);
  // Question 8 or 2, plus the shared 20 coin milestone; never the old +20 on top.
  assert.equal(h.read("economyState/alice/balances/coins"), 1000 + after.result.coins + 20);
  assert.ok([2, 8].includes(after.result.coins));
});
