"use strict";
const crypto = require("node:crypto");
const fs = require("node:fs");
const zlib = require("node:zlib");
const {RewardError} = require("./rewarded_ads");
const catalog = JSON.parse(zlib.gunzipSync(fs.readFileSync(__dirname + "/config/pvp_catalog.json.gz")));
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
function managerPool(c, seed) {
  const pool = [];
  for (const [pos, n] of Object.entries({GK: 3, DEF: 7, MID: 8, ATT: 7})) {
    const all = Object.values(c.players).filter((p) => p.position === pos && p.rank <= 6000);
    const cheap = shuffle(all.filter((p) => p.cost <= 10), seed + pos).slice(0, pos === "GK" ? 1 : 5);
    const chosen = [...cheap, ...shuffle(all.filter((p) => !cheap.includes(p)), seed + "rest" + pos)].slice(0, n);
    if (chosen.length !== n) fail("failed-precondition", "Dengeli kadro havuzu bulunamadı.");
    pool.push(...chosen.map((p) => p.id));
  }
  return {id: hash(seed + "manager"), pool, budget: 120, buildMs: 180000};
}
function puzzle(c, mode, seed, choices = {}) {
  if (!MODES.includes(mode)) fail("invalid-argument", "Geçersiz mod.");
  if (mode === "club_manager") return managerPool(c, seed);
  if (["club_club", "club_country", "grid_random"].includes(mode)) {
    let pairs = c.pairs.filter((p) => p.answers.length >= (mode === "grid_random" ? 6 : 8) &&
      (mode === "club_country" ? p.criteria[1].startsWith("country:") : p.criteria[1].startsWith("club:")));
    if (choices.left || choices.right) {
      pairs = pairs.filter((p) =>
        p.criteria[0] === choices.left && p.criteria[1] === choices.right ||
      mode === "club_club" && p.criteria[0] === choices.right && p.criteria[1] === choices.left);
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
  return {id: hash(seed + "five"), clubs: shuffle(c.clubOptions, seed).slice(0, 5)};
}
function hydrate(raw) {
  if (!raw) return null;
  return {...raw, ready: raw.ready || {}, choices: raw.choices || {}, presence: raw.presence || {},
    scores: raw.scores || {}, owners: raw.owners || {}, used: raw.used || {}, answers: raw.answers || {},
    squads: raw.squads || {}, receipts: raw.receipts || {}, audit: raw.audit || {}, rematch: raw.rematch || {}};
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
}
function finish(r, status, reason, time, winner) {
  if (terminal(r)) return;
  r.status = status; r.reason = reason; r.finishedAt = time;
  r.winnerUid = winner === undefined ? r.scores[r.host] > r.scores[r.guest] ? r.host :
    r.scores[r.host] < r.scores[r.guest] ? r.guest : null : winner;
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
    r.scores[uid] = Object.values(r.answers).filter((a) =>
      a.revealed && a[uid]?.correct).length;
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
    finish(r, r.mode === "club_manager" ? "cancelled" : "finished", "Süre tamamlandı.", r.endsAt,
        r.mode === "club_manager" ? null : undefined); return;
  }
  if (["grid_classic", "grid_reverse", "cinko"].includes(r.mode)) {
    while (time >= r.turnDeadline) {
      r.turnUid = r.turnUid === r.host ? r.guest : r.host; r.turnDeadline += 45000;
    }
  }
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
function simulate(c, r) {
  const powers = {[r.host]: power(c, r.squads[r.host]), [r.guest]: power(c, r.squads[r.guest])};
  const goals = {}; const xg = {};
  for (const uid of [r.host, r.guest]) {
    const other = uid === r.host ? r.guest : r.host; const t = r.squads[uid].tactics;
    const rnd = (i) => parseInt(hash([r.seed, [r.host, r.guest].map((u) => [u, r.squads[u]]), uid,
      i]).slice(0, 8), 16) / 4294967296;
    xg[uid] = clamp(1.1 + (powers[uid] - powers[other]) * .045 + rnd(0) * .6 +
      (t.press - .5) * .25 + (t.tempo - .5) * .2 + (.5 - r.squads[other].tactics.press) * .15, .3, 4.5);
    goals[uid] = Array.from({length: 8}, (_, i) => rnd(i + 1) < clamp(xg[uid] / 8, .02, .55)).filter(Boolean).length;
  }
  return {powers, goals, xg};
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
  if (r.mode === "club_manager") {
    if (input.action !== "squad" || r.squads[uid]) fail("failed-precondition", "Kadro zaten kilitlendi.");
    r.squads[uid] = validateXi(c, r, input);
    if (r.squads[r.host] && r.squads[r.guest]) {
      r.simulation = simulate(c, r); r.scores = r.simulation.goals; finish(r, "finished",
          "Maç simülasyonu tamamlandı.", time);
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
    if (r.scores[uid] >= 4 || Object.keys(r.owners).length === 6) finish(r, "finished", "Eksenler tamamlandı.", time);
    r.turnUid = uid === r.host ? r.guest : r.host; r.turnDeadline = time + 45000; return {accepted: true, correct};
  }
  const id = c.shadowIds?.[String(input.playerId)] || String(input.playerId); const p = c.players[id];
  if (!p) fail("invalid-argument", "Listeden tek bir futbolcu seç.");
  const usedKey = r.mode === "grid_random" ? uid + "__" + id : id;
  if (r.used[usedKey]) fail("already-exists", "Bu futbolcu zaten kullanıldı.");
  let correct = false; let points = 0; let cells = [];
  if (r.mode === "grid_random") {
    const index = randomRound(r, time); const deadline = r.startsAt + index * 32000 + 30000;
    if (input.round !== index || time >= deadline) fail("failed-precondition", "Tur kapandı.");
    const a = r.answers[index] ||= {};
    if (a[uid]) fail("already-exists", "Bu turdaki cevabın kilitlendi.");
    correct = r.puzzle.rounds[index].criteria.every((k) => matches(c, p, k));
    a[uid] = {playerId: id, correct, at: time}; r.used[usedKey] = true; revealRounds(r, time);
    return {accepted: true, submitted: true};
  }
  if (["club_club", "club_country"].includes(r.mode)) {
    correct = r.puzzle.rounds[0].criteria.every((k) => matches(c, p, k)); points = correct ? 1 : 0;
  } else if (r.mode === "random_five") {
    points = r.puzzle.clubs.filter((k) => matches(c, p, k)).length; correct = points > 0;
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
  const q = r.puzzle;
  if (q && !["waiting", "ready", "cancelled", "expired"].includes(r.status)) {
    const criteria = (ids) => ids.map((id) => c.criteria[id]);
    if (["club_club", "club_country"].includes(r.mode)) v.criteria = criteria(q.rounds[0].criteria);
    if (r.mode === "random_five") v.criteria = criteria(q.clubs);
    if (["grid_classic", "grid_reverse"].includes(r.mode)) {
      if (r.mode === "grid_classic" || done) {
        v.rows = criteria(q.rows); v.cols = criteria(q.cols);
      }
      if (r.mode === "grid_reverse") v.players = q.witness.map((id) => player(c, id));
    }
    if (["cinko", "loto"].includes(r.mode)) v.criteria = criteria(q.criteria);
    if (r.mode === "loto") v.players = shuffle(q.players, r.seedId).map((id) => player(c, id));
    if (r.mode === "grid_random") {
      const index = randomRound(r, Math.max(time, r.startsAt)); v.round = index; v.totalRounds = 5;
      v.criteria = criteria(q.rounds[index].criteria); v.roundDeadline = r.startsAt + index * 32000 + 30000;
      v.submitted = !!r.answers[index]?.[uid];
      v.rounds = Object.fromEntries(Object.entries(r.answers).filter(([, a]) => a.revealed));
    }
    if (r.mode === "club_manager") {
      v.budget = q.budget; v.pool = q.pool.map((id) => ({...player(c, id), rating: c.players[id].rating,
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
module.exports = {catalog, MODES, RULE, terminal, fail, hash, norm, list, shuffle, matches, player,
  FORMATIONS, puzzle, hydrate, start, finish, advance, move, view, validateXi, power, simulate};
