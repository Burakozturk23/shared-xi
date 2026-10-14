"use strict";
// Every charged story unit is resolved from a server-owned catalog, never a client price.
const definitions = {
  journey: {path: "journeyRewardState", rows: Object.values(require("./player_journey").journeys),
    progress: "journeys"},
  what_if: {path: "whatIfState", rows: Object.values(require("./what_if").scenarios), progress: "progress"},
  ucl: {path: "uclMomentsState", rows: Object.values(require("./ucl_moments").matches), progress: "results"},
  international: {path: "internationalGloryState", rows: Object.values(require("./international_glory").matches),
    progress: "results"},
  nostalgia: {path: "nostalgiaState", rows: require("./nostalgia").catalog.chapters, progress: "completed"},
  dynasties: {path: "dynastiesState", rows: require("./dynasties").catalog.dynasties, progress: "completed"},
  docu: {path: "footballDocuState", rows: require("./football_docu").catalog.episodes, progress: "completed"},
  derby: {path: "derbyDayState", rows: [], progress: "completed"},
};
// Derby catalog entries are already durable rivalry units.
definitions.derby.rows = Object.values(require("./derby_day").tasks);
function resolve(mode, id) {
  const def = definitions[mode];
  if (!def) return null;
  const row = def.rows.find((r) => r.id === id || r.taskIds?.includes(id) || r.tasks?.some((t) => t.id === id));
  return row ? {id: row.id, path: def.path, progress: def.progress,
    taskIds: row.taskIds || row.tasks?.map((t) => t.id) || [row.id]} : null;
}
async function migrated(db, uid, unit) {
  const s = (await db.ref(unit.path + "/" + uid).get()).val() || {};
  const p = s[unit.progress] || {};
  return Boolean(p[unit.id] || unit.taskIds.some((id) => p[id]));
}
module.exports = {definitions, resolve, migrated};
