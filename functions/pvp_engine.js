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
    p.countryKeys.includes(k.value) : k.type === "league" && p.leagues.includes(k.value);
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
const pairPool = (c, mode) => c.pairs.filter((p) => p.answers.length >= PAIR_MIN_ANSWERS &&
  (mode === "club_country" ? p.criteria[1].startsWith("country:") : p.criteria[1].startsWith("club:")));
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
    const chosen = shuffle(pairs, seed).slice(0, mode === "grid_random" ? 5 : 1);
    if (chosen.length !== (mode === "grid_random" ? 5 : 1)) {
      fail("failed-precondition",
          "Yeterli ortak futbolcu yok; seçimi değiştir.");
    }
    return {id: hash(chosen.map((p) => p.id)), rounds: chosen};
  }
  if (["grid_classic", "grid_reverse"].includes(mode)) return structuredClone(shuffle(c.grids, seed)[0]);
  if (mode === "cinko" || mode === "loto") return structuredClone(shuffle(c[mode], seed)[0]);
  // Random Five: a checked board (a 4-club player, 4+ with 3 clubs, 20+ with 2);
  // older catalogs fall back to five random clubs.
  if (c.five?.length) return structuredClone(shuffle(c.five, seed)[0]);
  return {id: hash(seed + "five"), clubs: shuffle(c.clubOptions, seed).slice(0, 5)};
}
function hydrate(raw) {
  if (!raw) return null;
  return {...raw, ready: raw.ready || {}, choices: raw.choices || {}, presence: raw.presence || {},
    scores: raw.scores || {}, owners: raw.owners || {}, used: raw.used || {}, answers: raw.answers || {},
    squads: raw.squads || {}, receipts: raw.receipts || {}, audit: raw.audit || {}, rematch: raw.rematch || {},
    moveStats: raw.moveStats || {}};
}
function start(r, c, time) {
  r.puzzle = puzzle(c, r.mode, r.seed, r.choices);
  r.seedId = hash([r.seed, r.puzzle.id, r.dataRevision, r.ruleVersion]);
  r.status = "countdown"; r.startsAt = time + 5000;
  const duration = r.mode === "loto" || r.mode === "club_manager" ? 180000 : r.mode === "grid_random" ? 160000 :
    ["club_club", "club_country", "random_five"].includes(r.mode) ? 90000 : 30 * 45000;
  r.endsAt = r.startsAt + duration; r.turnUid = parseInt(hash(r.seed).slice(0, 8), 16) % 2 ? r.host : r.guest;
  r.turnDeadline = r.startsAt + 45000; r.scores = {[r.host]: 0, [r.guest]: 0};
  r.presence = {[r.host]: time, [r.guest]: time};
  if (r.mode === "random_five") r.fiveRules = 2;
  if (r.mode.startsWith("grid_")) r.gridRules = 2;
  if (r.mode === "club_manager") r.managerRules = 2;
  if (r.mode === "cinko") {
    // Moving first is worth about a point in Çinko, so the second player starts with 1.
    r.cinkoRules = 2; r.scores[r.turnUid === r.host ? r.guest : r.host] = CINKO_SECOND_BONUS;
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
function finish(r, status, reason, time, winner) {
  if (terminal(r)) return;
  r.status = status; r.reason = reason; r.finishedAt = time;
  r.winnerUid = winner === undefined ? r.scores[r.host] > r.scores[r.guest] ? r.host :
    r.scores[r.host] < r.scores[r.guest] ? r.guest : PENALTY[r.mode] ? raceTieBreak(r) :
    r.gridRules === 2 && r.mode !== "grid_random" ? gridTieBreak(r) : null : winner;
  if (r.series && ["finished", "forfeit"].includes(status)) {
    r.series.wins ||= {};
    if (r.winnerUid) r.series.wins[r.winnerUid] = (r.series.wins[r.winnerUid] || 0) + 1;
    else r.series.draws = (r.series.draws || 0) + 1;
  }
  r.resultHash = hash([r.seedId, r.scores, r.owners, r.answers, r.squads, r.status, r.reason, r.winnerUid]);
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
  if (r.mode === "grid_random") revealRounds(r, time);
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
  if (["grid_classic", "grid_reverse", "cinko"].includes(r.mode)) {
    while (time >= r.turnDeadline && !terminal(r)) {
      if (r.cinkoRules === 2) cinkoPass(r, r.turnUid, r.turnDeadline, true);
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
function cinkoTurn(r, uid, time) {
  r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000;
}
function cinkoPass(r, uid, time, timeout = false) {
  r.passes = (r.passes || 0) + 1; r.last = {uid, pass: true, timeout, points: 0};
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
  r.last = {uid, playerId: id, correct: right, wrong, points};
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
function move(c, r, uid, input, time) {
  if (r.status !== "playing" || time < r.startsAt || time >= r.endsAt) {
    fail("failed-precondition",
        "Maç şu an hamle kabul etmiyor.");
  }
  if (["grid_classic", "grid_reverse", "cinko"].includes(r.mode) && r.turnUid !== uid) {
    fail(
        "permission-denied", "Rakibinin sırası.");
  }
  if (r.mode === "cinko" && r.cinkoRules === 2) return cinkoMove(c, r, uid, input, time);
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
    r.used[id] = {uid, points, playerId: id}; r.scores[uid] += points;
    for (const i of cells) r.owners[i] = {uid, playerId: id};
  }
  if (["grid_classic", "cinko"].includes(r.mode)) {
    const n = r.mode === "cinko" ? 5 : 3;
    if (lineWin(r.owners, uid, n)) finish(r, "finished", "Çizgi tamamlandı.", time, uid);
    else if (Object.keys(r.owners).length === n * n) finish(r, "finished", "Tahta tamamlandı.", time);
    r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000;
  }
  if (r.mode === "loto" && Object.keys(r.owners).length === 16) finish(r, "finished", "Tahta tamamlandı.", time);
  return {accepted: true, correct, points};
}
function view(c, r, uid, time) {
  const other = uid === r.host ? r.guest : r.host; const done = terminal(r);
  const v = {id: r.id, mode: r.mode, playKind: r.playKind, schemaVersion: 1, ruleVersion: r.ruleVersion,
    dataRevision: r.dataRevision, seedId: r.seedId || null, revision: r.revision, status: r.status,
    host: r.host, guest: r.guest || null, names: r.names, myUid: uid, serverNow: time,
    ready: r.ready, choices: r.status === "ready" || done ? r.choices : {}, scores: r.scores,
    startsAt: r.startsAt || null, endsAt: r.endsAt || null, turnUid: r.turnUid || null,
    turnDeadline: r.turnDeadline || null, owners: r.owners, used: r.mode === "grid_random" ? {} :
        r.used, otherLastSeen: r.presence[other] || null,
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
      // After the match: the shared players nobody found, best-known first.
      if (done) {
        v.found = Object.values(r.used).map((u) => ({...player(c, u.playerId), uid: u.uid}));
        v.missed = q.rounds[0].answers.filter((id) => !r.used[id])
            .sort((a, b) => c.players[a].rank - c.players[b].rank).slice(0, 12).map((id) => player(c, id));
      }
    }
    if (r.mode === "random_five") {
      v.criteria = criteria(q.clubs);
      if (r.fiveRules === 2) v.fivePoints = FIVE_POINTS;
      if (done) {
        // Who found whom, and the best answers nobody gave (most clubs first).
        const fit = (id) => q.clubs.filter((k) => matches(c, c.players[id], k)).length;
        v.found = Object.values(r.used).map((u) => ({...player(c, u.playerId), uid: u.uid, clubs: fit(u.playerId)}));
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
      // After a reverse match: every club and country each axis accepted.
      if (r.mode === "grid_reverse" && done) {
        v.accepted = Object.fromEntries(["r0", "r1", "r2", "c0", "c1", "c2"].map((axis) => {
          const n = Number(axis[1]); const ids = q.witness.filter((_, i) => axis[0] === "r" ?
            Math.floor(i / 3) === n : i % 3 === n);
          const first = c.players[ids[0]];
          const keys = [...first.clubs.map((x) => "club:" + x), ...first.countryKeys.map((x) => "country:" + x)];
          return [axis, keys.filter((k) => c.criteria[k] && ids.every((id) => matches(c, c.players[id], k)))
              .map((k) => c.criteria[k].label)];
        }));
      }
    }
    if (["cinko", "loto"].includes(r.mode)) v.criteria = criteria(q.criteria);
    if (r.mode === "cinko") {
      v.cinkoRules = r.cinkoRules || 1; v.passes = r.passes || 0;
      if (r.cinkoRules === 2) v.secondBonus = CINKO_SECOND_BONUS;
      if (r.cinkoRules === 2) v.open = cinkoOpen(c, r);
      // The last move of either player: who, which player, right and wrong cells.
      v.lastMove = r.last ? {...r.last, player: r.last.playerId ? player(c, r.last.playerId) : null} : null;
    }
    if (r.mode === "loto") v.players = shuffle(q.players, r.seedId).map((id) => player(c, id));
    if (PENALTY[r.mode]) {
      // Wrong moves of both players; the lock only for the viewer.
      v.wrongMoves = {[r.host]: r.moveStats[r.host]?.wrong || 0, [r.guest]: r.moveStats[r.guest]?.wrong || 0};
      v.maxWrong = PENALTY[r.mode].maxWrong; v.lockUntil = r.moveStats[uid]?.lockUntil || null;
    }
    if (r.gridRules === 2) {
      v.gridRules = 2; v.gridWrong = {[r.host]: r.moveStats[r.host]?.wrong || 0,
        [r.guest]: r.moveStats[r.guest]?.wrong || 0};
      if (r.mode === "grid_random") v.rareBonus = GRID_RARE_BONUS;
    }
    if (r.mode === "grid_random") {
      const index = randomRound(r, Math.max(time, r.startsAt)); v.round = index; v.totalRounds = 5;
      v.criteria = criteria(q.rounds[index].criteria); v.roundDeadline = r.startsAt + index * 32000 + 30000;
      v.submitted = !!r.answers[index]?.[uid];
      v.rounds = Object.fromEntries(Object.entries(r.answers).filter(([, a]) => a.revealed));
    }
    if (r.mode === "club_manager") {
      v.budget = q.budget; v.managerRules = r.managerRules || 1;
      v.pool = q.pool.map((id) => ({...player(c, id), rating: c.players[id].rating,
        cost: c.players[id].cost}));
      v.submitted = !!r.squads[uid]; v.mySquad = r.squads[uid] || null;
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
  PENALTY, MIN_GAP_MS, FIVE_POINTS, GRID_RARE_BONUS, gridTieBreak,
  PAIR_MIN_ANSWERS, POPULAR_RANK, raceTieBreak, pairOptions,
  FORMATIONS, MANAGER_TIERS, MANAGER_BUDGET, counter,
  puzzle, hydrate, start, finish, advance, move, view, validateXi, power, simulate};
Object.defineProperty(module.exports, "catalog", {enumerable: true, get: loadCatalog});
