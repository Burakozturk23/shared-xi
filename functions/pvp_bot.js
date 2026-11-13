"use strict";
// Ranked fallback bot. When a ranked search finds nobody within BOT_AFTER_MS, a bot
// takes the second seat. It is shown as a bot ("Linkball Botu"), plays through the
// engine's own move() with the same rules and clocks as a person, keeps its presence
// fresh so the 60-second absence rule never fires, and is beatable: it thinks a few
// seconds and answers right about six times in ten. Its moves are a pure function of
// the room and the time, so a replayed poll makes the same move.
const crypto = require("node:crypto");
const E = require("./pvp_engine");

const BOT_AFTER_MS = 20000;
const BOT_NAME = "Linkball Botu";
const BOT_PREFIX = "bot:";
const isBot = (uid) => typeof uid === "string" && uid.startsWith(BOT_PREFIX);
const ACCURACY = 0.62;
const KNOWN = 75;

function roll(...key) {
  return parseInt(crypto.createHash("sha256").update(JSON.stringify(key)).digest("hex").slice(0, 8), 16) / 0x100000000;
}
const pick = (list, ...key) => list.length ? list[Math.floor(roll(...key) * list.length)] : null;

// Known players, best first, built once per catalog.
const knownCache = new WeakMap();
function known(c) {
  if (!knownCache.has(c)) {
    knownCache.set(c, Object.keys(c.players).filter((id) => c.players[id].rating >= KNOWN && !c.players[id].shadow)
        .sort((a, b) => c.players[b].rating - c.players[a].rating));
  }
  return knownCache.get(c);
}
// A right answer a fan would give: a known player first, any player otherwise.
function rightOf(c, ids, used, ...key) {
  const open = ids.filter((id) => !used(id));
  const famous = open.filter((id) => c.players[id]?.rating >= KNOWN);
  return pick(famous.length ? famous.slice(0, 12) : open, ...key);
}
// A wrong answer: a known player who does not fit.
function wrongOf(c, fits, used, ...key) {
  const pool = known(c).filter((id) => !used(id) && !fits(c.players[id])).slice(0, 400);
  return pick(pool, ...key);
}

/** Seats the bot in a ranked room that waited BOT_AFTER_MS for a person. */
function join(r, time) {
  const uid = BOT_PREFIX + r.id;
  r.guest = uid; r.names[uid] = BOT_NAME; r.status = "ready"; r.revision++;
  r.bot = {uid, joinedAt: time, steps: 0};
  r.ready = {...r.ready, [uid]: true};
  r.presence = {[uid]: time, [r.host]: time};
  return uid;
}

/** The bot's move for this moment, if any: one at most per call. */
function step(c, r, time) {
  const uid = r.bot?.uid;
  if (!uid || E.terminal(r)) return null;
  r.presence[uid] = time;
  if (r.status === "ready") {
    r.ready[uid] = true; return null;
  }
  if (r.status !== "playing" || time < r.startsAt) return null;
  const input = decide(c, r, uid, time);
  if (!input) return null;
  try {
    const result = E.move(c, r, uid, input, time);
    r.bot.steps++; r.bot.last = time;
    return result;
  } catch (error) {
    // A move the rules refuse (a lock, a closed round) is simply not made.
    r.bot.last = time;
    return null;
  }
}

// Think a few seconds after a turn, call or round opens (seeded per room and moment).
const thought = (r, opened, key) => opened + 2500 + Math.floor(roll(r.id, "think", key) * 6000);
const right = (r, key) => roll(r.id, "right", key) < ACCURACY;

