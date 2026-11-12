"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const zlib = require("node:zlib");
const {RewardError} = require("./rewarded_ads");
// The catalog is about 110 MB in memory: it loads on first use, so callers that only
// need MODES or RULE (profile and ranked stats) stay small.
let loaded = null;
const loadCatalog = () => loaded ||=
  JSON.parse(zlib.gunzipSync(fs.readFileSync(__dirname + "/config/pvp_catalog.json.gz")));
const MODES = ["club_club", "club_country", "grid_classic", "grid_random", "grid_reverse",
  "random_five", "cinko", "loto", "club_manager"];
const RULE = "PVP_RULES_V1";
const terminal = (r) => ["finished", "cancelled", "forfeit", "expired"].includes(r.status);
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (x) => crypto.createHash("sha256").update(typeof x === "string" ? x : JSON.stringify(x)).digest("hex");
const norm = (s) => String(s || "").toLowerCase().replace(/ı/g, "i").replace(/ß/g, "ss")
    .replace(/ø/g, "o").replace(/ł/g, "l").replace(/đ/g, "d").normalize("NFKD").replace(/[^a-z0-9]/g, "");
const list = (x) => Array.isArray(x) ? x : Object.values(x || {});
const shuffle = (a, seed) => [...a].sort((a, b) => hash(seed + JSON.stringify(a)).localeCompare(hash(
    seed + JSON.stringify(b))));
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
function matches(c, p, id) {
  const k = c.criteria[id]; if (!k || !p) return false;
  return k.type === "club" ? p.clubs.includes(k.value) : k.type === "country" ?
    p.countryKeys.includes(k.value) : k.type === "coach" ? (p.coaches || []).includes(k.value) :
    k.type === "league" && p.leagues.includes(k.value);
}
// Reverse Grid: every club, country and coach the given players all share (labels).
function acceptedFor(c, ids) {
  const first = c.players[ids[0]];
  const keys = [...first.clubs.map((x) => "club:" + x), ...first.countryKeys.map((x) => "country:" + x),
    ...(first.coaches || []).map((x) => "coach:" + x)];
  return keys.filter((k) => c.criteria[k] && ids.every((id) => matches(c, c.players[id], k)))
      .map((k) => c.criteria[k].label);
}
function player(c, id) {
  const p = c.players[String(id)]; return p ? {id: p.id, name: p.name, country: p.countries.join(" / "),
    position: p.position} : null;
}
const FORMATIONS = {"433": {GK: 1, DEF: 4, MID: 3, ATT: 3}, "442": {GK: 1, DEF: 4, MID: 4, ATT: 2},
  "352": {GK: 1, DEF: 3, MID: 5, ATT: 2}, "451": {GK: 1, DEF: 4, MID: 5, ATT: 1}};
// Club Manager pool: each position mixes stars (cost 14+), regulars (10) and cheap
// players (6), so the best-rated XI costs about 140 against a budget of 120 and
// every formation still has a cheap XI (66 or less).
const MANAGER_TIERS = {GK: [1, 1, 1], DEF: [2, 2, 3], MID: [2, 3, 3], ATT: [2, 2, 3]};
const MANAGER_BUDGET = 120;
function managerPool(c, seed) {
  const pool = [];
  for (const [pos, [stars, regular, cheap]] of Object.entries(MANAGER_TIERS)) {
    const all = Object.values(c.players).filter((p) => p.position === pos && p.rank <= 6000);
    const tier = (test, n, key) => shuffle(all.filter((p) => test(p.cost)), seed + key + pos).slice(0, n);
    const chosen = [...tier((x) => x >= 14, stars, "star"), ...tier((x) => x === 10, regular, "regular"),
      ...tier((x) => x <= 6, cheap, "cheap")];
    if (chosen.length !== stars + regular + cheap) fail("failed-precondition", "Dengeli kadro havuzu bulunamadı.");
    pool.push(...chosen.map((p) => p.id));
  }
  return {id: hash(seed + "manager"), pool, budget: MANAGER_BUDGET, buildMs: 180000};
}
// Club-Club / Club-Country pairs need at least 6 shared players (Random Grid too).
const PAIR_MIN_ANSWERS = 6;
const POPULAR_RANK = 3000;
// Coach x club pairs only serve Random Grid (never Club-Club, never friend choices).
const coachPair = (p) => p.criteria[0].startsWith("coach:");
const pairPool = (c, mode) => c.pairs.filter((p) => p.answers.length >= PAIR_MIN_ANSWERS &&
  (mode === "grid_random" || !coachPair(p)) &&
  (mode === "club_country" ? p.criteria[1].startsWith("country:") : p.criteria[1].startsWith("club:")));
// Random Grid coach rounds per board (owner): ~25% none, ~60% one, ~15% two.
function withCoaches(pairs, seed) {
  const roll = parseInt(hash([seed, "coach"]).slice(0, 8), 16) / 0x100000000;
  const coaches = shuffle(pairs.filter(coachPair), seed).slice(0, roll < 0.25 ? 0 : roll < 0.85 ? 1 : 2);
  return shuffle([...coaches, ...shuffle(pairs.filter((p) => !coachPair(p)), seed).slice(0, 5 - coaches.length)], seed);
}
const pairFits = (mode, p, left, right) => p.criteria[0] === left && p.criteria[1] === right ||
  mode === "club_club" && p.criteria[0] === right && p.criteria[1] === left;
// Picks one country with weight sqrt(its pair count), then keeps that country's pairs.
function balancedCountry(pairs, seed) {
  const groups = {};
  for (const p of pairs) (groups[p.criteria[1]] ||= []).push(p);
  const keys = Object.keys(groups).sort(); const weights = keys.map((k) => Math.sqrt(groups[k].length));
  let roll = parseInt(hash([seed, "country"]).slice(0, 8), 16) / 0x100000000 * weights.reduce((a, b) => a + b, 0);
  for (let i = 0; i < keys.length; i++) {
    roll -= weights[i];
    if (roll < 0) return groups[keys[i]];
  }
  return groups[keys.at(-1)] || [];
}
// Friend mode: option ids that make a playable pair with the other side's choice.
function pairOptions(c, mode, side, other) {
  const options = mode === "club_country" && side === "right" ? c.countryOptions : c.clubOptions;
  if (!other) return options;
  const pool = pairPool(c, mode);
  return options.filter((id) => pool.some((p) => side === "left" ? pairFits(mode, p, id, other) :
    pairFits(mode, p, other, id)));
}
// Friend Club modes: a choice for a player who pressed ready without one. It
// pairs with the other side's choice, or, while that is open, has at least
// one playable pair, so the other side always keeps options.
function autoChoice(c, mode, side, other, seed) {
  let options = pairOptions(c, mode, side, other);
  if (!other) {
    const pool = pairPool(c, mode);
    options = options.filter((id) => pool.some((p) => side === "left" ? p.criteria[0] === id ||
      mode === "club_club" && p.criteria[1] === id : p.criteria[1] === id ||
      mode === "club_club" && p.criteria[0] === id));
  }
  if (!options.length) fail("failed-precondition", "Bu seçimle oynanabilir eşleşme kalmadı; başka seçim yap.");
  return shuffle(options, hash([seed, "auto", side]))[0];
}
function puzzle(c, mode, seed, choices = {}) {
  if (!MODES.includes(mode)) fail("invalid-argument", "Geçersiz mod.");
  if (mode === "club_manager") return managerPool(c, seed);
  if (["club_club", "club_country", "grid_random"].includes(mode)) {
    let pairs = pairPool(c, mode);
    if (choices.left || choices.right) {
      pairs = pairs.filter((p) => pairFits(mode, p, choices.left, choices.right));
    } else if (mode !== "grid_random") {
      // Random and ranked pairs: at least three answers among the 3000 best-known
      // players, and for Club-Country every country gets a fair share instead
      // of France and Brazil dominating.
      pairs = pairs.filter((p) => p.answers.filter((id) => c.players[id].rank <= POPULAR_RANK).length >= 3);
      if (mode === "club_country") pairs = balancedCountry(pairs, seed);
    }
    const chosen = mode === "grid_random" && !choices.left && !choices.right ? withCoaches(pairs, seed) :
      shuffle(pairs, seed).slice(0, mode === "grid_random" ? 5 : 1);
    if (chosen.length !== (mode === "grid_random" ? 5 : 1)) {
      fail("failed-precondition",
          "Yeterli ortak futbolcu yok; seçimi değiştir.");
    }
    return {id: hash(chosen.map((p) => p.id)), rounds: chosen};
  }
  if (mode === "grid_classic") return structuredClone(shuffle(c.grids, seed)[0]);
  // Reverse answers come from the app picker (clubs and countries only), so no coach axes there.
  if (mode === "grid_reverse") {
    return structuredClone(shuffle(c.grids.filter((g) => ![...g.rows, ...g.cols].some((k) =>
      k.startsWith("coach:"))), seed)[0]);
  }
  if (mode === "cinko" || mode === "loto") return structuredClone(shuffle(c[mode], seed)[0]);
  // Random Five: one checked board per round (a 4-club player, 4+ with 3 clubs,
  // 20+ with 2), each new five sharing as few clubs as possible with the earlier
  // ones; older catalogs fall back to random clubs.
  if (mode === "random_five") {
    if (!c.five?.length) {
      const clubs = shuffle(c.clubOptions, seed);
      const boards = Array.from({length: FIVE_ROUNDS}, (_, i) => clubs.slice(i * 5 % (clubs.length - 4)).slice(0, 5));
      return {id: hash(seed + "five"), boards};
    }
    const order = shuffle(c.five, seed);
    // Depth-first in the shuffled order: the first five boards sharing no club
    // (a bounded search; a greedy pass can paint itself into a corner).
    let boards = []; let steps = 0;
    const pick = (from, chosen, seen) => {
      if (chosen.length === FIVE_ROUNDS) return chosen;
      for (let i = from; i < order.length && steps < 20000; i++) {
        steps++;
        if (order[i].clubs.some((k) => seen.has(k))) continue;
        const found = pick(i + 1, [...chosen, order[i]], new Set([...seen, ...order[i].clubs]));
        if (found) return found;
      }
      return null;
    };
    boards = pick(0, [], new Set()) || [];
    for (const b of order) if (boards.length < FIVE_ROUNDS && !boards.includes(b)) boards.push(b);
    return {id: hash(boards.map((b) => b.id)), boards: boards.map((b) => [...b.clubs])};
  }
  if (c.five?.length) return structuredClone(shuffle(c.five, seed)[0]);
  return {id: hash(seed + "five"), clubs: shuffle(c.clubOptions, seed).slice(0, 5)};
}
function hydrate(raw) {
  if (!raw) return null;
  return {...raw, ready: raw.ready || {}, choices: raw.choices || {}, presence: raw.presence || {},
    scores: raw.scores || {}, owners: raw.owners || {}, used: raw.used || {}, answers: raw.answers || {},
    squads: raw.squads || {}, receipts: raw.receipts || {}, audit: raw.audit || {}, rematch: raw.rematch || {},
    moveStats: raw.moveStats || {},
    // RTDB drops empty lists and maps: the draft and plan keep their shape.
    ...raw.draft ? {draft: {...raw.draft, picks: raw.draft.picks || {}}} : {},
    ...raw.plan ? {plan: {...raw.plan, choices: raw.plan.choices || {}}} : {}};
}
function start(r, c, time) {
  // Grid Random (randomBoard 1): no fixed rounds; pairs are drawn on the board.
  if (r.mode === "grid_random") r.randomBoard = 1;
  r.puzzle = r.randomBoard ? {id: hash([r.seed, "board"])} : r.mode === "club_manager" ? draftPool(c, r.seed) :
    puzzle(c, r.mode, r.seed, r.choices);
  r.seedId = hash([r.seed, r.puzzle.id, r.dataRevision, r.ruleVersion]);
  r.status = "countdown"; r.startsAt = time + 5000;
  const duration = r.mode === "loto" ? LOTO_CALLS * LOTO_CALL_MS + (LOTO_CALLS - 1) * LOTO_REVEAL_MS :
    r.mode === "club_manager" ? 180000 :
    r.mode === "grid_random" && !r.randomBoard ? 160000 :
    r.mode === "random_five" ? FIVE_ROUNDS * FIVE_ANSWER_MS + (FIVE_ROUNDS - 1) * FIVE_REVEAL_MS :
    ["club_club", "club_country"].includes(r.mode) ? 90000 : 30 * 45000;
  r.endsAt = r.startsAt + duration; r.turnUid = parseInt(hash(r.seed).slice(0, 8), 16) % 2 ? r.host : r.guest;
  r.turnDeadline = r.startsAt + 45000; r.scores = {[r.host]: 0, [r.guest]: 0};
  r.presence = {[r.host]: time, [r.guest]: time};
  if (r.mode === "random_five") {
    r.fiveRules = 3; r.fiveStarts = [r.startsAt];
  }
  if (r.mode.startsWith("grid_")) r.gridRules = 2;
  if (r.mode === "club_manager") {
    r.managerRules = 3; draftStart(r, time);
  }
  if (r.mode === "loto") {
    r.lotoRules = 3; r.lotoCalls = [r.startsAt]; r.lotoQueue = shuffle(r.puzzle.players, hash([r.seed, "queue"]));
  }
  if (r.mode === "cinko") {
    // Moving first is worth about a point in Çinko, so the second player starts with 1.
    r.cinkoRules = 2; r.cinkoBonusUid = r.turnUid === r.host ? r.guest : r.host;
    r.scores[r.cinkoBonusUid] = CINKO_SECOND_BONUS;
  }
}
// Wrong guesses cost something in the free-for-all modes: a wrong move locks
// that player (Loto 3 s, Club-Club / Club-Country 2 s), the match allows a
// limited number of wrong moves (then no more moves), and moves are at least
// 400 ms apart.
const PENALTY = {loto: {lockMs: 3000, maxWrong: 8}, club_club: {lockMs: 2000, maxWrong: 10},
  club_country: {lockMs: 2000, maxWrong: 10}, random_five: {lockMs: 2000, maxWrong: 10}};
