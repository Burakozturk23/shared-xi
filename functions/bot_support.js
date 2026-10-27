"use strict";
const crypto = require("node:crypto");
const P = require("./pvp_engine");
const B = require("./boosts");
const {RewardError} = require("./rewarded_ads");
// Four remaining Botla Oyna modes. Each keeps its legacy rules (Loto clocks and
// +10 scoring, Team Race three round wins, Çinko connected cells with -1 wrong
// and 0 pass, Random Five free edits and five rounds) while the board, answers,
// bot moves and paid support live in one account-owned session.
const catalog = P.catalog;
const VERSION = catalog.version + "-bot-v1";
const MODES = ["bot_loto", "bot_team_race", "bot_cinko", "bot_random_five"];
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const kind = (r) => r.mode.slice(4);
const realtime = (r) => ["loto", "team_race"].includes(kind(r));
const pos = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", ATT: "Forvet"};
const POPULAR_CLUBS = [11, 631, 31, 281, 985, 148, 762, 405, 29, 379, 1003, 180, 131, 418, 13, 368, 681, 1049,
  1050, 621, 150, 5, 46, 506, 6195, 12, 398, 430, 800, 27, 16, 15, 23826, 24, 18, 583, 1041, 244, 162, 1082, 141,
  36, 114, 449, 610, 720, 294, 336, 465, 124, 383].map((id) => "club:" + id).filter((id) => catalog.criteria[id]);
const POPULAR_LEAGUES = ["Premier League", "LaLiga", "Serie A", "Bundesliga", "Ligue 1", "Süper Lig", "Eredivisie",
  "Liga Portugal", "Primeira Liga", "Scottish Premiership", "Belgian Pro League"].map((label) =>
  Object.values(catalog.criteria).find((k) => k.type === "league" && k.label === label.toLowerCase())?.id)
    .filter(Boolean);
const POPULAR_COUNTRIES = ["Brazil", "Argentina", "France", "Germany", "Spain", "England", "Italy", "Portugal",
  "Netherlands", "Belgium", "Croatia", "Uruguay", "Colombia", "Turkey", "Poland", "Denmark", "Sweden",
  "Switzerland", "Serbia", "Morocco", "Senegal", "Nigeria", "Mexico", "Japan", "Wales", "Scotland"]
    .map((name) => "country:" + P.norm(name)).filter((id) => catalog.criteria[id]);
let index = null;
// Inverse criterion index with exactly the pvp_engine matching semantics.
function answers(id) {
  if (!index) {
    index = new Map(); const leagues = {};
    for (const k of Object.values(catalog.criteria)) if (k.type === "league") leagues[k.value] = k.id;
    for (const p of Object.values(catalog.players)) {
      for (const key of [...p.clubs.map((v) => "club:" + v), ...p.countryKeys.map((v) => "country:" + v),
        ...p.leagues.map((v) => leagues[v]).filter(Boolean)]) {
        if (!index.has(key)) index.set(key, new Set());
        index.get(key).add(p.id);
      }
    }
  }
  return index.get(id) || new Set();
}
const matches = (id, criterion) => answers(criterion).has(id);
const byRank = (a, b) => catalog.players[a].rank - catalog.players[b].rank || a.localeCompare(b);
// P.shuffle hashes inside the comparator; large pools hash each item once.
const shuffled = (a, key) => a.map((x) => [P.hash(key + JSON.stringify(x)), x])
    .sort((x, y) => x[0].localeCompare(y[0])).map((x) => x[1]);
function random(r, key) {
  return parseInt(P.hash([r.seed, key]).slice(0, 8), 16) / 0x100000000;
}
function pick(r, a, key) {
  return a[Math.floor(random(r, key) * a.length)];
}
function between(r, [low, high], key) {
  return low + Math.floor(random(r, key) * (high - low + 1));
}
const name = (id) => ({id, name: catalog.players[id].name});
function describe(id) {
  const p = catalog.players[id];
  return `milliyeti ${p.countries.join(" / ")}; mevki grubu ${pos[p.position]}`;
}
function restored(raw) {
  const s = {sessions: {}, active: {}, records: {}, assistedRecords: {}, ...raw};
  for (const r of Object.values(s.sessions)) {
    r.actions ||= {}; r.hints ||= {}; r.used ||= {}; r.human ||= {}; r.bot ||= {}; r.skips ||= {};
    r.owners ||= {}; r.opponents ||= [];
    // RTDB drops empty objects; five history slots must stay addressable.
    if (r.rounds) r.history = Array.from({length: r.round + 1}, (_, i) => r.history?.[i] || {});
    if (r.race) r.race.found ||= {};
  }
  return s;
}
function finish(r, reason, time) {
  if (r.finished) return;
  r.finished = true; r.reason = reason; r.finishedAt = time; r.turn = "done"; r.completed = reason === "completed";
  r.masteryEligible = false; r.leaderboardEligible = false;
  r.winner = r.userScore > r.botScore ? 1 : r.userScore < r.botScore ? 2 : 0;
}

