"use strict";
// Günün maçları — tek kaynak API-Football, tek anahtar (API_FOOTBALL_KEY), tek çağıran
// (Cloud Functions). Bütün çalıştırmalar RTDB'deki ortak günlük bütçeyi paylaşır ve
// birbirleriyle çakışmaz. Yazılan biçim `daily_fixtures/{YYYY-MM-DD}` uygulamanın
// okuduğu sözleşmedir (matches, topMatch, sources).
const {randomUUID} = require("node:crypto");
const {dayKey} = require("./rewarded_ads");
const {fixtureClub} = require("./fixture_clubs");

// leagueId → [ad, ülke, önem]
const LEAGUES = {
  2: ["Şampiyonlar Ligi", "World", 100], 3: ["Avrupa Ligi", "World", 70], 848: ["Konferans Ligi", "World", 50],
  203: ["Süper Lig", "Turkey", 55], 39: ["Premier League", "England", 45], 140: ["La Liga", "Spain", 45],
  135: ["Serie A", "Italy", 40], 78: ["Bundesliga", "Germany", 40], 61: ["Ligue 1", "France", 40],
  88: ["Eredivisie", "Netherlands", 25], 94: ["Primeira Liga", "Portugal", 25], 40: ["Championship", "England", 15],
};
const DERBIES = new Set(["36-141", "114-141", "36-114", "131-418", "13-418", "281-985", "31-985",
  "29-31", "11-148", "5-46", "12-398", "16-27", "244-583", "294-720"]);
const STATUSES = new Set(["TBD", "NS", "1H", "HT", "2H", "ET", "BT", "P", "SUSP", "INT",
  "FT", "AET", "PEN", "PST", "CANC", "ABD", "AWD", "WO", "LIVE"]);
const FINAL = new Set(["FT", "AET", "PEN", "CANC", "PST", "AWD", "WO", "ABD"]);
// 100 istek/gün planında el ile kullanım ve yeniden deneme için 20 istek boşta kalır.
const DAILY_LIMIT = 80;
const LEASE_MS = 5 * 60000;
const STALE_MS = 30 * 3600000;
const CONTROL = "daily_fixture_control/api";
const rows = (value) => Array.isArray(value) ? value : Object.values(value || {});

function assertDate(date) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      new Date(date + "T12:00:00Z").toISOString().slice(0, 10) !== date) throw Error("Invalid fixture date");
}
function decorate(m) {
  const ids = [fixtureClub(m, "home"), fixtureClub(m, "away")];
  const isDerby = ids.every(Boolean) && DERBIES.has(ids.sort((a, b) => a - b).join("-"));
  return {...m, isDerby, importance: (LEAGUES[m.leagueId]?.[2] || 10) + (isDerby ? 80 : 0)};
}

/** One date query covers every league; never one request per league or match. */
async function fetchDay(date, apiKey, request = fetch) {
  assertDate(date);
  const query = new URLSearchParams({date, timezone: "Europe/Istanbul"});
  const response = await request("https://v3.football.api-sports.io/fixtures?" + query,
      {headers: {"x-apisports-key": apiKey}, signal: AbortSignal.timeout(15000)});
  if (!response.ok) throw Error("Fixture HTTP " + response.status);
  const body = await response.json();
  // A suspended key or plan limit answers 200 with `errors`: that is a failure, not an empty day.
  if (body.errors && Object.keys(body.errors).length) {
    throw Error("Fixture request rejected: " + JSON.stringify(body.errors));
  }
  if (!Array.isArray(body.response) || body.paging?.total > 1 ||
      body.results != null && body.results !== body.response.length) {
    throw Error("Fixture response incomplete");
  }
  const matches = [];
  const seen = new Set();
  for (const item of body.response) {
    const league = LEAGUES[item?.league?.id];
    if (!league) continue;
    const f = item.fixture; const h = item.teams?.home; const a = item.teams?.away;
    if (!Number.isSafeInteger(f?.id) || f.id <= 0 || seen.has(f.id) || !Number.isFinite(Date.parse(f.date)) ||
        !h?.name || !a?.name || !STATUSES.has(f.status?.short) || !Number.isSafeInteger(h.id) ||
        !Number.isSafeInteger(a.id) || h.id === a.id ||
        [item.goals?.home, item.goals?.away].some((s) => s != null && (!Number.isSafeInteger(s) || s < 0))) {
      throw Error("Invalid fixture response");
    }
    if (dayKey(Date.parse(f.date)) !== date) continue;
    seen.add(f.id);
    matches.push(decorate({fixtureId: f.id, sourceFixtureId: f.id, source: "api-football",
      homeApiId: h.id, awayApiId: a.id, homeName: h.name, awayName: a.name,
      leagueId: item.league.id, leagueName: league[0], leagueCountry: league[1], kickoff: f.date,
      status: f.status.short, homeScore: item.goals?.home ?? null, awayScore: item.goals?.away ?? null}));
  }
  return matches.sort((x, y) => y.importance - x.importance || x.fixtureId - y.fixtureId);
}