// Random Five (rooms started with fiveRules 2): clubs matched -> points; 3+ clubs earn a bonus.
const FIVE_POINTS = [0, 1, 2, 4, 6, 8];
// Random Five rounds (fiveRules 3): a new five each round; both players name one
// player for it, hidden until the round closes (both answered or 25 s). The
// answers stay open 4 s, then the next five comes in.
const FIVE_ROUNDS = 5;
const FIVE_ANSWER_MS = 25000;
const FIVE_REVEAL_MS = 4000;
const LOTO_LINE_BONUS = 2;
// Loto (rooms started with lotoRules 3), as the bot plays it: each side has its own card of
// the same 16 cells; the board's 16 players are called one by one, the same order for
// both. A call lasts 15 s (sooner once both played): place the player on a cell of your
// own card or pass. The call then closes and both results open: a right cell +1, a row or
// column of your card all right +2 once; a wrong cell stays taken. Equal points go to fewer
// wrong cells, then the faster right answers.
const LOTO_CALLS = 16;
const LOTO_CALL_MS = 15000;
const LOTO_REVEAL_MS = 2000;
const lotoLinesOf = (cell) => {
  const row = Math.floor(cell / 4); const col = cell % 4;
  return [["r" + row, [0, 1, 2, 3].map((k) => row * 4 + k)], ["c" + col, [0, 1, 2, 3].map((k) => k * 4 + col)]];
};
function lotoReveal(r, a) {
  for (const uid of [r.host, r.guest]) {
    const x = a[uid] ||= {timeout: true};
    if (x.cell === undefined) continue;
    const card = (r.cards ||= {})[uid] ||= {};
    card["c" + x.cell] = {playerId: x.playerId, correct: !!x.correct};
    const st = r.moveStats[uid] ||= {wrong: 0};
    if (!x.correct) {
      st.wrong = (st.wrong || 0) + 1; continue;
    }
    r.scores[uid] = (r.scores[uid] || 0) + 1;
    const done = (r.lotoLines ||= {})[uid] ||= {};
    for (const [key, line] of lotoLinesOf(x.cell)) {
      if (!done[key] && line.every((k) => card["c" + k]?.correct)) {
        done[key] = true; r.scores[uid] += LOTO_LINE_BONUS; x.lines = [...x.lines || [], key];
      }
    }
  }
}
function lotoSync(r, time) {
  if (r.lotoRules !== 3 || terminal(r) || r.status !== "playing") return;
  r.lotoCalls = list(r.lotoCalls).length ? list(r.lotoCalls) : [r.startsAt];
  for (;;) {
    const i = r.lotoCalls.length - 1; const a = r.answers[i] || {};
    if (!a.revealed) {
      const deadline = r.lotoCalls[i] + LOTO_CALL_MS; const both = a[r.host] && a[r.guest];
      if (!both && time < deadline) return;
      a.revealed = true; a.closedAt = both ? Math.max(a[r.host].at, a[r.guest].at) : deadline;
      lotoReveal(r, a); r.answers[i] = a;
    }
    if (i === LOTO_CALLS - 1) {
      finish(r, "finished", "16 futbolcu çekildi.", a.closedAt); return;
    }
    const next = a.closedAt + LOTO_REVEAL_MS;
    if (time < next) return;
    r.lotoCalls.push(next);
  }
}
function lotoMove(c, r, uid, input, time) {
  lotoSync(r, time);
  if (terminal(r)) fail("failed-precondition", "Maç bitti.");
  const i = r.lotoCalls.length - 1; const a = r.answers[i] || {};
  if (a.revealed || input.round !== undefined && Number(input.round) !== i) {
    fail("failed-precondition", "Bu çekiliş kapandı; sıradaki futbolcu geliyor.");
  }
  if (a[uid]) fail("already-exists", "Bu futbolcu için hamleni yaptın; rakibini bekle.");
  const id = r.lotoQueue[i];
  if (input.action === "pass") {
    a[uid] = {pass: true, at: time};
  } else {
    if (!/^(0|[1-9][0-9]?)$/.test(String(input.targetId))) fail("invalid-argument", "Boş bir kutu seç.");
    const cell = Number(input.targetId);
    if (cell >= 16 || r.cards?.[uid]?.["c" + cell]) fail("invalid-argument", "Bu kutu dolu; boş bir kutu seç.");
    a[uid] = {cell, playerId: id, correct: matches(c, c.players[id], r.puzzle.criteria[cell]), at: time};
  }
  r.answers[i] = a; lotoSync(r, time);
  return {accepted: true, submitted: true, round: i};
}
function lotoTieBreak(r) {
  const wrong = (uid) => r.moveStats?.[uid]?.wrong || 0;
  if (wrong(r.host) !== wrong(r.guest)) return wrong(r.host) < wrong(r.guest) ? r.host : r.guest;
  const calls = list(r.lotoCalls);
  const spent = (uid) => list(r.answers).reduce((sum, a, i) => sum + (a?.[uid]?.correct ? a[uid].at - calls[i] : 0), 0);
  if (spent(r.host) !== spent(r.guest)) return spent(r.host) < spent(r.guest) ? r.host : r.guest;
  return null;
}
const MIN_GAP_MS = 400;
function guard(r, uid, time) {
  const rule = PENALTY[r.mode]; const st = r.moveStats[uid] ||= {wrong: 0};
  if ((st.wrong || 0) >= rule.maxWrong) {
    fail("resource-exhausted", `${rule.maxWrong} yanlış hamle hakkın doldu; bu maçta yeni hamle yapamazsın.`);
  }
  if (time < (st.lockUntil || 0)) {
    fail("resource-exhausted", `Yanlış hamle: ${Math.ceil((st.lockUntil - time) / 1000)} sn bekle.`);
  }
  if (time - (st.lastMoveAt || 0) < MIN_GAP_MS) fail("resource-exhausted", "Biraz yavaş: hamleler arası kısa bekle.");
}
function record(r, uid, correct, time) {
  const st = r.moveStats[uid]; st.lastMoveAt = time;
  if (correct) st.lastCorrectAt = time;
  else {
    st.wrong = (st.wrong || 0) + 1; st.lockUntil = time + PENALTY[r.mode].lockMs;
  }
}
// Grid (rooms started with gridRules 2): equal scores go to the player with fewer wrong
// answers; a rare answer in Grid Random (the less known half of the pair) earns +1.
const GRID_RARE_BONUS = 1;
function gridTieBreak(r) {
  const a = r.moveStats?.[r.host]?.wrong || 0; const b = r.moveStats?.[r.guest]?.wrong || 0;
  return a === b ? null : a < b ? r.host : r.guest;
}
function gridWrong(r, uid, correct) {
  if (r.gridRules !== 2 || correct) return;
  const st = r.moveStats[uid] ||= {wrong: 0}; st.wrong = (st.wrong || 0) + 1;
}
// Equal scores: fewer wrong moves wins, then the earlier last correct move.
function raceTieBreak(r) {
  const a = r.moveStats?.[r.host] || {}; const b = r.moveStats?.[r.guest] || {};
  if ((a.wrong || 0) !== (b.wrong || 0)) return (a.wrong || 0) < (b.wrong || 0) ? r.host : r.guest;
  if (a.lastCorrectAt && b.lastCorrectAt && a.lastCorrectAt !== b.lastCorrectAt) {
    return a.lastCorrectAt < b.lastCorrectAt ? r.host : r.guest;
  }
  return null;
}
// Random Five rounds: equal points go to the player with more rounds scored,
// then the faster answers in all (a timeout counts the full 25 s).
function fiveTieBreak(r) {
  const rounds = list(r.answers).filter((a) => a?.revealed);
  const hits = (uid) => rounds.filter((a) => a[uid]?.points > 0).length;
  const spent = (uid) => rounds.reduce((sum, a, i) => sum + (a[uid]?.at ? a[uid].at - r.fiveStarts[i] :
    FIVE_ANSWER_MS), 0);
  if (hits(r.host) !== hits(r.guest)) return hits(r.host) > hits(r.guest) ? r.host : r.guest;
  if (spent(r.host) !== spent(r.guest)) return spent(r.host) < spent(r.guest) ? r.host : r.guest;
  return null;
}
function fiveScores(r) {
  for (const uid of [r.host, r.guest]) {
    r.scores[uid] = list(r.answers).filter((a) => a?.revealed).reduce((sum, a) => sum + (a[uid]?.points || 0), 0);
  }
}
// Closes the open round once both answered or its 25 s are up, and opens the
// next five 4 s later; the last round's close ends the match.
function fiveSync(r, time) {
  if (r.fiveRules !== 3 || terminal(r) || r.status !== "playing") return;
  r.fiveStarts = list(r.fiveStarts).length ? list(r.fiveStarts) : [r.startsAt];
  for (;;) {
    const i = r.fiveStarts.length - 1; const a = r.answers[i] || {};
    if (!a.revealed) {
      const deadline = r.fiveStarts[i] + FIVE_ANSWER_MS;
      const both = a[r.host] && a[r.guest];
      if (!both && time < deadline) return;
      a.revealed = true; a.closedAt = both ? Math.max(a[r.host].at, a[r.guest].at) : deadline;
      for (const uid of [r.host, r.guest]) a[uid] ||= {timeout: true, points: 0};
      r.answers[i] = a; fiveScores(r);
    }
    if (i === FIVE_ROUNDS - 1) {
      finish(r, "finished", "Beş tur tamamlandı.", a.closedAt); return;
    }
    const next = a.closedAt + FIVE_REVEAL_MS;
    if (time < next) return;
    r.fiveStarts.push(next);
  }
}
function fiveMove(c, r, uid, id, input, time) {
  fiveSync(r, time);
  if (terminal(r)) fail("failed-precondition", "Maç bitti.");
  const i = r.fiveStarts.length - 1; const a = r.answers[i] || {};
  if (a.revealed || input.round !== undefined && Number(input.round) !== i) {
    fail("failed-precondition", "Bu beşli kapandı; yeni beşli geliyor.");
  }
  if (a[uid]) fail("already-exists", "Bu beşli için tahminini yaptın; rakibini bekle.");
  if (r.used[uid + "__" + id]) fail("already-exists", "Bu futbolcuyu bu maçta zaten yazdın.");
  const clubs = r.puzzle.boards[i].filter((k) => matches(c, c.players[id], k)).length;
  const points = FIVE_POINTS[clubs];
  a[uid] = {playerId: id, clubs, points, at: time}; r.answers[i] = a; r.used[uid + "__" + id] = true;
  fiveSync(r, time);
  return {accepted: true, submitted: true, correct: points > 0, points, clubs, round: i};
}
function finish(r, status, reason, time, winner) {
  if (terminal(r)) return;
  r.status = status; r.reason = reason; r.finishedAt = time;
  r.winnerUid = winner === undefined ? r.scores[r.host] > r.scores[r.guest] ? r.host :
    r.scores[r.host] < r.scores[r.guest] ? r.guest : r.fiveRules === 3 ? fiveTieBreak(r) :
    r.lotoRules === 3 ? lotoTieBreak(r) :
    PENALTY[r.mode] ? raceTieBreak(r) :
    r.gridRules === 2 && (r.mode !== "grid_random" || r.randomBoard) ? gridTieBreak(r) : null : winner;
  if (r.series && ["finished", "forfeit"].includes(status)) {
    r.series.wins ||= {};
    if (r.winnerUid) r.series.wins[r.winnerUid] = (r.series.wins[r.winnerUid] || 0) + 1;
    else r.series.draws = (r.series.draws || 0) + 1;
    if (r.series.limit > 1) r.series.results = [...r.series.results || [], r.winnerUid || null];
  }
  if (r.series?.limit > 1) seriesClose(r.series, status);
  r.resultHash = hash([r.seedId, r.scores, r.owners, r.answers, r.squads, r.status, r.reason, r.winnerUid]);
}
// Three-game series: the first to two wins takes it; at most three games, draws
// count as played. A game that never got played (cancelled, expired) ends the series.
function seriesClose(s, status) {
  const wins = s.wins || {}; const need = Math.floor(s.limit / 2) + 1;
  const best = Math.max(0, ...Object.values(wins));
  s.need = need;
  s.over = best >= need || s.game >= s.limit || !["finished", "forfeit"].includes(status);
  if (!s.over) return;
  const [a, b] = Object.entries(wins).sort(([, x], [, y]) => y - x);
  s.winner = a && (!b || a[1] > b[1]) ? a[0] : null;
}
function randomRound(r, time) {
  return Math.min(4, Math.floor((time - r.startsAt) / 32000));
}
function revealRounds(r, time) {
  for (let i = 0; i < 5; i++) {
    const a = r.answers[i] || {}; const end = r.startsAt + i * 32000 + 30000;
    if (time >= end || a[r.host] && a[r.guest]) {
      a.revealed = true;
      for (const uid of [r.host, r.guest]) a[uid] ||= {correct: false, timeout: true};
      r.answers[i] = a;
    }
  }
  for (const uid of [r.host, r.guest]) {
    r.scores[uid] = Object.values(r.answers).filter((a) => a.revealed && a[uid]?.correct)
        .reduce((sum, a) => sum + 1 + (a[uid].bonus || 0), 0);
  }
}
function advance(r, time) {
  if (terminal(r)) return;
  if (["waiting", "ready"].includes(r.status) && time >= r.createdAt + 300000) {
    finish(r, "expired", "Odanın bekleme süresi doldu.", time, null); return;
  }
  if (r.status === "waiting") return;
  if (r.status === "countdown" && time >= r.startsAt) r.status = "playing";
  if (!["countdown", "playing"].includes(r.status)) return;
  const end = Math.min(time, r.endsAt);
  const absent = [r.host, r.guest].filter((uid) => end - r.presence[uid] > 30000);
  if (absent.length) {
    finish(r, absent.length === 2 ? "cancelled" : "forfeit", "30 saniyelik yeniden bağlanma süresi doldu.", end,
        absent.length === 1 ? [r.host, r.guest].find((u) => u !== absent[0]) : null); return;
  }
  if (r.mode === "grid_random" && !r.randomBoard) revealRounds(r, time);
  fiveSync(r, Math.min(time, r.endsAt));
  lotoSync(r, Math.min(time, r.endsAt));
  managerSync(r, time);
  if (terminal(r)) return;
  if (time >= r.endsAt) {
    // Club Manager (managerRules 2): the side that locked its XI wins when the other did not.
    const locked = r.mode === "club_manager" && r.managerRules === 2 ?
      [r.host, r.guest].filter((uid) => r.squads[uid]) : [];
    if (locked.length === 1) {
      finish(r, "forfeit", "Rakip kadrosunu süresinde kilitlemedi.", r.endsAt, locked[0]); return;
    }
    finish(r, r.mode === "club_manager" ? "cancelled" : "finished", "Süre tamamlandı.", r.endsAt,
        r.mode === "club_manager" ? null : undefined); return;
  }
  if (["grid_classic", "grid_reverse", "cinko"].includes(r.mode) || r.randomBoard) {
    while (time >= r.turnDeadline && !terminal(r)) {
      if (r.cinkoRules === 2) cinkoPass(r, r.turnUid, r.turnDeadline, true);
      // A pair drawn and left unplayed is gone with the turn.
      if (r.randomBoard) r.pending = null;
      r.turnUid = r.turnUid === r.host ? r.guest : r.host; r.turnDeadline += 45000;
    }
  }
}
// ---- Futbol Çinko, same rules as Botla Oyna (rooms started with cinkoRules 2):
// pick an unused player and a connected group of open cells (no diagonals);
// each matching cell is yours (+1), each wrong cell costs 1 point and stays open.
// A player is used once per match, right or wrong. Pass is allowed; four passes
// or timeouts in a row end the match. The match ends when no open cell has an
// unused answer left (or at the time limit); the higher score wins.
const CINKO_SIZE = 5;
const CINKO_PASS_END = 4;
const CINKO_SECOND_BONUS = 1;
const answerIndex = new WeakMap();
function answersOf(c, k) {
  let m = answerIndex.get(c);
  if (!m) answerIndex.set(c, m = new Map());
  if (!m.has(k)) m.set(k, Object.keys(c.players).filter((id) => matches(c, c.players[id], k)));
  return m.get(k);
}
function cinkoOpen(c, r) {
  return r.puzzle.criteria.map((_, i) => i).filter((i) => !r.owners[i] &&
    answersOf(c, r.puzzle.criteria[i]).some((id) => !r.used[id]));
}
function connected(cells) {
  const left = new Set(cells.slice(1)); const seen = [cells[0]];
  for (let i = 0; i < seen.length; i++) {
    const x = seen[i];
    for (const n of [x - CINKO_SIZE, x + CINKO_SIZE, x % CINKO_SIZE ? x - 1 : -1, (x + 1) % CINKO_SIZE ? x + 1 : -1]) {
      if (left.delete(n)) seen.push(n);
    }
  }
  return !left.size;
}
// The last five moves (passes and timeouts too) for the move list.
function cinkoLog(r) {
  r.log = [...list(r.log), r.last].slice(-5);
}
function cinkoTurn(r, uid, time) {
  r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000;
}
function cinkoPass(r, uid, time, timeout = false) {
  r.passes = (r.passes || 0) + 1; r.last = {uid, pass: true, timeout, points: 0}; cinkoLog(r);
  if (r.passes >= CINKO_PASS_END) finish(r, "finished", "İki oyuncu da üst üste pas geçti.", time);
}
function cinkoMove(c, r, uid, input, time) {
  if (input.action === "pass") {
    cinkoPass(r, uid, time); if (!terminal(r)) cinkoTurn(r, uid, time);
    return {accepted: true, pass: true, points: 0};
  }
  const id = c.shadowIds?.[String(input.playerId)] || String(input.playerId); const p = c.players[id];
  if (!p) fail("invalid-argument", "Listeden tek bir futbolcu seç.");
  if (r.used[id]) fail("already-exists", "Bu futbolcu bu maçta kullanıldı.");
  const cells = input.cells; const open = cinkoOpen(c, r);
  if (!Array.isArray(cells) || !cells.length || new Set(cells).size !== cells.length ||
    cells.some((i) => !open.includes(i))) fail("invalid-argument", "Önce oyuncu ve açık kutular seç.");
  if (!connected(cells)) {
    fail("invalid-argument", "Kutular yan yana veya üst üste bağlı kalmalı. Çapraz bağlantı sayılmaz.");
  }
  const right = cells.filter((i) => matches(c, p, r.puzzle.criteria[i]));
  const wrong = cells.filter((i) => !right.includes(i)); const points = right.length - wrong.length;
  for (const i of right) r.owners[i] = {uid, playerId: id};
  r.used[id] = {uid, points, playerId: id}; r.scores[uid] += points; r.passes = 0;
  r.last = {uid, playerId: id, correct: right, wrong, points}; cinkoLog(r);
  if (!cinkoOpen(c, r).length) finish(r, "finished", "Tahtada açık kutu kalmadı.", time);
  else cinkoTurn(r, uid, time);
  return {accepted: true, correct: right.length > 0, points};
}
function lineWin(owners, uid, n) {
  const lines = [];
  for (let i = 0; i < n; i++) {
    lines.push(Array.from({length: n}, (_, j) => i * n + j));
    lines.push(Array.from({length: n}, (_, j) => j * n + i));
  }
  lines.push(Array.from({length: n}, (_, j) => j * (n + 1)), Array.from({length: n}, (_, j) => (j + 1) * (n - 1)));
  return lines.some((line) => line.every((i) => owners[i]?.uid === uid));
}
function validateXi(c, r, input) {
  const ids = input.playerIds; const f = FORMATIONS[input.formation]; const tactics = input.tactics;
  if (!f || !Array.isArray(ids) || ids.length !== 11 || new Set(ids).size !== 11 ||
    ids.some((id) => !r.puzzle.pool.includes(id))) fail("invalid-argument", "Havuzdan 11 farklı oyuncu seç.");
  const xi = ids.map((id) => c.players[id]);
  if (Object.entries(f).some(([p, n]) => xi.filter((x) => x.position === p).length !== n)) {
    fail("failed-precondition", "Kadro dizilişin pozisyonlarını karşılamıyor.");
  }
  if (xi.reduce((n, p) => n + p.cost, 0) > r.puzzle.budget) fail("failed-precondition", "Kadro bütçeyi aşıyor.");
  if (!tactics || ["press", "tempo", "width"].some((k) => !Number.isFinite(tactics[k]) ||
      tactics[k] < 0 || tactics[k] > 1)) {
    fail("invalid-argument", "Geçersiz taktik.");
  }
  return {playerIds: [...ids].sort(), formation: input.formation, tactics: {press: tactics.press, tempo:
      tactics.tempo, width: tactics.width}};
}
function power(c, squad) {
  const xi = squad.playerIds.map((id) => c.players[id]); let link = 0;
  for (let i = 0; i < 11; i++) {
    for (let j = i + 1; j < 11; j++) {
      const a = xi[i]; const b = xi[j]; const club = a.linkClubs.some((x) => b.linkClubs.includes(x));
      const country = a.countryKeys.some((x) => b.countryKeys.includes(x));
      link += club && country ? 1.45 : club ? 1 : country ? .55 : a.linkLeagues.some((x) =>
        b.linkLeagues.includes(x)) ? .2 : 0;
    }
  }
  const t = squad.tactics;
  const mult = clamp((1 - (Math.abs(t.press - .5) + Math.abs(t.tempo - .5) + Math.abs(t.width - .5)) * .04 +
    1 + t.press * .03 + t.tempo * .025) / 2, .92, 1.08);
  return clamp((xi.reduce((n, p) => n + p.rating, 0) / 11 * .72 + clamp(link * .35, 0,
      14) + 4 * 1.2 + 8) * mult, 40, 98);
}
// Rooms started with managerRules 2: tactics are a cycle, not a ladder. Press beats
// tempo, tempo beats width, width beats press; the team power uses neutral tactics,
// so no setting wins against every other. Less xG noise, and a draw goes to penalties.
const NEUTRAL = {press: .5, tempo: .5, width: .5};
function counter(a, b) {
  return a.press * b.tempo + a.tempo * b.width + a.width * b.press;
}
function penalties(r, powers, rnd) {
  const score = {[r.host]: 0, [r.guest]: 0};
  const chance = (uid, other) => clamp(.75 + (powers[uid] - powers[other]) * .004, .62, .86);
  for (let k = 0; k < 20; k++) {
    for (const uid of [r.host, r.guest]) {
      if (rnd(uid, 20 + k) < chance(uid, uid === r.host ? r.guest : r.host)) score[uid]++;
    }
    const left = Math.max(0, 4 - k);
    if (k >= 4 ? score[r.host] !== score[r.guest] : Math.abs(score[r.host] - score[r.guest]) > left) break;
  }
  if (score[r.host] === score[r.guest]) score[rnd(r.host, 99) < .5 ? r.host : r.guest]++;
  return score;
}
function simulate(c, r) {
  const v2 = r.managerRules === 2;
  const team = (uid) => v2 ? {...r.squads[uid], tactics: NEUTRAL} : r.squads[uid];
  const powers = {[r.host]: power(c, team(r.host)), [r.guest]: power(c, team(r.guest))};
  const goals = {}; const xg = {};
  for (const uid of [r.host, r.guest]) {
    const other = uid === r.host ? r.guest : r.host; const t = r.squads[uid].tactics;
    const rnd = (i) => parseInt(hash([r.seed, [r.host, r.guest].map((u) => [u, r.squads[u]]), uid,
      i]).slice(0, 8), 16) / 4294967296;
    const o = r.squads[other].tactics;
    xg[uid] = v2 ? clamp(1.2 + (powers[uid] - powers[other]) * .045 + rnd(0) * .3 +
      (counter(t, o) - counter(o, t)) * .3, .3, 4.5) :
      clamp(1.1 + (powers[uid] - powers[other]) * .045 + rnd(0) * .6 +
      (t.press - .5) * .25 + (t.tempo - .5) * .2 + (.5 - o.press) * .15, .3, 4.5);
    goals[uid] = Array.from({length: 8}, (_, i) => rnd(i + 1) < clamp(xg[uid] / 8, .02, .55)).filter(Boolean).length;
  }
  if (!v2 || goals[r.host] !== goals[r.guest]) return {powers, goals, xg};
  const shoot = (uid, i) => parseInt(hash([r.seed, [r.host, r.guest].map((u) => [u, r.squads[u]]), "pen", uid,
    i]).slice(0, 8), 16) / 4294967296;
  return {powers, goals, xg, penalties: penalties(r, powers, shoot)};
}
// ---- Club Manager draft (rooms started with managerRules 3) ----
// A pool of 36 well-known players (rating 76+); three anchor clubs bring four players
// each, so playing them together is worth chasing. The players pick in snake order
// (A B B A A B ...), 15 s a pick; a missed pick takes the best legal player. A side's
// picks must still fit one formation, which follows from its picks. Then each side
// picks a game plan and a captain (25 s, hidden), and the server plays the match:
// chances minute by minute, scorers and assists from the XIs, cards, and penalties
// after a draw. Everything the clock needs (ratings, positions, links) is stored in
// the room, so a missed pick or plan needs no catalog.
const DRAFT_POOL = {GK: 4, DEF: 11, MID: 12, ATT: 9};
const DRAFT_STARS = {GK: 1, DEF: 2, MID: 3, ATT: 3};
const DRAFT_PICKS = 22;
const DRAFT_PICK_MS = 15000;
const DRAFT_FIRST_PICK_MS = 20000;
const PLAN_MS = 25000;
const PLANS = ["attack", "counter", "possession"];
// Attack beats possession, possession beats counter, counter beats attack.
const PLAN_BEATS = {attack: "possession", possession: "counter", counter: "attack"};
// The unit each plan leans on.
const PLAN_UNIT = {attack: "ATT", counter: "DEF", possession: "MID"};
function draftLink(c, a, b) {
  const shared = a.linkClubs.find((x) => b.linkClubs.includes(x));
  const country = a.countryKeys.some((x) => b.countryKeys.includes(x));
  const club = shared ? c.clubs[shared]?.name || "" : "";
  if (shared && country) return [1.45, "both", club];
  if (shared) return [1, "club", club];
  if (country) return [.55, "country", a.countries.find((x) => b.countries.includes(x)) || ""];
  if (a.linkLeagues.some((x) => b.linkLeagues.includes(x))) return [.2, "league", ""];
  return null;
}
function draftPool(c, seed) {
  const all = Object.values(c.players).filter((p) => p.rating >= 76 && p.rank <= 5000 && DRAFT_POOL[p.position]);
  const chosen = []; const count = {GK: 0, DEF: 0, MID: 0, ATT: 0};
  const take = (p) => {
    if (chosen.includes(p.id) || count[p.position] >= DRAFT_POOL[p.position]) return false;
    chosen.push(p.id); count[p.position]++; return true;
  };
  const anchors = [];
  for (const k of shuffle(c.gridClubs || c.clubOptions, seed + "anchor")) {
    if (anchors.length === 3) break;
    const club = k.slice(5); const group = shuffle(all.filter((p) => p.clubs.includes(club)), seed + k);
    if (group.length < 4) continue;
    let n = 0;
    for (const p of group) if (n < 4 && take(p)) n++;
    if (n >= 3) anchors.push(k);
  }
  for (const pos of Object.keys(DRAFT_POOL)) {
    const group = all.filter((p) => p.position === pos);
    const stars = shuffle(group.filter((x) => x.rating >= 85), seed + "star" + pos).slice(0, DRAFT_STARS[pos]);
    for (const p of stars) take(p);
    for (const p of shuffle(group, seed + "fill" + pos)) take(p);
  }
  if (Object.keys(DRAFT_POOL).some((pos) => count[pos] !== DRAFT_POOL[pos])) {
    fail("failed-precondition", "Draft havuzu hazırlanamadı.");
  }
  const pool = shuffle(chosen, seed + "order");
  const meta = Object.fromEntries(pool.map((id) => [id, {...player(c, id),
    rating: Math.round(c.players[id].rating * 10) / 10}]));
  const links = [];
  for (let i = 0; i < pool.length; i++) {
    for (let j = i + 1; j < pool.length; j++) {
      const l = draftLink(c, c.players[pool[i]], c.players[pool[j]]);
      if (l) links.push([pool[i], pool[j], ...l]);
    }
  }
  return {id: hash([seed, "draft", pool]), pool, meta, links, anchors: anchors.map((k) => c.criteria[k]),
    draftRules: 4};
}
const counts = (q, ids) => {
  const n = {GK: 0, DEF: 0, MID: 0, ATT: 0};
  for (const id of ids) n[q.meta[id].position]++;
  return n;
};
// The formations a set of picks can still become.
function openFormations(q, ids) {
  const n = counts(q, ids);
  return Object.keys(FORMATIONS).filter((f) => Object.keys(n).every((pos) => n[pos] <= FORMATIONS[f][pos]));
}
function formationOf(q, ids) {
  const n = counts(q, ids);
  return Object.keys(FORMATIONS).find((f) => Object.keys(n).every((pos) => n[pos] === FORMATIONS[f][pos])) || null;
}
const draftPicker = (r, k) => {
  const second = r.draft.first === r.host ? r.guest : r.host;
  return Math.floor((k + 1) / 2) % 2 === 0 ? r.draft.first : second;
};
const taken = (r) => new Set([...list(r.draft.picks[r.host]), ...list(r.draft.picks[r.guest])]);
function legalPicks(r, uid) {
  const q = r.puzzle; const mine = list(r.draft.picks[uid]); const gone = taken(r);
  return q.pool.filter((id) => !gone.has(id) && openFormations(q, [...mine, id]).length);
}
// Where a side's picks stand, as the app draws them: one row per line (GK, DEF, MID,
// ATT), in pick order from the left, spread over the slots of the side's formation
// (or the first one it can still become).
const LINES = ["GK", "DEF", "MID", "ATT"];
function draftSpots(q, ids) {
  const f = FORMATIONS[formationOf(q, ids) || openFormations(q, ids)[0]] || {};
  const n = counts(q, ids); const seen = {}; const at = {};
  for (const id of ids) {
    const pos = q.meta[id].position; const i = seen[pos] = (seen[pos] ?? -1) + 1;
    at[id] = {line: LINES.indexOf(pos), index: i, x: (i + 1) / (Math.max(n[pos], f[pos] || 0) + 1)};
  }
  return at;
}
// Pools from draftRules 4 link only neighbours on the pitch: the next player in the
// same line, or a player in the line in front or behind standing within a quarter of
// the width (the keeper with his centre-backs, a lone striker with the three midfielders
// behind him); never keeper and striker. Older pools (3) keep every pair.
const NEIGHBOUR_X = .25;
const neighbours = (a, b) => a.line === b.line ? Math.abs(a.index - b.index) === 1 :
  Math.abs(a.line - b.line) === 1 && Math.abs(a.x - b.x) <= NEIGHBOUR_X + 1e-9;
