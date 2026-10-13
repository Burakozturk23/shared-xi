"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/what_if_catalog.json");
const scenarios = Object.fromEntries(catalog.scenarios.map((s) => [s.id, s]));
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const stateOf = (raw) => ({progress: {}, hints: {}, rewards: {}, favorites: [], ...raw});
function routeOf(input) {
  const scenario = typeof input.scenarioId === "string" && Object.hasOwn(scenarios, input.scenarioId) ?
    scenarios[input.scenarioId] : null;
  const route = scenario?.routes.find((r) => r.id === input.routeId);
  if (!route) fail("invalid-argument", "Geçersiz What If rotası.");
  return {scenario, route, task: route.task};
}
function accepts(task, answers) {
  if (!Array.isArray(answers) || answers.length !== task.answerKeys.length ||
      new Set(answers).size !== answers.length || answers.some((a) => typeof a !== "string")) return false;
  return task.type === "timeline" ? answers.every((a, i) => a === task.answerKeys[i]) :
    answers.every((a) => task.answerKeys.includes(a));
}
function createService({db, grantCoins, grantXp, chargeHint, projectBadges, now = Date.now}) {
  const ref = (uid) => db.ref("whatIfState/" + uid);
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
  const ends = (s, id) => Object.keys(s.progress[id]?.ends || {}).filter((r) => ["real", "alternate"].includes(r));
  const counts = (s) => catalog.chapters.map((c) => catalog.scenarios
      .filter((j) => j.chapter === c.id && ends(s, j.id).length > 0).length);
  const earned = (s, id, coins, xp) => {
    s.rewards[id] ||= {coins, xp, earnedAt: now(), settled: false};
  };
  async function settle(uid) {
    const s = await get(uid);
    for (const [id, reward] of Object.entries(s.rewards)) {
      if (reward.settled) continue;
      await grantCoins(uid, "what_if_v1__" + id, "what_if", id, reward.coins, "what-if-v1");
      if (reward.xp) await grantXp(uid, "what_if__" + id, reward.xp);
      await change(uid, (latest) => {
        latest.rewards[id].settled = true;
      });
    }
    await projectBadges(uid, {what_if_total: counts(s).reduce((a, b) => a + b, 0),
      what_if_dual: catalog.scenarios.filter((j) => ends(s, j.id).length === 2).length});
  }
  async function status(uid) {
    await settle(uid);
    const s = await get(uid);
    return {ok: true, version: catalog.version, progress: s.progress, hints: s.hints,
      rewards: s.rewards, favorites: s.favorites, chapterCounts: counts(s), hintPrice: 10};
  }
  async function submit(uid, input) {
    if (input.version !== catalog.version) fail("failed-precondition", "What If içeriğini güncelle.");
    const {scenario, route, task} = routeOf(input);
    if (!accepts(task, input.answers)) fail("invalid-argument", "Cevap doğrulanamadı.");
    await change(uid, (s) => {
      const p = s.progress[scenario.id] ||= {ends: {}};
      p.ends[route.id] ||= now();
      earned(s, "scenario__" + scenario.id, 10, 25);
      counts(s).forEach((n, i) => {
        if (n === 8) earned(s, "chapter__" + (i + 1), 60, 100);
      });
    });
    return status(uid);
  }
  async function favorites(uid, input) {
    const ids = input.ids;
    if (!Array.isArray(ids) || ids.length > 3 || new Set(ids).size !== ids.length ||
        ids.some((id) => typeof id !== "string" || !Object.hasOwn(scenarios, id))) {
      fail("invalid-argument", "Vitrin için en fazla üç farklı kart seç.");
    }
    await change(uid, (s) => {
      if (ids.some((id) => !ends(s, id).length)) fail("permission-denied", "Önce hikâyeyi tamamla.");
      s.favorites = ids;
    });
    return status(uid);
  }
  async function hint(uid, input) {
    const {task, scenario, route} = routeOf(input);
    const s = await get(uid);
    if (s.hints[task.id]?.coin || s.hints[task.id]?.ad) return status(uid);
    if (ends(s, scenario.id).includes(route.id)) fail("failed-precondition", "Bu son zaten açık.");
    await chargeHint(uid, task.id, 10);
    await change(uid, (latest) => {
      (latest.hints[task.id] ||= {}).coin = true;
    });
    return status(uid);
  }
  async function prepareReward(uid, placement, input = {}) {
    const s = await get(uid);
    if (placement === "what_if_double") {
      const chapter = input.chapter;
      if (!Number.isInteger(chapter) || chapter < 1 || chapter > 3) fail("invalid-argument", "Geçersiz bölüm.");
      if (!s.rewards["chapter__" + chapter]?.settled || s.rewards["double__" + chapter]) {
        fail("failed-precondition", "Bölüm bonusu hazır değil veya alındı.");
      }
      return {amount: 60, claimKey: "what_if_double__" + chapter, context: {chapter}};
    }
    if (placement !== "what_if_hint") fail("invalid-argument", "Geçersiz yardım.");
    const {scenario, route, task} = routeOf(input);
    if (ends(s, scenario.id).includes(route.id) || s.hints[task.id]?.coin || s.hints[task.id]?.ad) {
      fail("failed-precondition", "Yardım zaten açık veya bu son keşfedildi.");
    }
    return {amount: 0, claimKey: "what_if_hint__" + task.id,
      context: {scenarioId: scenario.id, routeId: route.id}};
  }
  async function settleReward(uid, receipt) {
    await change(uid, (s) => {
      if (receipt.placement === "what_if_double") {
        const chapter = receipt.context?.chapter;
        if (!Number.isInteger(chapter) || chapter < 1 || chapter > 3 || !s.rewards["chapter__" + chapter]) {
          fail("failed-precondition", "Bölüm tamamlanmamış.");
        }
        earned(s, "double__" + chapter, 60, 0);
      } else if (receipt.placement === "what_if_hint") {
        const {task} = routeOf(receipt.context || {});
        (s.hints[task.id] ||= {}).ad = true;
      } else fail("invalid-argument", "Geçersiz reklam.");
    });
    await settle(uid);
  }
  return {status, submit, favorites, hint, prepareReward, settleReward};
}
module.exports = {createService, catalog, scenarios, accepts};
