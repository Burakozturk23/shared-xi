"use strict";
const {RewardError, dayKey} = require("./rewarded_ads");
// One play streak for the six daily games. A day counts once any of them is
// completed, assisted runs included; days turn at 00:00 Türkiye.
const GAMES = ["daily_lingo", "passa_daily", "daily_anagram", "daily_footballer", "daily_question", "daily_match"];
const DAY = 86400000;
const MILESTONE = {coins: 20, xp: 30};
const FULL_DAY = {coins: 5, xp: 10};
const shift = (day, n) => new Date(Date.parse(day + "T00:00:00Z") + n * DAY).toISOString().slice(0, 10);
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const normalize = (raw) => ({streak: 0, best: 0, lastDay: "", days: {}, outbox: {}, paid: {}, ...raw});
function bump(s, day, enabled) {
  if (s.streak % 7 !== 0 || !s.streak) return;
  const id = "daily_streak__" + day;
  if (s.paid[id] || s.outbox[id]) return;
  // The first week also leaves one basic support in the bag.
  if (enabled) s.outbox[id] = {...MILESTONE, day, streak: s.streak, boost: s.streak === 7 && !s.firstWeek};
  if (s.streak === 7) s.firstWeek = true;
}
function createService({db, grantCoins, grantXp, grantBoost, isLinked, legacy = async () => [],
  getPolicy = async () => ({}), recordBest = async () => {}, now = Date.now}) {
  const ref = (uid) => db.ref("dailyStreakState/" + uid);
  const read = async (uid) => normalize((await ref(uid).get()).val());
  async function change(uid, fn) {
    let error;
    const tx = await ref(uid).transaction((raw) => {
      error = null; const s = normalize(structuredClone(raw));
      try {
        fn(s);
      } catch (e) {
        error = e; return;
      }
      return s;
    });
    if (error) throw error;
    return normalize(tx.snapshot.val());
  }
  // Carry the longest live streak of the old per-game counters, once.
  async function seed(uid) {
    if ((await read(uid)).seeded) return;
    const today = dayKey(now()); const yesterday = shift(today, -1);
    // A legacy counter that already includes today is rolled back one day so
    // today's mark adds it again (and can reach a milestone).
    const live = (await legacy(uid)).filter((x) => x && x.streak > 0 && x.lastDay >= yesterday)
        .map((x) => x.lastDay === today ? {streak: x.streak - 1, lastDay: yesterday} : x).filter((x) => x.streak > 0)
        .sort((a, b) => b.streak - a.streak || b.lastDay.localeCompare(a.lastDay))[0];
    await change(uid, (s) => {
      if (s.seeded) return;
      s.seeded = true;
      if (live && !s.lastDay) {
        s.streak = live.streak; s.best = Math.max(s.best, live.streak); s.lastDay = live.lastDay;
        s.firstWeek = live.streak >= 7;
      }
    });
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, reward] of Object.entries(s.outbox)) {
      if (reward.coins) await grantCoins(uid, id, "daily_streak_reward", reward.day, reward.coins, "daily-streak-v1");
      if (reward.xp) await grantXp(uid, id, reward.xp);
      if (reward.boost) await grantBoost(uid, id);
      await change(uid, (next) => {
        next.paid[id] = true; delete next.outbox[id];
      });
    }
  }
  async function mark(uid, day, game) {
    if (!GAMES.includes(game) || day !== dayKey(now())) return;
    if ((await read(uid)).days[day]?.games?.[game]) return;
    await seed(uid);
    const enabled = (await getPolicy()).rewardsEnabled === true;
    const next = await change(uid, (s) => {
      const d = s.days[day] ||= {games: {}};
      if (d.games[game]) return;
      d.games[game] = true;
      if (day > s.lastDay) {
        if (s.lastDay === shift(day, -1)) s.streak++;
        else {
          // Remember the broken run for the same-day ad repair.
          if (s.streak > 0) s.broken = {streak: s.streak, lastDay: s.lastDay, day};
          s.streak = 1;
        }
        s.lastDay = day; s.best = Math.max(s.best, s.streak);
        bump(s, day, enabled);
      }
      if (!d.full && GAMES.every((g) => d.games[g])) {
        d.full = true;
        if (enabled) s.outbox["daily_six__" + day] = {...FULL_DAY, day};
      }
      // A week of day records is enough for the strip and the repair window.
      for (const key of Object.keys(s.days)) if (key < shift(day, -7)) delete s.days[key];
    });
    // Streak badges (7 / 30 days) follow the shared streak; the signal only grows.
    await recordBest(uid, next.best);
    await settle(uid);
  }
  function repairable(s, today) {
    if (s.lastRepair && s.lastRepair > shift(today, -7)) return 0;
    if (s.streak > 0 && s.lastDay === shift(today, -2)) return s.streak;
    if (s.broken?.day === today && s.lastDay === today && s.broken.lastDay === shift(today, -2)) {
      return s.broken.streak;
    }
    return 0;
  }
  async function status(uid) {
    await seed(uid); await settle(uid);
    const today = dayKey(now()); const s = await read(uid); const d = s.days[today] || {games: {}};
    const alive = [today, shift(today, -1)].includes(s.lastDay) ? s.streak : 0;
    return {ok: true, dayKey: today, streak: alive, best: s.best, playedToday: s.lastDay === today,
      today: {played: GAMES.filter((g) => d.games[g]), total: GAMES.length, full: d.full === true},
      repairStreak: repairable(s, today), nextMilestone: alive + (7 - alive % 7),
      rewardsEnabled: (await getPolicy()).rewardsEnabled === true,
      nextDayAt: Date.parse(today + "T00:00:00+03:00") + DAY};
  }
  async function prepareRepair(uid) {
    await seed(uid);
    const today = dayKey(now());
    if (!repairable(await read(uid), today)) fail("failed-precondition", "Seri koruması şu anda kullanılamıyor.");
    return {amount: 0, claimKey: "daily_streak_" + today, context: {day: today}};
  }
  async function settleRepair(uid, receipt) {
    const today = dayKey(now()); const enabled = (await getPolicy()).rewardsEnabled === true;
    const next = await change(uid, (s) => {
      // A late callback after midnight no longer matches the missed day.
      if (receipt.context?.day !== today || !repairable(s, today)) return;
      if (s.lastDay === shift(today, -2)) s.lastDay = shift(today, -1);
      else {
        s.streak = s.broken.streak + 1; s.best = Math.max(s.best, s.streak); bump(s, today, enabled);
      }
      delete s.broken; s.lastRepair = today;
    });
    await recordBest(uid, next.best);
    await settle(uid);
  }
  return {mark, status, settle, prepareRepair, settleRepair};
}
module.exports = {createService, GAMES, MILESTONE, FULL_DAY};
