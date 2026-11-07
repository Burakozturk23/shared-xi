"use strict";

// Pure rules; all currency and attempt changes are committed together at
// economyState/{uid}. The caller supplies server time and verified Premium.
const catalog = require("./data/squad_challenge_catalog.json");
const players = new Map(catalog.players.map((p) => [p.id, p]));
const themes = new Map(catalog.themes.map((t) => [t.id, t]));
const formations = new Map(catalog.formations.map((f) => [f.id, f]));
const {squadPolicy} = require("./economy_config");
const DEFAULT_POLICY = squadPolicy();
const DAY = 86400000;
const RESET_OFFSET = 3 * 3600000;
// Link targets are shares of the formation's adjacent pairs, so they stay
// comparable when the daily formation changes (4-3-3 has 14, 3-4-3 has 22).
const levels = [
  {label: "Isınma", budget: 135, share: .4, countries: 3},
  {label: "Ustalık", budget: 120, share: .55, countries: 4},
  {label: "Büyük görev", budget: 105, share: .7, countries: 5},
];
// One club can credit at most this many links: eleven players from a single
// club no longer max the chemistry, connections have to come from careers.
const CLUB_LINK_CAP = 3;
// Extra coins for a stronger winning XI, paid once with the mission reward.
const STAR_BONUS = {2: 5, 3: 10};
const formationIds = catalog.formations.map((f) => f.id);
const edgeCount = (formation) => formation.adjacency.reduce((n, row) => n + row.length, 0) / 2;

class SquadError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function dayKey(now) {
  return new Date(now + RESET_OFFSET).toISOString().slice(0, 10);
}

function missions(day, policy = DEFAULT_POLICY) {
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
    // Three different formations a day, rotating through all seven.
    const formationId = formationIds[((n + i * 2) % formationIds.length + formationIds.length) % formationIds.length];
    const edges = edgeCount(formations.get(formationId));
    const links = Math.ceil(edges * level.share);
    const twoStar = Math.ceil(edges * Math.min(level.share + .15, .8));
    const reward = policy.rewards[i];
    return {
      label: level.label,
      budget: level.budget,
      countries: level.countries,
      links: links,
      twoStar: twoStar,
      threeStar: Math.max(twoStar + 1, Math.floor(edges * .9)),
      maxLinks: edges,
      clubLinkCap: CLUB_LINK_CAP,
      starBonus: STAR_BONUS,
      reward: reward,
      // Half the mission reward, never above the configured price.
      extraPrice: Math.min(policy.extraPrice, Math.ceil(reward / 2)),
      economyConfigId: policy.configId,
      id: day + "__" + i + "__" + theme.id,
      day: day,
      themeId: theme.id,
      formationId: formationId,
    };
  });
}

function missionFor(id, policy = DEFAULT_POLICY) {
  const day = String(id).slice(0, 10);
  const found = missions(day, policy).find((m) => m.id === id);
  if (!found) throw new SquadError("invalid-argument", "Görev bulunamadı.");
  return found;
}

// Slots may name a position with its group prefix ("Defender - Left-Back");
// players carry the bare name. Compare the bare names.
const bare = (position) => String(position).split(" - ").pop();
function positionFits(player, slot) {
  const broad = ["Goalkeeper", "Defender", "Midfield", "Attack"];
  const detail = player.detailedPosition;
  return detail && !broad.includes(detail) ?
    slot.positions.some((p) => bare(p) === bare(detail)) : player.position === slot.broad;
}

/**
 * Adjacent pairs sharing a club, credited so that no club credits more than
 * CLUB_LINK_CAP of them (a maximum b-matching; at most 22 pairs).
 */
