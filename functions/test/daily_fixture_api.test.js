"use strict";
// Günün maçları: tek kaynak API-Football, tek anahtar, ortak günlük bütçe.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const F = require("../daily_fixture_api");

// Minimal RTDB: get / set / transaction on slash paths.
function fakeDb(seed = {}) {
  const data = structuredClone(seed);
  const at = (path) => path.split("/").reduce((o, k) => o?.[k], data);
  const put = (path, value) => {
    const keys = path.split("/"); let o = data;
    for (const k of keys.slice(0, -1)) o = o[k] ||= {};
    if (value === undefined || value === null) delete o[keys.at(-1)]; else o[keys.at(-1)] = value;
  };
  return {data, ref: (path) => ({
    get: async () => ({val: () => structuredClone(at(path) ?? null), exists: () => at(path) != null}),
    set: async (v) => put(path, structuredClone(v)),
    transaction: async (fn) => {
      const next = fn(structuredClone(at(path) ?? null));
      if (next === undefined) return {committed: false, snapshot: {val: () => structuredClone(at(path) ?? null)}};
      put(path, structuredClone(next));
      return {committed: true, snapshot: {val: () => structuredClone(at(path) ?? null)}};
    },
  })};
}
const fixture = (id, league, date, status = "NS", home = [40, "Liverpool"], away = [33, "Manchester United"]) => ({
  fixture: {id, date: date + "T19:00:00+03:00", status: {short: status}},
  league: {id: league},
  teams: {home: {id: home[0], name: home[1]}, away: {id: away[0], name: away[1]}},
  goals: {home: status === "FT" ? 2 : null, away: status === "FT" ? 1 : null},
});
function api(byDate) {
  const calls = [];
  const request = async (url, init) => {
    calls.push({url, key: init.headers["x-apisports-key"]});
    const date = new URL(url).searchParams.get("date");
    const response = byDate[date] || [];
    return {ok: true, json: async () => ({results: response.length, paging: {current: 1, total: 1}, errors: [],
      response})};
  };
  return {request, calls};
}
const NOW = Date.parse("2026-11-08T03:00:00Z"); // 06:00 İstanbul
const TODAY = "2026-11-08";

test("only the agreed leagues are kept (no Brazil, no Scotland)", async () => {
  const {request} = api({[TODAY]: [fixture(1, 39, TODAY), fixture(2, 71, TODAY), fixture(3, 179, TODAY),
    fixture(4, 203, TODAY, "NS", [611, "Fenerbahce"], [645, "Galatasaray"])]});
  const matches = await F.fetchDay(TODAY, "k", request);
  assert.deepEqual(matches.map((m) => m.leagueId).sort((a, b) => a - b), [39, 203]);
  assert.equal(F.LEAGUES[71], undefined);
  assert.equal(F.LEAGUES[179], undefined);
});

test("day run fetches only today, one request with one key", async () => {
  const db = fakeDb();
  const {request, calls} = api({[TODAY]: [fixture(1, 39, TODAY)]});
  const r = await F.runSync({db, apiKey: "k", mode: "day", now: NOW, request});
  assert.equal(r.state, "ok");
  assert.equal(calls.length, 1);
  assert.equal(new URL(calls[0].url).searchParams.get("date"), TODAY);
  assert.equal(calls[0].key, "k");
  assert.equal(db.data.daily_fixture_control.api.used, 1);
  const day = db.data.daily_fixtures[TODAY];
  assert.equal(day.matches.length, 1);
  assert.equal(day.topMatch.fixtureId, 1);
  assert.equal(day.sources.api.state, "ok");
  assert.equal(day.sources.supplemental.state, "ok"); // installed apps read this field
  assert.equal(db.data.daily_fixtures["2026-11-09"], undefined);
});

test("day run refreshes even when today's stored matches are all final", async () => {
  const db = fakeDb({daily_fixtures: {[TODAY]: {sources: {api: {state: "ok"}},
    matches: [{fixtureId: 1, status: "FT", kickoff: TODAY + "T16:00:00Z", leagueId: 39}]}}});
  const {calls, request} = api({});
  await F.runSync({db, apiKey: "k", mode: "day", now: NOW, request});
  assert.equal(calls.length, 1);
});

test("the shared daily budget stops every caller at the limit", async () => {
  const db = fakeDb({daily_fixture_control: {api: {day: TODAY, used: F.DAILY_LIMIT}}});
  const {request, calls} = api({});
  const r = await F.runSync({db, apiKey: "k", mode: "day", now: NOW, request});
  assert.equal(calls.length, 0);
  assert.equal(r.state, "budget");
  assert.equal(db.data.daily_fixture_control.api.used, F.DAILY_LIMIT);
});

