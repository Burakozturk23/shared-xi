"use strict";
// These are server-owned completion records. A section counts only after all
// required stages are complete; replaying a solved section creates no new event.
const definitions = [
  ["journeyRewardState", "player_journey", "Oyuncu Yolculuğu"],
  ["whatIfState", "what_if", "What If"],
  ["uclMomentsState", "ucl_moments", "UCL Moments"],
  ["nostalgiaState", "nostalgia", "Türkiye Nostaljisi"],
  ["internationalGloryState", "international_glory", "International Glory"],
  ["dynastiesState", "dynasties", "Hanedanlar"],
  ["footballDocuState", "football_docu", "Futbol Belgeseli"],
  ["derbyDayState", "derby_day", "Derbi Günü"],
];
function sections(mode) {
  if (!definitions.some((d) => d[1] === mode)) return [];
  const c = require("./" + mode).catalog;
  if (mode === "player_journey") {
    return c.chapters.flatMap((ch) => ch.journeys.map((j) =>
      ({id: j.id, tasks: j.tasks.map((t) => t.id), journey: true})));
  }
  if (mode === "what_if") {
    return c.scenarios.flatMap((s) => s.routes.map((r) =>
      ({id: s.id + ":" + r.id, scenario: s.id, route: r.id, tasks: [r.task.id]})));
  }
  if (mode === "nostalgia") return c.chapters.map((ch) => ({id: ch.id, tasks: ch.tasks.map((t) => t.id)}));
  if (mode === "dynasties" || mode === "football_docu") {
    return (c.dynasties || c.episodes).map((s) => ({id: s.id, tasks: s.taskIds}));
  }
  return (c.matches || c.tasks).map((t) => ({id: t.id, tasks: [t.id]}));
}
function finishedAt(s, section) {
  if (section.journey) {
    const p = s?.journeys?.[section.id];
    return p?.solved === section.tasks.length ? p.completedAt : null;
  }
  if (section.scenario) return s?.progress?.[section.scenario]?.ends?.[section.route];
  const times = section.tasks.map((t) => s?.completed?.[t]);
  return times.every((t) => Number.isSafeInteger(t) && t > 0) ? Math.max(...times) : null;
}
function changed(uid, family, before, after) {
  const mode = definitions.find((d) => d[0] === family)?.[1];
  if (!mode || !after) return [];
  return sections(mode).flatMap((section) => {
    const time = finishedAt(after, section);
    if (finishedAt(before, section) || !Number.isSafeInteger(time) || time <= 0) return [];
    // Legacy clients have unreported free hints. Do not certify a clean result.
    return [{uid, eventId: family + ":" + section.id, modeId: mode, source: "solo_verified",
      result: "completed", serverValidated: true, verificationVersion: 1, serverFinishedAtMs: time,
      assisted: section.tasks.some((id) => !!after.hints?.[id]), assistanceUnknown: true}];
  });
}
function hasRemaining(mode, state) {
  return sections(mode).some((s) => !finishedAt(state, s));
}
module.exports = {definitions, sections, finishedAt, changed, hasRemaining};