function creditedLinks(selected, formation, cap = CLUB_LINK_CAP) {
  const pairs = [];
  for (let i = 0; i < 11; i++) {
    for (const j of formation.adjacency[i]) {
      if (j <= i || !selected[i] || !selected[j]) continue;
      const common = selected[i].clubIds.filter((club) => selected[j].clubIds.includes(club)).sort((a, b) => a - b);
      if (common.length) pairs.push(common);
    }
  }
  const owner = new Array(pairs.length).fill(null);
  const load = new Map();
  const augment = (e, seen) => {
    for (const club of pairs[e]) {
      if (seen.has(club)) continue;
      seen.add(club);
      if ((load.get(club) || 0) < cap) {
        load.set(club, (load.get(club) || 0) + 1); owner[e] = club; return true;
      }
      for (let other = 0; other < pairs.length; other++) {
        if (owner[other] === club && augment(other, seen)) {
          owner[e] = club; return true;
        }
      }
    }
    return false;
  };
  let links = 0;
  for (let e = 0; e < pairs.length; e++) if (augment(e, new Set())) links++;
  return {links, raw: pairs.length};
}

/** 1 star at the target, 2 and 3 for a stronger XI; 0 when not won. */
function starsFor(mission, score) {
  if (score.links < mission.links || score.countries < mission.countries) return 0;
  if (!mission.twoStar) return 1;
  return score.links >= mission.threeStar ? 3 : score.links >= mission.twoStar ? 2 : 1;
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
  const seen = new Set();
  for (const player of selected) {
    if (theme.uniqueCountries && player.countries.some((c) => seen.has(c))) {
      throw new SquadError("invalid-argument", "Her oyuncu farklı bir ülkeden olmalı.");
    }
    for (const country of player.countries) seen.add(country);
  }
  // One country per player (the first): dual nationals do not count twice.
  const countrySet = new Set(selected.map((p) => p.countries[0]).filter(Boolean));
  const cost = ids.reduce((sum, id) => sum + theme.costs[id], 0);
  if (cost > budget) throw new SquadError("invalid-argument", "Kadro kredisi aşıldı.");
  const {links, raw} = creditedLinks(selected, formation);
  const shared = new Set();
  for (let i = 0; i < 11; i++) {
    for (let j = i + 1; j < 11; j++) {
      for (const club of selected[i].clubIds) if (selected[j].clubIds.includes(club)) shared.add(club);
    }
  }
  const continents = new Set(selected.map((p) => catalog.continents[p.countries[0]]).filter(Boolean));
  const score = links * 2 + (countrySet.size >= 5 ? 10 : 0) +
    (shared.size >= 6 ? 15 : 0) + (continents.size >= 3 ? 10 : 0) + (cost <= 120 ? 15 : 0);
  return {cost: cost, links: links, rawLinks: raw, countries: countrySet.size, score: score};
}

function prepare(state, now) {
  const day = dayKey(now);
  const previous = state.squadChallenge || {};
  if (previous.day && previous.day > day) {
    throw new SquadError("failed-precondition", "Günlük görevler yenilendi. Tekrar dene.");
  }
  const sameDay = previous.day === day;
  state.squadChallenge = {
    ...previous,
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
    if (id.slice(0, 10) < cutoff && id !== state.squadChallenge.active?.id &&
        run.status !== "active" && !(run.adCredits > 0)) {
      delete state.squadChallenge.runs[id];
    }
  }
  return state.squadChallenge;
}

function claimId(mission) {
  return "squad__" + mission.id;
}

function status(state, now, premium, policy = DEFAULT_POLICY) {
  const progress = prepare(state, now);
  return {
    catalogVersion: catalog.version,
    economyConfigId: policy.configId,
    enabled: policy.enabled,
    day: progress.day,
    serverNow: now,
    resetsAt: Date.parse(progress.day + "T00:00:00Z") - RESET_OFFSET + DAY,
    freeRemaining: policy.enabled ? Math.max(0, policy.freeAttempts - progress.freeUsed) : 0,
    freeTotal: policy.freeAttempts,
    extraPrice: policy.extraPrice,
    extraRemaining: policy.enabled && policy.extraEnabled ? Math.max(0, policy.maxPaid - progress.paidUsed) : 0,
    premium: premium,
    coins: state.balances.coins,
    dailyMaxCoins: policy.enabled ? policy.rewards.reduce((sum, r) => sum + r + STAR_BONUS[3], 0) : 0,
    completedTotal: progress.completedTotal,
    bestByTheme: progress.bestByTheme,
    active: progress.active,
    missions: missions(progress.day, policy).map((m) => ({...m,
      reward: state.claims[claimId(m)]?.amount ?? m.reward, completed: !!state.claims[claimId(m)]})),
  };
}

