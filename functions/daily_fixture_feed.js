"use strict";
const fs = require("node:fs");
const path = require("node:path");
const {gunzipSync} = require("node:zlib");
const {dayKey} = require("./rewarded_ads");
const {fixtureClub} = require("./fixture_clubs");
const snapshot = JSON.parse(gunzipSync(fs.readFileSync(
    path.join(__dirname, "config/daily_fixture_snapshot.json.gz"))).toString());
const STATUS = {SCHEDULED: "TBD", TIMED: "NS", IN_PLAY: "LIVE", PAUSED: "HT", EXTRA_TIME: "ET",
  PENALTY_SHOOTOUT: "P", FINISHED: "FT", SUSPENDED: "SUSP", POSTPONED: "PST", CANCELLED: "CANC", AWARDED: "AWD"};
const WEIGHT = {2: 100, 3: 70, 848: 50, 203: 55, 39: 45, 140: 45, 135: 40, 78: 40,
  61: 40, 88: 25, 94: 25, 40: 15, 71: 20};
const DERBIES = new Set(["36-141", "114-141", "36-114", "131-418", "13-418", "281-985", "31-985",
  "29-31", "11-148", "5-46", "12-398", "16-27", "244-583", "294-720"]);
const rows = (value) => Array.isArray(value) ? value : Object.values(value || {});
function assertDate(date) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      new Date(date + "T12:00:00Z").toISOString().slice(0, 10) !== date) throw Error("Invalid fixture date");
}
function decorate(m) {
  const ids = [fixtureClub(m, "home"), fixtureClub(m, "away")];
  const isDerby = ids.every(Boolean) && DERBIES.has(ids.sort((a, b) => a - b).join("-"));
  return {...m, isDerby, importance: (WEIGHT[m.leagueId] || 10) + (isDerby ? 80 : 0)};
}
const byDay = new Map();
for (const row of snapshot.matches) {
  const key = dayKey(Date.parse(row[1]));
  if (!byDay.has(key)) byDay.set(key, []);
  byDay.get(key).push(row);
}
function snapshotDay(date) {
  assertDate(date);
  return (byDay.get(date) || []).map((r) => {
    const [leagueId, leagueName, leagueCountry] = snapshot.competitions[r[3]];
    return decorate({fixtureId: 4000000000 + r[0], sourceFixtureId: r[0], source: snapshot.provider,
      kickoff: r[1], status: STATUS[r[2]], leagueId, leagueName, leagueCountry,
      homeSourceId: r[4], awaySourceId: r[5], homeName: snapshot.teams[r[4]], awayName: snapshot.teams[r[5]],
      sourceUpdatedAt: Date.parse(r[6]), homeScore: r[7], awayScore: r[8]});
  });
}
async function fetchTurkey(date, apiKey, request = fetch) {
  assertDate(date);
  const year = Number(date.slice(0, 4)) - (Number(date.slice(5, 7)) < 7 ? 1 : 0);
  const query = new URLSearchParams({date, league: "203", season: String(year), timezone: "Europe/Istanbul"});
  const response = await request("https://v3.football.api-sports.io/fixtures?" + query,
      {headers: {"x-apisports-key": apiKey}, signal: AbortSignal.timeout(15000)});
  if (!response.ok) throw Error("Turkey fixture HTTP " + response.status);
  const body = await response.json();
  if (!Array.isArray(body.response) || body.errors && Object.keys(body.errors).length) {
    throw Error("Turkey fixture request rejected");
  }
  const matches = [];
  for (const item of body.response) {
    const f = item.fixture;
    const h = item.teams?.home;
    const a = item.teams?.away;
    if (item.league?.id !== 203 || !Number.isSafeInteger(f?.id) || f.id <= 0 || f.id >= 4000000000 ||
        !Number.isFinite(Date.parse(f.date)) || !h?.name || !a?.name || !f.status?.short ||
        !Number.isSafeInteger(h.id) || !Number.isSafeInteger(a.id) || h.id === a.id) {
      throw Error("Invalid Turkey fixture response");
    }
    if (dayKey(Date.parse(f.date)) !== date) throw Error("Unexpected Turkey fixture day");
    matches.push(decorate({fixtureId: f.id, sourceFixtureId: f.id, source: "api-football",
      homeApiId: h.id, awayApiId: a.id, homeName: h.name, awayName: a.name,
      leagueId: 203, leagueName: "Süper Lig", leagueCountry: "Turkey", kickoff: f.date,
      status: f.status.short, homeScore: item.goals?.home ?? null, awayScore: item.goals?.away ?? null}));
  }
  return matches;
}
function eventKey(m) {
  const h = fixtureClub(m, "home");
  const a = fixtureClub(m, "away");
  return h && a ? [m.leagueId, dayKey(Date.parse(m.kickoff)), h, a].join(":") : null;
}
async function syncDay({db, date, apiKey, request = fetch, now = Date.now()}) {
  assertDate(date);
  let turkey = null;
  let state = "unconfigured";
  if (apiKey) {
    try {
      turkey = await fetchTurkey(date, apiKey, request); state = "ok";
    } catch (_) {
      state = "error";
    }
  }
  const calendar = snapshotDay(date);
  const ref = db.ref("daily_fixtures/" + date);
  const tx = await ref.transaction((previous) => {
    const old = rows(previous?.matches);
    // Preserve already-started identities when replacing the previous all-league API feed.
    const replacements = calendar.map((m) => {
      const key = eventKey(m);
      const prior = key && old.find((v) => Number.isFinite(Date.parse(v.kickoff)) && eventKey(v) === key);
      return prior ? {...m, fixtureId: prior.fixtureId} : m;
    });
    const cachedTurkey = old.filter((m) => m.leagueId === 203 &&
      Number.isFinite(Date.parse(m.kickoff)) && dayKey(Date.parse(m.kickoff)) === date);
    const matches = [...replacements, ...(turkey ?? cachedTurkey)]
        .sort((a, b) => b.importance - a.importance || a.fixtureId - b.fixtureId);
    return {updatedAt: now, matches, topMatch: matches[0] || null, sources: {
      snapshot: {state: date < snapshot.coverageStart || date > snapshot.coverageEnd ? "out-of-range" : "available",
        updatedAt: Date.parse(snapshot.sourceUpdatedAt), coverageStart: snapshot.coverageStart,
        coverageEnd: snapshot.coverageEnd, count: calendar.length},
      turkey: {state, updatedAt: turkey ? now : previous?.sources?.turkey?.updatedAt ||
        (cachedTurkey.length ? previous?.updatedAt || 0 : 0), count: (turkey ?? cachedTurkey).length},
    }};
  });
  return tx.snapshot.val();
}
function readDay(raw, date, now) {
  const recent = raw?.updatedAt && now - raw.updatedAt <= 30 * 3600000 && raw.updatedAt <= now + 300000;
  const bundled = snapshotDay(date);
  const sources = raw?.sources || {
    snapshot: {state: date < snapshot.coverageStart || date > snapshot.coverageEnd ? "out-of-range" : "available",
      updatedAt: Date.parse(snapshot.sourceUpdatedAt), coverageStart: snapshot.coverageStart,
      coverageEnd: snapshot.coverageEnd, count: bundled.length},
    turkey: {state: recent ? "legacy" : "pending", updatedAt: recent ? raw.updatedAt : 0},
  };
  const input = recent ? rows(raw.matches) : [...bundled,
    ...rows(raw?.matches).filter((m) => m.leagueId === 203)];
  const unique = new Map();
  for (const match of input) {
    if (!match || !Number.isSafeInteger(match.fixtureId) || match.fixtureId <= 0 ||
        !Number.isFinite(Date.parse(match.kickoff)) || dayKey(Date.parse(match.kickoff)) !== date) continue;
    const turkeyTime = sources.turkey?.updatedAt || 0;
    const stale = match.leagueId === 203 ? now - turkeyTime > 30 * 3600000 :
      match.source !== "football-data-snapshot" && !recent;
    unique.set(match.fixtureId, {...match, stale});
  }
  const calendar = [...unique.values()].sort((a, b) => Date.parse(a.kickoff) - Date.parse(b.kickoff));
  return {calendar, sources, updatedAt: raw?.updatedAt || null,
    snapshotUsed: calendar.some((m) => m.source === "football-data-snapshot"),
    snapshotUpdatedAt: Date.parse(snapshot.sourceUpdatedAt),
    coverageStart: snapshot.coverageStart, coverageEnd: snapshot.coverageEnd};
}
module.exports = {snapshotDay, fetchTurkey, syncDay, rows, snapshot, eventKey, readDay};