// ---- Football Loto: same 16 players, separate boards, per-player clock.
const LOTO_SECONDS = {easy: 20, medium: 15, hard: 12};
const LOTO_BOT = {easy: [[1800, 2999], .35], medium: [[1200, 2199], .55], hard: [[800, 1499], .75]};
const lotoTiers = (() => {
  const boards = catalog.loto.map((b) => ({...b, avg: b.players.reduce((n, id) => n + catalog.players[id].rank, 0)}))
      .sort((a, b) => a.avg - b.avg || a.id.localeCompare(b.id));
  const third = Math.ceil(boards.length / 3);
  return {easy: boards.slice(0, third), medium: boards.slice(third, 2 * third), hard: boards.slice(2 * third)};
})();
const lotoValid = (r, id, cell) => matches(id, r.board.criteria[cell]);
function lotoStart(r, time) {
  const board = pick(r, lotoTiers[r.difficulty], "board");
  r.board = {id: board.id, criteria: board.criteria, queue: shuffled(board.players, r.seed + "queue")};
  r.humanIndex = 0; r.botIndex = 0;
  r.deadline = time + 1500 + LOTO_SECONDS[r.difficulty] * 1000;
  r.botAt = time + 1500 + between(r, LOTO_BOT[r.difficulty][0], "bot0");
}
function lotoAdvance(r, cell, reason, time) {
  const id = r.board.queue[r.humanIndex];
  if (cell === null) {
    r.skips[id] = reason;
    r.feedback = reason === "timeout" ? "Süre doldu. Sıradaki oyuncu geldi." : "Pas geçildi.";
  } else {
    r.human[cell] = id; r.feedback = catalog.players[id].name + " yerleştirildi.";
  }
  r.humanIndex++;
}
function lotoBotMove(r) {
  const id = r.board.queue[r.botIndex];
  const empty = Array.from({length: 16}, (_, i) => i).filter((i) => r.bot[i] === undefined);
  const correct = empty.filter((i) => lotoValid(r, id, i)); const wrong = empty.filter((i) => !lotoValid(r, id, i));
  const aims = random(r, "aim" + r.botIndex) < LOTO_BOT[r.difficulty][1];
  const candidates = !correct.length ? wrong : !wrong.length || aims ? correct : wrong;
  if (candidates.length) r.bot[pick(r, candidates, "cell" + r.botIndex)] = id;
  r.botIndex++;
  if (r.botIndex < 16) r.botAt += between(r, LOTO_BOT[r.difficulty][0], "bot" + r.botIndex);
}
function lotoTick(r, time) {
  if (r.pausedAt) return;
  const seconds = LOTO_SECONDS[r.difficulty] * 1000;
  while (r.humanIndex < 16 && time >= r.deadline) {
    lotoAdvance(r, null, "timeout", time); r.deadline += seconds;
  }
  // Once the player has finished, only the bot's thinking delays are skipped.
  while (r.botIndex < 16 && (time >= r.botAt || r.humanIndex >= 16)) lotoBotMove(r);
  if (r.humanIndex >= 16 && r.botIndex >= 16) {
    const score = (placed) => 10 * Object.entries(placed).filter(([cell, id]) => lotoValid(r, id, Number(cell))).length;
    r.userScore = score(r.human); r.botScore = score(r.bot); finish(r, "completed", time);
  }
}

// ---- Team Race: chosen club against a random partner, first to three rounds.
const RACE_BOT = {easy: [[6500, 9500], .55], medium: [[4200, 7000], .72], hard: [[2600, 4600], .88]};
function partners(club) {
  const counts = new Map();
  for (const id of answers(club)) {
    for (const v of catalog.players[id].clubs) {
      const other = "club:" + v;
      if (other !== club && catalog.criteria[other]) counts.set(other, (counts.get(other) || 0) + 1);
    }
  }
  return [...counts].filter(([, n]) => n >= 3).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, 16).map(([id]) => id);
}
function raceRound(r, time) {
  const pool = partners(r.club); const fresh = pool.filter((id) => !r.opponents.includes(id));
  const opponent = pick(r, fresh.length ? fresh : pool, "opponent" + r.round);
  const left = answers(r.club); const shared = [...answers(opponent)].filter((id) => left.has(id));
  r.opponents.push(opponent);
  r.race = {round: r.round, opponent, players: shuffled(shared, r.seed + "round" + r.round).slice(0, 12),
    found: {}, userFound: 0, botFound: 0, startsAt: time + 3000, over: false};
  r.race.botAt = r.race.startsAt + between(r, RACE_BOT[r.difficulty][0], "delay" + r.round + ":0");
  r.botTries = 0; r.feedback = null;
}
const remaining = (r) => r.race.players.filter((id) => !r.race.found[id]);
function raceEnd(r, time) {
  if (remaining(r).length) return;
  const race = r.race; race.over = true;
  if (race.userFound > race.botFound) r.userScore++;
  else if (race.botFound > race.userFound) r.botScore++;
  if (r.userScore >= 3 || r.botScore >= 3) finish(r, "completed", time);
}
function raceTick(r, time) {
  const race = r.race;
  if (r.pausedAt || !race || race.over) return;
  while (!race.over && time >= race.botAt) {
    const tries = ++r.botTries;
    if (random(r, "accuracy" + race.round + ":" + tries) > RACE_BOT[r.difficulty][1]) r.feedback = "Bot pas geçti.";
    else {
      const id = pick(r, remaining(r), "claim" + race.round + ":" + tries);
      race.found[id] = 2; race.botFound++; r.feedback = "Bot buldu: " + catalog.players[id].name;
      raceEnd(r, time);
    }
    race.botAt += between(r, RACE_BOT[r.difficulty][0], "delay" + race.round + ":" + tries);
  }
}

