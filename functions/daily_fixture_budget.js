"use strict";
const {randomUUID} = require("node:crypto");
const {dayKey} = require("./rewarded_ads");
const {syncDay, rows, isSupplemental} = require("./daily_fixture_feed");
const LIMIT = 3;
const LEASE_MS = 90000;
const RETRY_MS = 3600000;

// Reserve BEFORE the HTTP call. Timeouts/crashes consume a request too.
// Keep the legacy /turkey control path so upgrading does not reset spent quota.
// One transaction covers both the global lease and all of today's request slots.
async function reserve(db, day, slot, now) {
  const token = randomUUID();
  const tx = await db.ref("daily_fixture_control/turkey").transaction((previous) => {
    if (previous?.lock?.until > now || previous?.day > day) return;
    const state = previous?.day === day ? previous : {day, used: 0, slots: {}};
    const prior = state.slots?.[slot];
    if (state.used >= LIMIT || prior?.state === "ok" || prior?.attempts >= 2 ||
        prior && now - prior.at < RETRY_MS) return;
    return {...state, used: state.used + 1, lock: {token, until: now + LEASE_MS},
      slots: {...state.slots, [slot]: {at: now, attempts: (prior?.attempts || 0) + 1, state: "pending"}}};
  });
  return tx.committed ? token : null;
}
async function release(db, day, slot, token, result) {
  await db.ref("daily_fixture_control/turkey").transaction((state) => {
    // A cold transaction callback must return a value to load the actual record.
    if (!state) return state;
    if (state.day !== day || state.lock?.token !== token) return;
    return {...state, lock: null, slots: {...state.slots, [slot]: {...state.slots[slot], state: result}}};
  });
}
async function runSupplementalSync({db, apiKey, mode = "baseline", date, now = Date.now(), request = fetch}) {
  if (!["baseline", "refresh"].includes(mode)) throw Error("Invalid sync mode");
  const today = dayKey(now);
  const tomorrow = dayKey(now + 86400000);
  if (date && ![today, tomorrow].includes(date)) throw Error("Only today and tomorrow may consume API quota");
  if (!apiKey) return {state: "unconfigured", results: []};
  let dates = date ? [date] : mode === "baseline" ? [today, tomorrow] : [today];
  if (mode === "refresh") {
    if (date && date !== today) throw Error("Refresh is limited to today");
    const raw = (await db.ref("daily_fixtures/" + today).get()).val();
    const hasMatch = rows(raw?.matches).some((m) => isSupplemental(m) &&
      !["FT", "AET", "PEN", "CANC", "PST", "AWD", "WO", "ABD"].includes(m.status));
    // An unsuccessful/missing morning request gets one recovery opportunity.
    if (!hasMatch && raw?.sources?.supplemental?.state === "ok") dates = [];
  }
  const results = [];
  for (const target of dates) {
    const slot = "supplemental_" + mode + "_" + target;
    const token = await reserve(db, today, slot, now);
    if (!token) {
      results.push({date: target, state: "skipped"});
      continue;
    }
    let state = "error";
    try {
      const result = await syncDay({db, date: target, apiKey, now, request});
      state = result.sources.supplemental.state;
      results.push({date: target, state, matches: result.sources.supplemental.count});
    } finally {
      await release(db, today, slot, token, state);
    }
  }
  return {state: results.some((r) => r.state === "error") ? "error" : "ok", results};
}
module.exports = {runSupplementalSync, LIMIT};
