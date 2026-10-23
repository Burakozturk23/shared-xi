"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {RULE} = require("../pvp_engine");
const event = (settlement, before = false) => ({params: {mode: "club_club", matchId: "match"},
  data: {before: {exists: () => before}, after: {exists: () => !!settlement, val: () => settlement}}});

test("actual PvP settlement advances daily play and win missions exactly once without enabling rewards", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}, bob: {displayName: "Bob"}}});
  await h.context.lbSettlePvp({id: "match", mode: "club_club", host: "alice", guest: "bob",
    status: "finished", rankedEligible: true, playKind: "ranked", ruleVersion: RULE,
    winnerUid: "alice", finishedAt: h.now, rewardPolicy: {}, audit: {}, names: {}, scores: {}},
  {rankedEnabled: true, rewardsEnabled: false, eloEnabled: false});
  const settlement = h.read("rankedState/settlements/club_club/match");
  assert.equal(settlement.player1Result, "win");
  assert.equal(settlement.player2Result, "loss");
  await h.context.exports.syncRankedMissions(event(settlement));
  await h.context.exports.syncRankedMissions(event(settlement));
  assert.deepEqual(h.read("missionState/alice/daily/counters"), {rankedPlayed: 1, rankedWins: 1, dailyChallenge: 0});
  assert.deepEqual(h.read("missionState/bob/daily/counters"), {rankedPlayed: 1, rankedWins: 0, dailyChallenge: 0});
  assert.equal(settlement.rewards.alice.coins, 0);
  assert.equal(settlement.rewards.alice.eloDelta, 0);
});

test("older PvP results work; invalid and update events are ignored", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}, bob: {displayName: "Bob"}}});
  const settlement = {serverValidated: true, settledAt: h.now, player1Uid: "alice", player2Uid: "bob",
    rewards: {alice: {result: "draw"}, bob: {result: "draw"}}};
  await h.context.exports.syncRankedMissions(event({...settlement, serverValidated: false}));
  await h.context.exports.syncRankedMissions(event(settlement, true));
  await h.context.exports.syncRankedMissions(event(null));
  await h.context.exports.syncRankedMissions(event({...settlement, rewards: {}}));
  assert.equal(h.read("missionState"), null);
  await h.context.exports.syncRankedMissions(event(settlement));
  for (const uid of ["alice", "bob"]) {
    assert.deepEqual(h.read(`missionState/${uid}/daily/counters`), {rankedPlayed: 1, rankedWins: 0, dailyChallenge: 0});
  }
});

test("legacy duel results retain account eligibility and server-day boundaries", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}, bob: {displayName: "Bob"}}});
  h.setLinked("bob", false);
  const settlement = {serverValidated: true, settledAt: h.now, player1Uid: "alice", player2Uid: "bob",
    player1Result: "win", player2Result: "loss"};
  await h.context.exports.syncRankedMissions(event({...settlement, settledAt: h.now - 86400000}));
  assert.equal(h.read("missionState"), null);
  await h.context.exports.syncRankedMissions(event(settlement));
  assert.equal(h.read("missionState/alice/daily/counters/rankedWins"), 1);
  assert.equal(h.read("missionState/bob"), null);
});
