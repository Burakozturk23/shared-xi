"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/international_catalog.json");
const matches = Object.fromEntries(catalog.matches.map((m) => [m.id, m]));
const stateOf = (raw) => ({completed: {}, hints: {}, rewards: {}, ...raw});
function matchOf(id) {
  if (typeof id !== "string" || !Object.hasOwn(matches, id)) {
    throw new RewardError("invalid-argument", "Geçersiz millî karşılaşma.");
  }
  return matches[id];
}
function accepts(match, answers) {
  return Array.isArray(answers) && answers.length === match.answerKeys.length &&
    answers.every((id, i) => typeof id === "string" && id === match.answerKeys[i]);
}
function createService({db, grantCoins, grantXp, chargeHint, isPro, now = Date.now}) {
  const ref = (uid) => db.ref("internationalGloryState/" + uid);
  const get = async (uid) => stateOf((await ref(uid).get()).val());
  async function settle(uid) {
    const s = await get(uid);
    for (const [id, reward] of Object.entries(s.rewards)) {
      if (reward.settled) continue;
      await grantCoins(uid, "international_v2__" + id, "international_glory", id, reward.coins, "international-v2");
      await grantXp(uid, "international_v2__" + id, reward.xp);
      await ref(uid).transaction((raw) => {
        const latest = stateOf(raw);
        if (latest.rewards[id]) latest.rewards[id].settled = true;
        return latest;
      });
    }
  }
  async function status(uid, eligible = true) {
    if (eligible) await settle(uid);
    const s = await get(uid);
    const results = Object.fromEntries(Object.keys(s.completed).filter((id) => Object.hasOwn(matches, id))
        .map((id) => [id, matches[id].result]));
    return {version: catalog.version, completed: s.completed, rewards: s.rewards, results,
      rewardEligible: eligible, pro: eligible && await isPro(uid), hints: Object.fromEntries(
          Object.keys(s.hints).filter((id) => Object.hasOwn(matches, id)).map((id) => [id, help(matches[id])]))};
  }
  async function submit(uid, input, eligible = true) {
    if (input.version !== catalog.version) {
      throw new RewardError("failed-precondition", "International Glory içeriğini güncelle.");
    }
    const match = matchOf(input.matchId);
    if (!accepts(match, input.answers)) return {correct: false};
    await ref(uid).transaction((raw) => {
      const s = stateOf(raw);
      s.completed[match.id] ||= now();
      const earn = (id, coins, xp) => {
        s.rewards[id] ||= {coins, xp, earnedAt: now(), settled: false};
      };
      earn(match.id, catalog.economy.match.coins, catalog.economy.match.xp);
      const count = Object.keys(s.completed).filter((id) => Object.hasOwn(matches, id)).length;
      for (const milestone of catalog.economy.milestones) {
        if (count >= milestone.count) earn("milestone_" + milestone.count, milestone.coins, milestone.xp);
      }
      return s;
    });
    return {correct: true, ...await status(uid, eligible)};
  }
  function help(m) {
    if (["timeline", "route"].includes(m.type)) {
      return {text: "İlk sıradaki kart: " + m.options.find((o) => o.id === m.answerKeys[0]).label};
    }
    const excluded = m.options.filter((o) => !m.answerKeys.includes(o.id)).slice(0, 2);
    return {text: "Elenen seçenekler: " + excluded.map((o) => o.label).join(", ")};
  }
  async function hint(uid, input, eligible = true) {
    if (input.version !== catalog.version) throw new RewardError("failed-precondition", "İçeriği güncelle.");
    const m = matchOf(input.matchId);
    if (!eligible) throw new RewardError("permission-denied", "Ek yardım için Google hesabına bağlan.");
    const s = await get(uid);
    if (!s.hints[m.id]) {
      if (!await isPro(uid)) await chargeHint(uid, m.id, catalog.economy.hintCoins);
      await ref(uid).transaction((raw) => {
        const latest = stateOf(raw); latest.hints[m.id] = true; return latest;
      });
    }
    return status(uid, eligible);
  }
  return {status, submit, hint};
}
module.exports = {catalog, matches, accepts, createService};
