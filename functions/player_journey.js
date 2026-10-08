"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/journey_catalog.json");
const chapters = catalog.chapters;
const journeys = Object.fromEntries(chapters.flatMap((c) => c.journeys.map((j) => [j.id, j])));
const fail = (code, text) => {
  throw new RewardError(code, text);
};
const stateOf = (raw) => ({journeys: {}, hints: {}, rewards: {}, favorites: [], ...raw});
function taskOf(input) {
  const journey = typeof input.journeyId === "string" && Object.hasOwn(journeys, input.journeyId) ?
    journeys[input.journeyId] : null;
  const index = journey?.tasks.findIndex((t) => t.id === input.taskId) ?? -1;
  if (!journey || index < 0) fail("invalid-argument", "Geçersiz kariyer görevi.");
  return {journey, task: journey.tasks[index], index};
}
function accepts(task, keys) {
  if (!Array.isArray(keys) || keys.length !== task.requiredCount || new Set(keys).size !== keys.length) return false;
  const options = Object.fromEntries(task.options.map((o) => [o.key, o.label]));
  if (keys.some((k) => typeof k !== "string" || !Object.hasOwn(options, k))) return false;
  return task.type === "timeline" ? keys.every((k, i) => options[k] === options[task.answerKeys[i]]) :
    keys.every((k) => task.answerKeys.includes(k));
}
function createService({db, grantCoins, grantXp, chargeHint, projectBadges, now = Date.now}) {
  const ref = (uid) => db.ref("journeyRewardState/" + uid);
  const get = async (uid) => stateOf((await ref(uid).get()).val());
  async function change(uid, fn) {
    let error;
    const tx = await ref(uid).transaction((raw) => {
      error = null;
      const state = stateOf(raw);
      try {
        fn(state); return state;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    return stateOf(tx.snapshot.val());
  }
  function earned(state, id, coins, xp) {
    state.rewards[id] ||= {coins, xp, earnedAt: now(), settled: false};
  }
  function counts(state) {
    return chapters.map((c) => c.journeys.filter((j) => state.journeys[j.id]?.solved === 4).length);
  }
  async function settle(uid) {
    const state = await get(uid);
    for (const [id, reward] of Object.entries(state.rewards)) {
      if (reward.settled) continue;
      await grantCoins(uid, "journey_v1__" + id, "player_journey", id, reward.coins, "journey-v1");
      if (reward.xp) await grantXp(uid, id, reward.xp);
      await change(uid, (s) => {
        s.rewards[id].settled = true;
      });
    }
    await projectBadges(uid, counts(state));
  }
  async function status(uid) {
    await settle(uid);
    const s = await get(uid);
    const completed = Object.keys(journeys).filter((id) => s.journeys[id]?.solved === 4);
    return {ok: true, version: catalog.version, completed, progress: s.journeys, hints: s.hints,
      rewards: s.rewards, favorites: s.favorites, chapterCounts: counts(s),
      finalUnlocked: completed.length === 32, hintPrice: 10,
      playerReward: {coins: 20, xp: 40}, chapterReward: {coins: 80, xp: 120}, finalReward: {coins: 150, xp: 300}};
  }
  async function submit(uid, input) {
    if (input.version !== catalog.version) fail("failed-precondition", "Uygulamanı güncelle.");
    const {journey, task, index} = taskOf(input);
    if (!accepts(task, input.answers)) fail("invalid-argument", "Cevap doğrulanamadı.");
    await change(uid, (s) => {
      const progress = s.journeys[journey.id] ||= {solved: 0};
      if (index > progress.solved) fail("failed-precondition", "Önceki aşamaların eşitlenmesi bekleniyor.");
      if (index === progress.solved) progress.solved++;
      if (progress.solved === 4) {
        progress.completedAt ||= now();
        earned(s, "player__" + journey.id, 20, 40);
      }
      const totals = counts(s);
      for (let i = 0; i < 4; i++) if (totals[i] === 8) earned(s, "chapter__" + (i + 1), 80, 120);
      if (totals.every((n) => n === 8)) earned(s, "final", 150, 300);
    });
    return status(uid);
  }
  async function favorites(uid, input) {
    const ids = input.ids;
    if (!Array.isArray(ids) || ids.length > 3 || new Set(ids).size !== ids.length ||
      ids.some((id) => typeof id !== "string" || !Object.hasOwn(journeys, id))) {
      fail("invalid-argument", "En fazla üç farklı kariyer seç.");
    }
    await change(uid, (s) => {
      if (ids.some((id) => s.journeys[id]?.solved !== 4)) fail("permission-denied", "Önce bu kariyeri tamamla.");
      s.favorites = ids;
    });
    return status(uid);
  }
  async function hint(uid, input) {
    const {task, index, journey} = taskOf(input);
    const s = await get(uid);
    if (index > (s.journeys[journey.id]?.solved || 0)) fail("failed-precondition", "Önceki aşamayı eşitle.");
    // Debit receipt persists in the canonical wallet. A crash before entitlement
    // creation is repaired by retrying exactly this task, never charging again.
    await chargeHint(uid, task.id, 10);
    await change(uid, (latest) => {
      (latest.hints[task.id] ||= {}).coin = true;
    });
    return status(uid);
  }
  async function prepareReward(uid, placement, input = {}) {
    const s = await get(uid);
    if (placement === "story_double") {
      const chapter = input.chapter;
      if (!Number.isInteger(chapter) || chapter < 1 || chapter > 4) fail("invalid-argument", "Geçersiz bölüm.");
      if (!s.rewards["chapter__" + chapter]?.settled || s.rewards["double__" + chapter]) {
        fail("failed-precondition", "Bölüm bonusu hazır değil veya zaten alındı.");
      }
      return {amount: 80, claimKey: "story_double__" + chapter, context: {chapter}};
    }
    if (placement !== "story_hint") fail("invalid-argument", "Geçersiz yardım.");
    const {task, index, journey} = taskOf(input);
    if (index !== (s.journeys[journey.id]?.solved || 0) || s.hints[task.id]?.ad || s.hints[task.id]?.coin) {
      fail("failed-precondition", "Bu aşama için yardım hazır değil veya zaten açıldı.");
    }
    return {amount: 0, claimKey: "story_hint__" + task.id, context: {journeyId: journey.id, taskId: task.id}};
  }
  async function settleReward(uid, receipt) {
    await change(uid, (s) => {
      if (receipt.placement === "story_double") {
        const chapter = receipt.context?.chapter;
        if (!s.rewards["chapter__" + chapter]) fail("failed-precondition", "Bölüm tamamlanmamış.");
        earned(s, "double__" + chapter, 80, 0);
      } else if (receipt.placement === "story_hint") {
        const {task} = taskOf(receipt.context || {});
        (s.hints[task.id] ||= {}).ad = true;
      } else fail("invalid-argument", "Geçersiz reklam.");
    });
    await settle(uid);
  }
  return {status, submit, favorites, hint, prepareReward, settleReward};
}
module.exports = {createService, catalog, accepts, journeys};
