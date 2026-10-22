"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {runSupplementalSync} = require("../daily_fixture_budget");
const {publishSnapshot, HANDLE} = require("../daily_fixture_import");
const {snapshot, readDay, syncDay} = require("../daily_fixture_feed");
const {createService} = require("../daily_matches");
const {harness} = require("./support/economy_harness");
const morning = Date.parse("2026-10-21T03:15:00Z");
const afternoon = morning + 8 * 3600000;
function response(counter, {empty = false, fail = false} = {}) {
  return async (url) => {
    counter.calls++;
    const date = new URL(url).searchParams.get("date");
    if (fail) throw Error("offline");
    return {ok: true, json: async () => ({errors: [], response: empty ? [] : [{
      fixture: {id: date.endsWith("21") ? 123 : 124, date: date + "T20:00:00+03:00", status: {short: "NS"}},
      league: {id: 203}, teams: {home: {id: 611, name: "Fenerbahce"}, away: {id: 549, name: "Besiktas"}},
      goals: {home: null, away: null},
    }]})};
  };
}
function imported() {
  return {...structuredClone(snapshot), sourceUpdatedAt: "2026-10-21T01:00:00Z",
    import: {dataset: HANDLE, parquetSha256: "a".repeat(64)}};
}
test("concurrent/repeated/manual jobs share a hard three-request limit and clients use cached data", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  h.setTime(morning);
  const counter = {calls: 0};
  const options = {db: h.db, apiKey: "test", now: morning, request: response(counter)};
  await Promise.all(Array.from({length: 10}, () => runSupplementalSync(options)));
  // Complete a slot skipped due to another job holding the global lease.
  await runSupplementalSync(options);
  assert.equal(counter.calls, 2);
  await runSupplementalSync({...options, now: afternoon, mode: "refresh"});
  assert.equal(counter.calls, 3);
  for (let i = 0; i < 10; i++) await runSupplementalSync({...options, now: afternoon + 3600000});
  assert.equal(counter.calls, 3);
  assert.equal(h.read("daily_fixture_control/turkey").used, 3);
  const service = createService({db: h.db, now: () => morning, grantCoins: async () => {}, isLinked: async () => true});
  for (let i = 0; i < 5; i++) await service.status("alice");
  assert.equal(counter.calls, 3);
});
test("empty match day needs two calls; errors consume quota and have only one recovery opportunity", async () => {
  for (const fail of [false, true]) {
    const h = harness(); const counter = {calls: 0};
    const options = {db: h.db, apiKey: "test", now: morning, request: response(counter, {empty: true, fail})};
    await runSupplementalSync(options);
    await runSupplementalSync(options);
    assert.equal(counter.calls, 2);
    await runSupplementalSync({...options, mode: "refresh", now: afternoon});
    assert.equal(counter.calls, fail ? 3 : 2);
    await runSupplementalSync({...options, mode: "refresh", now: afternoon + 3600000});
    assert.equal(counter.calls, fail ? 3 : 2);
  }
});
test("reservation failure makes no HTTP call; keys are optional and budget follows Istanbul", async () => {
  const h = harness(); const counter = {calls: 0};
  const options = {db: h.db, apiKey: "test", now: morning, request: response(counter, {empty: true})};
  await runSupplementalSync({...options, apiKey: undefined});
  assert.equal(counter.calls, 0);
  h.failNext("daily_fixture_control/turkey");
  await assert.rejects(runSupplementalSync(options));
  assert.equal(counter.calls, 0);
  await assert.rejects(runSupplementalSync({...options, date: "2025-10-21"}));
  await runSupplementalSync(options);
  await runSupplementalSync({...options, now: Date.parse("2026-10-21T21:10:00Z")});
  assert.equal(counter.calls, 4);
  assert.equal(h.read("daily_fixture_control/turkey").day, "2026-10-22");
  assert.equal(h.read("daily_fixture_control/turkey").used, 2);
});
test("Kaggle updates without a deployment; Turkey, source age, empty days and existing game IDs survive", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  const date = "2026-10-21";
  const counter = {calls: 0};
  await syncDay({db: h.db, date, apiKey: "test", now: morning, request: response(counter)});
  const raw = h.read("daily_fixtures/" + date);
  const lille = raw.matches.find((m) => m.homeName === "Lille OSC");
  lille.fixtureId = 987;
  h.seed("daily_fixtures/" + date, raw);
  const data = imported();
  const result = await publishSnapshot({db: h.db, data, now: morning});
  assert.equal(result.days, 15);
  const saved = h.read("daily_fixtures/" + date);
  assert.equal(saved.matches.find((m) => m.homeName === "Lille OSC").fixtureId, 987);
  assert.equal(saved.sources.turkey.updatedAt, morning);
  assert.equal(saved.matches.find((m) => m.leagueId === 203).homeScore, undefined); // RTDB omits null.
  assert.equal(h.read("daily_fixtures/2026-10-22").sources.snapshot.count, 0);
  const stale = readDay(saved, date, morning + 31 * 3600000);
  assert.equal(stale.snapshotUpdatedAt, Date.parse(data.sourceUpdatedAt));
  assert.equal(stale.calendar.find((m) => m.leagueId === 203).stale, true);
  await syncDay({db: h.db, date, apiKey: "test", now: afternoon, request: response(counter, {fail: true})});
  assert.equal(h.read("daily_fixtures/" + date).sources.snapshot.provider, "kaggle");
  assert.equal(h.read("daily_fixtures/" + date).sources.snapshot.updatedAt, Date.parse(data.sourceUpdatedAt));
  assert.equal(h.read("daily_fixtures/" + date).sources.turkey.updatedAt, morning);
});
test("corrupt/stale/regressing/partial Kaggle imports cannot erase the last good calendar", async () => {
  const h = harness(); const data = imported();
  await publishSnapshot({db: h.db, data, now: morning});
  const before = h.read("daily_fixtures");
  const duplicate = structuredClone(data); duplicate.matches.push(duplicate.matches[0]);
  await assert.rejects(publishSnapshot({db: h.db, data: duplicate, now: morning}));
  await assert.rejects(publishSnapshot({db: h.db, data, now: morning + 4 * 86400000}));
  const old = {...data, sourceUpdatedAt: snapshot.sourceUpdatedAt};
  await assert.rejects(publishSnapshot({db: h.db, data: old, now: morning}));
  h.seed("daily_fixture_control/kaggle/count", data.matches.length * 2);
  await assert.rejects(publishSnapshot({db: h.db, data, now: morning}));
  assert.deepEqual(h.read("daily_fixtures"), before);
});
test("import interrupted between days can resume, and simultaneous Turkey writes are retained", async () => {
  const h = harness(); const data = imported(); const counter = {calls: 0};
  h.failNext("daily_fixtures/2026-10-22");
  await assert.rejects(publishSnapshot({db: h.db, data, now: morning}));
  assert.equal(h.read("daily_fixture_control/kaggle").lastSuccessAt, undefined);
  assert.ok(h.read("daily_fixtures/2026-10-21"));
  await Promise.all([
    publishSnapshot({db: h.db, data, now: morning + 1000}),
    runSupplementalSync({db: h.db, apiKey: "test", now: morning + 1000, request: response(counter)}),
  ]);
  assert.equal(h.read("daily_fixture_control/kaggle").lastSuccessAt, morning + 1000);
  const saved = h.read("daily_fixtures/2026-10-21");
  assert.equal(saved.sources.snapshot.provider, "kaggle");
  assert.equal(saved.sources.turkey.state, "ok");
  assert.equal(saved.matches.filter((m) => m.leagueId === 203).length, 1);
});
