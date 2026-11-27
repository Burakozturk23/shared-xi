"use strict";
// Regenerates test/support/squad_scoring_cases.json, the fixtures that keep the
// Flutter preview scorer identical to the canonical server scorer:
//   node functions/test/make_squad_scoring_cases.js
const fs = require("node:fs");
const path = require("node:path");
const engine = require("../squad_challenge");
const {solve} = require("./squad_fixture");

const rows = [];
engine.catalog.themes.filter((t) => t.dailyEligible).forEach((theme, i) => {
  // Every formation, and both a hard XI and a single-club-heavy one, so the
  // per-club link cap and the matching are exercised.
  const formation = engine.catalog.formations[i % engine.catalog.formations.length];
  const edges = formation.adjacency.reduce((n, row) => n + row.length, 0) / 2;
  const mission = {id: "contract__" + theme.id, day: "2026-09-18", themeId: theme.id,
    formationId: formation.id, label: "Büyük görev", reward: 40, budget: 105,
    links: Math.ceil(edges * .7), countries: 5};
  const ids = solve(mission);
  rows.push({mission, ids, score: engine.evaluate(theme.id, formation.id, ids, mission.budget)});
});
fs.writeFileSync(path.join(__dirname, "../../test/support/squad_scoring_cases.json"),
    JSON.stringify(rows, null, 2) + "\n");
console.log(rows.length + " cases");
