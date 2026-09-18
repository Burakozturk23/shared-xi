"use strict";
const engine = require("../squad_challenge");

function wallet(coins = 200) {
  return {version: 1, balances: {coins}, lifetimeEarned: coins, lifetimeSpent: 0,
    claims: {}, purchases: {}, inventory: {}, createdAt: 0, updatedAt: 0};
}

// Construct a legal squad using canonical data. This is deliberately not the
// game implementation: it searches complete XIs and checks the actual scorer.
function solve(mission) {
  const theme = engine.catalog.themes.find((t) => t.id === mission.themeId);
  const formation = engine.catalog.formations.find((f) => f.id === mission.formationId);
  const byId = new Map(engine.catalog.players.map((p) => [p.id, p]));
  const pool = theme.players.map((id) => byId.get(id));
  const choices = formation.slots.map((slot) => pool.filter((p) => engine.positionFits(p, slot)));
  const anchors = new Map();
  for (const p of pool) for (const club of p.clubIds) anchors.set(club, (anchors.get(club) || 0) + 1);
  const clubs = [...anchors].sort((a, b) => b[1] - a[1]).slice(0, 50).map(([id]) => id);
  let seed = 87;
  const random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  for (const club of clubs) {
    for (let trial = 0; trial < 18; trial++) {
      const slots = Array(11).fill(null);
      const used = new Set();
      const nations = new Set();
      let cost = 0;
      const order = choices.map((_, i) => i).sort((a, b) => choices[a].length - choices[b].length);
      for (const i of order) {
        const remaining = 11 - used.size;
        const candidates = choices[i].filter((p) => !used.has(p.id) &&
          cost + theme.costs[p.id] + (remaining - 1) * 3 <= mission.budget);
        const ranked = candidates.map((p) => {
          const newNations = p.countries.filter((n) => !nations.has(n)).length;
          const bonds = formation.adjacency[i].filter((j) => slots[j] &&
            p.clubIds.some((id) => byId.get(slots[j]).clubIds.includes(id))).length;
          const value = (p.clubIds.includes(club) ? 9 : 0) + bonds * 3 +
            (nations.size < mission.countries ? newNations * 5 : 0) -
            theme.costs[p.id] * (trial % 3 + 1) * .35 + random() * 4;
          return {p, value};
        }).sort((a, b) => b.value - a.value);
        if (!ranked.length) break;
        const p = ranked[0].p;
        slots[i] = p.id;
        used.add(p.id);
        for (const n of p.countries) nations.add(n);
        cost += theme.costs[p.id];
      }
      if (used.size !== 11) continue;
      const score = engine.evaluate(theme.id, formation.id, slots, mission.budget);
      if (score.links >= mission.links && score.countries >= mission.countries) return slots;
    }
  }
  throw new Error("No feasible squad found for " + mission.themeId);
}

module.exports = {wallet, solve};