test("a new day resets the budget", async () => {
  const db = fakeDb({daily_fixture_control: {api: {day: "2026-11-07", used: F.DAILY_LIMIT}}});
  const {calls, request} = api({});
  await F.runSync({db, apiKey: "k", mode: "live", now: NOW, request});
  assert.equal(calls.length, 1);
  assert.equal(db.data.daily_fixture_control.api.day, TODAY);
});

test("live run skips the request when every match of today is finished", async () => {
  const db = fakeDb({daily_fixtures: {[TODAY]: {updatedAt: NOW, sources: {api: {state: "ok"}},
    matches: [{fixtureId: 1, status: "FT", kickoff: TODAY + "T16:00:00Z", leagueId: 39}]}}});
  const {calls, request} = api({});
  const r = await F.runSync({db, apiKey: "k", mode: "live", now: NOW, request});
  assert.equal(calls.length, 0);
  assert.equal(r.state, "ok");
});

test("a failed request keeps the last good matches and marks the source", async () => {
  const db = fakeDb({daily_fixtures: {[TODAY]: {updatedAt: NOW - 1000, sources: {api: {state: "ok"}},
    matches: [{fixtureId: 1, status: "NS", kickoff: TODAY + "T16:00:00Z", leagueId: 39}]}}});
  const request = async () => ({ok: false, status: 429, json: async () => ({})});
  const r = await F.runSync({db, apiKey: "k", mode: "live", now: NOW, request});
  assert.equal(r.state, "error");
  assert.equal(db.data.daily_fixtures[TODAY].matches.length, 1);
  assert.equal(db.data.daily_fixtures[TODAY].sources.api.state, "error");
});

test("an API error body (suspended key, plan limit) is an error, never an empty day", async () => {
  const db = fakeDb();
  const request = async () => ({ok: true, json: async () => ({errors: {access: "Your account is suspended"},
    response: [], results: 0, paging: {current: 1, total: 1}})});
  const r = await F.runSync({db, apiKey: "k", mode: "live", now: NOW, request});
  assert.equal(r.state, "error");
  assert.equal(db.data.daily_fixtures?.[TODAY]?.matches, undefined);
});

test("no key: nothing is requested", async () => {
  const {calls, request} = api({});
  const r = await F.runSync({db: fakeDb(), apiKey: "", mode: "day", now: NOW, request});
  assert.equal(r.state, "unconfigured");
  assert.equal(calls.length, 0);
});

test("two runs never overlap (job lease)", async () => {
  const db = fakeDb({daily_fixture_control: {api: {day: TODAY, used: 0, lock: {token: "x", until: NOW + 60000}}}});
  const {calls, request} = api({});
  const r = await F.runSync({db, apiKey: "k", mode: "day", now: NOW, request});
  assert.equal(r.state, "busy");
  assert.equal(calls.length, 0);
});

test("the API's own error message reaches the result, and failures are detectable", async () => {
  const errors = {plan: "Free plans do not have access to this date"};
  const request = async () => ({ok: true, json: async () => ({errors, response: [], results: 0,
    paging: {current: 1, total: 1}})});
  const r = await F.runSync({db: fakeDb(), apiKey: "secret-key", mode: "day", now: NOW, request});
  assert.match(r.results[0].error, /Free plans do not have access/);
  assert.ok(!JSON.stringify(r).includes("secret-key"));
  for (const state of ["error", "budget", "unconfigured"]) assert.equal(F.failed({state}), true);
  for (const state of ["ok", "busy"]) assert.equal(F.failed({state}), false);
});

test("readDay keeps the app contract and marks old data stale", () => {
  const raw = {updatedAt: NOW, sources: {api: {state: "ok", updatedAt: NOW}},
    matches: [{fixtureId: 1, status: "NS", kickoff: TODAY + "T16:00:00Z", leagueId: 39, homeName: "A",
      awayName: "B"}, {fixtureId: 2, status: "NS", kickoff: "2026-11-09T16:00:00Z", leagueId: 39}]};
  const feed = F.readDay(raw, TODAY, NOW + 3600000);
  assert.equal(feed.calendar.length, 1);
  assert.equal(feed.calendar[0].stale, false);
  assert.equal(feed.snapshotUsed, false);
  assert.ok(feed.competitions.includes("Premier League"));
  assert.equal(F.readDay(raw, TODAY, NOW + 31 * 3600000).calendar[0].stale, true);
  assert.deepEqual(F.readDay(null, TODAY, NOW).calendar, []);
});

test("teams map by API id first, then by name; unknown teams are reported", async () => {
  const db = fakeDb();
  const {request} = api({[TODAY]: [fixture(9, 39, TODAY, "NS", [999001, "Totally Unknown FC"],
      [33, "Manchester United"])]});
  await F.runSync({db, apiKey: "k", mode: "live", now: NOW, request});
  assert.equal(db.data.daily_fixture_control.unmapped["999001"].name, "Totally Unknown FC");
  assert.equal(db.data.daily_fixture_control.unmapped["33"], undefined);
});
