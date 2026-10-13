"use strict";
const {RewardError} = require("./rewarded_ads");
const baseCatalog = require("./config/ucl_catalog.json");
const expansion = require("./config/five_mode_expansion.json");
const catalog = {...baseCatalog, matches: [...baseCatalog.matches, ...expansion.ucl]};
const matches = Object.fromEntries(catalog.matches.map((m) => [m.id, m]));
const stateOf = (raw) => ({completed: {}, rewards: {}, ...raw});
function matchOf(id) {
  if (typeof id !== "string" || !Object.hasOwn(matches, id)) {
    throw new RewardError("invalid-argument", "Geçersiz Avrupa gecesi.");
  }
  return matches[id];
}
function accepts(match, answers) {
  return Array.isArray(answers) && answers.length === match.answerKeys.length &&
    answers.every((id, i) => typeof id === "string" && id === match.answerKeys[i]);
}
function createService({db, grantCoins, grantXp, now = Date.now}) {
  const ref = (uid) => db.ref("uclMomentsState/" + uid);
  const get = async (uid) => stateOf((await ref(uid).get()).val());
  function accrue(s) {
    const earn = (id, coins, xp) => {
      s.rewards[id] ||= {coins, xp, earnedAt: now(), settled: false};
    };
    for (const m of catalog.matches) {
      if (s.completed[m.id]) earn(m.id, catalog.economy.match.coins, catalog.economy.match.xp);
    }
    const count = catalog.matches.filter((m) => s.completed[m.id]).length;
    for (const milestone of catalog.economy.milestones) {
      if (count >= milestone.count) earn("milestone_" + milestone.count, milestone.coins, milestone.xp);
    }
    return s;
  }
  async function reconcile(uid) {
    // Only server-confirmed progress is eligible. Preserve every existing receipt.
    await ref(uid).transaction((raw) => accrue(stateOf(raw)));
  }
  async function settle(uid) {
    const s = await get(uid);
    for (const [id, reward] of Object.entries(s.rewards)) {
      if (reward.settled) continue;
      await grantCoins(uid, "ucl_v1__" + id, "ucl_moments", id, reward.coins, "ucl-v1");
      await grantXp(uid, "ucl_v1__" + id, reward.xp);
      await ref(uid).transaction((raw) => {
        const latest = stateOf(raw);
        if (latest.rewards[id]) latest.rewards[id].settled = true;
        return latest;
      });
    }
  }
  async function status(uid, eligible = true) {
    await reconcile(uid);
    if (eligible) await settle(uid);
    const s = await get(uid);
    const results = Object.fromEntries(Object.keys(s.completed).filter((id) => Object.hasOwn(matches, id))
        .map((id) => [id, matches[id].result]));
    return {version: catalog.version, completed: s.completed, rewards: s.rewards, results,
      rewardEligible: eligible};
  }
  async function submit(uid, input, eligible = true) {
    if (input.version !== catalog.version) {
      throw new RewardError("failed-precondition", "UCL Moments içeriğini güncelle.");
    }
    const match = matchOf(input.matchId);
    if (!accepts(match, input.answers)) return {correct: false};
    await ref(uid).transaction((raw) => {
      const s = stateOf(raw);
      s.completed[match.id] ||= now();
      accrue(s);
      return s;
    });
    return {correct: true, ...await status(uid, eligible)};
  }
  return {status, submit};
}
module.exports = {catalog, matches, accepts, createService};
