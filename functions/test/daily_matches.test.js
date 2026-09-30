"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {createService, resolveFixture, coins} = require("../daily_matches");
const {createService: createAds, dayKey} = require("../rewarded_ads");
const {defaults} = require("../economy_config");
const catalog = require("../config/daily_catalog.json");
const unit = "ca-app-pub-1234567890123456/1234567890";
function setup() {
  const h = harness();
  let linked = true;
  const service = createService({db: h.db, now: () => h.now, isLinked: async () => linked,
    grantCoins: (...args) => h.context.lbProgressionGrantCoins(h.db, ...args)});
  const fixture = (id = 1, date = dayKey(h.now)) => ({fixtureId: id, homeName: "Fenerbahce", awayName: "Besiktas",
    kickoff: date + "T20:00:00+03:00", leagueId: 203, isDerby: true, leagueName: "Süper Lig", status: "NS"});
  const put = (date = dayKey(h.now), matches = [fixture()]) => h.db.ref("daily_fixtures/" + date)
      .set({updatedAt: h.now, matches});
  let seq = 0;
  const config = JSON.parse(JSON.stringify(defaults)); config.sources.rewarded_coin.enabled = true;
  const ads = createAds({db: h.db, now: () => h.now, getConfig: async () => config, units: {android: unit},
    isLinked: async () => linked, isPro: async () => false, grantCoins: () => {
      throw Error("Wrong reward path");
    },
    randomId: () => (++seq).toString(16).padStart(48, "0"),
    prepareDailyReward: service.prepareReward, settleDailyReward: service.settleReward});
  return {h, service, fixture, put, ads, setLinked: (v) => linked = v,
    wallet: () => h.read("economyState/alice/balances/coins") || 0,
    async answer(key, count = 3) {
      let result;
      for (const id of catalog.pairs["36-114"].slice(0, count)) {
        result = await service.play("alice", {key, action: "answer", answer: catalog.players[id].name});
      }
      return result;
    },
    async ad(placement, key, request = "a".repeat(32)) {
      const {ticket} = await ads.prepare("alice", "android", placement, request, {key});
      const event = {user_id: "alice", custom_data: ticket.id, ad_unit: unit, transaction_id: ticket.id,
        timestamp: h.now};
      return {ticket, event};
    }};
}
test("catalog selects known clubs with >=4 shared players; postponed/unknown/invalid excluded", () => {
  const s = setup();
  assert.ok(resolveFixture(s.fixture()).sharedCount >= 4);
  assert.equal(resolveFixture({...s.fixture(), status: "PST"}), null);
  assert.equal(resolveFixture({...s.fixture(), homeName: "Unknown FC"}), null);
  assert.equal(resolveFixture({...s.fixture(), kickoff: "invalid"}), null);
  assert.equal(coins(2, 4), 0); assert.equal(coins(3, 4), 30); assert.equal(coins(4, 4), 50);
  assert.equal(coins(100, 100), 60);
});
test("server verifies answers and awards one immutable receipt after 3 correct; retry cannot farm", async () => {
  const s = setup(); await s.put(); const {session} = await s.service.start("alice", 1);
  assert.equal(session.answers, undefined); assert.deepEqual(session.remainingPlayers, []);
  await s.answer(session.key);
  const results = await Promise.all([1, 2].map(() => s.service.play("alice", {key: session.key, action: "finish",
    coins: 99999})));
  assert.equal(results[0].session.reward, 30); assert.equal(s.wallet(), 30);
  assert.equal((await s.service.start("alice", 1)).session.finished, true);
  assert.equal((await s.service.status("alice")).streak, 1);
  await assert.rejects(s.service.play("bob", {key: session.key, action: "finish"}));
});
test("three distinct wrong answers finish a loss; hints do not mark answers correct", async () => {
  const s = setup(); await s.put(); const {session} = await s.service.start("alice", 1);
  const hint = await s.service.play("alice", {key: session.key, action: "hint"});
  assert.equal(hint.session.found.length, 0); assert.ok(hint.session.hint);
  for (const answer of ["unknown1", "unknown2", "unknown3"]) {
    await s.service.play("alice", {key: session.key,
      action: "answer", answer});
  }
  assert.equal(s.wallet(), 0); assert.equal((await s.service.start("alice", 1)).session.finished, true);
});
test("SSV-only double is exactly the base reward and replay/client retry never pays twice", async () => {
  const s = setup(); await s.put(); const {session} = await s.service.start("alice", 1);
  await assert.rejects(s.ad("daily_double", session.key));
  await s.answer(session.key); await s.service.play("alice", {key: session.key, action: "finish"});
  const {event, ticket} = await s.ad("daily_double", session.key);
  assert.equal(ticket.amount, 30); assert.equal(s.wallet(), 30);
  await Promise.all([s.ads.accept(event), s.ads.accept(event)]);
  assert.equal(s.wallet(), 60);
  await s.ads.prepare("alice", "android", "daily_double", "a".repeat(32), {key: session.key});
  assert.equal(s.wallet(), 60);
  await assert.rejects(s.ad("daily_double", session.key, "b".repeat(32)));
});
test("cancelled hint consumes no benefit; verified hint survives UI closure and grants no coins", async () => {
  const s = setup(); await s.put(); const {session} = await s.service.start("alice", 1);
  await s.service.play("alice", {key: session.key, action: "hint"});
  const {event, ticket} = await s.ad("daily_hint", session.key);
  await s.ads.cancel("alice", ticket.id);
  assert.equal((await s.service.start("alice", 1)).session.adHint, false);
  await s.ads.accept(event);
  assert.equal((await s.service.start("alice", 1)).session.adHint, true);
  assert.equal(s.wallet(), 0);
});
test("three starts per Istanbul day; day rollover rejects old submissions", async () => {
  const s = setup(); await s.put(undefined, [1, 2, 3, 4].map((i) => s.fixture(i)));
  const {session} = await s.service.start("alice", 1);
  await s.service.start("alice", 2); await s.service.start("alice", 3);
  await assert.rejects(s.service.start("alice", 4));
  s.h.setTime(s.h.now + 86400000);
  await assert.rejects(s.service.play("alice", {key: session.key, action: "answer", answer: "test"}));
});
test("streak ignores empty fixture days; one missed playable day can be repaired once per week", async () => {
  const s = setup(); await s.h.db.ref("dailyMatchState/alice").set({streak: 4, lastWin: "2026-09-18"});
  await s.put("2026-09-19", []); await s.put();
  assert.equal((await s.service.status("alice")).streak, 4);
  await s.put("2026-09-19", [s.fixture(9, "2026-09-19")]);
  assert.equal((await s.service.status("alice")).repairStreak, 4);
  const {event} = await s.ad("daily_streak"); await s.ads.accept(event);
  assert.equal((await s.service.status("alice")).streak, 4);
  const {session} = await s.service.start("alice", 1); await s.answer(session.key);
  await s.service.play("alice", {key: session.key, action: "finish"});
  assert.equal((await s.service.status("alice")).streak, 5);
  await assert.rejects(s.ad("daily_streak", undefined, "b".repeat(32)));
});
test("anonymous base and doubled rewards wait for same-account linking, then settle once", async () => {
  const s = setup(); s.setLinked(false); await s.put(); const {session} = await s.service.start("alice", 1);
  await s.answer(session.key); await s.service.play("alice", {key: session.key, action: "finish"});
  const {event} = await s.ad("daily_double", session.key); await s.ads.accept(event);
  assert.equal(s.wallet(), 0); assert.equal((await s.service.status("alice")).pendingCoins, 60);
  s.setLinked(true); await s.service.status("alice"); await s.service.status("alice"); assert.equal(s.wallet(), 60);
});