// ---- Futbol Çinko: 5×5 board of popular clubs, countries and leagues.
const SIZE = 5;
function component(cells) {
  const left = new Set(cells); let best = [];
  while (left.size) {
    const part = [left.values().next().value]; left.delete(part[0]);
    for (let i = 0; i < part.length; i++) {
      const c = part[i]; const row = Math.floor(c / SIZE);
      for (const n of [c - SIZE, c + SIZE, row === Math.floor((c - 1) / SIZE) ? c - 1 : -1,
        row === Math.floor((c + 1) / SIZE) ? c + 1 : -1]) {
        if (left.delete(n)) part.push(n);
      }
    }
    if (part.length > best.length) best = part;
  }
  return best;
}
function distinct(sets) {
  const owners = new Map();
  function assign(cell, seen) {
    for (const id of sets[cell]) {
      if (seen.has(id)) continue; seen.add(id);
      if (!owners.has(id) || assign(owners.get(id), seen)) {
        owners.set(id, cell); return true;
      }
    }
    return false;
  }
  return sets.every((_, cell) => assign(cell, new Set()));
}
function cinkoBoard(r) {
  for (let attempt = 0; attempt < 20; attempt++) {
    const key = r.seed + attempt; const cells = [];
    const add = (id) => {
      if (!cells.includes(id) && answers(id).size >= 2) cells.push(id);
    };
    const clubs = shuffled(POPULAR_CLUBS, key + "clubs");
    for (const id of clubs) if (cells.length < Math.round(SIZE * SIZE * .7)) add(id);
    for (const id of shuffled(POPULAR_COUNTRIES, key + "countries")) {
      if (cells.length < Math.round(SIZE * SIZE * .7) + Math.round(SIZE * SIZE * .15)) add(id);
    }
    for (const id of shuffled(POPULAR_LEAGUES, key + "leagues")) if (cells.length < SIZE * SIZE) add(id);
    for (const id of clubs) if (cells.length < SIZE * SIZE) add(id);
    const board = shuffled(cells, key + "board");
    if (board.length === SIZE * SIZE && distinct(board.map(answers))) return board;
  }
  fail("failed-precondition", "Çinko tahtası hazırlanamadı. Tekrar dene.");
}
function playable(r) {
  return r.cells.map((_, i) => i).filter((i) => !r.owners[i] &&
    [...answers(r.cells[i])].some((id) => !r.used[id]));
}
function cinkoApply(r, id, cells, owner, time) {
  const correct = cells.filter((i) => matches(id, r.cells[i])); const wrong = cells.filter((i) => !correct.includes(i));
  for (const i of correct) r.owners[i] = {owner, playerId: id};
  r.used[id] = true; r.current = null;
  r.last = {owner, playerId: id, correct, wrong, points: correct.length - wrong.length};
  if (owner === 1) r.userScore += correct.length - wrong.length; else r.botScore += correct.length - wrong.length;
  if (!playable(r).length) finish(r, "completed", time);
}
function cinkoBot(r, time) {
  if (r.turn !== "bot" || r.botAt > time || r.finished) return;
  const open = playable(r); const options = new Map();
  for (const i of open) {
    for (const id of answers(r.cells[i])) {
      if (!r.used[id]) options.set(id, [...options.get(id) || [], i]);
    }
  }
  const cap = {easy: 1, medium: 3, hard: SIZE * SIZE}[r.difficulty]; let best = []; let chosen = null; let ties = 0;
  // Rank connected components, not scattered matches; ties are seeded per move.
  for (const id of [...options.keys()].sort()) {
    const connected = component(options.get(id)).slice(0, cap);
    if (connected.length > best.length) {
      best = connected; chosen = id; ties = 1;
    } else if (connected.length === best.length && random(r, "tie" + r.revision + ":" + id) < 1 / ++ties) {
      best = connected; chosen = id;
    }
  }
  r.turn = "user";
  if (chosen) cinkoApply(r, chosen, best, 2, time);
  else finish(r, "completed", time);
  r.revision++;
}

