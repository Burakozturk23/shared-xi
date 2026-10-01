"use strict";
// Season points are derived only from canonical, server-issued wallet receipts.
// Buying coins, watching ads and claiming season rewards never generate points.
const {dayKey, RewardError} = require("./rewarded_ads");
const STEPS = 20;
const STEP_SP = 100;
const DAILY_CAP = 150;
function seasonAt(now) {
  const day = dayKey(now);
  const id = day.slice(0, 7);
  const [y, m] = id.split("-").map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return {id, startsOn: id + "-01", endsOn: id + "-" + last, day,
    daysLeft: last - Number(day.slice(8)) + 1};
}
function points(claims, season, now) {
  const days = {};
  for (const row of Object.values(claims || {})) {
    if (!Number.isFinite(row?.claimedAt) || row.claimedAt > now || !(row.amount > 0)) continue;
    const day = dayKey(row.claimedAt);
    if (!day.startsWith(season.id)) continue;
    const bucket = days[day] ||= {checkIn: 0, daily: 0, career: 0, match: 0};
    if (row.sourceType === "daily_reward") bucket.checkIn = 10;
    if (row.sourceType === "mission_reward") {
      if (String(row.sourceId).startsWith("general__")) bucket.career += 50;
      else bucket.daily = Math.min(90, bucket.daily + 30);
    }
    // One winning fixture per day. Double-bonus receipts have their own key.
    if (row.sourceType === "daily_match" && !String(row.sourceId).includes("double")) bucket.match = 50;
  }
  const totals = Object.fromEntries(Object.entries(days).map(([day, b]) =>
    [day, Math.min(DAILY_CAP, b.checkIn + b.daily + b.career + b.match)]));
  return {sp: Math.min(STEPS * STEP_SP, Object.values(totals).reduce((a, b) => a + b, 0)),
    todaySp: totals[season.day] || 0};
}
const reward = (step, lane) => step % 5 === 0 ? (lane === "pro" ? 100 : 60) : (lane === "pro" ? 40 : 20);
const claimId = (id, step, lane) => `season_v1__${id}__${step}__${lane}`;
function createService({db, isPro, grantCoins, now = Date.now}) {
  async function status(uid) {
    const time = now();
    const season = seasonAt(time);
    const [snapshot, pro] = await Promise.all([db.ref("economyState/" + uid).get(), isPro(uid)]);
    const claims = snapshot.val()?.claims || {};
    const score = points(claims, season, time);
    const level = Math.floor(score.sp / STEP_SP);
    const tiers = Array.from({length: STEPS}, (_, i) => {
      const step = i + 1;
      return {step, requiredSp: step * STEP_SP, unlocked: level >= step,
        freeCoins: reward(step, "free"), proCoins: reward(step, "pro"),
        freeClaimed: !!claims[claimId(season.id, step, "free")],
        proClaimed: !!claims[claimId(season.id, step, "pro")]};
    });
    return {...season, ...score, title: "Sezon Rotası", level, maxLevel: STEPS, stepSp: STEP_SP,
      dailyCap: DAILY_CAP, pro, tiers, freeTotal: 560, proTotal: 1040};
  }
  async function claim(uid, input) {
    const profile = await status(uid);
    const {seasonId, step, lane} = input;
    if (seasonId !== profile.id) throw new RewardError("failed-precondition", "Sezon yenilendi. Ekranı yenile.");
    if (!Number.isInteger(step) || step < 1 || step > STEPS || !["free", "pro"].includes(lane)) {
      throw new RewardError("invalid-argument", "Geçersiz sezon ödülü.");
    }
    const tier = profile.tiers[step - 1];
    const claimed = tier[lane + "Claimed"];
    if (!claimed && (!tier.unlocked || (lane === "pro" && !profile.pro))) {
      throw new RewardError("failed-precondition", "Bu ödül henüz açık değil.");
    }
    const id = claimId(seasonId, step, lane);
    const result = await grantCoins(uid, id, "season_pass", `${seasonId}__${step}__${lane}`,
        reward(step, lane), "season-v1");
    return {granted: result.granted, amount: reward(step, lane), profile: await status(uid)};
  }
  return {status, claim};
}
module.exports = {createService, seasonAt, points, reward};
