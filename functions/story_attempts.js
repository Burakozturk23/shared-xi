"use strict";
const {RewardError} = require("./rewarded_ads");

// Wrong answers per story task. Three misses in a row start a short cooldown
// that doubles with every further miss (30 s … 10 min), so a script cannot
// walk four-option tasks by trial and error. A correct answer clears the run
// and keeps how many misses came before it.
const FREE_MISSES = 3;
const BASE_MS = 30000;
const MAX_MS = 600000;
const key = (id) => String(id).replace(/[.#$[\]/]/g, "_");

function cooldownMs(streak) {
  return streak < FREE_MISSES ? 0 : Math.min(MAX_MS, BASE_MS * 2 ** (streak - FREE_MISSES));
}

function create({db, now = Date.now}) {
  const ref = (uid, mode, taskId) => db.ref(`storyAttempts/${uid}/${mode}/${key(taskId)}`);
  async function before(uid, mode, taskId) {
    const v = (await ref(uid, mode, taskId).get()).val();
    const wait = (v?.until || 0) - now();
    if (wait > 0) {
      throw new RewardError("resource-exhausted",
          `Art arda yanlış denemeler: ${Math.ceil(wait / 1000)} sn sonra yeniden dene.`);
    }
  }
  // Only a real guess counts: a non-empty list of strings. Malformed input can
  // never be right, so counting it would slow nobody down.
  async function wrong(uid, mode, taskId, answers) {
    if (!Array.isArray(answers) || !answers.length || answers.some((a) => typeof a !== "string")) return;
    await ref(uid, mode, taskId).transaction((raw) => {
      const v = raw || {};
      const streak = (v.streak || 0) + 1; const wait = cooldownMs(streak);
      return {...v, streak, wrong: (v.wrong || 0) + 1, lastWrongAt: now(), ...(wait ? {until: now() + wait} : {})};
    });
  }
  async function solved(uid, mode, taskId) {
    await ref(uid, mode, taskId).transaction((raw) => {
      if (!raw) return {wrong: 0, solvedAt: now(), wrongBeforeSolve: 0};
      const rest = {...raw}; delete rest.until; delete rest.streak;
      return {...rest, solvedAt: rest.solvedAt || now(), wrongBeforeSolve: rest.wrongBeforeSolve ?? (rest.wrong || 0)};
    });
  }
  return {before, wrong, solved};
}

module.exports = {create, cooldownMs, FREE_MISSES};
