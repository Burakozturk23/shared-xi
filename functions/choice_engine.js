"use strict";
const crypto = require("node:crypto");
const catalog = require("./config/choice_catalog.json");
const {RewardError} = require("./rewarded_ads");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (v) => crypto.createHash("sha256").update(String(v)).digest("hex");
const list = (v) => Array.isArray(v) ? v : Object.values(v || {});
const order = (items, seed) => [...items].sort((a, b) => hash(seed + a).localeCompare(hash(seed + b)));
const modes = ["this_or_that", "higher_lower", "blind_ranking"];
function hydrate(r) {
  if (!r) return null;
  for (const k of ["history", "orderedCandidateIds", "usedIds", "placements", "rewardKeys"]) r[k] = list(r[k]);
  r.actions ||= {}; return r;
}
function bracket(ids, history) {
  let round = [...ids]; let winners = []; let match = 0; let roundNumber = 1;
  for (const event of history) {
    const left = round[match * 2]; const right = round[match * 2 + 1];
    if (!left || !right || event.leftId !== left || event.rightId !== right ||
      ![left, right].includes(event.winnerId) || event.matchNumber !== ids.length - round.length + match + 1) {
      fail("invalid-argument", "Turnuva seçim dizisi geçersiz.");
    }
    winners.push(event.winnerId); match++;
    if (winners.length === round.length / 2) {
      round = winners; winners = []; match = 0; roundNumber++;
    }
  }
  return {leftId: round.length > 1 ? round[match * 2] : null,
    rightId: round.length > 1 ? round[match * 2 + 1] : null, championId: round.length === 1 ? round[0] : null,
    roundNumber, roundSize: round.length, matchNumber: history.length + 1};
}
function score(values) {
  let comparable = 0; let correct = 0; let exactMatches = 0;
  for (let i = 0; i < values.length; i++) {
    const above = values.filter((x) => x > values[i]).length;
    const same = values.filter((x) => x === values[i]).length;
    if (i >= above && i < above + same) exactMatches++;
    for (let j = i + 1; j < values.length; j++) {
      if (values[i] === values[j]) continue;
      comparable++; if (values[i] > values[j]) correct++;
    }
  }
  if (!comparable) fail("failed-precondition", "Eşit değerlerden sıralama üretilemez.");
  return {score: Math.round(100 * correct / comparable), exactMatches, comparable, correct};
}
function metricGroup(c, metricId, seed) {
  const m = c.metrics[metricId];
  if (!m?.gatePassed) fail("failed-precondition", m?.reason || "Kriter doğrulanmadı.");
  const scopes = Object.keys(m.groups).filter((k) => list(m.groups[k]).length >= 120);
  const scope = order(scopes, seed)[0];
  if (!scope) fail("failed-precondition", "Karşılaştırılabilir veri yetersiz.");
  return {scope, rows: list(m.groups[scope])};
}
function higherPair(c, r) {
  const rows = list(c.metrics[r.metricId].groups[r.scope]).filter((x) => !r.usedIds.includes(x.id));
  const band = r.streak < 3 ? "easy" : r.streak < 9 ? "normal" : r.streak < 19 ? "hard" : "master";
  const limits = {easy: [0.45, 1], normal: [0.2, 0.65], hard: [0.08, 0.3], master: [0.01, 0.15]}[band];
  const shuffled = order(rows.map((x) => x.id), r.privateSeed + r.history.length);
  const values = Object.fromEntries(rows.map((x) => [x.id, x.value]));
  for (let i = 0; i < shuffled.length; i++) {
    for (let j = i + 1; j < shuffled.length; j++) {
      let a = shuffled[i]; let b = shuffled[j];
      const gap = Math.abs(values[a] - values[b]) / Math.max(values[a], values[b]);
      if (gap < limits[0] || gap > limits[1] || Math.round(values[a]) === Math.round(values[b])) continue;
      const higher = parseInt(hash(r.privateSeed + ":direction:" + r.history.length).slice(0, 2), 16) % 2 === 0;
      if ((values[b] > values[a]) !== higher) [a, b] = [b, a];
      r.usedIds.push(a, b);
      return {id: hash(r.id + ":" + r.history.length).slice(0, 24), leftId: a, rightId: b,
        leftValue: values[a], rightValue: values[b], difficulty: band, knownSide: r.history.length % 2};
    }
  }
  return null;
}
function create(c, input, time) {
  if (!modes.includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
  const r = {id: input.requestId, mode: input.mode, dataVersion: c.version, phase: "prepared", revision: 0,
    privateSeed: crypto.randomBytes(24).toString("hex"), createdAt: time, finished: false, completed: false,
    history: [], actions: {}, orderedCandidateIds: [], usedIds: [], placements: [], rewardKeys: [],
    earnedCoins: 0, streak: 0, renderTemplateVersion: 1};
  if (r.mode === "this_or_that") {
    const theme = c.themes[input.bracketId]; const f = theme?.formats[String(input.size || 16)];
    if (!f) fail("invalid-argument", "Tema bu boyutu desteklemiyor.");
    r.bracketId = theme.id; r.size = Number(input.size || 16); r.type = theme.type;
    r.contentVerified = f.approved === true; r.orderedCandidateIds = list(f.candidateIds);
    if (r.orderedCandidateIds.length !== r.size || new Set(r.orderedCandidateIds).size !== r.size) {
      fail("failed-precondition", "Aday manifesti geçersiz.");
    }
    r.seedOrderHash = hash(r.orderedCandidateIds.join("|"));
  } else if (r.mode === "higher_lower") {
    r.metricId = input.metricId; const g = metricGroup(c, r.metricId, r.privateSeed); r.scope = g.scope;
    r.question = higherPair(c, r); if (!r.question) fail("failed-precondition", "Geçerli ilk çift yok.");
  } else {
    r.type = input.type || "objective"; r.size = Number(input.size || 5);
    if (![5, 10].includes(r.size) || !["objective", "personal"].includes(r.type)) {
      fail("invalid-argument", "Geçersiz sıralama seçimi.");
    }
    if (r.type === "personal") {
      const theme = c.personal[input.themeId]; if (!theme) fail("invalid-argument", "Tema bulunamadı.");
      r.themeId = theme.id; r.orderedCandidateIds = order(list(theme.ids), r.privateSeed).slice(0, r.size);
    } else {
      r.metricId = input.metricId; const g = metricGroup(c, r.metricId, r.privateSeed); r.scope = g.scope;
      const rows = g.rows.sort((a, b) => a.value - b.value || a.id.localeCompare(b.id));
      for (let attempt = 0; attempt < 40; attempt++) {
        const chosen = [];
        for (let i = 0; i < r.size; i++) {
          const slice = rows.slice(Math.floor(i * rows.length / r.size), Math.floor((i + 1) * rows.length / r.size));
          chosen.push(order(slice.map((x) => x.id), r.privateSeed + attempt)[0]);
        }
        const values = Object.fromEntries(rows.map((x) => [x.id, x.value]));
        if (new Set(chosen.map((i) => values[i])).size < (r.size === 5 ? 4 : 7)) continue;
        r.orderedCandidateIds = order(chosen, r.privateSeed + "reveal");
        r.values = Object.fromEntries(chosen.map((i) => [i, values[i]])); break;
      }
    }
    if (r.orderedCandidateIds.length !== r.size || new Set(r.orderedCandidateIds).size !== r.size) {
      fail("failed-precondition", "Tam ve çeşitli liste üretilemedi.");
    }
  }
  return r;
}
function act(c, r, input) {
  if (input.action === "finish") {
    r.finished = true; r.reason = "Oyun sonlandırıldı."; return;
  }
  if (r.mode === "this_or_that") {
    if (input.action === "undo") {
      if (!r.history.length) fail("failed-precondition", "Geri alınacak seçim yok.");
      r.history.pop(); return;
    }
    if (input.action !== "choose") fail("invalid-argument", "Geçersiz tercih.");
    const b = bracket(r.orderedCandidateIds, r.history);
    if (![b.leftId, b.rightId].includes(input.candidateId)) fail("invalid-argument", "Rakiplerden birini seç.");
    r.history.push({matchNumber: b.matchNumber, leftId: b.leftId, rightId: b.rightId, winnerId: input.candidateId});
    r.championId = bracket(r.orderedCandidateIds, r.history).championId;
    if (r.championId) {
      r.completed = true; r.finished = true;
    }
  } else if (r.mode === "higher_lower") {
    if (input.action === "next" && r.answered) {
      r.answered = false; r.question = higherPair(c, r);
      if (!r.question) {
        r.finished = true; r.reason = "Uygun çift kalmadı; serin korundu.";
      }
      return;
    }
    if (input.action !== "guess" || r.answered || input.questionId !== r.question.id ||
      !["higher", "lower"].includes(input.direction)) fail("failed-precondition", "Bu soru zaten cevaplandı.");
    const q = r.question; const known = q.knownSide === 0 ? q.leftValue : q.rightValue;
    const hidden = q.knownSide === 0 ? q.rightValue : q.leftValue;
    r.correct = (hidden > known) === (input.direction === "higher"); r.answered = true;
    r.history.push({...q, direction: input.direction, correct: r.correct});
    if (r.correct) r.streak++; else {
      r.finished = true; r.reason = "Seri tamamlandı.";
    }
  } else {
    const slot = input.slot; const current = r.orderedCandidateIds[r.placements.length];
    if (input.action !== "place" || input.candidateId !== current || !Number.isInteger(slot) ||
      slot < 0 || slot >= r.size || r.placements.some((p) => p.slot === slot)) {
      fail("invalid-argument", "Boş konum ve sıradaki oyuncu gerekli.");
    }
    r.placements.push({slot, candidateId: current});
    if (r.placements.length === r.size) {
      r.completed = true; r.finished = true;
      if (r.type === "objective") {
        Object.assign(r, score([...r.placements].sort((a, b) => a.slot - b.slot)
            .map((p) => r.values[p.candidateId])));
      }
    }
  }
}
function candidate(c, id, tournament = false) {
  const p = tournament ? c.candidates[id] : c.players[id];
  if (!p) fail("failed-precondition", "Sürümlü aday bulunamadı.");
  const {seasonKey, ...safe} = p; delete safe.legacyHighlight;
  return {...safe, ...(p.contentStatus === "verified" ? {seasonKey} : {})};
}
function publicRun(c, raw) {
  const r = hydrate(raw); if (!r) return null;
  const out = Object.fromEntries(["id", "ownerUid", "renderTemplateVersion", "seedOrderHash", "mode", "phase",
    "revision", "dataVersion", "createdAt", "completedAt", "finished", "completed", "practice", "earnedCoins",
    "rewardKeys", "bracketId", "size", "type", "metricId", "themeId", "scope", "streak", "answered", "correct",
    "reason", "rewardReason", "contentVerified"].filter((k) => r[k] != null).map((k) => [k, r[k]]));
  if (r.mode === "this_or_that") {
    Object.assign(out, bracket(r.orderedCandidateIds, r.history), {history: r.history,
      orderedCandidateIds: r.orderedCandidateIds,
      candidates: Object.fromEntries(r.orderedCandidateIds.map((i) => [i, candidate(c, i, true)]))});
  } else if (r.mode === "higher_lower") {
    if (r.question) {
      const q = r.question;
      out.question = {id: q.id, left: candidate(c, q.leftId), right: candidate(c, q.rightId),
        knownSide: q.knownSide, difficulty: q.difficulty,
        ...(q.knownSide === 0 || r.answered ? {leftValue: q.leftValue} : {}),
        ...(q.knownSide === 1 || r.answered ? {rightValue: q.rightValue} : {})};
    }
  } else {
    out.placements = r.placements.map((p) => ({...p, player: candidate(c, p.candidateId)}));
    if (!r.finished) out.current = candidate(c, r.orderedCandidateIds[r.placements.length]);
    if (r.completed && r.type === "objective") {
      Object.assign(out, {score: r.score, exactMatches: r.exactMatches, comparable: r.comparable, values: r.values});
    }
  }
  return out;
}
module.exports = {catalog, fail, hash, list, modes, hydrate, bracket, score, create, act, publicRun, higherPair};
