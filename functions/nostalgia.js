"use strict";
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/nostalgia_catalog.json");
const tasks = Object.fromEntries(catalog.chapters.flatMap((c) => c.tasks.map((t) => [t.id, t])));
const stateOf = (raw) => ({completed: {}, hints: {}, rewards: {}, ...raw});
const fail = (code, message) => {
  throw new RewardError(code, message);
};
function taskOf(input) {
  if (input.version !== catalog.version) fail("failed-precondition", "Nostalji içeriğini güncelle.");
  if (typeof input.taskId !== "string" || !Object.hasOwn(tasks, input.taskId)) {
    fail("invalid-argument", "Geçersiz nostalji görevi.");
  }
  return tasks[input.taskId];
}
function accepts(task, answers) {
  return Array.isArray(answers) && answers.length === task.answerKeys.length &&
    answers.every((key, i) => typeof key === "string" && key === task.answerKeys[i]);
}
function createService({db, grantCoins, grantXp, chargeHint, isPro, now = Date.now}) {
  const ref = (uid) => db.ref("nostalgiaState/" + uid);
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
  function available(state, task) {
    const chapter = catalog.chapters.find((c) => c.id === task.chapterId);
    if (chapter.tasks[1].id === task.id && !state.completed[chapter.tasks[0].id]) {
      fail("failed-precondition", "Önce ilk görevi eşitle.");
    }
  }
  async function settle(uid) {
    const state = await get(uid);
    for (const [id, reward] of Object.entries(state.rewards)) {
      if (reward.settled) continue;
      const receipt = "nostalgia_v2__" + id;
      await grantCoins(uid, receipt, "turkish_nostalgia", id, reward.coins, "nostalgia-v2");
      await grantXp(uid, receipt, reward.xp);
      await change(uid, (s) => {
        s.rewards[id].settled = true;
      });
    }
  }
  async function status(uid, eligible = true) {
    if (eligible) await settle(uid);
    const s = await get(uid);
    return {version: catalog.version, completed: s.completed, hints: s.hints, rewards: s.rewards,
      pro: eligible && await isPro(uid), rewardEligible: eligible};
  }
  async function submit(uid, input, eligible = true) {
    const task = taskOf(input);
    if (!accepts(task, input.answers)) return {correct: false};
    await change(uid, (s) => {
      available(s, task);
      s.completed[task.id] ||= now();
      const earn = (id, reward) => {
        s.rewards[id] ||= {...reward, earnedAt: now(), settled: false};
      };
      earn(task.id, catalog.economy.task);
      for (const c of catalog.chapters) {
        if (c.tasks.every((t) => s.completed[t.id])) earn(c.id, catalog.economy.chapter);
      }
      if (Object.keys(tasks).every((id) => s.completed[id])) earn("album", catalog.economy.final);
    });
    return {correct: true, ...await status(uid, eligible)};
  }
  async function hint(uid, input, eligible = true) {
    const task = taskOf(input);
    if (!eligible) fail("permission-denied", "Güçlü yardım için Google hesabına bağlan.");
    const state = await get(uid);
    available(state, task);
    if (!state.hints[task.id]) {
      // The canonical wallet receipt makes concurrent requests and crash retries
      // safe. Pro is evaluated on the server, never accepted from the caller.
      if (!await isPro(uid)) await chargeHint(uid, task.id, catalog.economy.hintPrice);
      await change(uid, (s) => {
        s.hints[task.id] = true;
      });
    }
    return status(uid, eligible);
  }
  return {status, submit, hint};
}
module.exports = {catalog, tasks, accepts, createService};
