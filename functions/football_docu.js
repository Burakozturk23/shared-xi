"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/football_docu_catalog.json");
const tasks = Object.fromEntries(catalog.tasks.map((t) => [t.id, t]));
const stateOf = (raw) => ({completed: {}, hints: {}, rewards: {}, ...raw});
function taskOf(id) {
  if (typeof id !== "string" || !Object.hasOwn(tasks, id)) throw new RewardError("invalid-argument", "Geçersiz görev.");
  return tasks[id];
}
function accepts(t, answers) {
  if (!Array.isArray(answers) || answers.length !== t.answerKeys.length ||
      new Set(answers).size !== answers.length || answers.some((a) => typeof a !== "string")) return false;
  return t.interaction === "multi" ? answers.every((a) => t.answerKeys.includes(a)) :
    answers.every((a, i) => a === t.answerKeys[i]);
}
const completedEpisodes = (s) => catalog.episodes.filter((d) => d.taskIds.every((id) => s.completed[id]));
function createService({db, documentRef, grantCoins, grantXp, chargeHint, isPro, now = Date.now}) {
  const ref = documentRef || ((uid) => db.ref("footballDocuState/" + uid));
  const get = async (uid) => stateOf((await ref(uid).get()).val());
  function check(input) {
    if (input.version !== catalog.version) {
      throw new RewardError("failed-precondition", "Football Docu-Series içeriğini güncelle.");
    }
    return taskOf(input.taskId);
  }
  function available(s, t) {
    return t.stage === 1 || !!s.completed[t.episodeId + "-01"];
  }
  async function settle(uid) {
    const s = await get(uid);
    for (const [id, r] of Object.entries(s.rewards)) {
      if (r.settled) continue;
      await grantCoins(uid, "football_docu_v2__" + id, "football_docu", id, r.coins, "football_docu-v2");
      await grantXp(uid, "football_docu_v2__" + id, r.xp);
      await ref(uid).transaction((raw) => {
        const latest = stateOf(raw);
        if (latest.rewards[id]) latest.rewards[id].settled = true;
        return latest;
      });
    }
  }
  function help(t) {
    if (t.interaction === "boolean") {
      return {text: "Karşı örnek aramak için iddiadaki her turnuvayı ve sezonu ayrı değerlendir."};
    }
    const label = (id) => t.options.find((o) => o.id === id).label;
    if (t.interaction === "order") return {text: "İlk kart: " + label(t.answerKeys[0])};
    if (t.interaction === "match") return {text: t.slots[0] + ": " + label(t.answerKeys[0])};
    const excluded = t.options.filter((o) => !t.answerKeys.includes(o.id)).slice(0, t.interaction === "multi" ? 1 : 2);
    return {text: "Elenen seçenekler: " + excluded.map((o) => o.label).join(", ")};
  }
  async function status(uid, eligible = true) {
    if (eligible) await settle(uid);
    const s = await get(uid); const files = completedEpisodes(s);
    return {version: catalog.version, rewardEligible: eligible, pro: eligible && await isPro(uid),
      results: Object.fromEntries(Object.keys(s.completed).filter((id) => Object.hasOwn(tasks, id))
          .map((id) => [id, {...tasks[id].result,
            sources: files.some((d) => d.id === tasks[id].episodeId) ? tasks[id].result.sources : []}])),
      rewards: s.rewards,
      files: Object.fromEntries(files.map((d) => [d.id, {story: d.story,
        earnedAt: Math.max(...d.taskIds.map((id) => s.completed[id]))}])),
      archivist: files.length === 24,
      hints: Object.fromEntries(Object.keys(s.hints).filter((id) => Object.hasOwn(tasks, id))
          .map((id) => [id, help(tasks[id])]))};
  }
  async function submit(uid, input, eligible = true) {
    const t = check(input);
    if (!available(await get(uid), t)) throw new RewardError("failed-precondition", "Önce ilk araştırmayı tamamla.");
    if (!accepts(t, input.answers)) return {correct: false};
    const tx = await ref(uid).transaction((raw) => {
      const s = stateOf(raw);
      if (!available(s, t)) return raw; // A cold null snapshot must be retried by RTDB.
      s.completed[t.id] ||= now();
      const earn = (id, coins, xp) => {
        s.rewards[id] ||= {coins, xp, earnedAt: now(), settled: false};
      };
      earn(t.id, catalog.economy.task.coins, catalog.economy.task.xp);
      const count = completedEpisodes(s).length;
      for (const m of catalog.economy.milestones) if (count >= m.count) earn("milestone_" + m.count, m.coins, m.xp);
      return s;
    });
    if (!stateOf(tx.snapshot.val()).completed[t.id]) {
      throw new RewardError("failed-precondition", "İlerleme değişti. Eşitleyip yeniden dene.");
    }
    return {correct: true, ...await status(uid, eligible)};
  }
  async function hint(uid, input, eligible = true) {
    const t = check(input);
    await documentRef?.guardHint?.(uid, t.id);
    if (!eligible) throw new RewardError("permission-denied", "Ek yardım için Google hesabına bağlan.");
    const s = await get(uid);
    if (t.interaction === "boolean") {
      throw new RewardError("failed-precondition", "Bu manşette ücretsiz ipucu yeterli; ek yardım satılmaz.");
    }
    if (!available(s, t)) throw new RewardError("failed-precondition", "Önce ilk araştırmayı tamamla.");
    if (!s.hints[t.id]) {
      if (s.completed[t.id]) throw new RewardError("failed-precondition", "Bu görevin cevabı zaten açık.");
      const receipt = (await db.ref("economyState/" + uid + "/purchases/football_docu_v2_hint__" + t.id).get()).val();
      const price = receipt ? receipt.priceCoins : await isPro(uid) ? 0 : catalog.economy.hintCoins;
      if (!Number.isInteger(input.maxPrice) || input.maxPrice < price) {
        throw new RewardError("failed-precondition", "Yardım fiyatını eşitle ve yeniden onayla.");
      }
      await chargeHint(uid, t.id, price);
      await ref(uid).transaction((raw) => {
        const latest = stateOf(raw); latest.hints[t.id] = true; return latest;
      });
    }
    return status(uid, eligible);
  }
  return {status, submit, hint};
}
module.exports = {catalog, tasks, accepts, completedEpisodes, createService};
