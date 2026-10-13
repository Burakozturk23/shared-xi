"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const extra = require("../config/five_mode_expansion.json");
const publicPack = require("../../assets/data/five_mode_expansion.json");
const cases = [
  ["ucl", "ucl_catalog", "submitUclMoment", "getUclMoments", "uclMomentsState", "matchId", 1, 506, 1065, 24, 60],
  ["international", "international_catalog", "submitInternationalGlory", "getInternationalGlory",
    "internationalGloryState", "matchId", 2, 672, 1355, 32, 80],
  ["dynastyTasks", "dynasties_catalog", "submitDynasties", "getDynasties",
    "dynastiesState", "taskId", 2, 504, 1135, 48, 120],
  ["nostalgia", "nostalgia_catalog", "submitTurkishNostalgia", "getTurkishNostalgia",
    "nostalgiaState", "taskId", 2, 465, 1020, 81, 180],
];
const flattened = (data, key) => key === "nostalgia" ? data.flatMap((c) => c.tasks) : data;
for (const [key, base, submit, status, path, idKey, version, coins, xp, newCoins, newXp] of cases) {
  test(key + ": new tasks inherit mode rewards exactly once, with legacy receipts preserved", async () => {
    const h = harness();
    const tasks = flattened(extra[key], key);
    const input = (t) => ({version, [idKey]: t.id, answers: t.answerKeys});
    for (const t of tasks) {
      assert.equal((await h.call(submit, {...input(t), answers: ["unknown"]})).correct, false);
      await Promise.all([h.call(submit, input(t)), h.call(submit, input(t))]);
    }
    assert.equal(h.read("economyState/alice/balances/coins"), newCoins);
    assert.equal(h.read("progressionState/alice/lifetimeXp"), newXp);
    const receipts = h.read(path + "/alice/rewards");
    assert.ok(Object.keys(receipts).length >= tasks.length);
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
  test(key + ": old unpaid expansion progress reconciles once, retries recover XP, and guests wait", async () => {
    const h = harness();
    const tasks = flattened(extra[key], key);
    const completed = Object.fromEntries(tasks.map((t) => [t.id, 1]));
    completed.unknown = 1; // Unrecognized progress is never monetized.
    h.seed(path + "/alice", {completed, rewards: {}});
    h.failNext("progressionState/alice");
    await assert.rejects(h.call(status));
    await Promise.all([h.call(status), h.call(status)]);
    assert.equal(h.read("economyState/alice/balances/coins"), newCoins);
    assert.equal(h.read("progressionState/alice/lifetimeXp"), newXp);
    const receipts = h.read(path + "/alice/rewards");
    await h.call(status);
    assert.deepEqual(h.read(path + "/alice/rewards"), receipts);
    const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
    h.seed(path + "/guest", {completed});
    await h.call(status, {}, guest);
    assert.equal(h.read("economyState/guest"), null);
    assert.equal(h.read("progressionState/guest"), null);
    const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["guest-linked"]}}}};
    await h.call(status, {}, linked);
    await h.call(status, {}, linked);
    assert.equal(h.read("economyState/guest/balances/coins"), newCoins);
    assert.equal(h.read("progressionState/guest/lifetimeXp"), newXp);
  });
  if (key !== "nostalgia") test(key + ": new content counts towards existing collection thresholds", async () => {
    const h = harness();
    const original = require("../config/" + base + ".json");
    const old = original.matches || original.tasks;
    const threshold = original.economy.milestones[0];
    const allNew = flattened(extra[key], key);
    const unitSize = key === "dynastyTasks" ? 2 : 1;
    const someOld = old.slice(0, threshold.count * unitSize - allNew.length);
    for (const t of [...someOld, ...allNew]) {
      await h.call(submit, {version, [idKey]: t.id, answers: t.answerKeys});
    }
    const reward = h.read(path + "/alice/rewards/milestone_" + threshold.count);
    assert.equal(reward.coins, threshold.coins);
    assert.equal(reward.xp, threshold.xp);
    assert.equal(reward.settled, true);
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
  assert.equal(h.read("economyState/alice/balances/coins"), 240);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 440);
  assert.deepEqual(s.chapterCounts, [0, 0, 0, 0]);
  assert.equal(h.read("userAchievements/alice/journey_legend"), null);
  await h.call("setJourneyShowcase", {ids: ["PJ-33", "PJ-35", "PJ-40"]});
  for (const c of require("../config/journey_catalog.json").chapters) for (const j of c.journeys) await finish(j);
  s = await h.call("getPlayerJourney");
  assert.equal(s.completed.length, 40);
  assert.equal(s.finalUnlocked, true);
  assert.equal(h.read("economyState/alice/balances/coins"), 1350);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 2500);
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

test("old expansion careers reconcile once; chapter five supports the existing double bonus", async () => {
  const h = harness();
  h.seed("journeyRewardState/alice", {journeys: Object.fromEntries(
    extra.journey.journeys.map((j) => [j.id, {solved: 4, completedAt: 1}]))});
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("getPlayerJourney"));
  await Promise.all([h.call("getPlayerJourney"), h.call("getPlayerJourney")]);
  assert.equal(h.read("economyState/alice/balances/coins"), 240);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 440);
  const service = h.context.lbJourneyService();
  const prepared = await service.prepareReward("alice", "story_double", {chapter: 5});
  assert.equal(prepared.amount, 80);
  await Promise.all([service.settleReward("alice", {placement: "story_double", context: {chapter: 5}}),
    service.settleReward("alice", {placement: "story_double", context: {chapter: 5}})]);
  assert.equal(h.read("economyState/alice/balances/coins"), 320);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 440);
  await assert.rejects(service.prepareReward("alice", "story_double", {chapter: 5}));
  await assert.rejects(service.prepareReward("alice", "story_double", {chapter: 6}));
  assert.equal((await h.call("getPlayerJourney")).finalUnlocked, false);
});
