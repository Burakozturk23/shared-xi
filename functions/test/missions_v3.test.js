"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const M = require("../missions_v3");
const E = require("../mission_events");
const {harness} = require("./support/economy_harness");
const {points, seasonAt} = require("../season_pass");
const now = Date.parse("2026-10-24T12:00:00Z");
const ready = Object.fromEntries(M.soloModes.map(([m]) => [m, true]));
const policy = {enabled: true, weeklyEnabled: true, public: true, readyModes: ready};
function state(time = now) {
  return M.decorate({daily: {dateKey: new Date(time + 10800000).toISOString().slice(0, 10),
    counters: {}, claims: {}, processed: {}}, generalClaims: {}, updatedAt: time}, {}, time);
}
const event = (id, modeId = "matching", time = now) => ({uid: "alice", eventId: id, modeId,
  serverValidated: true, verificationVersion: 1, source: "solo_verified", result: "completed",
  serverFinishedAtMs: time});
test("five stable choices, at least three solo, refresh and next-day diversity", () => {
  for (let i = 0; i < 50; i++) {
    const s = state(); M.assign(s, "u" + i, {...ready, online: true}, policy, now);
    assert.equal(s.daily.assigned.length, 5); assert.ok(s.daily.assigned.filter((d) => d.solo).length >= 3);
    const old = structuredClone(s.daily.assigned);
    M.assign(s, "u" + i, {...ready, online: true}, policy, now + 5000);
    assert.deepEqual(s.daily.assigned, old);
    const next = state(now + 86400000); next.previousDailyIds = old.map((d) => d.definitionId);
    M.assign(next, "u" + i, ready, policy, now + 86400000);
    assert.notDeepEqual(next.daily.assigned.map((d) => d.definitionId).sort(), next.previousDailyIds.sort());
  }
});
test("readiness and migration preserve legacy rights", () => {
  const s = state(); M.assign(s, "a", ready, {}, now); assert.equal(s.daily.assigned.length, 0);
  M.assign(s, "a", {matching: true}, policy, now); assert.equal(s.daily.assigned.length, 0);
  s.daily.counters.rankedPlayed = 1;
  M.assign(s, "a", ready, policy, now); assert.equal(s.schemaVersion, 2);
});
test("unavailable replacement retains slot identity and progress history", () => {
  const s = state(); M.assign(s, "a", ready, policy, now);
  const d = s.daily.assigned.find((d) => d.modeId);
  M.assign(s, "a", {...ready, [d.modeId]: false}, policy, now);
  const replacement = s.daily.assigned.find((x) => x.id === d.id);
  assert.notEqual(replacement.definitionId, d.definitionId); assert.equal(replacement.replaced.length, 1);
});
test("verified event dedupe, late-period isolation, friend and ranked separation", () => {
  const s = state(); assert.equal(M.record(s, event("one"), now), true);
  assert.equal(M.record(s, event("one"), now), false);
  M.record(s, event("old", "pyramid", now - 8 * 86400000), now);
  assert.equal(s.general.counters.soloCompleted, 2); assert.equal(s.weekly.counters.soloCompleted, 1);
  for (const patch of [{serverValidated: false}, {verificationVersion: 0}, {forfeit: true},
    {participated: false}, {serverFinishedAtMs: now + 1}]) {
    assert.equal(M.record(s, {...event("bad"), ...patch}, now), false);
  }
  const friend = {...event("friend", "club_club"), source: "friend_settlement", result: "win"};
  M.record(s, friend, now); assert.equal(s.daily.counters.friendPlayed, 1);
  assert.equal(s.daily.counters.rankedWins, undefined);
  assert.equal(M.record(s, {...friend, eventId: "assisted", assisted: true}, now), false);
});
test("three daily and two weekly claims, replay and disabled rewards", () => {
  const s = state(); M.assign(s, "a", ready, policy, now);
  for (const [m] of M.soloModes) for (let n = 0; n < 10; n++) M.record(s, event(m + n, m), now);
  for (const d of s.daily.assigned.slice(0, 3)) {
    assert.equal(M.claim(s, d.id, policy, now, "one").claim.rewardCoins, 20);
    assert.equal(M.claim(s, d.id, policy, now, "two").claim.nonce, "one");
  }
  assert.throws(() => M.claim(s, s.daily.assigned[3].id, policy, now, "four"));
  for (const w of M.weeklyCatalog.slice(0, 2)) M.claim(s, w.id, policy, now, "week");
  assert.throws(() => M.claim(s, M.weeklyCatalog[2].id, policy, now, "week"));
  assert.equal(M.items(s, {}).weekly.every((d) => !d.enabled), true);
});
test("Monday Istanbul boundary, weekly/new career receipts award zero SP", () => {
  assert.equal(M.weekKey(Date.parse("2026-10-25T20:59:59Z")), "2026-10-19");
  assert.equal(M.weekKey(Date.parse("2026-10-25T21:00:00Z")), "2026-10-26");
  const claims = Object.fromEntries(["weekly__2026-10-19__weekly_explorer", "general__solo_knowledge_10", "unknown"]
      .map((sourceId) => [sourceId, {sourceId, sourceType: "mission_reward", amount: 25, claimedAt: now}]));
  assert.equal(points(claims, seasonAt(now), now).sp, 0);
  claims.daily = {sourceId: "2026-10-24__daily_v3_slot_1", sourceType: "mission_reward", amount: 20, claimedAt: now};
  assert.equal(points(claims, seasonAt(now), now).sp, 30);
});
test("mode adapters reject partial or repeated terminal events", () => {
  assert.equal(E.fromRun("a", "arcade", "r", {mode: "matching", finished: true}), null);
  assert.equal(E.fromRun("a", "choice", "r", {mode: "higher_lower", finished: true,
    recorded: true, phase: "active", streak: 4}), null);
  const run = {mode: "matching", finished: true, recorded: true, phase: "active", won: true, finishedAt: now};
  assert.equal(E.changedRuns("a", "arcade", {}, {sessions: {r: run}}).length, 1);
  assert.equal(E.changedRuns("a", "arcade", {sessions: {r: run}}, {sessions: {r: run}}).length, 0);
  assert.equal(E.changedRuns("a", "balances", {}, {sessions: {r: run}}).length, 0);
});
test("callable concurrency and RTDB empty-map persistence mint once", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}}, runtimeConfig: {missionsV3: policy}},
      {omitEmptyObjects: true});
  const first = await h.call("getMyMissions"); assert.equal(first.profile.daily.length, 5);
  for (const [m] of M.soloModes) await h.context.lbMissionRecordEvents(h.db, "alice", [event(m, m, h.now)]);
  const profile = (await h.call("getMyMissions")).profile;
  const item = profile.daily.find((d) => d.claimable); assert.ok(item);
  const results = await Promise.all([h.call("claimMissionReward", {missionId: item.id, periodKey: item.periodKey}),
    h.call("claimMissionReward", {missionId: item.id, periodKey: item.periodKey})]);
  assert.equal(results.filter((r) => r.granted).length, 1);
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
});
test("forfeit and nonparticipation cannot advance counters", async () => {
  const h = harness();
  for (const extra of [{forfeit: true}, {participants: {alice: false}}, {rankedEligible: false}]) {
    await h.context.exports.syncRankedMissions({params: {mode: "club_club", matchId: "bad"},
      data: {before: {exists: () => false}, after: {exists: () => true, val: () => ({serverValidated: true,
        player1Uid: "alice", player1Result: "win", settledAt: h.now, ...extra})}}});
  }
  assert.equal(h.read("missionState/alice"), null);
});

test("stale daily and weekly card cannot claim the next period's slot", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}}, runtimeConfig: {missionsV3: policy}},
      {omitEmptyObjects: true});
  await h.call("getMyMissions");
  for (const [m] of M.soloModes) await h.context.lbMissionRecordEvents(h.db, "alice", [event(m, m, h.now)]);
  const profile = (await h.call("getMyMissions")).profile;
  const item = profile.daily.find((d) => d.claimable);
  for (const periodKey of [undefined, "2020-01-01", "weekly__2020-01-01"]) {
    await assert.rejects(h.call("claimMissionReward", {missionId: item.id, periodKey}),
        {code: "failed-precondition"});
  }
  assert.equal(h.read("economyState/alice/balances/coins") || 0, 0);
  await h.call("claimMissionReward", {missionId: item.id, periodKey: item.periodKey});
  assert.equal(h.read("economyState/alice/balances/coins"), 20);
});
