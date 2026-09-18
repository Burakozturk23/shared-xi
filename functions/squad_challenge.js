"use strict";

// Pure rules; all currency and attempt changes are committed together at
// economyState/{uid}. The caller supplies server time and verified Premium.
const catalog = require("./data/squad_challenge_catalog.json");
const players = new Map(catalog.players.map((p) => [p.id, p]));
const themes = new Map(catalog.themes.map((t) => [t.id, t]));
const formations = new Map(catalog.formations.map((f) => [f.id, f]));
const DAILY_FREE = 3;
const EXTRA_PRICE = 20;
const MAX_PAID = 3;
const DAY = 86400000;
const RESET_OFFSET = 3 * 3600000;
const levels = [
  {label: "Isınma", reward: 20, budget: 135, links: 4, countries: 3},
  {label: "Ustalık", reward: 30, budget: 120, links: 6, countries: 4},
  {label: "Büyük görev", reward: 40, budget: 105, links: 8, countries: 5},
];

class SquadError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function dayKey(now) {
  return new Date(now + RESET_OFFSET).toISOString().slice(0, 10);
}

function missions(day) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    throw new SquadError("invalid-argument", "Görev tarihi geçersiz.");
  }
  const n = Math.floor(Date.parse(day + "T00:00:00Z") / DAY);
  if (!Number.isFinite(n) || new Date(n * DAY).toISOString().slice(0, 10) !== day) {
    throw new SquadError("invalid-argument", "Görev tarihi geçersiz.");
  }
  const pool = catalog.themes.filter((t) => t.dailyEligible);
  return levels.map((level, i) => {
    const theme = pool[((n + i * 11) % pool.length + pool.length) % pool.length];
    return {
      ...level,
      id: day + "__" + i + "__" + theme.id,
      day: day,
      themeId: theme.id,
      formationId: "4-3-3",
    };
  });
}

function missionFor(id) {
  const day = String(id).slice(0, 10);
  const found = missions(day).find((m) => m.id === id);
  if (!found) throw new SquadError("invalid-argument", "Görev bulunamadı.");
  return found;
}

function positionFits(player, slot) {
  const broad = ["Goalkeeper", "Defender", "Midfield", "Attack"];
  const detail = player.detailedPosition;
  return detail && !broad.includes(detail) ?
    slot.positions.includes(detail) : player.position === slot.broad;
}

function evaluate(themeId, formationId, ids, budget = 160) {
  const theme = themes.get(themeId);
  const formation = formations.get(formationId);
  if (!theme || !formation || !Array.isArray(ids) || ids.length !== 11 ||
      new Set(ids).size !== 11 || !ids.every(Number.isSafeInteger)) {
    throw new SquadError("invalid-argument", "11 farklı oyuncu seçmelisin.");
  }
  const selected = ids.map((id, index) => {
    const player = players.get(id);
    if (!player || !theme.players.includes(id) || !positionFits(player, formation.slots[index])) {
      throw new SquadError("invalid-argument", "Oyuncu, tema veya mevki uygun değil.");
    }
    return player;
  });
  const countrySet = new Set();
  for (const player of selected) {
    if (theme.uniqueCountries && player.countries.some((c) => countrySet.has(c))) {
      throw new SquadError("invalid-argument", "Her oyuncu farklı bir ülkeden olmalı.");
    }
    for (const country of player.countries) countrySet.add(country);
  }
  const cost = ids.reduce((sum, id) => sum + theme.costs[id], 0);
  if (cost > budget) throw new SquadError("invalid-argument", "Kadro kredisi aşıldı.");
  let links = 0;
  for (let i = 0; i < 11; i++) {
    for (const j of formation.adjacency[i]) {
      if (j > i && selected[i].clubIds.some((club) => selected[j].clubIds.includes(club))) links++;
    }
  }
  const shared = new Set();
  for (let i = 0; i < 11; i++) {
    for (let j = i + 1; j < 11; j++) {
      for (const club of selected[i].clubIds) if (selected[j].clubIds.includes(club)) shared.add(club);
    }
  }
  const continents = new Set(selected.map((p) => catalog.continents[p.countries[0]]).filter(Boolean));
  const score = links * 2 + (countrySet.size >= 5 ? 10 : 0) +
    (shared.size >= 6 ? 15 : 0) + (continents.size >= 3 ? 10 : 0) + (cost <= 120 ? 15 : 0);
  return {cost: cost, links: links, countries: countrySet.size, score: score};
}

function prepare(state, now) {
  const day = dayKey(now);
  const previous = state.squadChallenge || {};
  const sameDay = previous.day === day;
  state.squadChallenge = {
    day: day,
    freeUsed: sameDay ? previous.freeUsed || 0 : 0,
    paidUsed: sameDay ? previous.paidUsed || 0 : 0,
    active: previous.active || null,
    runs: {...(previous.runs || {})},
    completedTotal: previous.completedTotal || 0,
    bestByTheme: {...(previous.bestByTheme || {})},
  };
  // Retain recent receipts and any active run. Old reward claims remain in
  // the canonical wallet, so an old mission can never be rewarded again.
  const cutoff = dayKey(now - 2 * DAY);
  for (const [id, run] of Object.entries(state.squadChallenge.runs)) {
    if (id.slice(0, 10) < cutoff && id !== state.squadChallenge.active?.id && run.status !== "active") {
      delete state.squadChallenge.runs[id];
    }
  }
  return state.squadChallenge;
}

function claimId(mission) {
  return "squad__" + mission.id;
}