function start(state, input, now, premium, policy) {
  const progress = prepare(state, now);
  const mission = missionFor(input.missionId, policy);
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
  if (!policy.enabled) {
    throw new SquadError("failed-precondition", "Günlük ödüllü görevler kapalı. Ücretsiz antrenman açık.");
  }
  let payment = "premium";
  if (!premium) {
    if (progress.freeUsed < policy.freeAttempts) {
      payment = "free";
      progress.freeUsed++;
    } else {
      if (input.payment !== "coins") {
        throw new SquadError("resource-exhausted", "Bugünkü ücretsiz denemelerin bitti.");
      }
      if (!policy.extraEnabled || progress.paidUsed >= policy.maxPaid) {
        throw new SquadError("resource-exhausted", "Bugünkü ek deneme limiti doldu.");
      }
      const price = mission.extraPrice;
      if ((input.expectedPriceCoins ?? price) !== price) {
        throw new SquadError("failed-precondition", "Ek deneme fiyatı değişti. Görevleri yenile.");
      }
      if (state.balances.coins < price) {
        throw new SquadError("failed-precondition", "Ek deneme için yeterli Link Coin yok.");
      }
      payment = "coins";
      const balanceBefore = state.balances.coins;
      state.balances.coins -= price;
      state.lifetimeSpent += price;
      progress.paidUsed++;
      const txId = "squad_entry__" + id;
      state.purchases[txId] = {
        txId: txId, offerId: "squad_extra_attempt", itemId: id,
        priceCoins: price, balanceBefore, balanceAfter: state.balances.coins,
        sourceType: "squad_extra_attempt", sourceId: id, economyConfigId: policy.configId,
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
  const stars = starsFor(mission, score);
  const won = stars > 0;
  const key = claimId(mission);
  let reward = 0;
  if (won && !state.claims[key]) {
    reward = mission.reward + (STAR_BONUS[stars] || 0);
    const balanceBefore = state.balances.coins;
    if (!Number.isSafeInteger(balanceBefore + reward)) throw new SquadError("out-of-range", "Balance overflow");
    state.balances.coins += reward;
    state.lifetimeEarned += reward;
    state.claims[key] = {
      txId: key, sourceType: "squad_challenge", sourceId: mission.id,
      amount: reward, balanceBefore, balanceAfter: state.balances.coins, claimedAt: now,
      economyConfigId: mission.economyConfigId || "legacy",
    };
    progress.completedTotal++;
  }
  const penalty = run.assisted ? run.supportPenalty || 0 : 0;
  const finalScore = Math.max(0, score.score - penalty);
  const records = run.assisted ? (progress.assistedBestByTheme ||= {}) : progress.bestByTheme;
  records[mission.themeId] = Math.max(records[mission.themeId] || 0, finalScore);
  const result = {...run, status: "finished", playerIds: input.playerIds.slice(),
    result: {...score, ...(run.boostPolicy ? {rawScore: score.score, score: finalScore, penalty,
      assisted: run.assisted === true, masteryEligible: !run.assisted} : {}),
    won: won, stars: stars, reward: reward, finishedAt: now}};
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

function apply(state, action, input, now, premium, policy = DEFAULT_POLICY) {
  let run = null;
  if (action === "start") run = start(state, input, now, premium, policy);
  else if (action === "finish") run = finish(state, input, now);
  else if (action === "abandon") run = abandon(state, input, now);
  else if (action !== "status") throw new SquadError("invalid-argument", "İşlem geçersiz.");
  require("./squad_support").recover(state, now);
  state.createdAt = state.createdAt || now;
  state.updatedAt = now;
  return {ok: true, run: run, hub: status(state, now, premium, policy)};
}

module.exports = {apply, status, missions, missionFor, evaluate, positionFits, creditedLinks, starsFor, dayKey,
  catalog, SquadError, CLUB_LINK_CAP, STAR_BONUS};
