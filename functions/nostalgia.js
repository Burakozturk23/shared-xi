"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/nostalgia_catalog.json");
const tasks = Object.fromEntries(catalog.tasks.map((t) => [t.id, t]));
const chapters = Object.fromEntries(catalog.chapters.map((c) => [c.id, c]));
const stateOf = (raw) => ({completed: {}, rewards: {}, hints: {}, ...raw});
function taskOf(input) {
  if (input.version !== catalog.version) throw new RewardError("failed-precondition", "Nostalji içeriğini güncelle.");
  if (typeof input.taskId !== "string" || !Object.hasOwn(tasks, input.taskId)) {
    throw new RewardError("invalid-argument", "Geçersiz nostalji görevi.");
  }
  return tasks[input.taskId];
}
function accepts(task, answers) {
  return Array.isArray(answers) && answers.length === task.answerKeys.length &&
    answers.every((id, i) => typeof id === "string" && id === task.answerKeys[i]);
}
function requirePrevious(s, task) {
  const previous = chapters[task.chapterId].taskIds[0];
  if (previous !== task.id && !s.completed[previous]) {
    throw new RewardError("failed-precondition", "Önce bölümün ilk görevini doğrula.");
  }
}
function createService({db, grantCoins, grantXp, chargeHint, isPro, now = Date.now}) {
  const ref = (uid) => db.ref("nostalgiaState/" + uid);
  const get = async (uid) => stateOf((await ref(uid).get()).val());
  async function settle(uid) {
    const s = await get(uid);
    for (const [id, reward] of Object.entries(s.rewards)) {
      if (reward.settled) continue;
      await grantCoins(uid, "nostalgia_v1__" + id, "nostalgia", id, reward.coins, "nostalgia-v1");
      await grantXp(uid, "nostalgia_v1__" + id, reward.xp);
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
    const done = (c) => c.taskIds.every((id) => s.completed[id]);
    return {version: catalog.version, rewards: s.rewards, rewardEligible: eligible,
      results: Object.fromEntries(Object.keys(s.completed).filter((id) => Object.hasOwn(tasks, id))
          .map((id) => [id, tasks[id].result])),
      albums: Object.fromEntries(catalog.chapters.filter(done).map((c) => [c.id, c.album])),
      hints: Object.fromEntries(Object.keys(s.hints).filter((id) => Object.hasOwn(tasks, id))
          .map((id) => [id, tasks[id].strongHint])),
      hintPrice: await isPro(uid) ? 0 : catalog.economy.hintCoins,
      badge: catalog.chapters.every(done) ? "nostalgia_archivist_v1" : null};
  }
  async function submit(uid, input, eligible = true) {
    const task = taskOf(input);
    requirePrevious(await get(uid), task);
    if (!accepts(task, input.answers)) return {correct: false};
    await ref(uid).transaction((raw) => {
      const s = stateOf(raw);
      s.completed[task.id] ||= now();
      const earn = (id, reward) => {
        s.rewards[id] ||= {...reward, earnedAt: now(), settled: false};
      };
      earn(task.id, catalog.economy.task);
      const complete = catalog.chapters.filter((c) => c.taskIds.every((id) => s.completed[id]));
      for (const chapter of complete) earn(chapter.id, catalog.economy.chapter);
      if (complete.length === catalog.chapters.length) earn("album", catalog.economy.album);
      return s;
    });
    return {correct: true, ...await status(uid, eligible)};
  }
  async function hint(uid, input, eligible = true) {
    const task = taskOf(input); const s = await get(uid);
    requirePrevious(s, task);
    if (s.hints[task.id]) return status(uid, eligible);
    if (s.completed[task.id]) throw new RewardError("failed-precondition", "Bu görevin cevabı zaten açık.");
    if (!eligible) throw new RewardError("permission-denied", "Güçlü yardım için bu misafir hesabını Google’a bağla.");
    const price = await isPro(uid) ? 0 : catalog.economy.hintCoins;
    if (!Number.isInteger(input.maxPrice) || input.maxPrice < price) {
      throw new RewardError("failed-precondition", "Yardım fiyatını yenile ve yeniden onayla.");
    }
    // Zero-price claims also create a receipt, so a later Pro expiry cannot charge a retry.
    await chargeHint(uid, task.id, price);
    await ref(uid).transaction((raw) => {
      const latest = stateOf(raw); latest.hints[task.id] = true; return latest;
    });
    return status(uid, eligible);
  }
  return {status, submit, hint};
}
module.exports = {catalog, tasks, accepts, createService};