/** Takes one request from the shared daily budget; false when the day's budget is spent. */
async function spend(db, now) {
  const day = dayKey(now);
  const tx = await db.ref(CONTROL).transaction((s) => {
    const state = s?.day === day ? s : {...s, day, used: 0};
    if (state.used >= DAILY_LIMIT) return;
    return {...state, used: state.used + 1};
  });
  return tx.committed;
}
async function lease(db, now) {
  const token = randomUUID();
  const tx = await db.ref(CONTROL).transaction((s) => {
    if (s?.lock?.until > now) return;
    return {...s, lock: {token, until: now + LEASE_MS}};
  });
  return tx.committed ? token : null;
}
async function release(db, token) {
  await db.ref(CONTROL).transaction((s) => {
    if (!s) return s;
    if (s.lock?.token !== token) return;
    return {...s, lock: null};
  });
}

function sourceMeta(state, now, count, previous) {
  const meta = {state, attemptedAt: now, updatedAt: state === "ok" ? now : previous?.updatedAt || 0,
    count, provider: "api-football", competitions: Object.values(LEAGUES).map((l) => l[0])};
  return meta;
}
async function writeDay(db, date, matches, now) {
  await db.ref("daily_fixtures/" + date).transaction(() => {
    const meta = sourceMeta("ok", now, matches.length);
    // `supplemental` and `turkey` keep the source contract of installed apps.
    return {updatedAt: now, matches, topMatch: matches[0] || null,
      sources: {api: meta, supplemental: meta,
        turkey: {...meta, count: matches.filter((m) => m.leagueId === 203).length}}};
  });
}
async function markError(db, date, now) {
  await db.ref("daily_fixtures/" + date).transaction((previous) => {
    if (!previous) return; // never invent an empty day
    const meta = sourceMeta("error", now, rows(previous.matches).length, previous.sources?.api);
    return {...previous, sources: {...previous.sources, api: meta, supplemental: meta}};
  });
}
async function reportUnmapped(db, matches, now) {
  const missing = {};
  for (const m of matches) {
    for (const side of ["home", "away"]) {
      if (!fixtureClub(m, side)) {
        missing[m[side + "ApiId"]] = {name: m[side + "Name"], leagueId: m.leagueId, lastSeen: now};
      }
    }
  }
  for (const [id, info] of Object.entries(missing)) await db.ref("daily_fixture_control/unmapped/" + id).set(info);
}

/**
 * Only today is ever requested. mode "day": always (start of the day). mode "live":
 * nothing when every match of today is already final.
 */
async function runSync({db, apiKey, mode = "live", now = Date.now(), request = fetch}) {
  if (!["day", "live"].includes(mode)) throw Error("Invalid sync mode");
  if (!apiKey) return {state: "unconfigured", results: []};
  const today = dayKey(now);
  if (mode === "live") {
    const raw = (await db.ref("daily_fixtures/" + today).get()).val();
    const open = rows(raw?.matches).some((m) => !FINAL.has(m.status));
    if (raw?.sources?.api?.state === "ok" && !open) return {state: "ok", results: []};
  }
  const token = await lease(db, now);
  if (!token) return {state: "busy", results: []};
  try {
    if (!await spend(db, now)) return {state: "budget", results: [{date: today, state: "budget"}]};
    try {
      const matches = await fetchDay(today, apiKey, request);
      await writeDay(db, today, matches, now);
      await reportUnmapped(db, matches, now);
      return {state: "ok", results: [{date: today, state: "ok", matches: matches.length}]};
    } catch (error) {
      await markError(db, today, now);
      return {state: "error", results: [{date: today, state: "error", error: String(error.message).slice(0, 240)}]};
    }
  } finally {
    await release(db, token);
  }
}
/** The scheduled job should show as failed: today's fixtures were not refreshed. */
const failed = (result) => ["error", "budget", "unconfigured"].includes(result.state);

/** Today's calendar for getDailyMatches, with the field names installed apps read. */
function readDay(raw, date, now) {
  const sources = raw?.sources || {api: {state: "pending", updatedAt: 0}, supplemental: {state: "pending"}};
  const updated = sources.api?.updatedAt || raw?.updatedAt || 0;
  const stale = !updated || now - updated > STALE_MS || updated > now + 300000;
  const unique = new Map();
  for (const m of rows(raw?.matches)) {
    if (!m || !Number.isSafeInteger(m.fixtureId) || m.fixtureId <= 0 ||
        !Number.isFinite(Date.parse(m.kickoff)) || dayKey(Date.parse(m.kickoff)) !== date) continue;
    unique.set(m.fixtureId, {...m, stale});
  }
  const calendar = [...unique.values()].sort((a, b) => Date.parse(a.kickoff) - Date.parse(b.kickoff));
  return {calendar, sources, updatedAt: raw?.updatedAt || null, snapshotUsed: false, snapshotUpdatedAt: null,
    coverageStart: null, coverageEnd: null, competitions: Object.values(LEAGUES).map((l) => l[0])};
}

module.exports = {LEAGUES, DAILY_LIMIT, fetchDay, runSync, readDay, rows, failed};