// ---- Random Five: five shared boards, one user and one bot answer each.
const FIVE_LIMIT = {easy: 2, medium: 3, hard: 5};
let fiveSeeds = null;
function fiveRound(r, previous, i) {
  const pool = POPULAR_CLUBS.filter((id) => answers(id).size >= 2); const inPool = new Set(pool);
  fiveSeeds ||= Object.values(catalog.players).map((p) => p.clubs.map((v) => "club:" + v)
      .filter((id) => inPool.has(id))).filter((ids) => ids.length >= 3);
  const seeds = shuffled(fiveSeeds, r.seed + "seeds" + i).slice(0, 64);
  let best = null; let bestQuality = -1;
  for (const avoid of [true, false]) {
    for (const [n, seed] of seeds.entries()) {
      const key = r.seed + i + ":" + avoid + ":" + n;
      const core = shuffled(seed.filter((id) => !avoid || !previous.includes(id)), key);
      if (core.length < 3) continue;
      const selected = core.slice(0, core.length >= 4 && random(r, key + "four") < .5 ? 4 : 3);
      const counts = new Map();
      const include = (club) => {
        for (const id of answers(club)) counts.set(id, (counts.get(id) || 0) + 1);
      };
      selected.forEach(include);
      while (selected.length < 5) {
        // Club quality = sum over its players already counted: 5 for overlaps of two or more, else 1.
        const quality = new Map();
        for (const [p, n] of counts) {
          for (const v of catalog.players[p].clubs) {
            const id = "club:" + v;
            if (inPool.has(id) && !selected.includes(id) && !(avoid && previous.includes(id))) {
              quality.set(id, (quality.get(id) || 0) + (n >= 2 ? 5 : 1));
            }
          }
        }
        const ranked = [...quality].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
        if (!ranked.length) break;
        const next = pick(r, ranked.slice(0, 5), key + "next" + selected.length)[0];
        selected.push(next); include(next);
      }
      if (selected.length !== 5 || counts.size < 10) continue;
      const triples = [...counts.values()].filter((v) => v >= 3).length;
      const doubles = [...counts.values()].filter((v) => v >= 2).length;
      if (triples * 5 + doubles <= bestQuality) continue;
      bestQuality = triples * 5 + doubles; best = shuffled(selected, key + "order");
      if (triples >= 10 && doubles >= 15) return best;
    }
    if (best) return best;
  }
  fail("failed-precondition", "Beşler için yeterli bağlantısı olan tahta üretilemedi.");
}
const matched = (r, id) => r.rounds[r.round].filter((club) => matches(id, club));
function fiveBot(r, time) {
  if (r.turn !== "bot" || r.botAt > time || r.finished) return;
  const candidates = new Set();
  for (const club of r.rounds[r.round]) for (const id of answers(club)) if (!r.used[id]) candidates.add(id);
  const all = [...candidates].sort();
  const preferred = all.filter((id) => matched(r, id).length <= FIVE_LIMIT[r.difficulty]);
  const available = preferred.length ? preferred : all; let move = {pass: true};
  if (available.length) {
    const scores = available.map((id) => matched(r, id).length);
    const target = preferred.length ? Math.max(...scores) : Math.min(...scores);
    const id = pick(r, available.filter((id) => matched(r, id).length === target), "five" + r.round);
    r.used[id] = true; move = {playerId: id, clubs: matched(r, id)};
  }
  r.history[r.round].bot = move; r.botScore += move.clubs?.length || 0; r.turn = "result"; r.revision++;
  if (r.round === 4) finish(r, "completed", time);
}

