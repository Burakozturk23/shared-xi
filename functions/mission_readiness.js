"use strict";
const {dayKey} = require("./rewarded_ads");
const W = require("./daily_words");
const S = require("./mission_story_events");
// The pilot allowlist is necessary but not sufficient. Intersect it with the
// game's own gate, current content, and each user's remaining one-shot content.
async function resolve(db, uid, requested, runtime, now, squadEnabled) {
  const ready = Object.fromEntries(Object.entries(requested || {}).map(([k, v]) => [k, v === true]));
  const events = [];
  const gate = (ids, live) => ids.forEach((id) => ready[id] = ready[id] === true && live);
  const online = require("./mission_health").availability(runtime.missionsV3?.serviceHealth, runtime, now);
  gate(["online"], online.online); gate(["friends"], online.friends);
  gate(["matching", "pyramid", "burst_survival"], runtime.arcade?.enabled === true);
  gate(["this_or_that", "blind_ranking", "higher_lower"], runtime.choice?.enabled === true);
  const fake = runtime.fakeClub;
  gate(["fake_endless"], fake?.dataEnabled !== false && fake?.soloEnabled === true &&
    require("./fake_club").catalog.questions.some((q) => q.difficulty === "easy" &&
      !(fake.disabledQuestions || []).includes(q.questionId)));
  gate(["squad_challenge"], squadEnabled === true);
  const mc = require("./mystery_chain").catalog;
  const disabled = runtime.mysteryChain?.disabledFiles || [];
  gate(["mystery"], mc.mystery.some((p) => !disabled.includes("mystery__" + p.playerId)));
  gate(["chain"], mc.mastery.some((p) => !disabled.includes("chain__" + p.id)));
  const jobs = S.definitions.filter(([, mode]) => ready[mode]).map(async ([family, mode]) => {
    const state = (await db.ref(family + "/" + uid).get()).val();
    ready[mode] = S.hasRemaining(mode, state);
    events.push(...S.changed(uid, family, null, state));
  });
  if (W.MODES.some((mode) => ready[mode])) {
    jobs.push((async () => {
      const day = dayKey(now); const week = W.weekKey(now);
      const [daily, weekly, state] = await Promise.all([
        db.ref("dailyWordPrivate/daily/" + day).get(), db.ref("dailyWordPrivate/weekly/" + week).get(),
        db.ref("dailyWordState/" + uid).get(),
      ]);
      const data = state.val() || {};
      const today = {days: {[day]: data.days?.[day] || {}}, weeks: {[week]: data.weeks?.[week] || {}}};
      events.push(...require("./mission_events").changedWords(uid, null, today));
      for (const mode of W.MODES) {
        const isWeek = mode === "passa_weekly";
        const pack = (isWeek ? weekly : daily).val() || W.compiled(isWeek ? week : day, isWeek);
        const run = isWeek ? data.weeks?.[week] : data.days?.[day]?.[mode];
        const ids = !pack ? [] : mode === "daily_lingo" ? [pack.lingo?.id] :
        mode === "daily_anagram" ? pack.anagram?.map((q) => q.questionId) : pack.questions?.map((q) => q.id);
        const healthy = runtime.dailyWords?.enabled === true && pack && ids?.length && ids.every((id) =>
          id && !(runtime.dailyWords.disabledQuestions || []).includes(id));
        gate([mode], !!healthy && !run?.finished);
      }
    })());
  }
  await Promise.all(jobs);
  return {readyModes: ready, events};
}
module.exports = {resolve};
