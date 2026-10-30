"use strict";
const engine = require("../squad_challenge");

function wallet(coins = 200) {
  return {version: 1, balances: {coins}, lifetimeEarned: coins, lifetimeSpent: 0,
    claims: {}, purchases: {}, inventory: {}, createdAt: 0, updatedAt: 0};
}

// Construct a legal squad using canonical data. This is deliberately not the
// game implementation: a seeded local search over complete XIs, judged only by
// the canonical scorer (credited links with the per-club cap, countries).
function solve(mission) {
  const theme = engine.catalog.themes.find((t) => t.id === mission.themeId);
  const formation = engine.catalog.formations.find((f) => f.id === mission.formationId);
  const byId = new Map(engine.catalog.players.map((p) => [p.id, p]));
  const pool = theme.players.map((id) => byId.get(id));
  const choices = formation.slots.map((slot) => pool.filter((p) => engine.positionFits(p, slot)));
  let seed = 87;
  const random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  const pick = (list) => list[Math.floor(random() * list.length)];
  const score = (slots) => {
    try {
      const s = engine.evaluate(theme.id, formation.id, slots, mission.budget);
      return {...s, value: Math.min(s.links, mission.links) * 4 + Math.min(s.countries, mission.countries) * 3 +
        s.links * .5};
    } catch (e) {
      return null;
    }
  };
  for (let restart = 0; restart < 40; restart++) {
    // Cheapest legal start, then single-slot swaps that never break the rules.
    let slots = null;
    for (let t = 0; t < 300 && !slots; t++) {
      const trial = choices.map((c) => [...Array(6)].map(() => pick(c))
          .sort((a, b) => theme.costs[a.id] - theme.costs[b.id])[0].id);
      if (score(trial)) slots = trial;
    }
    if (!slots) continue;
    let current = score(slots);
    for (let step = 0; step < 4000; step++) {
      if (current.links >= mission.links && current.countries >= mission.countries) return slots;
      const i = Math.floor(random() * 11);
      const next = slots.slice();
      next[i] = pick(choices[i]).id;
      const s = score(next);
      if (s && (s.value >= current.value || random() < .02)) {
        slots = next; current = s;
      }
    }
  }
  throw new Error("No feasible squad found for " + mission.themeId + " " + mission.formationId);
}

module.exports = {wallet, solve};