function status(state, now, premium) {
  const progress = prepare(state, now);
  return {
    catalogVersion: catalog.version,
    day: progress.day,
    serverNow: now,
    resetsAt: Date.parse(progress.day + "T00:00:00Z") - RESET_OFFSET + DAY,
    freeRemaining: Math.max(0, DAILY_FREE - progress.freeUsed),
    freeTotal: DAILY_FREE,
    extraPrice: EXTRA_PRICE,
    extraRemaining: Math.max(0, MAX_PAID - progress.paidUsed),
    premium: premium,
    coins: state.balances.coins,
    dailyMaxCoins: levels.reduce((sum, l) => sum + l.reward, 0),
    completedTotal: progress.completedTotal,
    bestByTheme: progress.bestByTheme,
    active: progress.active,
    missions: missions(progress.day).map((m) => ({...m, completed: !!state.claims[claimId(m)]})),
  };
}

function start(state, input, now, premium) {
  const progress = prepare(state, now);
  const mission = missionFor(input.missionId);
  const id = input.requestId;
  if (typeof id !== "string" || !/^\d{4}-\d{2}-\d{2}__[a-f0-9]{32}$/.test(id) ||
      id.slice(0, 10) !== mission.day) {
    throw new SquadError("invalid-argument", "Başlatma isteği geçersiz.");
  }
  if (progress.runs[id]) {
    if (progress.runs[id].mission.id !== mission.id) {
      throw new SquadError("failed-precondition", "Bu istek başka bir göreve ait.");
    }
    return progress.runs[id];
  }
  if (progress.active) {
    if (progress.active.mission.id === mission.id) return progress.active;
    throw new SquadError("failed-precondition", "Önce açık görevine dön veya onu bırak.");
  }
  if (mission.day !== progress.day) {
    throw new SquadError("failed-precondition", "Günlük görevler yenilendi. Ekranı yenile.");
  }
  if (state.claims[claimId(mission)]) {
    throw new SquadError("already-exists", "Bu görevin ödülünü zaten aldın. Antrenmanda devam edebilirsin.");
  }
  let payment = "premium";
  if (!premium) {
    if (progress.freeUsed < DAILY_FREE) {
      payment = "free";
      progress.freeUsed++;
    } else {
      if (input.payment !== "coins") {
        throw new SquadError("resource-exhausted", "Bugünkü ücretsiz denemelerin bitti.");
      }
      if (progress.paidUsed >= MAX_PAID) {
        throw new SquadError("resource-exhausted", "Bugünkü 3 ek denemeni kullandın.");
      }
      if (state.balances.coins < EXTRA_PRICE) {
        throw new SquadError("failed-precondition", "Ek deneme için 20 coin gerekli.");
      }
      payment = "coins";
      state.balances.coins -= EXTRA_PRICE;
      state.lifetimeSpent += EXTRA_PRICE;
      progress.paidUsed++;
      const txId = "squad_entry__" + id;
      state.purchases[txId] = {
        txId: txId, offerId: "squad_extra_attempt", itemId: id,
        priceCoins: EXTRA_PRICE, balanceAfter: state.balances.coins,
        purchasedAt: now,
      };
    }
  }
  const run = {id: id, mission: mission, payment: payment, startedAt: now, status: "active"};
  progress.active = run;
  progress.runs[id] = run;
  return run;
}

function finish(state, input, now) {
  const progress = prepare(state, now);
  const run = progress.runs[input.runId];
  if (!run) throw new SquadError("not-found", "Görev kaydı bulunamadı.");
  if (run.status === "finished") {
    if (JSON.stringify(run.playerIds) !== JSON.stringify(input.playerIds)) {
      throw new SquadError("failed-precondition", "Bu denemeye başka bir kadro kaydedilmiş.");
    }
    return run;
  }
  if (run.status !== "active" || progress.active?.id !== run.id) {
    throw new SquadError("failed-precondition", "Bu deneme kapatılmış.");
  }
  const mission = run.mission;
  const score = evaluate(mission.themeId, mission.formationId, input.playerIds, mission.budget);
  const won = score.links >= mission.links && score.countries >= mission.countries;
  const key = claimId(mission);
  let reward = 0;
  if (won && !state.claims[key]) {
    reward = mission.reward;
    state.balances.coins += reward;
    state.lifetimeEarned += reward;
    state.claims[key] = {
      txId: key, sourceType: "squad_challenge", sourceId: mission.id,
      amount: reward, balanceAfter: state.balances.coins, claimedAt: now,
    };
    progress.completedTotal++;
  }
  progress.bestByTheme[mission.themeId] = Math.max(progress.bestByTheme[mission.themeId] || 0, score.score);
  const result = {...run, status: "finished", playerIds: input.playerIds.slice(),
    result: {...score, won: won, reward: reward, finishedAt: now}};
  progress.runs[run.id] = result;
  progress.active = null;
  return result;
}

function abandon(state, input, now) {
  const progress = prepare(state, now);
  const run = progress.runs[input.runId];
  if (!run) throw new SquadError("not-found", "Görev kaydı bulunamadı.");
  if (run.status !== "active") return run;
  const result = {...run, status: "abandoned"};
  progress.runs[run.id] = result;
  if (progress.active?.id === run.id) progress.active = null;
  return result;
}

function apply(state, action, input, now, premium) {
  let run = null;
  if (action === "start") run = start(state, input, now, premium);
  else if (action === "finish") run = finish(state, input, now);
  else if (action === "abandon") run = abandon(state, input, now);
  else if (action !== "status") throw new SquadError("invalid-argument", "İşlem geçersiz.");
  state.createdAt = state.createdAt || now;
  state.updatedAt = now;
  return {ok: true, run: run, hub: status(state, now, premium)};
}

module.exports = {apply, status, missions, missionFor, evaluate, positionFits, dayKey, catalog, SquadError};