// ---- Server-generated support. Text never names the hidden answer.
function targetKey(r, target) {
  const k = kind(r);
  if (k === "loto") {
    if (Number(target) !== r.humanIndex || r.humanIndex >= 16) {
      fail("failed-precondition", "Bu oyuncunun sırası geçti.");
    }
    return "player_" + r.humanIndex;
  }
  if (k === "team_race") {
    if (!r.race || r.race.over || Number(target) !== r.race.round || !remaining(r).length) {
      fail("failed-precondition", "Bu tur kapandı.");
    }
    return "round_" + r.race.round;
  }
  if (k === "cinko") {
    const i = Number(target);
    if (!Number.isInteger(i) || !playable(r).includes(i)) {
      fail("failed-precondition", "Açık ve oynanabilir bir kutu seç.");
    }
    return "cell_" + i;
  }
  if (Number(target) !== r.round || r.turn !== "user") fail("failed-precondition", "Bu tur kapandı.");
  return "round_" + r.round;
}
function hint(r, target) {
  const key = targetKey(r, target);
  if (r.hints[key]) fail("failed-precondition", "Bu yardım zaten açıldı.");
  const k = kind(r);
  if (k === "loto") return {key, text: "Bu oyuncunun " + describe(r.board.queue[r.humanIndex]) + "."};
  if (k === "team_race") {
    return {key, text: "Kalan ortak oyunculardan birinin " + describe(remaining(r).sort(byRank)[0]) + "."};
  }
  if (k === "cinko") {
    const criterion = catalog.criteria[r.cells[Number(target)]];
    const id = [...answers(criterion.id)].filter((id) => !r.used[id]).sort(byRank)[0]; const p = catalog.players[id];
    return {key, text: criterion.type === "country" ?
      `Bu kutuya uyan kullanılmamış bir adayın mevki grubu ${pos[p.position]}; adı "${p.name[0]}" harfiyle başlıyor.` :
      `Bu kutuya uyan kullanılmamış bir adayın ${describe(id)}.`};
  }
  const pool = new Set();
  for (const club of r.rounds[r.round]) for (const id of answers(club)) if (!r.used[id]) pool.add(id);
  const id = [...pool].sort((a, b) => matched(r, b).length - matched(r, a).length || byRank(a, b))[0];
  if (!id) fail("failed-precondition", "Bu turda kullanılabilir aday kalmadı.");
  return {key, text: `Kalan adaylardan biri beş kulübün ${matched(r, id).length} tanesine uyuyor; ${describe(id)}.`};
}
function usable(r, scope) {
  if (!r || r.finished || r.version !== VERSION) return false;
  try {
    return hint(r, scope.target).key === scope.targetKey;
  } catch (_) {
    return false;
  }
}
function tick(r, time) {
  const k = kind(r);
  if (k === "loto") lotoTick(r, time);
  else if (k === "team_race") raceTick(r, time);
  else if (k === "cinko") cinkoBot(r, time);
  else fiveBot(r, time);
}
function reconcile(s, e, time) {
  for (const [id, r] of Object.entries(s.sessions)) {
    if (r.version !== VERSION) finish(r, "catalog_changed", time);
    if (r.expiresAt <= time) finish(r, "expired", time);
    if (!r.finished) tick(r, time);
    B.recoverUnused(e, r, time, (_, scope) => usable(r, scope));
    if (r.finished && !r.recorded) {
      r.recorded = true;
      if (r.completed) {
        const records = r.assisted ? s.assistedRecords : s.records;
        const key = r.mode + ":" + r.difficulty; const old = records[key] || {};
        records[key] = {best: Math.max(old.best || 0, r.userScore), completed: (old.completed || 0) + 1,
          wins: (old.wins || 0) + (r.winner === 1 ? 1 : 0)};
      }
    }
    if (s.active[r.mode] !== id && r.finished && r.createdAt < time - 2 * 86400000 && !r.adCredits) {
      delete s.sessions[id];
    }
  }
}
const side = (m) => m ? {pass: !m.playerId, player: m.playerId ? name(m.playerId) : null,
  clubs: (m.clubs || []).map((id) => catalog.criteria[id])} : null;