// Fewer pairs count once only neighbours link: each is worth more, so a well-linked XI
// still reaches about the same chemistry (CHEM_PER_LINK, calibrated on drafted XIs).
const CHEM_PER_LINK = {3: .35, 4: .84};
function chemistry(q, ids) {
  const set = new Set(ids); let link = 0; const pairs = [];
  const near = q.draftRules >= 4 ? draftSpots(q, ids) : null;
  for (const [a, b, w, type, label] of list(q.links)) {
    if (set.has(a) && set.has(b) && (!near || neighbours(near[a], near[b]))) {
      link += w; if (type !== "league") pairs.push([a, b, type, label]);
    }
  }
  const value = clamp(link * CHEM_PER_LINK[q.draftRules >= 4 ? 4 : 3], 0, 14);
  return {value, score: Math.round(value / 14 * 100), pairs};
}
function draftStart(r, time) {
  r.draft = {first: r.turnUid, k: 0, picks: {[r.host]: [], [r.guest]: []}, deadline: r.startsAt + DRAFT_FIRST_PICK_MS};
  r.turnUid = r.draft.first; r.turnDeadline = r.draft.deadline;
  r.endsAt = r.startsAt + DRAFT_FIRST_PICK_MS + (DRAFT_PICKS - 1) * DRAFT_PICK_MS + PLAN_MS + 5000;
}
function draftPick(r, uid, id, time) {
  const d = r.draft; d.picks[uid] = [...list(d.picks[uid]), id]; d.k++;
  (d.log ||= []).push({uid, playerId: id, at: time});
  if (d.k === DRAFT_PICKS) {
    r.turnUid = null; r.turnDeadline = null; d.deadline = null;
    r.plan = {deadline: time + PLAN_MS, choices: {}};
  } else {
    r.turnUid = draftPicker(r, d.k); d.deadline = time + DRAFT_PICK_MS; r.turnDeadline = d.deadline;
  }
}
// A missed pick: the best-rated legal player (most links with the picks on a tie).
function autoPick(r, uid) {
  const q = r.puzzle; const mine = list(r.draft.picks[uid]);
  const score = (id) => q.meta[id].rating * 10 + chemistry(q, [...mine, id]).value;
  return legalPicks(r, uid).sort((a, b) => score(b) - score(a) || a.localeCompare(b))[0];
}
const defaultCaptain = (q, ids) => [...ids].sort((a, b) => q.meta[b].rating - q.meta[a].rating ||
  a.localeCompare(b))[0];
