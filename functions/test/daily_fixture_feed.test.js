"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {snapshotDay, fetchTurkey, syncDay, readDay, snapshot} = require("../daily_fixture_feed");
const {resolveFixture, createService} = require("../daily_matches");
const {harness} = require("./support/economy_harness");
const date = "2026-10-21";
const now = Date.parse(date + "T12:00:00Z");
const apiRow = {fixture: {id: 123, date: date + "T20:00:00+03:00", status: {short: "NS"}},
  league: {id: 203}, teams: {home: {id: 611, name: "Fenerbahce"}, away: {id: 549, name: "Besiktas"}},
  goals: {home: null, away: null}};
const reply = (response, errors = []) => async () => ({ok: true, json: async () => ({response, errors})});
test("import has unique namespaced IDs, correct days, and provider-specific club identities", () => {
  assert.equal(snapshot.matches.length, 13846);
  assert.equal(new Set(snapshot.matches.map((r) => r[0])).size, 13846);
  const matches = snapshotDay(date);
  assert.equal(matches.length, 10);
  assert.ok(matches.every((m) => m.fixtureId > 4000000000 && m.source === "football-data-snapshot"));
  assert.equal(matches.some((m) => m.leagueId === 203), false);
  const lille = matches.find((m) => m.homeName === "Lille OSC");
  assert.equal(resolveFixture(lille).homeClubId, 1082);
  assert.equal(resolveFixture(lille).awayClubId, 141);
  assert.equal(resolveFixture({...lille, homeSourceId: 99999}), null);
  assert.deepEqual(snapshotDay("2026-10-22"), []);
  assert.throws(() => snapshotDay("2026-02-31"));
});
test("API-Football is restricted to Super Lig, Istanbul day and season starting year", async () => {
  let url;
  const request = async (input, options) => {
    url = new URL(input); assert.equal(options.headers["x-apisports-key"], "test-key");
    assert.ok(options.signal); return {ok: true, json: async () => ({response: [apiRow], errors: []})};
  };
  const matches = await fetchTurkey(date, "test-key", request);
  assert.equal(url.searchParams.get("league"), "203");
  assert.equal(url.searchParams.get("season"), "2026");
  assert.equal(url.searchParams.get("timezone"), "Europe/Istanbul");
  assert.equal(matches[0].fixtureId, 123);
  await fetchTurkey("2027-01-03", "test-key", async (input) => {
    assert.equal(new URL(input).searchParams.get("season"), "2026");
    return {ok: true, json: async () => ({response: [], errors: []})};
  });
  await assert.rejects(fetchTurkey(date, "k", reply([{...apiRow, league: {id: 39}}])));
  await assert.rejects(fetchTurkey(date, "k", reply([], {requests: "quota"})));
  await assert.rejects(fetchTurkey(date, "k", reply([{...apiRow,
    fixture: {...apiRow.fixture, date: "2026-10-22T20:00:00+03:00"}}])));
});
test("Turkey failure preserves Turkey and snapshot timestamps while importing other competitions", async () => {
  const h = harness();
  await syncDay({db: h.db, date, apiKey: "k", request: reply([apiRow]), now});
  const later = now + 3600000;
  const result = await syncDay({db: h.db, date, apiKey: "k", now: later,
    request: async () => {
      throw Error("offline");
    }});
  assert.equal(result.matches.length, 11);
  assert.equal(result.sources.turkey.state, "error");
  assert.equal(result.sources.turkey.updatedAt, now);
  assert.equal(result.sources.snapshot.updatedAt, Date.parse(snapshot.sourceUpdatedAt));
  const stale = readDay(result, date, now + 31 * 3600000);
  assert.equal(stale.calendar.find((m) => m.leagueId === 203).stale, true);
  assert.equal(resolveFixture(stale.calendar.find((m) => m.leagueId === 203)), null);
  assert.ok(stale.calendar.some((m) => m.source === "football-data-snapshot"));
  const empty = await syncDay({db: h.db, date, apiKey: "k", request: reply([]), now: later});
  assert.equal(empty.matches.some((m) => m.leagueId === 203), false);
});
test("import can run without a Turkey key, retains legacy fixture IDs and separates calendar from games", async () => {
  const h = harness(); h.setTime(now);
  await h.db.ref("daily_fixtures/" + date).set({updatedAt: now, matches: [{fixtureId: 987,
    homeName: "Lille", awayName: "Galatasaray", leagueId: 2, kickoff: date + "T16:45:00Z", status: "NS"}]});
  const result = await syncDay({db: h.db, date, now});
  assert.equal(result.sources.turkey.state, "unconfigured");
  assert.equal(result.matches.find((m) => m.homeName === "Lille OSC").fixtureId, 987);
  const service = createService({db: h.db, now: () => now, grantCoins: async () => {}, isLinked: async () => true});
  const status = await service.status("alice");
  assert.equal(status.calendar.length, 10);
  assert.equal(status.matches.length, 1);
  assert.equal(status.calendar.filter((m) => m.playable).length, 1);
  assert.equal(status.matches[0].fixtureId, 987);
  assert.equal(status.matches[0].catalogKey, undefined);
  assert.equal(status.feed.snapshotUsed, true);
  await assert.rejects(service.start("alice", status.calendar.find((m) => !m.playable).fixtureId));
});
test("missing scheduler data can use bundled calendar with honest source age and coverage", () => {
  const feed = readDay(null, date, now);
  assert.equal(feed.calendar.length, 10);
  assert.equal(feed.sources.turkey.state, "pending");
  assert.equal(feed.updatedAt, null);
  assert.equal(feed.snapshotUpdatedAt, Date.parse("2026-10-20T21:02:45Z"));
  assert.equal(readDay(null, "2028-01-01", now).sources.snapshot.state, "out-of-range");
});