function view(r, time) {
  if (!r) return null;
  const k = kind(r); const label = (id) => catalog.criteria[id] || null; const done = r.finished;
  const v = {id: r.id, mode: r.mode, version: r.version, revision: r.revision, difficulty: r.difficulty,
    turn: r.turn, finished: r.finished, completed: !!r.completed, reason: r.reason || null,
    userScore: r.userScore, botScore: r.botScore, winner: r.winner ?? null, feedback: r.feedback || null,
    paused: !!r.pausedAt, hints: r.hints, support: B.view(r), assisted: r.assisted, adGranted: r.adGranted,
    masteryEligible: false, leaderboardEligible: false, rewardCoins: 0, rewardXp: 0, serverNow: time};
  if (k === "loto") {
    // Placement correctness and the bot board stay hidden until both boards are complete.
    Object.assign(v, {criteria: r.board.criteria.map(label), index: r.humanIndex, botIndex: r.botIndex,
      seconds: LOTO_SECONDS[r.difficulty], deadline: r.humanIndex < 16 ? r.deadline : null,
      // A paused clock must not become free thinking time for the shown player.
      current: r.humanIndex < 16 && !r.pausedAt ? name(r.board.queue[r.humanIndex]) : null,
      placements: Object.fromEntries(Object.entries(r.human).map(([cell, id]) =>
        [cell, {...name(id), ...done ? {correct: lotoValid(r, id, Number(cell))} : {}}])),
      passed: Object.values(r.skips).filter((x) => x === "pass").length,
      timedOut: Object.values(r.skips).filter((x) => x === "timeout").length});
    if (done) {
      v.botPlacements = Object.fromEntries(Object.entries(r.bot).map(([cell, id]) =>
        [cell, {...name(id), correct: lotoValid(r, id, Number(cell))}]));
    }
  } else if (k === "team_race") {
    const race = r.race;
    Object.assign(v, {club: label(r.club), round: race.round, opponent: label(race.opponent),
      startsAt: race.startsAt, over: race.over, total: race.players.length, remaining: remaining(r).length,
      userFound: race.userFound, botFound: race.botFound,
      found: Object.entries(race.found).map(([id, owner]) => ({...name(id), owner}))});
  } else if (k === "cinko") {
    const open = playable(r);
    Object.assign(v, {cells: r.cells.map((id, i) => ({...label(id), owner: r.owners[i]?.owner || 0,
      player: r.owners[i] ? name(r.owners[i].playerId) : null, playable: open.includes(i)})),
    current: r.current ? name(r.current) : null, botAt: r.turn === "bot" ? r.botAt : null,
    last: r.last ? {owner: r.last.owner, pass: !r.last.playerId, points: r.last.points || 0,
      correct: r.last.correct || [], wrong: r.last.wrong || [],
      player: r.last.playerId ? name(r.last.playerId) : null} : null});
  } else {
    Object.assign(v, {round: r.round, totalRounds: 5, clubs: r.rounds[r.round].map(label),
      botAt: r.turn === "bot" ? r.botAt : null,
      history: r.history.map((h, i) => ({round: i, clubs: r.rounds[i].map(label),
        user: side(h.user), bot: side(h.bot)}))});
  }
  return v;
}
function begin(r, input, time) {
  const k = kind(r);
  if (k === "loto") lotoStart(r, time);
  else if (k === "team_race") {
    if (catalog.criteria[input.clubId]?.type !== "club" || !partners(input.clubId).length) {
      fail("invalid-argument", "Bu kulüp için yeterli ortak oyuncu yok.");
    }
    r.club = input.clubId; r.round = 0; r.opponents = []; raceRound(r, time);
  } else if (k === "cinko") r.cells = cinkoBoard(r);
  else {
    r.rounds = [];
    for (let i = 0; i < 5; i++) r.rounds.push(fiveRound(r, r.rounds.at(-1) || [], i));
    r.round = 0; r.history = [{}];
  }
}
function move(r, input, time) {
  const k = kind(r); const action = input.action;
  if (action === "pause" && realtime(r)) {
    if (!r.pausedAt) r.pausedAt = time; return;
  }
  if (action === "resume" && realtime(r)) {
    if (r.pausedAt) {
      const shift = time - r.pausedAt; delete r.pausedAt;
      if (k === "loto") {
        r.deadline += shift; r.botAt += shift;
      } else if (!r.race.over) {
        r.race.startsAt += shift; r.race.botAt += shift;
      }
    }
    return;
  }
  if (r.pausedAt) fail("failed-precondition", "Oyun duraklatıldı. Devam et.");
  if (k === "loto") {
    if (input.index !== r.humanIndex || r.humanIndex >= 16) fail("failed-precondition", "Sıradaki oyuncu değişti.");
    const cell = Number(input.target);
    if (action === "place") {
      if (!Number.isInteger(cell) || cell < 0 || cell >= 16 || r.human[cell] !== undefined) {
        fail("invalid-argument", "Boş bir kutu seç.");
      }
      lotoAdvance(r, cell, null, time);
    } else if (action === "pass") lotoAdvance(r, null, "pass", time);
    else fail("invalid-argument", "İşlem geçersiz.");
    r.deadline = time + LOTO_SECONDS[r.difficulty] * 1000; lotoTick(r, time); return;
  }
  if (k === "team_race") {
    const race = r.race;
    if (action === "next") {
      if (!race.over) fail("failed-precondition", "Tur sürüyor.");
      r.round++; raceRound(r, time); return;
    }
    if (action !== "guess") fail("invalid-argument", "İşlem geçersiz.");
    if (race.over || Number(input.round) !== race.round) fail("failed-precondition", "Bu tur kapandı.");
    if (time < race.startsAt) fail("failed-precondition", "Geri sayım sürüyor.");
    if (!catalog.players[input.playerId]) fail("invalid-argument", "Listeden bir futbolcu seç.");
    if (race.found[input.playerId]) r.feedback = "Bu oyuncu zaten bulundu.";
    else if (!race.players.includes(input.playerId)) r.feedback = "Bu oyuncu bu eşleşmeye uymuyor.";
    else {
      race.found[input.playerId] = 1; race.userFound++;
      r.feedback = "Doğru! " + catalog.players[input.playerId].name + " · +1"; raceEnd(r, time);
    }
    return;
  }
  if (k === "random_five" && action === "next") {
    if (r.turn !== "result") fail("failed-precondition", "Tur sonucu henüz hazır değil.");
    r.round++; r.history.push({}); r.turn = "user"; return;
  }
  if (r.turn !== "user") fail("failed-precondition", "Sıra botta.");
  if (k === "cinko") {
    if (action === "choose") {
      const id = input.playerId;
      if (!catalog.players[id] || r.used[id]) fail("invalid-argument", "Bu oyuncu bu maçta kullanılamaz.");
      if (!playable(r).some((i) => matches(id, r.cells[i]))) {
        r.feedback = "Bu oyuncuya uyan açık kutu kalmadı. Başka bir oyuncu seç."; return;
      }
      r.current = id; r.feedback = null; return;
    }
    if (action === "cancel") {
      r.current = null; return;
    }
    if (action === "confirm") {
      const cells = input.cells; const open = playable(r);
      if (!r.current || !Array.isArray(cells) || !cells.length || new Set(cells).size !== cells.length ||
        cells.some((i) => !open.includes(i))) fail("invalid-argument", "Önce oyuncu ve açık kutular seç.");
      if (component(cells).length !== cells.length) {
        fail("invalid-argument", "Kutular yan yana veya üst üste bağlı kalmalı. Çapraz bağlantı sayılmaz.");
      }
      cinkoApply(r, r.current, cells, 1, time);
    } else if (action === "pass") {
      r.current = null; r.last = {owner: 1, pass: true, points: 0};
    } else fail("invalid-argument", "İşlem geçersiz.");
    if (!r.finished) {
      r.turn = "bot"; r.botAt = time + (action === "pass" ? 0 : 1100) + between(r, [850, 1300], "bot" + r.revision);
    }
    return;
  }
  if (action === "guess") {
    const id = input.playerId;
    if (!catalog.players[id]) fail("invalid-argument", "Listeden bir futbolcu seç.");
    // A rejected name is an edit, not a spent turn.
    if (r.used[id]) {
      r.feedback = "Bu oyuncu bu maçta zaten kullanıldı. Başka bir isim seç."; return;
    }
    if (!matched(r, id).length) {
      r.feedback = catalog.players[id].name + " bu beş kulübe uymuyor. Başka bir isim deneyebilirsin."; return;
    }
    r.used[id] = true; r.history[r.round].user = {playerId: id, clubs: matched(r, id)};
    r.userScore += matched(r, id).length;
  } else if (action === "pass") r.history[r.round].user = {pass: true};
  else fail("invalid-argument", "İşlem geçersiz.");
  r.feedback = null; r.turn = "bot"; r.botAt = time + between(r, [900, 1400], "bot" + r.round);
}
function createService({db, normalize, project, isLinked, now = Date.now}) {
  const mode = (input) => {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz bot modu."); return input.mode;
  };
  const read = async (uid) => restored((await db.ref("economyState/" + uid + "/botSupport").get()).val());
  async function change(uid, fn) {
    const ref = db.ref("economyState/" + uid); const base = (await ref.get()).val();
    const tx = await ref.transaction((raw) => {
      const e = normalize(structuredClone(raw ?? base)); const s = restored(e.botSupport);
      reconcile(s, e, now()); fn(s, e); reconcile(s, e, now()); e.botSupport = s; return e;
    });
    if (!tx.committed) fail("aborted", "Oyunu yenile.");
    await project(db, uid, normalize(tx.snapshot.val())); return restored(tx.snapshot.val().botSupport);
  }
  const response = (s, m, enabled) => ({legacy: !enabled && !s.active[m], availability: enabled,
    session: view(s.sessions[s.active[m]], now()), records: s.records, assistedRecords: s.assistedRecords,
    version: VERSION, serverNow: now(), clubIds: POPULAR_CLUBS});
  async function status(uid, input) {
    const m = mode(input); const policy = await B.policyFor(db, uid, await isLinked(uid));
    const before = await read(uid); const s = before.active[m] ? await change(uid, () => {}) : before;
    return response(s, m, policy?.readyModes?.[m] === true);
  }
  async function search(uid, input) {
    const m = mode(input); const s = await read(uid); const r = s.sessions[s.active[m]];
    if (!await isLinked(uid) || !r || r.finished || r.id !== input.sessionId || r.expiresAt <= now() ||
      kind(r) === "loto") fail("failed-precondition", "Aktif bot oyunu bulunamadı.");
    if (typeof input.query !== "string" || input.query.length > 80) fail("invalid-argument", "Arama geçersiz.");
    const q = P.norm(input.query); if (q.length < 2) return {players: []};
    // Search covers the whole catalog: it never narrows suggestions to correct answers.
    const used = kind(r) === "team_race" ? r.race.found : r.used;
    return {players: Object.values(catalog.players).filter((p) => !used[p.id] &&
      [p.name, ...p.aliases].some((s) => P.norm(s).includes(q))).sort((a, b) => a.rank - b.rank).slice(0, 20)
        .map((p) => ({id: p.id, name: p.name}))};
  }
  async function act(uid, input) {
    const m = mode(input);
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "")) fail("invalid-argument", "İşlem kimliği geçersiz.");
    const policy = await B.policyFor(db, uid, true); const seed = crypto.randomBytes(32).toString("hex");
    const fp = P.hash([m, input.action, input.sessionId, input.version, input.revision, input.target,
      input.playerId, input.cells, input.index, input.round, input.difficulty, input.clubId,
      ...B.paymentFingerprint(input)]);
    const s = await change(uid, (s, e) => {
      const time = now();
      if (input.action === "start") {
        const id = "bot_" + input.requestId;
        if (s.sessions[id]) {
          if (s.sessions[id].startFingerprint !== fp) fail("invalid-argument", "İstek değiştirilemez."); return;
        }
        if (policy?.readyModes?.[m] !== true || input.version !== VERSION) {
          fail("failed-precondition", "Yeni bot oyunu şu anda kapalı veya katalog değişti.");
        }
        if (s.sessions[s.active[m]] && !s.sessions[s.active[m]].finished) {
          fail("failed-precondition", "Önce açık oyunu bitir.");
        }
        const difficulty = input.difficulty || "medium";
        if (!["easy", "medium", "hard"].includes(difficulty)) fail("invalid-argument", "Zorluk geçersiz.");
        const r = {id, mode: m, version: VERSION, revision: 0, seed, difficulty, startFingerprint: fp,
          createdAt: time, expiresAt: time + 86400000, turn: "user", finished: false, actions: {}, hints: {},
          used: {}, userScore: 0, botScore: 0, adCredits: 0, adGranted: 0};
        begin(r, input, time); B.pin(r, policy);
        // Loto's per-player clock keeps running; an ad would cost the turn, so it is stock/Coin only.
        if (kind(r) === "loto" && r.boostPolicy) r.boostPolicy.products.boost_basic.ads = false;
        s.sessions[id] = r; s.active[m] = id; return;
      }
      const r = s.sessions[input.sessionId];
      if (!r || r.mode !== m || r.version !== input.version) fail("failed-precondition", "Bot oyunu değişti.");
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek değiştirilemez."); return;
      }
      // Real-time modes guard by player index / round; bot clock ticks do not stale the client.
      if (r.finished || r.version !== VERSION || !realtime(r) && r.revision !== input.revision) {
        fail("failed-precondition", "Oyun güncellendi. Yenile.");
      }
      if (input.action === "finish") finish(r, "partial", time);
      else if (input.action === "hint") {
        if (r.pausedAt) fail("failed-precondition", "Oyun duraklatıldı. Devam et.");
        if (!realtime(r) && r.turn !== "user") fail("failed-precondition", "Sıra botta.");
        const info = hint(r, input.target);
        if (input.paymentSource === "ad" && r.adScopes?.boost_basic?.targetKey !== info.key) {
          fail("failed-precondition", "Reklam hakkı başka bir hedefe ait.");
        }
        B.consume(e, r, input, "boost_basic", info.key, {text: info.text}, time); r.hints[info.key] = info.text;
      } else move(r, input, time);
      r.actions[input.requestId] = fp; r.revision++;
    });
    return response(s, m, policy?.readyModes?.[m] === true);
  }
  async function prepareHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "bot_support_hint") fail("permission-denied", "Hesap gerekli.");
    const s = await read(uid); const r = s.sessions[input.sessionId];
    if (!B.paid(r) || r.finished || r.expiresAt <= now() || r.version !== VERSION || input.boostId !== "boost_basic" ||
      !r.boostPolicy.products.boost_basic.ads || !realtime(r) && r.turn !== "user") {
      fail("failed-precondition", "Bu destek şu anda reklamla alınamaz.");
    }
    if (r.adProducts?.boost_basic > 0) {
      fail("failed-precondition", "Önce bekleyen reklam hakkını kullan veya ilgili hedefi tamamla.");
    }
    const info = hint(r, input.target);
    return B.adBenefit(r, {amount: 0, claimKey: "bot_hint_" + r.id + "_" + info.key,
      context: {sessionId: r.id, target: input.target, targetKey: info.key}}, "boost_basic");
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e) => {
      const r = s.sessions[receipt.context?.sessionId];
      if (!B.recoverAd(e, r, receipt, now(), "boost_basic", usable(r, receipt.context))) B.grantAd(r, receipt);
    });
  }
  return {status, search, act, prepareHint, settleHint};
}
module.exports = {createService, MODES, VERSION, catalog, answers, matches, hint, view, lotoTiers, cinkoBoard,
  fiveRound, component, partners, POPULAR_CLUBS};