function decide(c, r, uid, time) {
  const turnStart = r.turnDeadline ? r.turnDeadline - 45000 : r.startsAt;
  const myTurn = r.turnUid === uid;
  const mine = (key) => key + ":" + uid;
  if (r.managerRules === 3) return manager(c, r, uid, time);
  if (r.lotoRules === 3) return loto(c, r, uid, time);
  if (r.fiveRules === 3) return five(c, r, uid, time);
  if (r.mode === "cinko") {
    return myTurn && time >= thought(r, turnStart, mine("c" + r.turnDeadline)) ? cinko(c, r, uid) : null;
  }
  if (r.randomBoard) {
    return myTurn && time >= thought(r, turnStart, mine("b" + r.turnDeadline)) ? board(c, r, uid) : null;
  }
  if (r.mode === "grid_reverse") {
    return myTurn && time >= thought(r, turnStart, mine("v" + r.turnDeadline)) ? reverse(c, r) : null;
  }
  if (r.mode === "grid_classic") {
    return myTurn && time >= thought(r, turnStart, mine("g" + r.turnDeadline)) ? grid(c, r) : null;
  }
  if (["club_club", "club_country"].includes(r.mode)) return race(c, r, uid, time);
  return null;
}

function grid(c, r) {
  const used = (id) => !!r.used[id];
  const cells = [...Array(9).keys()].filter((i) => !r.owners[i]);
  const i = pick(cells, r.id, "cell", r.turnDeadline); if (i === null) return null;
  const key = [r.id, "grid", r.turnDeadline];
  const fits = (p) => E.matches(c, p, r.puzzle.rows[Math.floor(i / 3)]) && E.matches(c, p, r.puzzle.cols[i % 3]);
  const id = right(r, key) ? rightOf(c, r.puzzle.answers[i] || [], used, ...key) : wrongOf(c, fits, used, ...key);
  return id && {action: "answer", targetId: i, playerId: id};
}
function reverse(c, r) {
  const axes = ["r0", "r1", "r2", "c0", "c1", "c2"].filter((a) => !r.owners[a]);
  const axis = pick(axes, r.id, "axis", r.turnDeadline); if (!axis) return null;
  const truth = (axis[0] === "r" ? r.puzzle.rows : r.puzzle.cols)[Number(axis[1])];
  const criterionId = right(r, [r.id, "rev", r.turnDeadline]) ? truth :
    pick(Object.keys(c.criteria).filter((k) => k !== truth).slice(0, 300), r.id, "revw", r.turnDeadline);
  return {action: "answer", targetId: axis, criterionId};
}
function board(c, r) {
  const used = (id) => !!r.used[id]; const key = [r.id, "board", r.turnDeadline];
  if (r.pending) {
    const anchor = pick(E.ANCHORS.filter((i) => !r.owners[i]), ...key); if (anchor === null) return null;
    const [a, b] = r.pending.criteria; const both = new Set(E.answersOf(c, b));
    const fits = (p) => E.matches(c, p, a) && E.matches(c, p, b);
    const id = right(r, key) ? rightOf(c, E.answersOf(c, a).filter((x) => both.has(x)), used, ...key) :
      wrongOf(c, fits, used, ...key);
    return id && {action: "answer", targetId: anchor, playerId: id};
  }
  const open = [0, 1, 3, 5, 7, 8].filter((i) => !r.owners[i]).map((i) => [i, E.crossing(c, r, i)])
      .filter(([, fit]) => fit?.length);
  if (open.length) {
    const [i, fit] = pick(open, ...key); const row = r.boardRows[Math.floor(i / 3)]; const col = r.boardCols[i % 3];
    const fits = (p) => E.matches(c, p, row) && E.matches(c, p, col);
    const id = right(r, key) ? rightOf(c, fit, used, ...key) : wrongOf(c, fits, used, ...key);
    return id && {action: "answer", targetId: i, playerId: id};
  }
  return E.ANCHORS.some((i) => !r.owners[i]) ? {action: "draw"} : null;
}
function cinko(c, r, uid) {
  const used = (id) => !!r.used[id]; const key = [r.id, "cinko", r.turnDeadline];
  const open = E.cinkoOpen(c, r);
  if (!open.length || !right(r, key)) return {action: "pass"};
  const i = pick(open, ...key); const id = rightOf(c, E.answersOf(c, r.puzzle.criteria[i]), used, ...key);
  return id ? {action: "answer", playerId: id, cells: [i]} : {action: "pass"};
}
function race(c, r, uid, time) {
  // A guess every 6-12 s; the rules' own wrong-answer locks still apply.
  const last = r.bot.last || r.startsAt;
  if (time < last + 6000 + Math.floor(roll(r.id, "race", r.bot.steps) * 6000)) return null;
  const used = (id) => !!r.used[id]; const key = [r.id, "race", r.bot.steps];
  const q = r.puzzle.rounds[0]; const fits = (p) => q.criteria.every((k) => E.matches(c, p, k));
  const id = right(r, key) ? rightOf(c, q.answers || [], used, ...key) : wrongOf(c, fits, used, ...key);
  return id && {action: "answer", playerId: id};
}
function five(c, r, uid, time) {
  const i = E.list(r.fiveStarts).length - 1; const a = r.answers[i] || {};
  if (i < 0 || a[uid] || a.revealed || time < thought(r, r.fiveStarts[i], "five" + i)) return null;
  const used = (id) => !!r.used[uid + "__" + id]; const clubs = r.puzzle.boards[i]; const key = [r.id, "five", i];
  const count = (id) => clubs.filter((k) => E.matches(c, c.players[id], k)).length;
  const candidates = [...new Set(clubs.flatMap((k) => E.answersOf(c, k)))]
      .filter((id) => !used(id) && c.players[id].rating >= KNOWN);
  if (!candidates.length) return null;
  // Right: one of the best fits; otherwise a single-club player or, half the time, a miss.
  const best = Math.max(...candidates.map(count));
  if (!right(r, key) && roll(...key, "miss") < 0.5) {
    const miss = wrongOf(c, (p) => clubs.some((k) => E.matches(c, p, k)), used, ...key);
    if (miss) return {action: "answer", playerId: miss, round: i};
  }
  const pool = candidates.filter((id) => right(r, key) ? count(id) === best : count(id) === 1);
  const id = pick(pool.length ? pool : candidates, ...key);
  return {action: "answer", playerId: id, round: i};
}
function loto(c, r, uid, time) {
  const i = E.list(r.lotoCalls).length - 1; const a = r.answers[i] || {};
  if (i < 0 || a[uid] || a.revealed || time < thought(r, r.lotoCalls[i], "loto" + i)) return null;
  const id = r.lotoQueue[i]; const card = r.cards?.[uid] || {}; const key = [r.id, "loto", i];
  const empty = r.puzzle.criteria.map((_, k) => k).filter((k) => !card["c" + k]);
  const fits = empty.filter((k) => E.matches(c, c.players[id], r.puzzle.criteria[k]));
  if (fits.length && right(r, key)) return {action: "answer", targetId: pick(fits, ...key), round: i};
  // Unsure: mostly pass, sometimes a wrong cell.
  const wrong = empty.filter((k) => !fits.includes(k));
  return roll(...key, "pass") < 0.7 || !wrong.length ? {action: "pass", round: i} :
    {action: "answer", targetId: pick(wrong, ...key), round: i};
}
function manager(c, r, uid, time) {
  const q = r.puzzle;
  if (r.draft && r.draft.k < E.DRAFT_PICKS && r.turnUid === uid) {
    const opened = r.draft.deadline ? r.draft.deadline - E.DRAFT_PICK_MS : r.startsAt;
    if (time < opened + 1500 + Math.floor(roll(r.id, "pick", r.draft.k) * 2500)) return null;
    const legal = E.legalPicks(r, uid).sort((x, y) => q.meta[y].rating - q.meta[x].rating);
    // Mostly the best player left, now and then the second or third.
    const n = Math.min(legal.length, roll(r.id, "pickn", r.draft.k) < 0.6 ? 1 : 3);
    return legal.length ? {action: "pick", playerId: pick(legal.slice(0, n), r.id, "pickp", r.draft.k)} : null;
  }
  if (r.plan && !r.plan.choices?.[uid]) {
    const mine = E.list(r.draft?.picks?.[uid]);
    if (!mine.length) return null;
    const captain = [...mine].sort((x, y) => q.meta[y].rating - q.meta[x].rating)[0];
    return {action: "plan", plan: pick(E.PLANS, r.id, "plan"), captain};
  }
  return null;
}

module.exports = {BOT_AFTER_MS, BOT_NAME, BOT_PREFIX, isBot, join, step, decide};