function managerSync(r, time) {
  if (r.managerRules !== 3 || terminal(r) || r.status !== "playing") return;
  while (r.draft && r.draft.k < DRAFT_PICKS && time >= r.draft.deadline) {
    const uid = r.turnUid; draftPick(r, uid, autoPick(r, uid), r.draft.deadline);
    r.draft.log[r.draft.log.length - 1].auto = true;
  }
  if (r.plan && time >= r.plan.deadline) {
    for (const uid of [r.host, r.guest]) {
      r.plan.choices[uid] ||= {plan: null, captain: defaultCaptain(r.puzzle, list(r.draft.picks[uid])), auto: true};
    }
    managerPlay(r, r.plan.deadline);
  }
}
function managerMove(r, uid, input, time) {
  managerSync(r, time);
  if (terminal(r)) fail("failed-precondition", "Maç bitti.");
  const q = r.puzzle;
  if (input.action === "pick") {
    if (!r.draft || r.draft.k >= DRAFT_PICKS) fail("failed-precondition", "Draft bitti; oyun planını seç.");
    if (r.turnUid !== uid) fail("permission-denied", "Seçim sırası rakibinde.");
    const id = String(input.playerId);
    if (!q.meta[id]) fail("invalid-argument", "Havuzdan bir futbolcu seç.");
    if (taken(r).has(id)) fail("already-exists", "Bu futbolcu seçildi.");
    if (!legalPicks(r, uid).includes(id)) fail("failed-precondition", "Bu mevkide yerin kalmadı; başka mevkiden seç.");
    draftPick(r, uid, id, time);
    return {accepted: true, picked: id};
  }
  if (input.action === "plan") {
    if (!r.plan) fail("failed-precondition", "Önce draft tamamlanmalı.");
    if (r.plan.choices[uid]) fail("already-exists", "Planın kilitlendi.");
    if (!PLANS.includes(input.plan)) fail("invalid-argument", "Bir oyun planı seç.");
    const mine = list(r.draft.picks[uid]);
    if (!mine.includes(String(input.captain))) fail("invalid-argument", "Kaptanı kendi kadrondan seç.");
    r.plan.choices[uid] = {plan: input.plan, captain: String(input.captain)};
    if (r.plan.choices[r.host] && r.plan.choices[r.guest]) managerPlay(r, time);
    return {accepted: true};
  }
  fail("invalid-argument", "Bu aşamada geçersiz işlem.");
}
// Team power: average rating (the captain +10 %), links, then the plan edges as xG.
function draftPower(q, ids, captain) {
  const avg = ids.reduce((n, id) => n + q.meta[id].rating * (id === captain ? 1.1 : 1), 0) / ids.length;
  const chem = chemistry(q, ids);
  return {power: clamp(avg * .72 + chem.value + 12.8, 40, 98), rating: Math.round(avg * 10) / 10,
    chem: Math.round(chem.value * 10) / 10, chemistry: chem.score};
}
const unitAvg = (q, ids, pos) => {
  const xs = ids.filter((id) => q.meta[id].position === pos).map((id) => q.meta[id].rating);
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
};
// Goal chance per attack: 0.11 plus 0.012 per power point of difference (10 points: about
// 72 % wins), the plan edge (+0.025 against the plan it beats, -0.015 against the one that
// beats it) and the plan's unit (+0.001 per rating point above the team average).
const DRAFT_BASE = .11;
const DRAFT_PER_POWER = .012;
function managerPlay(r, time) {
  const q = r.puzzle; const sides = [r.host, r.guest];
  const rnd = (...k) => parseInt(hash([r.seed, "match", r.draft.picks, r.plan.choices, ...k]).slice(0, 8), 16) /
    4294967296;
  const team = {};
  for (const uid of sides) {
    const ids = list(r.draft.picks[uid]); const ch = r.plan.choices[uid];
    team[uid] = {ids, plan: ch.plan, captain: ch.captain, formation: formationOf(q, ids),
      ...draftPower(q, ids, ch.captain)};
  }
  const events = []; const goals = {}; const xg = {}; const shots = {}; const edge = {};
  for (const uid of sides) {
    const other = uid === r.host ? r.guest : r.host; const me = team[uid]; const them = team[other];
    const planEdge = !me.plan || !them.plan ? 0 : PLAN_BEATS[me.plan] === them.plan ? .025 :
      PLAN_BEATS[them.plan] === me.plan ? -.015 : 0;
    const fit = me.plan ? (unitAvg(q, me.ids, PLAN_UNIT[me.plan]) - me.rating) * .001 : 0;
    edge[uid] = Math.round((planEdge + fit) * 1000) / 1000;
    const p = clamp(DRAFT_BASE + (me.power - them.power) / 2 * DRAFT_PER_POWER + planEdge + fit, .03, .4);
    const n = 10 + Math.floor(rnd(uid, "n") * 3);
    goals[uid] = 0; xg[uid] = Math.round(p * n * 100) / 100; shots[uid] = n;
    const weight = (id, scoring) => {
      const m = q.meta[id];
      const w = scoring ? {GK: 0, DEF: .8, MID: 2.5, ATT: 5}[m.position] : {GK: .1, DEF: 1, MID: 3, ATT: 2}[m.position];
      return w * (m.rating / 80) ** 2 * (id === me.captain ? 1.3 : 1);
    };
    const pick = (ids, x, scoring) => {
      const ws = ids.map((id) => weight(id, scoring)); let t = x * ws.reduce((a, b) => a + b, 0);
      for (let i = 0; i < ids.length; i++) if ((t -= ws[i]) <= 0) return ids[i];
      return ids[ids.length - 1];
    };
    for (let i = 0; i < n; i++) {
      const minute = 1 + Math.floor(rnd(uid, i, "min") * 90);
      const shooter = pick(me.ids, rnd(uid, i, "who"), true);
      if (rnd(uid, i, "goal") < p) {
        goals[uid]++;
        const helpers = me.ids.filter((id) => id !== shooter);
        const assist = rnd(uid, i, "assist") < .75 ? pick(helpers, rnd(uid, i, "helper"), false) : null;
        events.push({minute, uid, type: "goal", playerId: shooter, ...assist ? {assistId: assist} : {}});
      } else {
        const keeper = them.ids.find((id) => q.meta[id].position === "GK");
        const save = rnd(uid, i, "save") < .45;
        events.push({minute, uid, type: save ? "save" : "miss", playerId: shooter,
          ...save && keeper ? {keeperId: keeper} : {}});
      }
    }
    const cards = Math.floor(rnd(uid, "cards") * 3.2);
    for (let i = 0; i < cards; i++) {
      const outfield = me.ids.filter((id) => q.meta[id].position !== "GK");
      events.push({minute: 1 + Math.floor(rnd(uid, i, "card") * 90), uid, type: "yellow",
        playerId: outfield[Math.floor(rnd(uid, i, "booked") * outfield.length)]});
    }
  }
  events.sort((a, b) => a.minute - b.minute || (a.uid === r.host ? -1 : 1));
  // The score as it stood at the break.
  const half = {[r.host]: 0, [r.guest]: 0};
  for (const e of events) if (e.type === "goal" && e.minute <= 45) half[e.uid]++;
  const mid = (uid) => unitAvg(q, team[uid].ids, "MID") +
    (team[uid].plan === "possession" ? 4 : team[uid].plan === "counter" ? -4 : 0);
  const possession = Math.round(clamp(50 + (mid(r.host) - mid(r.guest)) * 1.5, 30, 70));
  const sim = {rules: 3, goals, xg, shots, half, events, edge,
    possession: {[r.host]: possession, [r.guest]: 100 - possession},
    teams: Object.fromEntries(sides.map((uid) => [uid, {formation: team[uid].formation, plan: team[uid].plan,
      captain: team[uid].captain, power: Math.round(team[uid].power * 10) / 10, rating: team[uid].rating,
      chem: team[uid].chem, chemistry: team[uid].chemistry}]))};
  const powers = {[r.host]: team[r.host].power, [r.guest]: team[r.guest].power};
  if (goals[r.host] === goals[r.guest]) sim.penalties = penalties(r, powers, (uid, i) => rnd("pen", uid, i));
  // Player of the match: goals and assists, the winning side first, then rating.
  const winner = sim.penalties ? (sim.penalties[r.host] > sim.penalties[r.guest] ? r.host : r.guest) :
    goals[r.host] > goals[r.guest] ? r.host : r.guest;
  const credit = {};
  for (const e of events) {
    if (e.type === "goal") credit[e.playerId] = (credit[e.playerId] || 0) + 3;
    if (e.assistId) credit[e.assistId] = (credit[e.assistId] || 0) + 2;
    if (e.type === "save") credit[e.keeperId] = (credit[e.keeperId] || 0) + 1;
  }
  sim.mvp = [...team[winner].ids].sort((a, b) => (credit[b] || 0) - (credit[a] || 0) ||
    q.meta[b].rating - q.meta[a].rating || a.localeCompare(b))[0];
  r.simulation = sim; r.scores = {...goals};
  finish(r, "finished", sim.penalties ? "Beraberlik penaltılarla bitti." : "Maç tamamlandı.", time, winner);
}
// Grid Random board (randomBoard 1), as against the bot: an empty 3x3 board whose
// three diagonal anchors each get a drawn club pair. The player to move either
// draws a pair, names a shared player and puts it on a free anchor (the pair
// becomes that anchor's row and column, swap flips them), or fills a cell whose
// row and column are open. Every move passes the turn; a wrong answer or the
// turn clock drops a drawn pair. Three in a line wins (the anchor diagonal too).
const ANCHORS = [2, 4, 6];
const BOARD_COACH_SHARE = 0.35;
// Unused players fitting an open crossing; null while its row or column is unknown.
function crossing(c, r, i) {
  const row = r.boardRows?.[Math.floor(i / 3)]; const col = r.boardCols?.[i % 3];
  if (!row || !col) return null;
  const inCol = new Set(answersOf(c, col));
  return answersOf(c, row).filter((id) => inCol.has(id) && !r.used[id]);
}
// Open crossings nobody can fill any more: locked, not waited for.
function deadCells(c, r) {
  return [0, 1, 3, 5, 7, 8].filter((i) => !r.owners[i] && crossing(c, r, i)?.length === 0);
}
// Fair pairs left to draw: no criterion already on the board, at most one coach
// pair per board, three unused answers with a well-known one among them.
function boardPairs(c, r) {
  const axes = new Set([...Object.values(r.boardRows || {}), ...Object.values(r.boardCols || {})]);
  // Only the best-known clubs (catalog gridClubs); older catalogs keep every club.
  const known = c.gridClubs ? new Set(c.gridClubs) : null;
  const famous = (p) => !known || p.criteria.every((k) => !k.startsWith("club:") || known.has(k));
  const coach = [...axes].some((k) => k.startsWith("coach:"));
  return pairPool(c, "grid_random").filter((p) => famous(p) && !p.criteria.some((k) => axes.has(k)) &&
    (!coach || !coachPair(p)) && p.answers.filter((id) => !r.used[id]).length >= 3 &&
    p.answers.some((id) => !r.used[id] && c.players[id].rank <= POPULAR_RANK));
}
function boardOpen(c, r) {
  if (ANCHORS.some((i) => !r.owners[i]) && boardPairs(c, r).length) return true;
  return [0, 1, 3, 5, 7, 8].some((i) => !r.owners[i] && crossing(c, r, i)?.length > 0);
}
// Loto: some unused board player still fits some empty cell.
function lotoPlayable(c, r) {
  const open = r.puzzle.criteria.map((k, i) => r.owners[i] ? null : k).filter(Boolean);
  return r.puzzle.players.some((id) => !r.used[id] && open.some((k) => matches(c, c.players[id], k)));
}
function boardMove(c, r, uid, input, time) {
  if (input.action === "draw") {
    if (r.pending) fail("failed-precondition", "Önce çekilen ikiliyi oyna.");
    if (!ANCHORS.some((i) => !r.owners[i])) fail("failed-precondition", "Boş çapa kalmadı.");
    const pairs = boardPairs(c, r);
    if (!pairs.length) fail("failed-precondition", "Yeni ikili kalmadı; açık bir hücre oyna.");
    const n = r.pairNumber || 0; const roll = parseInt(hash([r.seed, "coach", n]).slice(0, 8), 16) / 0x100000000;
    const coaches = pairs.filter(coachPair); const clubs = pairs.filter((p) => !coachPair(p));
    const from = coaches.length && (roll < BOARD_COACH_SHARE || !clubs.length) ? coaches : clubs;
    r.pending = {criteria: [...shuffle(from, hash([r.seed, "pair", n]))[0].criteria]}; r.pairNumber = n + 1;
    return {accepted: true, drawn: true};
  }
  if (!/^[0-8]$/.test(String(input.targetId))) fail("invalid-argument", "Boş bir hücre seç.");
  const i = Number(input.targetId); if (r.owners[i]) fail("invalid-argument", "Boş bir hücre seç.");
  const id = c.shadowIds?.[String(input.playerId)] || String(input.playerId); const p = c.players[id];
  if (!p) fail("invalid-argument", "Listeden tek bir futbolcu seç.");
  if (r.used[id]) fail("already-exists", "Bu futbolcu zaten kullanıldı.");
  let correct;
  if (r.pending) {
    if (!ANCHORS.includes(i)) fail("failed-precondition", "Çekilen ikiliyi boş bir çapaya yerleştir.");
    const [a, b] = r.pending.criteria; correct = matches(c, p, a) && matches(c, p, b);
    if (correct) {
      const swap = input.swap === true;
      (r.boardRows ||= {})[Math.floor(i / 3)] = swap ? b : a; (r.boardCols ||= {})[i % 3] = swap ? a : b;
    }
    r.pending = null;
  } else {
    if (ANCHORS.includes(i)) fail("failed-precondition", "Çapaya oynamak için önce ikili çek.");
    const fit = crossing(c, r, i);
    if (!fit) fail("failed-precondition", "Bu hücrenin satırı ya da sütunu henüz açılmadı.");
    if (!fit.length) fail("failed-precondition", "Bu kesişimde oynanabilir futbolcu kalmadı.");
    correct = fit.includes(id);
  }
  if (correct) {
    r.owners[i] = {uid, playerId: id}; r.used[id] = {uid, points: 1, playerId: id}; r.scores[uid]++;
  }
  gridWrong(r, uid, correct);
  if (lineWin(r.owners, uid, 3)) finish(r, "finished", "Çizgi tamamlandı.", time, uid);
  else if (!boardOpen(c, r)) finish(r, "finished", "Tahtada oynanabilir hücre kalmadı.", time);
  r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000;
  return {accepted: true, correct};
}
function move(c, r, uid, input, time) {
  if (r.status !== "playing" || time < r.startsAt || time >= r.endsAt) {
    fail("failed-precondition",
        "Maç şu an hamle kabul etmiyor.");
  }
  if ((["grid_classic", "grid_reverse", "cinko"].includes(r.mode) || r.randomBoard) && r.turnUid !== uid) {
    fail(
        "permission-denied", "Rakibinin sırası.");
  }
  if (r.mode === "cinko" && r.cinkoRules === 2) return cinkoMove(c, r, uid, input, time);
  if (r.lotoRules === 3) return lotoMove(c, r, uid, input, time);
  if (r.randomBoard) return boardMove(c, r, uid, input, time);
  if (r.managerRules === 3) return managerMove(r, uid, input, time);
  if (r.mode === "club_manager") {
    if (input.action !== "squad" || r.squads[uid]) fail("failed-precondition", "Kadro zaten kilitlendi.");
    r.squads[uid] = validateXi(c, r, input);
    if (r.squads[r.host] && r.squads[r.guest]) {
      r.simulation = simulate(c, r); r.scores = r.simulation.goals;
      const pens = r.simulation.penalties;
      finish(r, "finished", pens ? "Beraberlik penaltılarla bitti." : "Maç simülasyonu tamamlandı.", time,
          pens ? pens[r.host] > pens[r.guest] ? r.host : r.guest : undefined);
    }
    return {accepted: true};
  }
  if (r.mode === "grid_reverse") {
    const axis = String(input.targetId); if (!/^[rc][0-2]$/.test(axis) || r.owners[axis]) {
      fail(
          "invalid-argument", "Boş bir eksen seç.");
    }
    if (!c.criteria[input.criterionId]) fail("invalid-argument", "Bir kulüp veya ülke seç.");
    const n = Number(axis[1]); const ids = r.puzzle.witness.filter((_, i) => axis[0] === "r" ?
        Math.floor(i / 3) === n : i % 3 === n);
    const correct = ids.every((id) => matches(c, c.players[id], input.criterionId));
    if (correct) {
      r.owners[axis] = {uid, criterionId: input.criterionId}; r.scores[uid]++;
    }
    gridWrong(r, uid, correct);
    if (r.scores[uid] >= 4 || Object.keys(r.owners).length === 6) finish(r, "finished", "Eksenler tamamlandı.", time);
    r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000; return {accepted: true, correct};
  }
  const id = c.shadowIds?.[String(input.playerId)] || String(input.playerId); const p = c.players[id];
  if (!p) fail("invalid-argument", "Listeden tek bir futbolcu seç.");
  if (r.fiveRules === 3) return fiveMove(c, r, uid, id, input, time);
  if (PENALTY[r.mode]) guard(r, uid, time);
  const usedKey = r.mode === "grid_random" ? uid + "__" + id : id;
  if (r.used[usedKey]) fail("already-exists", "Bu futbolcu zaten kullanıldı.");
  let correct = false; let points = 0; let cells = [];
  if (r.mode === "grid_random") {
    const index = randomRound(r, time); const deadline = r.startsAt + index * 32000 + 30000;
    if (input.round !== index || time >= deadline) fail("failed-precondition", "Tur kapandı.");
    const a = r.answers[index] ||= {};
    if (a[uid]) fail("already-exists", "Bu turdaki cevabın kilitlendi.");
    correct = r.puzzle.rounds[index].criteria.every((k) => matches(c, p, k));
    let bonus = 0;
    if (correct && r.gridRules === 2) {
      const all = [...r.puzzle.rounds[index].answers].sort((x, y) => c.players[x].rank - c.players[y].rank ||
        x.localeCompare(y));
      bonus = (all.indexOf(id) + 1) / all.length > .5 ? GRID_RARE_BONUS : 0;
    }
    a[uid] = {playerId: id, correct, at: time, ...bonus ? {bonus} : {}}; r.used[usedKey] = true;
    gridWrong(r, uid, correct); revealRounds(r, time);
    return {accepted: true, submitted: true};
  }
  if (["club_club", "club_country"].includes(r.mode)) {
    correct = r.puzzle.rounds[0].criteria.every((k) => matches(c, p, k)); points = correct ? 1 : 0;
    record(r, uid, correct, time);
  } else if (r.mode === "random_five") {
    const n = r.puzzle.clubs.filter((k) => matches(c, p, k)).length; correct = n > 0;
    points = r.fiveRules === 2 ? FIVE_POINTS[n] : n;
    record(r, uid, correct, time);
  } else if (r.mode === "grid_classic" || r.mode === "loto") {
    if (!/^(0|[1-9][0-9]?)$/.test(String(input.targetId))) fail("invalid-argument", "Boş bir hücre seç.");
    const i = Number(input.targetId); const size = r.mode === "loto" ? 16 : 9;
    if (!Number.isInteger(i) || i < 0 || i >= size || r.owners[i]) fail("invalid-argument", "Boş bir hücre seç.");
    if (r.mode === "loto" && !r.puzzle.players.includes(id)) {
      fail("invalid-argument",
          "Bu tahtanın futbolcularından birini seç.");
    }
    correct = r.mode === "loto" ? matches(c, p, r.puzzle.criteria[i]) :
      matches(c, p, r.puzzle.rows[Math.floor(i / 3)]) && matches(c, p, r.puzzle.cols[i % 3]);
    cells = correct ? [i] : []; points = cells.length;
    if (r.mode === "loto") record(r, uid, correct, time);
    else gridWrong(r, uid, correct);
  } else if (r.mode === "cinko") {
    cells = r.puzzle.criteria.map((k, i) => matches(c, p, k) && !r.owners[i] ? i : -1).filter((i) => i >= 0);
    points = cells.length; correct = points > 0;
  }
  if (correct) {
    r.used[id] = {uid, points, playerId: id,
      ...["club_club", "club_country", "random_five"].includes(r.mode) ? {at: time} : {}};
    r.scores[uid] += points;
    for (const i of cells) r.owners[i] = {uid, playerId: id};
  }
  // Loto bingo (lotoRules 2): the move that fills the last cell of a row or
  // column earns LOTO_LINE_BONUS for each line it completes.
  let lines = [];
  if (r.mode === "loto" && correct && r.lotoRules === 2) {
    const i = cells[0]; const row = Math.floor(i / 4); const col = i % 4;
    lines = [["r" + row, [0, 1, 2, 3].map((k) => row * 4 + k)], ["c" + col, [0, 1, 2, 3].map((k) => k * 4 + col)]]
        .filter(([key, line]) => !r.lotoLines?.[key] && line.every((k) => r.owners[k])).map(([key]) => key);
    for (const key of lines) (r.lotoLines ||= {})[key] = uid;
    points += lines.length * LOTO_LINE_BONUS; r.scores[uid] += lines.length * LOTO_LINE_BONUS;
  }
  if (["grid_classic", "cinko"].includes(r.mode)) {
    const n = r.mode === "cinko" ? 5 : 3;
    if (lineWin(r.owners, uid, n)) finish(r, "finished", "Çizgi tamamlandı.", time, uid);
    else if (Object.keys(r.owners).length === n * n) finish(r, "finished", "Tahta tamamlandı.", time);
    r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000;
  }
  if (r.mode === "loto" && Object.keys(r.owners).length === 16) finish(r, "finished", "Tahta tamamlandı.", time);
  // Loto: a player put in a right but different cell can leave the rest with
  // no place; then nobody waits out the clock.
  else if (r.mode === "loto" && correct && !lotoPlayable(c, r)) {
    finish(r, "finished", "Kalan futbolcular boş hücrelere uymuyor.", time);
  }
  // Club-Club / Club-Country: nothing left to find, so nobody waits out the clock.
  if (correct && ["club_club", "club_country"].includes(r.mode) &&
    r.puzzle.rounds[0].answers.every((x) => r.used[x])) {
    finish(r, "finished", "Tüm ortak futbolcular bulundu.", time);
  }
  // Races (Loto, Club modes): when both players used up their wrong moves nobody
  // can move any more, so the match ends instead of waiting out the clock.
  if (!correct && PENALTY[r.mode] && [r.host, r.guest].every((u) =>
    (r.moveStats[u]?.wrong || 0) >= PENALTY[r.mode].maxWrong)) {
    finish(r, "finished", "İki oyuncunun da yanlış hakkı bitti.", time);
  }
  return {accepted: true, correct, points, ...lines.length ? {lines} : {}};
}
// Board owners with what the board shows: the player of a cell, the criterion of an axis.
function namedOwners(c, owners) {
  return Object.fromEntries(Object.entries(owners || {}).map(([k, o]) => [k,
    o?.playerId && c.players[o.playerId] ? {...o, player: player(c, o.playerId)} :
    o?.criterionId && c.criteria[o.criterionId] ? {...o, criterion: c.criteria[o.criterionId]} : o]));
}
function view(c, r, uid, time) {
  const other = uid === r.host ? r.guest : r.host; const done = terminal(r);
  const v = {id: r.id, mode: r.mode, playKind: r.playKind, schemaVersion: 1, ruleVersion: r.ruleVersion,
    dataRevision: r.dataRevision, seedId: r.seedId || null, revision: r.revision, status: r.status,
    host: r.host, guest: r.guest || null, names: r.names, myUid: uid, serverNow: time,
    ready: r.ready, choices: r.status === "ready" || done ? r.choices : {}, scores: r.scores,
    startsAt: r.startsAt || null, endsAt: r.endsAt || null, turnUid: r.turnUid || null,
    turnDeadline: r.turnDeadline || null, owners: namedOwners(c, r.owners),
    used: r.mode === "grid_random" || r.fiveRules === 3 ? {} : r.used, otherLastSeen: r.presence[other] || null,
    profile: r.profile, series: r.series || null, nextRoom: r.nextRoom || null, rematch: r.rematch,
    rankedEligible: r.rankedEligible === true, reward: r.settlement?.[uid] || {status:
        r.playKind === "friend" ? "none" : "pending"}};
  if (r.status === "ready" && r.playKind === "friend" && ["club_club", "club_country"].includes(r.mode)) {
    // Only choices that make a playable pair with the other side's current choice.
    const side = uid === r.host ? "left" : "right";
    v.pairOptions = pairOptions(c, r.mode, side, r.choices[side === "left" ? "right" : "left"]);
  }
  const q = r.puzzle;
  if (q && !["waiting", "ready", "cancelled", "expired"].includes(r.status)) {
    const criteria = (ids) => ids.map((id) => c.criteria[id]);
    if (["club_club", "club_country"].includes(r.mode)) {
      v.criteria = criteria(q.rounds[0].criteria);
      // Live: who found whom and how many shared players there are (never which).
      v.answerCount = q.rounds[0].answers.length;
      v.found = Object.values(r.used).sort((a, b) => (a.at || 0) - (b.at || 0)).map((u) => ({
        ...player(c, u.playerId), uid: u.uid,
        ...u.at ? {second: Math.max(0, Math.floor((u.at - r.startsAt) / 1000))} : {}}));
      // After the match: the shared players nobody found, best-known first.
      if (done) {
        v.missed = q.rounds[0].answers.filter((id) => !r.used[id])
            .sort((a, b) => c.players[a].rank - c.players[b].rank).slice(0, 12).map((id) => player(c, id));
      }
    }
    if (r.fiveRules === 3) {
      const starts = list(r.fiveStarts).length ? list(r.fiveStarts) : [r.startsAt];
      const i = starts.length - 1; const a = r.answers[i] || {};
      const answer = (x, board, start) => x?.playerId ? {...player(c, x.playerId), points: x.points, clubs: x.clubs,
        clubIds: board.filter((k) => matches(c, c.players[x.playerId], k)),
        second: Math.max(0, Math.floor((x.at - start) / 1000))} : {timeout: true, points: 0, clubs: 0};
      // The best names of a closed five: most clubs first, then the best known.
      const best = (board) => [...new Set(board.flatMap((k) => answersOf(c, k)))]
          .map((id) => [id, board.filter((k) => matches(c, c.players[id], k)).length])
          .sort((x, y) => y[1] - x[1] || c.players[x[0]].rank - c.players[y[0]].rank).slice(0, 3)
          .map(([id, n]) => ({...player(c, id), clubs: n, points: FIVE_POINTS[n]}));
      Object.assign(v, {fiveRules: 3, fivePoints: FIVE_POINTS, round: i, totalRounds: FIVE_ROUNDS,
        criteria: criteria(q.boards[i]), roundStartsAt: starts[i], roundDeadline: starts[i] + FIVE_ANSWER_MS,
        roundClosed: !!a.revealed, nextRoundAt: a.revealed && i < FIVE_ROUNDS - 1 ? a.closedAt + FIVE_REVEAL_MS : null,
        revealMs: FIVE_REVEAL_MS, answerMs: FIVE_ANSWER_MS,
        // Before the close: only the viewer's own answer, and whether the rival has one.
        myAnswer: a[uid] && !a.revealed ? answer(a[uid], q.boards[i], starts[i]) : null,
        rivalAnswered: !!a[other],
        // starts[n], not `start`: that name is the module's start() function (x.at - start was NaN).
        rounds: starts.map((_, n) => [n, r.answers[n]]).filter(([, x]) => x?.revealed).map(([n, x]) => ({
          round: n, clubs: criteria(q.boards[n]), best: best(q.boards[n]),
          answers: {[r.host]: answer(x[r.host], q.boards[n], starts[n]),
            [r.guest]: answer(x[r.guest], q.boards[n], starts[n])},
        }))});
    } else if (r.mode === "random_five") {
      v.criteria = criteria(q.clubs);
      if (r.fiveRules === 2) v.fivePoints = FIVE_POINTS;
      const fit = (id) => q.clubs.filter((k) => matches(c, c.players[id], k)).length;
      // Live: who found whom, the clubs each name covers, its points and second.
      v.found = Object.values(r.used).sort((a, b) => (a.at || 0) - (b.at || 0)).map((u) => {
        const clubIds = q.clubs.filter((k) => matches(c, c.players[u.playerId], k));
        return {...player(c, u.playerId), uid: u.uid, clubs: clubIds.length, clubIds, points: u.points,
          ...u.at ? {second: Math.max(0, Math.floor((u.at - r.startsAt) / 1000))} : {}};
      });
      if (done) {
        // The best answers nobody gave (most clubs first).
        v.missed = [...new Set(q.clubs.flatMap((k) => answersOf(c, k)))].filter((id) => !r.used[id])
            .map((id) => [id, fit(id)]).filter(([, n]) => n >= 2)
            .sort((a, b) => b[1] - a[1] || c.players[a[0]].rank - c.players[b[0]].rank).slice(0, 10)
            .map(([id, n]) => ({...player(c, id), clubs: n}));
      }
    }
    if (["grid_classic", "grid_reverse"].includes(r.mode)) {
      if (r.mode === "grid_classic" || done) {
        v.rows = criteria(q.rows); v.cols = criteria(q.cols);
      }
      if (r.mode === "grid_reverse") v.players = q.witness.map((id) => player(c, id));
      // After a reverse match: every club, country and coach each axis accepted.
      if (r.mode === "grid_reverse" && done) {
        v.accepted = Object.fromEntries(["r0", "r1", "r2", "c0", "c1", "c2"].map((axis) => {
          const n = Number(axis[1]); const ids = q.witness.filter((_, i) => axis[0] === "r" ?
            Math.floor(i / 3) === n : i % 3 === n);
          return [axis, acceptedFor(c, ids)];
        }));
      }
    }
    if (["cinko", "loto"].includes(r.mode)) v.criteria = criteria(q.criteria);
    if (r.mode === "cinko") {
      v.cinkoRules = r.cinkoRules || 1; v.passes = r.passes || 0;
      if (r.cinkoRules === 2) v.secondBonus = CINKO_SECOND_BONUS;
      // Who starts with it, so the score card can say why the match is 0-1 before a move.
      if (r.cinkoBonusUid) v.secondBonusUid = r.cinkoBonusUid;
      if (r.cinkoRules === 2) v.open = cinkoOpen(c, r);
      // The last move of either player: who, which player, right and wrong cells.
      v.lastMove = r.last ? {...r.last, player: r.last.playerId ? player(c, r.last.playerId) : null} : null;
      v.moves = list(r.log).slice().reverse().map((m) => ({...m, correct: list(m.correct), wrong: list(m.wrong),
        player: m.playerId ? player(c, m.playerId) : null}));
    }
    if (r.mode === "loto" && r.lotoRules !== 3) v.players = shuffle(q.players, r.seedId).map((id) => player(c, id));
    if (r.lotoRules === 3) {
      const calls = list(r.lotoCalls).length ? list(r.lotoCalls) : [r.startsAt];
      const i = calls.length - 1; const a = r.answers[i] || {};
      const card = (side, all) => Object.fromEntries(Object.entries(r.cards?.[side] || {}).map(([k, x]) =>
        [k.slice(1), {player: player(c, x.playerId), ...all ? {correct: x.correct} : {}}]));
      const result = (x) => !x ? null : x.cell !== undefined ? {cell: x.cell, correct: !!x.correct,
        ...x.lines ? {lines: x.lines} : {}} : x.pass ? {pass: true} : {timeout: true};
      const last = [...list(r.answers).entries()].filter(([, x]) => x?.revealed).at(-1);
      Object.assign(v, {lotoRules: 3, call: i, totalCalls: LOTO_CALLS, callMs: LOTO_CALL_MS,
        callPlayer: r.status === "countdown" ? null : player(c, r.lotoQueue[i]),
        callStartsAt: calls[i], callDeadline: calls[i] + LOTO_CALL_MS, callClosed: !!a.revealed,
        nextCallAt: a.revealed && i < LOTO_CALLS - 1 ? a.closedAt + LOTO_REVEAL_MS : null,
        // The viewer's own move on the open call (its result opens with the call's close).
        myMove: a[uid] && !a.revealed ? (a[uid].pass ? {pass: true} : {cell: a[uid].cell}) : null,
        rivalMoved: !!a[other],
        myCard: card(uid, true), rivalPlaced: Object.keys(r.cards?.[other] || {}).length,
        lastCall: last ? {round: last[0], player: player(c, r.lotoQueue[last[0]]),
          mine: result(last[1][uid]), rival: result(last[1][other])} : null,
        lotoLines: {[uid]: Object.keys(r.lotoLines?.[uid] || {}), [other]: Object.keys(r.lotoLines?.[other] || {})},
        lineBonus: LOTO_LINE_BONUS, wrongCells: {[uid]: r.moveStats[uid]?.wrong || 0,
          [other]: r.moveStats[other]?.wrong || 0},
        ...done ? {rivalCard: card(other, true)} : {}});
    }
    if (r.mode === "loto" && r.lotoRules === 2) {
      v.lotoLines = r.lotoLines || {}; v.lineBonus = LOTO_LINE_BONUS;
    }
    if (PENALTY[r.mode] && r.fiveRules !== 3 && r.lotoRules !== 3) {
      // Wrong moves of both players; the lock only for the viewer.
      v.wrongMoves = {[r.host]: r.moveStats[r.host]?.wrong || 0, [r.guest]: r.moveStats[r.guest]?.wrong || 0};
      v.maxWrong = PENALTY[r.mode].maxWrong; v.lockUntil = r.moveStats[uid]?.lockUntil || null;
    }
    if (r.gridRules === 2) {
      v.gridRules = 2; v.gridWrong = {[r.host]: r.moveStats[r.host]?.wrong || 0,
        [r.guest]: r.moveStats[r.guest]?.wrong || 0};
      if (r.mode === "grid_random" && !r.randomBoard) v.rareBonus = GRID_RARE_BONUS;
    }
    if (r.randomBoard) {
      const axis = (k) => k ? c.criteria[k] : null;
      v.randomBoard = 1; v.anchors = ANCHORS; v.dead = deadCells(c, r);
      v.rows = [0, 1, 2].map((i) => axis(r.boardRows?.[i])); v.cols = [0, 1, 2].map((i) => axis(r.boardCols?.[i]));
      v.pending = r.pending ? {criteria: r.pending.criteria.map((k) => c.criteria[k])} : null;
    } else if (r.mode === "grid_random") {
      const index = randomRound(r, Math.max(time, r.startsAt)); v.round = index; v.totalRounds = 5;
      v.criteria = criteria(q.rounds[index].criteria); v.roundDeadline = r.startsAt + index * 32000 + 30000;
      v.submitted = !!r.answers[index]?.[uid];
      // Closed rounds only, each answer with its player for the round list.
      v.rounds = Object.fromEntries(Object.entries(r.answers).filter(([, a]) => a.revealed).map(([i, a]) =>
        [i, Object.fromEntries(Object.entries(a).map(([k, x]) => [k, x?.playerId ?
          {...x, player: player(c, x.playerId)} : x]))]));
    }
    if (r.managerRules === 3) {
      const picks = r.draft.picks; const mine = list(picks[uid]); const theirs = list(picks[other]);
      const phase = r.plan ? "plan" : "draft";
      Object.assign(v, {managerRules: 3, phase, pool: q.pool.map((id) => q.meta[id]), anchors: q.anchors,
        // Club and country links of the pool, for "+2 bağ" on each player.
        poolLinks: list(q.links).filter((l) => l[3] !== "league"),
        picks: {[r.host]: list(picks[r.host]), [r.guest]: list(picks[r.guest])}, pick: r.draft.k,
        totalPicks: DRAFT_PICKS, pickDeadline: r.draft.deadline || null, firstPicker: r.draft.first,
        lastPick: list(r.draft.log).at(-1) || null,
        legal: phase === "draft" && r.turnUid === uid ? legalPicks(r, uid) : [],
        formations: {[uid]: formationOf(q, mine) || openFormations(q, mine),
          [other]: formationOf(q, theirs) || openFormations(q, theirs)},
        chemistry: {[uid]: chemistry(q, mine), [other]: chemistry(q, theirs)},
        // The links each free pool player would bring where he would stand ("+2 bağ").
        ...q.draftRules >= 4 && phase === "draft" ? {linkPreview: Object.fromEntries(q.pool
            .filter((id) => !taken(r).has(id) && openFormations(q, [...mine, id]).length).map((id) =>
              [id, chemistry(q, [...mine, id]).pairs.filter((l) => l[0] === id || l[1] === id)
                  .map((l) => l[3] || "ülke")]))} : {},
        planDeadline: r.plan?.deadline || null, plans: PLANS,
        myPlan: r.plan?.choices[uid] || null, rivalPlanned: !!r.plan?.choices[other]});
      if (done) v.planChoices = r.plan?.choices || null;
      if (r.simulation) v.simulation = r.simulation;
    } else if (r.mode === "club_manager") {
      v.budget = q.budget; v.managerRules = r.managerRules || 1;
      v.pool = q.pool.map((id) => ({...player(c, id), rating: c.players[id].rating,
        cost: c.players[id].cost}));
      v.submitted = !!r.squads[uid]; v.mySquad = r.squads[uid] || null;
      // Whether the rival has locked an XI (not which XI) until both are in.
      v.rivalLocked = !!r.squads[other];
      if (r.squads[r.host] && r.squads[r.guest]) {
        v.squads = r.squads; v.simulation = r.simulation;
      }
    }
  }
  if (done) {
    v.reason = r.reason; v.winnerUid = r.winnerUid || null; v.finishedAt = r.finishedAt; v.resultHash = r.resultHash;
    v.result = r.winnerUid == null ? "draw" : r.winnerUid === uid ? "win" : "loss";
    if (r.status === "finished" && q) {
      if (q.rounds) v.answers = q.rounds.map((p) => p.answers.map((id) => player(c, id)));
      if (q.witness) v.witness = q.witness.map((id) => player(c, id));
    }
  }
  return v;
}
module.exports = {MODES, RULE, terminal, fail, hash, norm, list, shuffle, matches, player,
  PENALTY, MIN_GAP_MS, FIVE_POINTS, FIVE_ROUNDS, FIVE_ANSWER_MS, FIVE_REVEAL_MS, GRID_RARE_BONUS,
  LOTO_LINE_BONUS, LOTO_CALLS, LOTO_CALL_MS, LOTO_REVEAL_MS, gridTieBreak,
  PAIR_MIN_ANSWERS, POPULAR_RANK, raceTieBreak, pairOptions, autoChoice, acceptedFor,
  FORMATIONS, MANAGER_TIERS, MANAGER_BUDGET, counter, DRAFT_PICKS, DRAFT_PICK_MS, PLAN_MS, PLANS, PLAN_BEATS,
  draftPool, legalPicks, formationOf, chemistry, managerPlay, DRAFT_BASE, DRAFT_PER_POWER,
  puzzle, hydrate, start, finish, seriesClose, advance, move, view, validateXi, power, simulate};
Object.defineProperty(module.exports, "catalog", {enumerable: true, get: loadCatalog});
