"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const E = require("../mission_events");
const M = require("../missions_v3");
const {RULE} = require("../pvp_engine");
const {harness} = require("./support/economy_harness");
function room(mode, time) {
  return {id: "match", mode, status: "finished", host: "alice", guest: "bob", finishedAt: time,
    playKind: "friend", ranked: false, ruleVersion: RULE, resultHash: "server-result",
    winnerUid: "alice", winner: "alice", audit: {a: {uid: "alice", input: {action: "answer"}},
      b: {uid: "bob", input: {action: "squad"}}},
    answers: {alice: {0: {value: 1}}, bob: {0: {value: 2}}}};
}
function trigger(r, before = null) {
  return {params: {mode: r.mode, roomId: r.id}, data: {
    before: {val: () => before}, after: {val: () => r}}};
}
test("all thirteen friend modes count participation once without ranked counters or rewards", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}, bob: {displayName: "Bob"}}},
      {omitEmptyObjects: true});
  for (const [i, mode] of M.onlineModes.entries()) {
    const r = room(mode, h.now);
    const fn = i < 9 ? h.context.exports.syncPvpFriendMissions : h.context.exports.syncDuelFriendMissions;
    await fn(trigger(r)); await fn(trigger(r)); await fn(trigger(r, r));
  }
  for (const uid of ["alice", "bob"]) {
    assert.equal(h.read(`missionState/${uid}/daily/counters/friendPlayed`), 13);
    assert.equal(h.read(`missionState/${uid}/daily/counters/rankedPlayed`), 0);
    assert.equal(h.read(`missionState/${uid}/daily/counters/rankedWins`), 0);
    assert.equal(h.read(`economyState/${uid}/balances/coins`), null);
  }
});
test("friend bridge rejects incomplete, forfeit, ranked, self-play and unknown mode results", () => {
  const r = room("club_club", Date.now());
  for (const patch of [{status: "playing"}, {status: "forfeit"}, {cancelled: true}, {guest: "alice"},
    {playKind: "ranked"}, {ruleVersion: "unknown"}, {resultHash: null}, {assisted: true},
    {winnerUid: "outsider"}, {finishedAt: 0}]) {
    assert.deepEqual(E.friendResult("pvpV1", r.mode, r.id, {...r, ...patch}), []);
  }
  assert.deepEqual(E.friendResult("pvpV1", "unknown", r.id, {...r, mode: "unknown"}), []);
  const duel = room("career_race", Date.now());
  assert.deepEqual(E.friendResult("careerTransferOnline", duel.mode, duel.id, {...duel, ranked: true}), []);
  assert.deepEqual(E.friendResult("pvpV1", r.mode, r.id, {...r, audit: {}}), []);
});
test("late friend result only updates its week and career; idle and guest accounts cannot count", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}, bob: {displayName: "Bob"}}});
  h.setLinked("bob", false);
  const r = room("club_club", h.now - 8 * 86400000);
  await h.context.exports.syncPvpFriendMissions(trigger(r));
  assert.equal(h.read("missionState/alice/general/counters/friendPlayed"), 1);
  assert.equal(h.read("missionState/alice/daily/counters/friendPlayed"), null);
  assert.equal(h.read("missionState/alice/weekly/counters/friendPlayed"), null);
  assert.equal(h.read("missionState/bob"), null);
  assert.equal(E.friendResult("pvpV1", r.mode, r.id, {...r,
    audit: {a: {uid: "alice", input: {action: "poll"}}, b: r.audit.b}}).length, 1);
});
