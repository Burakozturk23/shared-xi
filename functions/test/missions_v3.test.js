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
test("three slots (knowledge, rivalry, discovery), stable on refresh and different the next day", () => {
  for (let i = 0; i < 50; i++) {
    const s = state(); M.assign(s, "u" + i, {...ready, online: true}, policy, now);
    assert.deepEqual(s.daily.assigned.map((d) => d.slot), ["knowledge", "rivalry", "discovery"]);
    assert.equal(s.daily.assigned[1].solo, false);
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
  // The replacement keeps the slot, so the day keeps its bonus.
  assert.equal(replacement.slot, d.slot); assert.ok(M.items(s, policy).daily.some((x) => x.bonus));
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
test("all three daily and weekly missions pay, then their bonus; replay and disabled rewards", () => {
  const s = state(); M.assign(s, "a", ready, policy, now);
  for (const [m] of M.soloModes) for (let n = 0; n < 10; n++) M.record(s, event(m + n, m), now);
  // Without online, the rivalry slot is a solo stand-in paying like discovery.
  const coins = {knowledge: 15, rivalry: 25, discovery: 25};
  assert.throws(() => M.claim(s, "daily_bonus", policy, now, "early"));
  for (const d of s.daily.assigned) {
    assert.equal(M.claim(s, d.id, policy, now, "one").claim.rewardCoins, coins[d.slot]);
    assert.equal(M.claim(s, d.id, policy, now, "two").claim.nonce, "one");
  }
  const bonus = M.claim(s, "daily_bonus", policy, now, "bonus");
  assert.equal(bonus.claim.rewardCoins, 40); assert.equal(bonus.claim.rewardXp, 40);
  assert.equal(bonus.sourceId, s.daily.dateKey + "__daily_bonus");
  assert.throws(() => M.claim(s, "weekly_bonus", policy, now, "early"));
  for (const w of M.weeklyCatalog) assert.equal(M.claim(s, w.id, policy, now, "week").claim.rewardCoins, 40);
  assert.equal(M.claim(s, "weekly_bonus", policy, now, "week").claim.rewardCoins, 100);
  assert.equal(M.items(s, {}).weekly.every((d) => !d.enabled), true);
  // The bonus earns no extra SP beyond the daily cap.
  assert.equal(M.items(s, policy).daily.find((d) => d.bonus).rewardSp, 0);
});
test("Monday Istanbul boundary; weekly receipts award zero SP, career stages 50", () => {
  assert.equal(M.weekKey(Date.parse("2026-10-25T20:59:59Z")), "2026-10-19");
  assert.equal(M.weekKey(Date.parse("2026-10-25T21:00:00Z")), "2026-10-26");
  const claims = Object.fromEntries(["weekly__2026-10-19__weekly_explorer", "unknown"]
      .map((sourceId) => [sourceId, {sourceId, sourceType: "mission_reward", amount: 25, claimedAt: now}]));
  assert.equal(points(claims, seasonAt(now), now).sp, 0);
  claims.daily = {sourceId: "2026-10-24__daily_v3_slot_1", sourceType: "mission_reward", amount: 20, claimedAt: now};
  assert.equal(points(claims, seasonAt(now), now).sp, 30);
  claims.career = {sourceId: "general__solo_knowledge_10", sourceType: "mission_reward", amount: 30, claimedAt: now};
  assert.equal(points(claims, seasonAt(now), now).sp, 80);
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
  // Three missions and the bonus card.
  const first = await h.call("getMyMissions"); assert.equal(first.profile.daily.length, 4);
  for (const [m] of M.soloModes) await h.context.lbMissionRecordEvents(h.db, "alice", [event(m, m, h.now)]);
  const profile = (await h.call("getMyMissions")).profile;
  const item = profile.daily.find((d) => d.claimable && d.slot === "knowledge"); assert.ok(item);
  const results = await Promise.all([h.call("claimMissionReward", {missionId: item.id, periodKey: item.periodKey}),
    h.call("claimMissionReward", {missionId: item.id, periodKey: item.periodKey})]);
  assert.equal(results.filter((r) => r.granted).length, 1);
  assert.equal(h.read("economyState/alice/balances/coins"), 15);
  // The knowledge mission also grants 15 XP, once, even with two concurrent claims.
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 15);
});
test("online mode missions in the rivalry slot pay most; older five-mission days keep their limit", () => {
  const s = state(); M.assign(s, "u1", {...ready, online: true}, policy, now);
  assert.equal(M.catalog.filter((d) => d.family === "online").length, M.onlineModes.length);
  const online = M.catalog.find((d) => d.id === "online_career_race");
  s.daily.assigned[1] = {...online, slot: "rivalry", definitionId: online.id, id: "daily_v3_slot_2", baseline: 0};
  M.record(s, {uid: "alice", eventId: "m1", modeId: "career_race", source: "friend_settlement", result: "loss",
    serverValidated: true, verificationVersion: 1, serverFinishedAtMs: now}, now);
  let p = M.items(s, policy);
  const card = p.daily.find((d) => d.definitionId === "online_career_race");
  assert.equal(card.claimable, true); assert.equal(card.rewardCoins, 35); assert.equal(card.rewardXp, 35);
  assert.equal(p.daily.find((d) => d.slot === "knowledge").rewardCoins, 15);
  // A day assigned before the slots (five missions) keeps three rewards and the old amounts.
  s.daily.assigned = [...M.catalog.filter((d) => d.solo).slice(0, 5)].map((d, i) => ({...d,
    definitionId: d.id, id: "daily_v3_slot_" + (i + 1), baseline: 0}));
  s.daily.claims = {daily_v3_slot_1: {}, daily_v3_slot_2: {}, daily_v3_slot_3: {}};
  p = M.items(s, policy);
  assert.equal(p.daily.some((d) => d.bonus), false);
  assert.ok(p.daily.filter((d) => !s.daily.claims[d.id]).every((d) => d.limitReached && d.rewardSp === 0));
  assert.equal(p.daily[3].rewardCoins, 20);
  // Career stages have default rewards (still behind careerEnabled) and 50 SP.
  p = M.items(s, {...policy, careerEnabled: true});
  const stage = p.general.find((d) => d.chainId === "solo_knowledge");
  assert.equal(stage.rewardCoins, 30); assert.equal(stage.rewardXp, 30); assert.equal(stage.rewardSp, 50);
  assert.equal(stage.enabled, true);
  assert.equal(M.items(s, {...policy, rewards: {daily: {solo: {coins: 12}}}}).daily[3].rewardCoins, 12);
});
test("career family chains count verified games of their family", () => {
  const s = state();
  for (const [m] of M.soloModes.filter(([, , f]) => f === "puzzle").slice(0, 5)) M.record(s, event("p" + m, m), now);
  const p = M.items(s, {...policy, careerEnabled: true});
  const puzzle = p.general.find((d) => d.chainId === "puzzle_hunter");
  assert.equal(puzzle.progress, 5); assert.equal(puzzle.claimable, true); assert.equal(puzzle.rewardCoins, 30);
  assert.equal(p.general.find((d) => d.chainId === "word_master").progress, 0);
  assert.deepEqual(p.general.map((d) => d.chainId),
      ["solo_knowledge", "mode_collector", "puzzle_hunter", "squad_master", "word_master", "arena"]);
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
  assert.equal(h.read("economyState/alice/balances/coins"), item.rewardCoins);
});

test("career guess followed by skip cannot masquerade as a completed ordering puzzle", async () => {
  const h = harness({users: {alice: {displayName: "Alice"}}});
  const catalog = require("../career_transfer").catalog;
  let sequence = 1000; const requestId = () => (++sequence).toString(16).padStart(32, "0");
  for (const finish of [false, true]) {
    let run = (await h.call("startCareerTransfer", {mode: "career", version: catalog.version,
      requestId: requestId()})).session;
    const privateRun = h.read(`economyState/alice/careerTransfer/sessions/${run.id}`);
    const puzzle = catalog.careers.find((p) => p.id === privateRun.puzzle);
    const act = (action, extra = {}) => h.call("actCareerTransfer", {mode: "career", version: catalog.version,
      sessionId: run.id, revision: run.revision, requestId: requestId(), action, ...extra});
    run = (await act("guess", {playerId: puzzle.playerId})).session;
    const before = h.read("economyState/alice/careerTransfer");
    const order = require("../career_transfer").cardsOf(puzzle).map((c) => c.id);
    run = (await act(finish ? "order" : "skip", finish ? {order} : {})).session;
    assert.equal(run.finished, true);
    const after = h.read("economyState/alice/careerTransfer");
    await h.context.exports.syncSoloMissions({params: {uid: "alice", family: "careerTransfer"},
      data: {before: {val: () => before}, after: {val: () => after}}});
    assert.equal(h.read("missionState/alice/daily/counters/mode__career"), finish ? 1 : null);
  }
});
// RTDB never stores an empty object: a week with no claim yet is read back without
// `weekly.claims`, and the first weekly reward of the week threw "Cannot set properties
// of undefined" (the app said "Ödül alınamadı"). Same for a day read back without claims.
test("the first weekly reward of a week is paid after an RTDB round trip drops the empty claims", () => {
  const s = state(); M.assign(s, "a", ready, policy, now);
  for (const [m] of M.soloModes) for (let n = 0; n < 10; n++) M.record(s, event(m + n, m), now);
  // What RTDB returns: empty objects gone.
  const stored = JSON.parse(JSON.stringify(s, (k, v) => v && typeof v === "object" && !Array.isArray(v) &&
    !Object.keys(v).length ? undefined : v));
  assert.equal(stored.weekly.claims, undefined);
  const back = M.decorate({daily: {...stored.daily, claims: {}}, generalClaims: {}, updatedAt: now}, stored, now);
  const w = M.weeklyCatalog[0];
  const paid = M.claim(back, w.id, policy, now, "first");
  assert.equal(paid.claim.rewardCoins, 40); assert.ok(back.weekly.claims[w.id]);
});
// A ranked fallback bot match counts as an online game of its mode, never as a ranked
// game or a ranked win.
test("a bot match counts for the mode's online missions, never as ranked", () => {
  const s = state();
  assert.equal(M.record(s, {uid: "alice", eventId: "bot1", modeId: "random_five", source: "bot_settlement",
    result: "win", serverValidated: true, verificationVersion: 1, serverFinishedAtMs: now}, now), true);
  assert.equal(s.daily.counters["online__random_five"], 1);
  assert.equal(s.daily.counters.rankedPlayed, undefined); assert.equal(s.daily.counters.rankedWins, undefined);
});
