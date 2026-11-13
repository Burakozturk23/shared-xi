"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const S = require("../mission_story_events");
const R = require("../mission_readiness");
const W = require("../daily_words");
const {harness} = require("./support/economy_harness");
function complete(section, time, state = {}) {
  if (section.journey) (state.journeys ||= {})[section.id] = {solved: section.tasks.length, completedAt: time};
  else if (section.scenario) {
    const p = (state.progress ||= {})[section.scenario] ||= {ends: {}};
    p.ends[section.route] = time;
  } else for (const id of section.tasks) (state.completed ||= {})[id] = time;
  return state;
}
for (const [family, mode] of S.definitions) {
  test(`${mode}: completed section counts once; unknown or partial sections cannot count`, async () => {
    const h = harness({users: {alice: {displayName: "Alice"}}}, {omitEmptyObjects: true});
    const section = S.sections(mode)[0]; const done = complete(section, h.now);
    assert.equal(S.changed("alice", family, null, {completed: {invented: h.now}}).length, 0);
    const fn = h.context.exports["syncMission_" + family];
    const event = {params: {uid: "alice"}, data: {before: {val: () => null}, after: {val: () => done}}};
    await fn(event); await fn(event);
    assert.equal(h.read(`missionState/alice/daily/counters/mode__${mode}`), 1);
    assert.equal(h.read("missionState/alice/daily/counters/unassistedCompleted"), null);
    assert.equal(S.changed("alice", family, done, done).length, 0);
    assert.equal(h.read("economyState/alice/balances/coins"), null);
    if (section.tasks.length > 1) {
      const partial = structuredClone(done);
      if (section.journey) partial.journeys[section.id].solved--;
      else delete partial.completed[section.tasks[0]];
      assert.equal(S.changed("alice", family, null, partial).length, 0);
    }
  });
}
test("content readiness respects live gates, missing calendar, disabled question and completed story", async () => {
  const h = harness();
  const requested = {matching: true, this_or_that: true, fake_endless: true, squad_challenge: true,
    daily_lingo: true, player_journey: true};
  const off = await R.resolve(h.db, "alice", requested, {}, h.now, false);
  for (const mode of ["matching", "this_or_that", "fake_endless", "squad_challenge", "daily_lingo"]) {
    assert.equal(off.readyModes[mode], false, mode);
  }
  const day = "2026-10-24"; const time = Date.parse(day + "T12:00:00Z");
  const pack = W.compiled(day, false); assert.ok(pack);
  h.seed("dailyWordPrivate/daily/" + day, pack);
  const runtime = {dailyWords: {enabled: true}, arcade: {enabled: true}};
  const on = await R.resolve(h.db, "alice", requested, runtime, time, true);
  assert.equal(on.readyModes.matching, true); assert.equal(on.readyModes.daily_lingo, true);
  runtime.dailyWords.disabledQuestions = [pack.lingo.id];
  assert.equal((await R.resolve(h.db, "alice", requested, runtime, time, true)).readyModes.daily_lingo, false);
  const completeState = S.sections("player_journey").reduce((s, section) => complete(section, time, s), {});
  h.seed("journeyRewardState/alice", completeState);
  const full = await R.resolve(h.db, "alice", requested, runtime, time, true);
  assert.equal(full.readyModes.player_journey, false);
  assert.equal(full.events.length, S.sections("player_journey").length);
  runtime.dailyWords.disabledQuestions = [];
  const future = Date.parse("2040-01-01T12:00:00Z");
  assert.equal((await R.resolve(h.db, "alice", requested, runtime, future, true)).readyModes.daily_lingo, false);
});
test("finished daily game is reconciled before assignment and cannot be offered as unfinished content", async () => {
  const h = harness(); const day = "2026-10-24"; const time = Date.parse(day + "T12:00:00Z");
  h.seed(`dailyWordState/alice/days/${day}/daily_lingo`, {mode: "daily_lingo", finished: true,
    eligible: true, result: {finishedAt: time}});
  const result = await R.resolve(h.db, "alice", {daily_lingo: true}, {dailyWords: {enabled: true}}, time, false);
  assert.equal(result.readyModes.daily_lingo, false);
  assert.equal(result.events.length, 1); assert.equal(result.events[0].serverFinishedAtMs, time);
});
