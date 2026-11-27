"use strict";
// Season points are derived only from canonical, server-issued wallet receipts.
// Buying coins, watching ads and claiming season rewards never generate points.
const {dayKey, RewardError} = require("./rewarded_ads");
const STEPS = 20;
const STEP_SP = 100;
const DAILY_CAP = 150;
// Unlocked rewards of last month stay claimable during the new month's first days.
const GRACE_DAYS = 3;
function seasonAt(now) {
  const day = dayKey(now);
  const id = day.slice(0, 7);
  const [y, m] = id.split("-").map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return {id, startsOn: id + "-01", endsOn: id + "-" + last, day,
    daysLeft: last - Number(day.slice(8)) + 1};
}
function previousId(id) {
  let [y, m] = id.split("-").map(Number); m--;
  if (!m) {
    m = 12; y--;
  }
  return `${y}-${String(m).padStart(2, "0")}`;
}
function seasonById(id) {
  const [y, m] = id.split("-").map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return {id, startsOn: id + "-01", endsOn: id + "-" + last, day: id + "-" + last, daysLeft: 0};
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
      const source = String(row.sourceId);
      if (/^general__general_(ranked_play|ranked_wins|daily_days)_\d+$/.test(source) ||
        /^general__(solo_knowledge|mode_collector)_\d+$/.test(source)) bucket.career += 50;
      else if (/^\d{4}-\d{2}-\d{2}__daily_[a-z0-9_]+$/.test(source)) {
        bucket.daily = Math.min(90, bucket.daily + 30);
      }
      // Weekly and new career receipts explicitly award zero SP.
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
// Pro şeridi son hali (runtimeConfig/seasonAvatars): 16 steps of 40 coins, step 5 and 15 give
// supports, step 10 an avatar from the 300 pool and step 20 one from the 450 pool.
const AVATAR_TIERS = Object.freeze({10: 300, 20: 450});
const AVATAR_STEPS = Object.freeze(Object.keys(AVATAR_TIERS).map(Number));
const SUPPORT_STEPS = Object.freeze({5: Object.freeze({boost_strong: 2}),
  15: Object.freeze({boost_connection: 1, boost_eliminate: 1, boost_basic: 1})});
const avatarStep = (step, lane, avatars) => avatars && lane === "pro" && AVATAR_STEPS.includes(step);
const supportStep = (step, lane, avatars) => avatars && lane === "pro" && !!SUPPORT_STEPS[step];
const claimId = (id, step, lane) => `season_v1__${id}__${step}__${lane}`;
function createService({db, isPro, grantCoins, now = Date.now, avatarsEnabled = async () => false,
  grantAvatar = null, grantSupports = null}) {
  // A reward step is claimed when its receipt exists (or its coins were paid before the switch:
  // those keep their coins, nothing is paid twice).
  const tiersOf = (claims, uses, season, level, avatars) => Array.from({length: STEPS}, (_, i) => {
    const step = i + 1; const proId = claimId(season.id, step, "pro");
    const proAvatar = avatarStep(step, "pro", avatars) && !claims[proId];
    const proSupport = supportStep(step, "pro", avatars) && !claims[proId];
    return {step, requiredSp: step * STEP_SP, unlocked: level >= step,
      freeCoins: reward(step, "free"), proCoins: proAvatar || proSupport ? 0 : reward(step, "pro"), proAvatar,
      proAvatarTier: proAvatar ? AVATAR_TIERS[step] : 0, proSupports: proSupport ? SUPPORT_STEPS[step] : null,
      proReward: uses[proId] || null,
      freeClaimed: !!claims[claimId(season.id, step, "free")],
      proClaimed: !!claims[proId] || !!uses[proId]};
  });
  const open = (tiers, pro) => tiers.reduce((n, t) => n + (t.unlocked && !t.freeClaimed ? 1 : 0) +
    (pro && t.unlocked && !t.proClaimed ? 1 : 0), 0);
  async function status(uid) {
    const time = now();
    const season = seasonAt(time);
    const [snapshot, pro, avatars] = await Promise.all([db.ref("economyState/" + uid).get(), isPro(uid),
      grantAvatar && grantSupports ? avatarsEnabled(uid) : false]);
    const claims = snapshot.val()?.claims || {}; const uses = snapshot.val()?.storeUses || {};
    const score = points(claims, season, time);
    const level = Math.floor(score.sp / STEP_SP);
    const tiers = tiersOf(claims, uses, season, level, avatars);
    // Last month's unlocked, unclaimed rewards during the grace days.
    const day = Number(season.day.slice(8)); let previous = null;
    if (day <= GRACE_DAYS) {
      const last = seasonById(previousId(season.id));
      const lastLevel = Math.floor(points(claims, last, time).sp / STEP_SP);
      const lastTiers = tiersOf(claims, uses, last, lastLevel, avatars);
      if (open(lastTiers, pro)) {
        previous = {id: last.id, level: lastLevel, claimDaysLeft: GRACE_DAYS - day + 1,
          unclaimed: open(lastTiers, pro), tiers: lastTiers};
      }
    }
    return {...season, ...score, title: "Sezon Rotası", level, maxLevel: STEPS, stepSp: STEP_SP,
      dailyCap: DAILY_CAP, pro, tiers, freeTotal: 560, proTotal: avatars ? 640 : 1040,
      unclaimed: open(tiers, pro), graceDays: GRACE_DAYS, previous, avatarSteps: avatars ? [...AVATAR_STEPS] : [],
      // Which pool each avatar step draws from and how many of it the player can still get.
      avatarPools: avatars ? Object.entries(AVATAR_TIERS).map(([step, tier]) => ({step: Number(step), tier,
        count: require("./pro_crate").pool({inventory: snapshot.val()?.inventory || {}}, tier)
            .filter((a) => a.price === tier).length})) : [],
      supportSteps: avatars ? Object.keys(SUPPORT_STEPS).map(Number) : []};
  }
  async function claim(uid, input) {
    const profile = await status(uid);
    const {seasonId, step, lane} = input;
    const past = profile.previous && seasonId === profile.previous.id;
    if (seasonId !== profile.id && !past) {
      throw new RewardError("failed-precondition", "Sezon yenilendi. Ekranı yenile.");
    }
    if (!Number.isInteger(step) || step < 1 || step > STEPS || !["free", "pro"].includes(lane)) {
      throw new RewardError("invalid-argument", "Geçersiz sezon ödülü.");
    }
    const tier = (past ? profile.previous.tiers : profile.tiers)[step - 1];
    const claimed = tier[lane + "Claimed"];
    if (!claimed && (!tier.unlocked || (lane === "pro" && !profile.pro))) {
      throw new RewardError("failed-precondition", "Bu ödül henüz açık değil.");
    }
    const id = claimId(seasonId, step, lane);
    if (tier.proAvatar && lane === "pro") {
      const avatar = await grantAvatar(uid, id, AVATAR_TIERS[step]);
      return {granted: !claimed, amount: 0, avatar, profile: await status(uid)};
    }
    if (tier.proSupports && lane === "pro") {
      const supports = await grantSupports(uid, id, SUPPORT_STEPS[step]);
      return {granted: !claimed, amount: 0, supports, profile: await status(uid)};
    }
    const result = await grantCoins(uid, id, "season_pass", `${seasonId}__${step}__${lane}`,
        reward(step, lane), "season-v1");
    return {granted: result.granted, amount: reward(step, lane), profile: await status(uid)};
  }
  return {status, claim};
}
module.exports = {createService, seasonAt, points, reward, GRACE_DAYS, previousId, AVATAR_STEPS, AVATAR_TIERS,
  SUPPORT_STEPS};
