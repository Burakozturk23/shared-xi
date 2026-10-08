"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {journeys, catalog} = require("../player_journey");
const {createService} = require("../rewarded_ads");
const {defaults} = require("../economy_config");
const unit = "ca-app-pub-1234567890123456/1234567890";
const proof = (id, index) => ({version: 1, journeyId: id, taskId: journeys[id].tasks[index].id,
  answers: journeys[id].tasks[index].answerKeys.slice(0, journeys[id].tasks[index].requiredCount)});
async function finish(h, id) {
  for (let i = 0; i < 4; i++) await h.call("submitPlayerJourney", proof(id, i));
}
test("server catalog matches all four bundled client assets", () => {
  for (const [i, n] of ["one", "two", "three", "four"].entries()) {
    assert.deepEqual(catalog.chapters[i], require("../../assets/data/player_journey_chapter_" + n + ".json"));
  }
});
test("reject guest, unknown IDs, wrong answers and skipped stages", async () => {
  const h = harness();
  await assert.rejects(h.call("getPlayerJourney", {}, null));
  await assert.rejects(h.call("submitPlayerJourney", {...proof("messi", 0), journeyId: "fake"}));
  await assert.rejects(h.call("submitPlayerJourney", {...proof("messi", 0), answers: ["o3"]}));
  await assert.rejects(h.call("submitPlayerJourney", proof("messi", 3)));
  assert.equal(h.read("economyState/alice"), null);
});
test("all 128 proofs mint 1110 coins / 2060 XP once and unlock five badges", async () => {
  const h = harness();
  for (const id of Object.keys(journeys)) await finish(h, id);
  let s = await h.call("getPlayerJourney");
  assert.equal(s.completed.length, 32);
  assert.equal(s.finalUnlocked, true);
  assert.equal(h.read("economyState/alice/balances/coins"), 1110);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 2060);
  for (const id of ["journey_chapter_1", "journey_chapter_2", "journey_chapter_3",
    "journey_chapter_4", "journey_legend"]) {
    assert.ok(h.read("userAchievements/alice/" + id));
  }
  await Promise.all([finish(h, "mbappe"), finish(h, "mbappe")]);
  assert.equal(h.read("economyState/alice/balances/coins"), 1110);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 2060);
  s = await h.call("setJourneyShowcase", {ids: ["messi", "neuer", "mbappe"]});
  assert.deepEqual(s.favorites, ["messi", "neuer", "mbappe"]);
  await assert.rejects(h.call("setJourneyShowcase", {ids: ["messi", "messi"]}));
  await assert.rejects(h.call("setJourneyShowcase", {ids: ["messi", "neuer", "mbappe", "ramos"]}));
});
test("wallet success and XP failure recover without paying twice", async () => {
  const h = harness();
  for (let i = 0; i < 3; i++) await h.call("submitPlayerJourney", proof("messi", i));
  h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitPlayerJourney", proof("messi", 3)));
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  await h.call("getPlayerJourney");
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 40);
  // Other progression writes must preserve journey XP receipt IDs.
  await h.call("getMyProgression");
  await finish(h, "messi");
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 40);
});
test("hints debit once, reject insufficient balance and recover entitlement after failure", async () => {
  const h = harness();
  const input = {journeyId: "messi", taskId: "messi_v2_1"};
  await assert.rejects(h.call("buyPlayerJourneyHint", input));
  h.seed("economyState/alice", {balances: {coins: 30}});
  h.failNext("journeyRewardState/alice");
  await assert.rejects(h.call("buyPlayerJourneyHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  await Promise.all([h.call("buyPlayerJourneyHint", input), h.call("buyPlayerJourneyHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
  assert.equal(h.read("journeyRewardState/alice/hints/messi_v2_1/coin"), true);
  await assert.rejects(h.call("buyPlayerJourneyHint", {journeyId: "messi", taskId: "messi_v2_4"}));
  await assert.rejects(h.call("setJourneyShowcase", {ids: ["messi"]}));
});
test("SSV binds story hints and doubles to eligible tasks/chapters, no XP doubling", async () => {
  const h = harness();
  const story = h.context.lbJourneyService();
  let seq = 0;
  const ads = createService({db: h.db, now: () => h.now, units: {android: unit},
    getConfig: async () => defaults, isPro: async () => false, isLinked: async () => true,
    grantCoins: () => {
      throw Error("Must use story settlement");
    },
    prepareStoryReward: story.prepareReward, settleStoryReward: story.settleReward,
    randomId: () => (++seq).toString(16).padStart(48, "0")});
  const prepare = (placement, context) => ads.prepare("alice", "android", placement,
      (++seq).toString(16).padStart(32, "0"), context);
  await assert.rejects(prepare("story_double", {chapter: 1}));
  const t = (await prepare("story_hint", {journeyId: "messi", taskId: "messi_v2_1"})).ticket;
  assert.equal(h.read("journeyRewardState/alice/hints/messi_v2_1"), null);
  const event = {user_id: "alice", custom_data: t.id, timestamp: h.now, ad_unit: unit, transaction_id: "proof1"};
  await ads.accept(event);
  await ads.accept(event);
  assert.equal(h.read("journeyRewardState/alice/hints/messi_v2_1/ad"), true);
  assert.equal(h.read("economyState/alice"), null);
  for (const j of catalog.chapters[0].journeys) await finish(h, j.id);
  h.setTime(h.now + 31000);
  const d = (await prepare("story_double", {chapter: 1})).ticket;
  const double = {...event, custom_data: d.id, timestamp: h.now, transaction_id: "proof2"};
  await Promise.all([ads.accept(double), ads.accept(double)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 320);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 440);
  await assert.rejects(prepare("story_double", {chapter: 1}));
  await assert.rejects(ads.accept({...double, transaction_id: "different"}));
});

test("Pro support needs no ad unit; cancelled watches and mismatched context cannot grant help", async () => {
  const h = harness();
  const story = h.context.lbJourneyService();
  let seq = 0;
  const service = (pro) => createService({db: h.db, now: () => h.now, units: pro ? {} : {android: unit},
    getConfig: async () => defaults, isPro: async () => pro, isLinked: async () => true,
    grantCoins: () => {
      throw Error("Wrong wallet route");
    },
    prepareStoryReward: story.prepareReward, settleStoryReward: story.settleReward,
    randomId: () => (++seq).toString(16).padStart(48, "0")});
  const ads = service(false);
  const request = "a".repeat(32);
  const context = {journeyId: "messi", taskId: "messi_v2_1"};
  const ticket = (await ads.prepare("alice", "android", "story_hint", request, context)).ticket;
  await assert.rejects(ads.prepare("alice", "android", "story_hint", request,
      {journeyId: "ronaldo", taskId: "ronaldo_v2_1"}), {code: "invalid-argument"});
  await ads.cancel("alice", ticket.id);
  assert.equal(h.read("journeyRewardState/alice"), null);
  h.setTime(h.now + 31000);
  const pro = await service(true).prepare("alice", "android", "story_hint", "b".repeat(32), context);
  assert.equal(pro.pro, true);
  assert.equal(h.read("journeyRewardState/alice/hints/messi_v2_1/ad"), true);
  assert.equal(h.read("economyState/alice"), null);
  assert.equal(h.read("progressionState/alice"), null);
});
