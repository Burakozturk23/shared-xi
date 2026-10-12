"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const extra = require("../config/five_mode_expansion.json");
const publicPack = require("../../assets/data/five_mode_expansion.json");
const cases = [
  ["ucl", "ucl_catalog", "submitUclMoment", "getUclMoments", "uclMomentsState", "matchId", 1, 482, 1005],
  ["international", "international_catalog", "submitInternationalGlory", "getInternationalGlory",
    "internationalGloryState", "matchId", 2, 640, 1275],
  ["dynastyTasks", "dynasties_catalog", "submitDynasties", "getDynasties", "dynastiesState", "taskId", 2, 456, 1015],
  ["nostalgia", "nostalgia_catalog", "submitTurkishNostalgia", "getTurkishNostalgia",
    "nostalgiaState", "taskId", 2, 384, 840],
];
const flattened = (data, key) => key === "nostalgia" ? data.flatMap((c) => c.tasks) : data;
for (const [key, base, submit, status, path, idKey, version, coins, xp] of cases) {
  test(key + ": new tasks never unlock old rewards; complete legacy content keeps exact totals", async () => {
    const h = harness();
    const tasks = flattened(extra[key], key);
    const input = (t) => ({version, [idKey]: t.id, answers: t.answerKeys});
    for (const t of tasks) {
      assert.equal((await h.call(submit, {...input(t), answers: ["unknown"]})).correct, false);
      await Promise.all([h.call(submit, input(t)), h.call(submit, input(t))]);
    }
    assert.equal(h.read("economyState/alice"), null);
    assert.equal(h.read("progressionState/alice"), null);
    assert.deepEqual(h.read(path + "/alice/rewards"), {});
    const original = require("../config/" + base + ".json");
    const old = key === "nostalgia" ? original.chapters.flatMap((c) => c.tasks) : original.matches || original.tasks;
    for (const t of old) await h.call(submit, input(t));
    await Promise.all(tasks.map((t) => h.call(submit, input(t))));
    assert.equal(h.read("economyState/alice/balances/coins"), coins);
    assert.equal(h.read("progressionState/alice/lifetimeXp"), xp);
    const other = await h.call(status, {}, {uid: "bob", token: {}});
    assert.equal(Object.keys(other.results || {}).length, 0);
    assert.equal(Object.keys(other.rewards || {}).length, 0);
  });
}
test("eight new careers: ordered stages, replay, results, showcase and old final reward isolation", async () => {
  const h = harness();
  const proof = (j, t) => ({version: 1, journeyId: j.id, taskId: t.id,
    answers: t.answerKeys.slice(0, t.requiredCount)});
  const finish = async (j) => {
    for (const t of j.tasks) await h.call("submitPlayerJourney", proof(j, t));
  };
  for (const j of extra.journey.journeys) {
    await assert.rejects(h.call("submitPlayerJourney", proof(j, j.tasks[1])));
    for (const t of j.tasks) {
      await assert.rejects(h.call("submitPlayerJourney", {...proof(j, t), answers: ["fake"]}));
    }
    await finish(j);
    await Promise.all([finish(j), finish(j)]);
  }
  let s = await h.call("getPlayerJourney");
  assert.equal(s.completed.length, 8);
  assert.equal(Object.keys(s.results).length, 32);
  assert.equal(s.finalUnlocked, false);
  assert.equal(h.read("economyState/alice"), null);
  assert.deepEqual(s.chapterCounts, [0, 0, 0, 0]);
  assert.equal(h.read("userAchievements/alice/journey_legend"), null);
  await h.call("setJourneyShowcase", {ids: ["PJ-33", "PJ-35", "PJ-40"]});
  for (const c of require("../config/journey_catalog.json").chapters) for (const j of c.journeys) await finish(j);
  s = await h.call("getPlayerJourney");
  assert.equal(s.completed.length, 40);
  assert.equal(s.finalUnlocked, true);
  assert.equal(h.read("economyState/alice/balances/coins"), 1110);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 2060);
});
test("expansion answers and source/explanation spoilers are absent from mobile assets", () => {
  const text = JSON.stringify(publicPack);
  for (const field of ["answerKeys", "result", "explanation", "story", "sources", "strongHint"]) {
    assert.ok(!text.includes("\"" + field + "\":"), field);
  }
  const ids = extra.journey.journeys.flatMap((j) => j.tasks).concat(extra.ucl,
      extra.nostalgia.flatMap((c) => c.tasks), extra.international, extra.dynastyTasks).map((t) => t.id);
  assert.equal(ids.length, 51);
  assert.equal(new Set(ids).size, 51);
});
