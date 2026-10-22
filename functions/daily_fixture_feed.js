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
const SUPPLEMENTAL = {203: ["Süper Lig", "Turkey"], 3: ["Avrupa Ligi", "World"],
  848: ["Konferans Ligi", "World"]};
const isSupplemental = (m) => Object.hasOwn(SUPPLEMENTAL, m?.leagueId);
const API_STATUSES = new Set(["TBD", "NS", "1H", "HT", "2H", "ET", "BT", "P", "SUSP", "INT",
  "FT", "AET", "PEN", "PST", "CANC", "ABD", "AWD", "WO", "LIVE"]);
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
  return expandRows(byDay.get(date) || [], snapshot);
}
function expandRows(data, source) {
  return data.map((r) => {
    const [leagueId, leagueName, leagueCountry] = source.competitions[r[3]];
    return decorate({fixtureId: 4000000000 + r[0], sourceFixtureId: r[0], source: source.provider,
      kickoff: r[1], status: STATUS[r[2]], leagueId, leagueName, leagueCountry,
      homeSourceId: r[4], awaySourceId: r[5], homeName: source.teams[r[4]], awayName: source.teams[r[5]],
      sourceUpdatedAt: Date.parse(r[6]), homeScore: r[7], awayScore: r[8]});
  });
}
function snapshotMeta(source, date, count) {
  return {state: date < source.coverageStart || date > source.coverageEnd ? "out-of-range" : "available",
    updatedAt: Date.parse(source.sourceUpdatedAt), coverageStart: source.coverageStart,
    coverageEnd: source.coverageEnd, count,
    competitions: Object.values(source.competitions).map((c) => c[1])};
}
function hasImported(raw) {
  return raw?.sources?.snapshot?.provider === "kaggle" &&
    raw.sources.snapshot.updatedAt >= Date.parse(snapshot.sourceUpdatedAt);
}
function mergeCalendar(previous, calendar, date, meta, now, supplemental = null, supplementalMeta = null) {
  const old = rows(previous?.matches);
  const replacements = calendar.map((m) => {
    const prior = old.find((v) => v.source === m.source && v.sourceFixtureId === m.sourceFixtureId) ||
      old.find((v) => Number.isFinite(Date.parse(v.kickoff)) && eventKey(m) && eventKey(v) === eventKey(m));
    return prior ? {...m, fixtureId: prior.fixtureId} : m;
  });
  const cached = old.filter((m) => isSupplemental(m) &&
    Number.isFinite(Date.parse(m.kickoff)) && dayKey(Date.parse(m.kickoff)) === date);
  const extra = supplemental ?? cached;
  const matches = [...replacements, ...extra]
      .sort((a, b) => b.importance - a.importance || a.fixtureId - b.fixtureId);
  return {updatedAt: now, matches, topMatch: matches[0] || null, sources: {snapshot: meta,
    supplemental: supplementalMeta || previous?.sources?.supplemental || {state: "pending", updatedAt: 0},
    // Keep the Turkey metadata contract for already installed clients.
    turkey: supplementalMeta ? {...supplementalMeta,
      updatedAt: supplemental === null ? previous?.sources?.turkey?.updatedAt || supplementalMeta.updatedAt :
        supplementalMeta.updatedAt, count: extra.filter((m) => m.leagueId === 203).length} :
      previous?.sources?.turkey || {state: "pending", updatedAt: 0, count: 0}}};
}
async function fetchSupplemental(date, apiKey, request = fetch) {
  assertDate(date);
  // One date query covers all three competitions; never one request per league/match.
  const query = new URLSearchParams({date, timezone: "Europe/Istanbul"});
  const response = await request("https://v3.football.api-sports.io/fixtures?" + query,
      {headers: {"x-apisports-key": apiKey}, signal: AbortSignal.timeout(15000)});
  if (!response.ok) throw Error("Supplemental fixture HTTP " + response.status);
  const body = await response.json();
  if (!Array.isArray(body.response) || body.errors && Object.keys(body.errors).length ||
      body.paging?.total > 1 || body.paging?.current > 1 ||
      body.results != null && body.results !== body.response.length) {
    throw Error("Supplemental fixture request rejected or incomplete");
  }
  const matches = [];
  const seen = new Set();
  for (const item of body.response) {
    if (!Object.hasOwn(SUPPLEMENTAL, item?.league?.id)) continue;
    const f = item.fixture;
    const h = item.teams?.home;
    const a = item.teams?.away;
    if (!Number.isSafeInteger(f?.id) || f.id <= 0 || f.id >= 4000000000 || seen.has(f.id) ||
        !Number.isFinite(Date.parse(f.date)) || !h?.name || !a?.name || !API_STATUSES.has(f.status?.short) ||
        !Number.isSafeInteger(h.id) || !Number.isSafeInteger(a.id) || h.id <= 0 || a.id <= 0 || h.id === a.id ||
        [item.goals?.home, item.goals?.away].some((s) => s != null && (!Number.isSafeInteger(s) || s < 0))) {
      throw Error("Invalid supplemental fixture response");
    }
    if (dayKey(Date.parse(f.date)) !== date) throw Error("Unexpected supplemental fixture day");
    seen.add(f.id);
    const [leagueName, leagueCountry] = SUPPLEMENTAL[item.league.id];
    matches.push(decorate({fixtureId: f.id, sourceFixtureId: f.id, source: "api-football",
      homeApiId: h.id, awayApiId: a.id, homeName: h.name, awayName: a.name,
      leagueId: item.league.id, leagueName, leagueCountry, kickoff: f.date,
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
  let supplemental = null;
  let state = "unconfigured";
  if (apiKey) {
    try {
      supplemental = await fetchSupplemental(date, apiKey, request); state = "ok";
    } catch (_) {
      state = "error";
    }
  }
  const calendar = snapshotDay(date);
  const ref = db.ref("daily_fixtures/" + date);
  const tx = await ref.transaction((previous) => {
    const imported = hasImported(previous);
    const currentCalendar = imported ? rows(previous.matches).filter((m) => m.source === snapshot.provider) : calendar;
    const cached = rows(previous?.matches).filter(isSupplemental);
    const previousMeta = previous?.sources?.supplemental;
    const newer = previousMeta?.attemptedAt > now;
    // An unsuccessful first upgrade must not claim the old Turkey fetch covered Europe.
    if (!supplemental && !previousMeta) {
      const merged = mergeCalendar(previous, currentCalendar, date,
          imported ? previous.sources.snapshot : snapshotMeta(snapshot, date, calendar.length), now);
      merged.sources.supplemental = {state, attemptedAt: now, updatedAt: 0, count: cached.length};
      merged.sources.turkey = {...merged.sources.turkey, state};
      return merged;
    }
    const supplementalMeta = newer ? previousMeta : {state, attemptedAt: now,
      updatedAt: supplemental ? now : previousMeta?.updatedAt || 0,
      count: (supplemental ?? cached).length, competitions: Object.values(SUPPLEMENTAL).map((c) => c[0])};
    return mergeCalendar(previous, currentCalendar, date,
        imported ? previous.sources.snapshot : snapshotMeta(snapshot, date, calendar.length), now,
        newer ? null : supplemental, supplementalMeta);
  });
  return tx.snapshot.val();
}
function readDay(raw, date, now) {
  const recent = raw?.updatedAt && now - raw.updatedAt <= 30 * 3600000 && raw.updatedAt <= now + 300000;
  const imported = hasImported(raw);
  const bundled = imported ? rows(raw.matches).filter((m) => m.source === snapshot.provider) : snapshotDay(date);
  const sources = raw?.sources || {
    snapshot: {state: date < snapshot.coverageStart || date > snapshot.coverageEnd ? "out-of-range" : "available",
      updatedAt: Date.parse(snapshot.sourceUpdatedAt), coverageStart: snapshot.coverageStart,
      coverageEnd: snapshot.coverageEnd, count: bundled.length},
    turkey: {state: recent ? "legacy" : "pending", updatedAt: recent ? raw.updatedAt : 0},
  };
  const input = recent ? rows(raw.matches) : [...bundled,
    ...rows(raw?.matches).filter(isSupplemental)];
  const unique = new Map();
  for (const match of input) {
    if (!match || !Number.isSafeInteger(match.fixtureId) || match.fixtureId <= 0 ||
        !Number.isFinite(Date.parse(match.kickoff)) || dayKey(Date.parse(match.kickoff)) !== date) continue;
    const sourceTime = sources.supplemental?.updatedAt ||
      (match.leagueId === 203 ? sources.turkey?.updatedAt : 0) || 0;
    const stale = isSupplemental(match) ? now - sourceTime > 30 * 3600000 || sourceTime > now + 300000 :
      match.source !== "football-data-snapshot" && !recent;
    unique.set(match.fixtureId, {...match, stale});
  }
  const calendar = [...unique.values()].sort((a, b) => Date.parse(a.kickoff) - Date.parse(b.kickoff));
  return {calendar, sources, updatedAt: raw?.updatedAt || null,
    snapshotUsed: calendar.some((m) => m.source === "football-data-snapshot"),
    snapshotUpdatedAt: imported ? sources.snapshot.updatedAt : Date.parse(snapshot.sourceUpdatedAt),
    coverageStart: imported ? sources.snapshot.coverageStart : snapshot.coverageStart,
    coverageEnd: imported ? sources.snapshot.coverageEnd : snapshot.coverageEnd,
    competitions: [...new Set([...(imported ? sources.snapshot.competitions :
      Object.values(snapshot.competitions).map((c) => c[1])), ...Object.values(SUPPLEMENTAL).map((c) => c[0])])]};
}
module.exports = {snapshotDay, fetchSupplemental, syncDay, rows, snapshot, eventKey, readDay,
  expandRows, snapshotMeta, mergeCalendar, STATUS, SUPPLEMENTAL, isSupplemental};
