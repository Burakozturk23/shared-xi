"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const H = require("../mission_health");
const M = require("../missions_v3");
const R = require("../mission_readiness");
const {harness} = require("./support/economy_harness");
const time = Date.parse("2026-10-25T12:00:00Z");
const snapshot = () => ({version: 1, checkedAt: time,
  endpoints: Object.fromEntries(Object.values(H.groups).flat().map((n) => [n, true]))});
test("health probes only fixed callable routes without identity or a game mutation", async () => {
  const seen = [];
  const health = await H.collect({now: () => time, fetchImpl: async (url, options) => {
    seen.push(url); assert.equal(options.body, "{\"data\":{}}");
    assert.deepEqual(options.headers, {"Content-Type": "application/json"});
    assert.equal(options.redirect, "error");
    assert.ok(url.startsWith("https://europe-west1-sharedix.cloudfunctions.net/"));
    return {status: 401, json: async () => ({error: {status: "UNAUTHENTICATED"}})};
  }});
  assert.equal(seen.length, 8); assert.deepEqual(health, snapshot());
});
test("404, gateway error, malformed JSON and network errors never certify a service", async () => {
  for (const fetchImpl of [async () => ({status: 404, json: async () => ({})}),
    async () => ({status: 503, json: async () => ({error: {status: "UNAUTHENTICATED"}})}),
    async () => ({status: 401, json: async () => {
      throw Error("HTML");
    }}),
    async () => {
      throw Error("network");
    }]) {
    const health = await H.collect({fetchImpl, now: () => time});
    assert.ok(Object.values(health.endpoints).every((v) => v === false));
    assert.deepEqual(H.availability(health, {pvp: {rankedEnabled: true, friendEnabled: true}}, time),
        {online: false, friends: false});
  }
});
test("missing, future and stale observations fail closed and preserve mode rollout gates", () => {
  for (const health of [null, {...snapshot(), checkedAt: time + 1},
    {...snapshot(), checkedAt: time - H.MAX_AGE_MS - 1}]) {
    assert.deepEqual(H.availability(health, {}, time), {online: false, friends: false});
  }
  const health = snapshot(); health.endpoints.enterCareerTransferOnline = false;
  assert.deepEqual(H.availability(health, {}, time), {online: false, friends: false});
  assert.deepEqual(H.availability(health, {pvp: {friendEnabled: true}}, time), {online: false, friends: true});
  assert.deepEqual(H.availability(health, {pvp: {rankedEnabled: true}}, time), {online: true, friends: false});
  const modes = Object.fromEntries(M.onlineModes.slice(0, 9).map((m) => [m, {rankedEnabled: false}]));
  assert.equal(H.availability(health, {pvp: {rankedEnabled: true, modes}}, time).online, false);
});
test("service outage replaces an unfinished ranked slot with solo without changing other slots", async () => {
  const h = harness();
  const ready = {coach11: true, vault: true, letter11: true, career: true, transfer: true, online: true};
  const state = M.decorate({daily: {dateKey: "2026-10-25", counters: {}, claims: {}, processed: {}},
    generalClaims: {}, updatedAt: time}, {}, time);
  const policy = {enabled: true};
  M.assign(state, "alice", ready, policy, time);
  const old = structuredClone(state.daily.assigned);
  const online = old.find((d) => !d.solo); assert.ok(online);
  const health = await R.resolve(h.db, "alice", ready, {}, time, false);
  M.assign(state, "alice", health.readyModes, policy, time);
  const replacement = state.daily.assigned.find((d) => d.id === online.id);
  assert.equal(replacement.solo, true); assert.equal(replacement.replaced[0].definitionId, online.definitionId);
  for (const d of old.filter((d) => d.solo)) assert.deepEqual(state.daily.assigned.find((x) => x.id === d.id), d);
});
test("disabled mission rollout does not run the scheduled network probes", async () => {
  const h = harness({runtimeConfig: {missionsV3: {enabled: false, readyModes: {online: true}}}});
  await h.context.exports.refreshMissionServiceHealth();
  assert.equal(h.read("runtimeConfig/missionsV3/serviceHealth"), null);
});
