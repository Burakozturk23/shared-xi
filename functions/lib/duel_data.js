"use strict";

// Server-side data contract. No callable/game endpoint is activated by this file.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const IDS = new Set(["F01", "F02", "F06", "F07", "F08", "F10", "F12", "F13",
  "F14", "F15", "F16", "F17", "F18", "F22", "F20", "F21", "F24", "F25",
  "F29", "T01", "T02", "T07", "T09", "T10"]);
const MINIMUM = {GK: 10, DEF: 20, MID: 20, FWD: 10};
const FORMATION = ["GK", "DEF", "MID", "DEF", "MID", "FWD"];

function createCatalog(data) {
  if (data.schemaVersion !== 1 || data.minimumCatalog !== 120 ||
      data.minimumConditionPlayers !== 6 || JSON.stringify(data.formation) !== JSON.stringify(FORMATION) ||
      Object.entries(MINIMUM).some(([k, v]) => data.minimumPositions[k] !== v)) {
    throw new Error("Unsupported duel contract");
  }
  const criteria = new Map();
  for (const c of data.criteria) {
    if (!IDS.has(c.id) || criteria.has(c.id) || c.cutoff !== data.cutoff) throw new Error("Invalid criterion");
    criteria.set(c.id, Object.freeze({...c,
      blockers: Object.freeze([...c.blockers]), directions: Object.freeze([...c.directions])}));
  }
  if (criteria.size !== IDS.size) throw new Error("Incomplete criteria");
  const players = new Map();
  for (const p of data.players) {
    if (!Number.isSafeInteger(p.id) || p.id <= 0 || players.has(p.id) || !MINIMUM[p.position]) {
      throw new Error("Invalid identity");
    }
    players.set(p.id, Object.freeze({...p, aliases: Object.freeze([...p.aliases])}));
  }
  const metrics = new Map();
  const evidence = (row) => {
    if (!Array.isArray(row.sources) || !row.sources.length ||
        row.sources.some((id) => !Object.hasOwn(data.sources, id))) {
      throw new Error("Missing evidence");
    }
  };
  for (const m of data.verifiedMetrics) {
    const c = criteria.get(m.criterionId);
    if (!c || !players.has(m.playerId) || !Number.isSafeInteger(m.value) || m.value < 0 ||
        m.status !== "verified" || m.coverage !== "complete" || m.cutoff !== data.cutoff ||
        m.scopeId !== c.scopeId || m.unit !== c.unit) throw new Error("Unverified or incompatible metric");
    evidence(m);
    if (!metrics.has(c.id)) metrics.set(c.id, new Map());
    if (metrics.get(c.id).has(m.playerId)) throw new Error("Duplicate metric");
    metrics.get(c.id).set(m.playerId, Object.freeze({...m, sources: Object.freeze([...m.sources])}));
  }
  const conditions = new Map();
  for (const c of data.conditions) {
    if (!players.has(c.playerId) || c.status !== "verified" || c.cutoff !== data.cutoff ||
        !["country", "club"].includes(c.kind) || typeof c.key !== "string" || !c.key ||
        c.meaning !== (c.kind === "club" ? "official_senior_appearance" : "senior_national_team")) {
      throw new Error("Unverified condition");
    }
    evidence(c);
    const id = `${c.kind}:${c.key}`;
    if (!conditions.has(id)) conditions.set(id, new Set());
    conditions.get(id).add(c.playerId);
  }
  const approved = data.acceptance.conditionPathsApproved === true && data.acceptance.gameplayApproved === true;
  function isAvailable(id) {
    const c = criteria.get(id);
    const values = metrics.get(id);
    return !!(approved && c?.enabled && c.blockers.length === 0 && values?.size >= 120 &&
      Object.entries(MINIMUM).every(([position, n]) =>
        [...values.keys()].filter((pid) => players.get(pid).position === position).length >= n));
  }
  function eligiblePlayerIds(id, position, condition, excluded = new Set()) {
    if (!isAvailable(id) || !MINIMUM[position]) return [];
    const allowed = conditions.get(`${condition.kind}:${condition.key}`) || new Set();
    return [...metrics.get(id).keys()].filter((pid) => allowed.has(pid) &&
      !excluded.has(pid) && players.get(pid).position === position).sort((a, b) => a - b);
  }
  function candidateConditions(id, position, excluded = new Set()) {
    return [...conditions.keys()].map((key) => {
      const i = key.indexOf(":");
      return {kind: key.slice(0, i), key: key.slice(i + 1)};
    }).filter((c) => eligiblePlayerIds(id, position, c, excluded).length >= 6);
  }
  function safeConditions(id, position, remainingPositions, excluded = new Set()) {
    if (!Array.isArray(remainingPositions) || remainingPositions.some((p) => !MINIMUM[p])) return [];
    // Sufficient (conservative) continuation certificate. A reserve condition
    // retains six choices even if all intervening same-position picks consume
    // its players. Primary positions are disjoint; conditions may repeat when
    // no other safe condition exists. No exponential pair enumeration required.
    for (const p of new Set(remainingPositions)) {
      const rounds = remainingPositions.filter((x) => x === p).length;
      const required = 6 + 2 * (rounds - 1) + (p === position ? 2 : 0);
      if (!candidateConditions(id, p, excluded).some((c) =>
        eligiblePlayerIds(id, p, c, excluded).length >= required)) return [];
    }
    return candidateConditions(id, position, excluded);
  }
  function score(id, selection, roundConditions) {
    if (!isAvailable(id) || selection.length !== 6 || new Set(selection).size !== 6 || roundConditions.length !== 6) {
      throw new Error("Criterion unavailable or incomplete lineup");
    }
    let total = 0;
    selection.forEach((pid, i) => {
      if (!eligiblePlayerIds(id, FORMATION[i], roundConditions[i]).includes(pid)) throw new Error("Illegal selection");
      total += metrics.get(id).get(pid).value;
    });
    if (!Number.isSafeInteger(total)) throw new Error("Unsafe score");
    return total;
  }
  return Object.freeze({version: data.version, cutoff: data.cutoff,
    isAvailable, eligiblePlayerIds, candidateConditions, safeConditions, score,
    availableCriteria: () => [...criteria.values()].filter((c) => isAvailable(c.id)).map((c) => c.id),
    verifiedMetric: (id, pid) => metrics.get(id)?.get(pid) ?? null});
}

function loadBundledCatalog(directory = path.join(__dirname, "../config")) {
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, "duel_manifest.json"), "utf8"));
  const raw = fs.readFileSync(path.join(directory, "duel_runtime.json"));
  if (manifest.schemaVersion !== 1 || raw.length !== manifest.bytes ||
      crypto.createHash("sha256").update(raw).digest("hex") !== manifest.sha256) {
    throw new Error("Duel package integrity mismatch");
  }
  const data = JSON.parse(raw);
  if (data.version !== manifest.version || data.cutoff !== manifest.cutoff ||
      data.baseDatabaseSha256 !== manifest.baseDatabaseSha256) throw new Error("Duel version mismatch");
  return createCatalog(data);
}

module.exports = {createCatalog, loadBundledCatalog};
