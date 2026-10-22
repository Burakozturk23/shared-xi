"use strict";
const {createHash, randomUUID} = require("node:crypto");
const {dayKey} = require("./rewarded_ads");
const {snapshot, STATUS, expandRows, snapshotMeta, mergeCalendar} = require("./daily_fixture_feed");
const HANDLE = "adrianjuliusaluoch/live-european-football-match-results";
const DAY = 86400000;
function validateSnapshot(data, now) {
  if (data?.schemaVersion !== 1 || data.provider !== snapshot.provider ||
      JSON.stringify(data.columns) !== JSON.stringify(snapshot.columns) ||
      !Array.isArray(data.matches) || data.matches.length < 1000 || data.matches.length > 200000 ||
      data.import?.dataset !== HANDLE || !/^[a-f0-9]{64}$/.test(data.import?.parquetSha256 || "")) {
    throw Error("Invalid Kaggle snapshot schema");
  }
  const updatedAt = Date.parse(data.sourceUpdatedAt);
  if (!Number.isFinite(updatedAt) || updatedAt > now + 300000 || now - updatedAt > 3 * DAY) {
    throw Error("Kaggle source is stale or future-dated");
  }
  const ids = new Set();
  const dates = [];
  for (const r of data.matches) {
    const validTime = (v) => typeof v === "string" && /(Z|[+-]\d\d:\d\d)$/.test(v) &&
      Number.isFinite(Date.parse(v));
    if (!Array.isArray(r) || r.length !== 9 || !Number.isSafeInteger(r[0]) || r[0] <= 0 ||
        r[0] >= 1000000000 || ids.has(r[0]) || !validTime(r[1]) || !validTime(r[6]) ||
        Date.parse(r[6]) > updatedAt || !STATUS[r[2]] || !snapshot.competitions[r[3]] ||
        JSON.stringify(data.competitions?.[r[3]]) !== JSON.stringify(snapshot.competitions[r[3]]) ||
        !Number.isSafeInteger(r[4]) || !Number.isSafeInteger(r[5]) || r[4] <= 0 || r[5] <= 0 || r[4] === r[5] ||
        [r[4], r[5]].some((id) => typeof data.teams?.[id] !== "string" || !data.teams[id].trim() ||
          data.teams[id].length > 160) ||
        [r[7], r[8]].some((score) => score !== null && (!Number.isSafeInteger(score) || score < 0))) {
      throw Error("Invalid Kaggle match; previous calendar retained");
    }
    ids.add(r[0]);
    dates.push(dayKey(Date.parse(r[1])));
  }
  dates.sort();
  const quarantined = data.import.quarantinedIds || [];
  if (!Array.isArray(quarantined) || quarantined.length > 50 ||
      quarantined.length > (data.matches.length + quarantined.length) * 0.005 ||
      new Set(quarantined).size !== quarantined.length ||
      quarantined.some((id) => !Number.isSafeInteger(id) || id <= 0 || id >= 1000000000 || ids.has(id))) {
    throw Error("Invalid quarantine report");
  }
  if (data.coverageStart !== dates[0] || data.coverageEnd !== dates.at(-1) ||
      data.coverageStart > dayKey(now) || data.coverageEnd < dayKey(now)) {
    throw Error("Kaggle coverage does not include today");
  }
  // No unknown competition labels may be copied into the public status response.
  for (const [code, details] of Object.entries(data.competitions || {})) {
    if (JSON.stringify(details) !== JSON.stringify(snapshot.competitions[code])) throw Error("Unknown competition");
  }
  return {updatedAt, count: data.matches.length,
    hash: createHash("sha256").update(JSON.stringify(data)).digest("hex")};
}
async function publishSnapshot({db, data, now = Date.now()}) {
  const valid = validateSnapshot(data, now);
  const token = randomUUID();
  const control = db.ref("daily_fixture_control/kaggle");
  const lease = await control.transaction((previous) => {
    if (previous?.lock?.until > now || previous?.updatedAt > valid.updatedAt ||
        previous?.count && valid.count < previous.count * 0.8) return;
    return {...previous, lock: {token, until: now + 15 * 60000}};
  });
  if (!lease.committed) throw Error("Kaggle import locked or rejected as an older/incomplete snapshot");
  const indexed = new Map();
  for (const r of data.matches) {
    const date = dayKey(Date.parse(r[1]));
    if (!indexed.has(date)) indexed.set(date, []);
    indexed.get(date).push(r);
  }
  let completed = false;
  try {
    // Preserve historical game/streak eligibility. Publish today + 14 days only.
    // Explicit empty days remove fixtures that were postponed to another date.
    for (let offset = 0; offset <= 14; offset++) {
      if ((await control.get()).val()?.lock?.token !== token) throw Error("Kaggle lease lost");
      const date = dayKey(now + offset * DAY);
      const calendar = expandRows(indexed.get(date) || [], data);
      await db.ref("daily_fixtures/" + date).transaction((previous) => {
        if (previous?.sources?.snapshot?.updatedAt > valid.updatedAt) return;
        return mergeCalendar(previous, calendar, date, {...snapshotMeta(data, date, calendar.length),
          provider: "kaggle", dataset: HANDLE, hash: valid.hash, importedAt: now,
          quarantinedCount: (data.import.quarantinedIds || []).length}, now);
      });
    }
    completed = true;
    return {state: "ok", days: 15, matches: valid.count, sourceUpdatedAt: valid.updatedAt, hash: valid.hash,
      quarantinedIds: data.import.quarantinedIds || []};
  } finally {
    await control.transaction((state) => {
      if (!state) return state;
      if (state.lock?.token !== token) return;
      return {...state, lock: null, ...(completed ? {updatedAt: valid.updatedAt, count: valid.count,
        hash: valid.hash, lastSuccessAt: now} : {lastFailureAt: now})};
    });
  }
}
module.exports = {publishSnapshot, validateSnapshot, HANDLE};
