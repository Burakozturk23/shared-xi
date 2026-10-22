"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {syncDay, readDay, snapshot, snapshotDay} = require("../daily_fixture_feed");
const {runSupplementalSync} = require("../daily_fixture_budget");
const {publishSnapshot, HANDLE} = require("../daily_fixture_import");
const {createService} = require("../daily_matches");
const date = "2026-10-22";
const now = Date.parse(date + "T03:15:00Z");
// Synthetic provider records, not a claim about the real fixtures on this date.
function fixture(id, league, day = date) {
  return {fixture: {id, date: day + "T20:00:00+03:00", status: {short: "NS"}}, league: {id: league},
    teams: {home: {id: 611, name: "Fenerbahce"}, away: {id: 549, name: "Besiktas"}},
    goals: {home: null, away: 0}};
}
const payload = [fixture(100, 203), fixture(101, 3), fixture(102, 848), fixture(103, 39)];
const response = (data = payload) => async () => ({ok: true, json: async () => ({response: data, errors: []})});
test("Kaggle-empty day exposes both European cups through the application status without extra API calls", async () => {
  const h = harness({}, {omitEmptyObjects: true}); h.setTime(now);
  assert.deepEqual(snapshotDay(date), []);
  await syncDay({db: h.db, date, apiKey: "test", now, request: response()});
  const service = createService({db: h.db, now: () => now, grantCoins: async () => {}, isLinked: async () => true});
  const status = await service.status("alice");
  assert.deepEqual(status.calendar.map((m) => m.leagueId).sort((a, b) => a - b), [3, 203, 848]);
  assert.ok(status.matches.some((m) => m.leagueId === 3));
  assert.ok(status.matches.some((m) => m.leagueId === 848));
  assert.ok(status.feed.competitions.includes("Avrupa Ligi"));
  assert.equal(status.feed.sources.supplemental.count, 3);
  assert.equal(status.feed.sources.turkey.count, 1);
});
test("Kaggle import and failed/older API responses preserve European fixtures and their true source age", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  await syncDay({db: h.db, date, apiKey: "test", now, request: response()});
  await publishSnapshot({db: h.db, now, data: {...structuredClone(snapshot),
    sourceUpdatedAt: "2026-10-21T21:04:22Z", import: {dataset: HANDLE, parquetSha256: "b".repeat(64)}}});
  const old = h.read("daily_fixtures/" + date);
  assert.equal(old.matches.length, 3);
  assert.equal(old.sources.supplemental.updatedAt, now);
  assert.equal(old.matches.find((m) => m.leagueId === 848).awayScore, 0);
  await syncDay({db: h.db, date, apiKey: "test", now: now + 3600000,
    request: async () => ({ok: true, json: async () => ({response: [], errors: {requests: "quota"}})})});
  const saved = h.read("daily_fixtures/" + date);
  assert.equal(saved.sources.supplemental.state, "error");
  assert.equal(saved.sources.supplemental.updatedAt, now);
  assert.equal(saved.matches.length, 3);
  await syncDay({db: h.db, date, apiKey: "test", now: now + 1000, request: response([])});
  assert.equal(h.read("daily_fixtures/" + date).matches.length, 3);
  const stale = readDay(saved, date, now + 31 * 3600000);
  assert.equal(stale.calendar.length, 3);
  assert.ok(stale.calendar.every((m) => m.stale));
  await syncDay({db: h.db, date, apiKey: "test", now: now + 7200000, request: response([])});
  assert.equal(readDay(h.read("daily_fixtures/" + date), date, now + 7200000).calendar.length, 0);
});
test("European-only match day triggers the optional refresh and all three leagues share three calls", async () => {
  const h = harness(); let calls = 0;
  const request = async (url) => {
    calls++;
    const day = new URL(url).searchParams.get("date");
    return response([fixture(101, 3, day), fixture(102, 848, day)])();
  };
  await runSupplementalSync({db: h.db, apiKey: "k", request, now});
  assert.equal(calls, 2);
  await runSupplementalSync({db: h.db, apiKey: "k", request, now: now + 8 * 3600000, mode: "refresh"});
  assert.equal(calls, 3);
  await runSupplementalSync({db: h.db, apiKey: "k", request, now: now + 9 * 3600000});
  assert.equal(calls, 3);
});
test("upgrade keeps Turkey quota and distinguishes Turkey-only data from full coverage", async () => {
  const h = harness(); let calls = 0;
  h.seed("daily_fixture_control/turkey", {day: date, used: 2, slots: {
    ["baseline_" + date]: {state: "ok", attempts: 1, at: now},
  }});
  h.seed("daily_fixtures/" + date, {updatedAt: now, matches: [],
    sources: {turkey: {state: "ok", updatedAt: now, count: 0}}});
  const request = async () => {
    calls++; return response(payload)();
  };
  await runSupplementalSync({db: h.db, apiKey: "k", request, now: now + 3600000, mode: "refresh"});
  assert.equal(calls, 1);
  assert.equal(h.read("daily_fixture_control/turkey").used, 3);
  assert.equal(h.read("daily_fixtures/" + date).sources.supplemental.count, 3);
  await runSupplementalSync({db: h.db, apiKey: "k", request, now: now + 7200000});
  assert.equal(calls, 1);
});
