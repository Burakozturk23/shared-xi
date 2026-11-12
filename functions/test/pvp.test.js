"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const E = require("../pvp_engine");
const {harness} = require("./support/economy_harness");
const c = E.catalog;
const base = (mode) => ({mode, schemaVersion: 1, ruleVersion: E.RULE, dataRevision: c.version});
let serial = 0;
const id = () => (++serial).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const boot = () => harness({runtimeConfig: {pvp: {friendEnabled: true, rankedEnabled: true,
  rewardsEnabled: true, eloEnabled: true}}}, {omitEmptyObjects: true});
const enter = async (h, uid, mode, action, extra = {}) => (await h.call("enterPvp", {...base(mode),
  action, actionId: id(), playKind: "friend", ...extra}, auth(uid))).room;
const act = async (h, uid, r, action = "poll", extra = {}) => (await h.call("actPvp", {...base(r.mode),
  roomId: r.id, action, revision: r.revision, ...(action === "poll" ? {} : {actionId: id()}), ...extra},
auth(uid))).room;
const raw = (h, r) => h.read(`pvpV1/${r.mode}/rooms/${r.id}`);
// A Grid Random room as started before the board rules: five fixed rounds.
function legacyRandom(h, r) {
  const at = `pvpV1/grid_random/rooms/${r.id}`; const q = raw(h, r);
  h.seed(`${at}/randomBoard`, null); h.seed(`${at}/puzzle`, E.puzzle(c, "grid_random", q.seed));
  h.seed(`${at}/endsAt`, q.startsAt + 160000);
}
// A Random Five room as started before the rounds: one board for 90 s.
function legacyFive(seed) {
  const r = E.hydrate({mode: "random_five", host: "a", guest: "b", seed, dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; r.fiveRules = 2; delete r.fiveStarts;
  r.puzzle = {id: "legacy", clubs: E.puzzle(c, "random_five", seed).boards[0]}; r.endsAt = r.startsAt + 90000;
  return r;
}
// Random Five rounds: the best and a fitting-none player of a five.
const fiveFit = (clubs, id) => clubs.filter((k) => E.matches(c, c.players[id], k)).length;
const fiveBest = (clubs, not = []) => Object.keys(c.players).filter((id) => !not.includes(id))
    .sort((x, y) => fiveFit(clubs, y) - fiveFit(clubs, x))[0];
const fiveNone = (clubs) => Object.keys(c.players).find((id) => !fiveFit(clubs, id));
// A Club Manager room as started before the draft: one budget pool, simultaneous XIs.
function legacyManager(h, r) {
  const at = `pvpV1/club_manager/rooms/${r.id}`; const q = raw(h, r);
  h.seed(`${at}/managerRules`, 2); h.seed(`${at}/puzzle`, E.puzzle(c, "club_manager", q.seed));
  h.seed(`${at}/draft`, null); h.seed(`${at}/endsAt`, q.startsAt + 180000);
}
function legacyRoom(seed) {
  const r = E.hydrate({mode: "grid_random", host: "a", guest: "b", seed, dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; delete r.randomBoard;
  r.puzzle = E.puzzle(c, "grid_random", seed); r.endsAt = r.startsAt + 160000; return r;
}
// Grid Random board rooms: who is to move, the other side, and a player fitting two criteria.
const fits = (a, b, not = []) => Object.keys(c.players).find((id) => !not.includes(id) &&
  E.matches(c, c.players[id], a) && E.matches(c, c.players[id], b));
const misfit = (a, b) => Object.keys(c.players).find((id) => !E.matches(c, c.players[id], a) ||
  !E.matches(c, c.players[id], b));
function boardRoom(seed) {
  const r = E.hydrate({mode: "grid_random", host: "a", guest: "b", seed, dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; return r;
}
// One full correct placement of a Loto board (players are stored shuffled).
function lotoSolution(board) {
  const cellOf = {};
  const tryPlace = (p, seen) => board.criteria.some((k, cell) => {
    if (!E.matches(c, c.players[p], k) || seen.has(cell)) return false;
    seen.add(cell);
    if (cellOf[cell] === undefined || tryPlace(cellOf[cell], seen)) {
      cellOf[cell] = p; return true;
    }
    return false;
  });
  for (const p of board.players) if (!tryPlace(p, new Set())) return null;
  return cellOf;
}
async function pair(h, mode, ranked = false, names = ["alice", "bob"], seed = null) {
  const [a, b] = names; const extra = {playKind: ranked ? "ranked" : "friend"};
  let r = await enter(h, a, mode, ranked ? "search" : "create", extra);
  if (seed) h.seed(`pvpV1/${mode}/rooms/${r.id}/seed`, seed);
  r = await enter(h, b, mode, ranked ? "search" : "join", {...extra, code: r.id});
  if (!ranked && ["club_club", "club_country"].includes(mode)) {
    const p = c.pairs.find((p) => p.answers.length >= 8 && p.criteria[1].startsWith(
        mode === "club_club" ? "club:" : "country:"));
    r = await act(h, a, r, "choose", {choice: p.criteria[0]});
    r = await act(h, b, r, "choose", {choice: p.criteria[1]});
  }
  r = await act(h, a, r, "ready"); r = await act(h, b, r, "ready");
  h.setTime(new Date(r.startsAt + 100).toISOString());
  await act(h, a, r); return act(h, b, r);
}
test("CORE01-06/CL05/GC01/CI01/LO01: canonical snapshot and solvability certificates", () => {
  assert.equal(c.grids.length, 300); assert.equal(c.cinko.length, 200); assert.equal(c.loto.length, 300);
  for (const g of c.grids) {
    for (let i = 0; i < 9; i++) {
      assert(E.matches(c, c.players[g.witness[i]], g.rows[Math.floor(i / 3)]));
      assert(E.matches(c, c.players[g.witness[i]], g.cols[i % 3]));
      assert(g.answers[i].length >= 3);
      assert(g.answers[i].some((id) => c.players[id].rank <= 3000), g.id);
    }
  }
  for (const g of c.loto) {
    assert.equal(new Set(g.players).size, 16);
    // A full correct board exists, and stored order is not the answer order.
    assert.ok(lotoSolution(g), g.id);
    assert.ok(g.players.some((p, i) => !E.matches(c, c.players[p], g.criteria[i])), g.id);
  }
  for (const mode of E.MODES) assert(E.puzzle(c, mode, "fixed"));
});
test("NAV01/02/05/CORE11: mode and protocol cannot silently fall back; rollout defaults closed", async () => {
  const h = boot(); const r = await enter(h, "alice", "club_country", "create");
  assert.equal(r.mode, "club_country");
  await assert.rejects(enter(h, "bob", "club_club", "join", {code: r.id}), {code: "failed-precondition"});
  await assert.rejects(enter(harness(), "alice", "club_manager", "search", {playKind: "ranked"}), {code:
      "failed-precondition"});
  await assert.rejects(h.call("getPvp", {...base("club_club"), schemaVersion: 0}, auth("alice")), {code:
      "failed-precondition"});
});
test("SEC01/05/07/08/09/11: authority, intent-only payload, duplicate/concurrent receipts", async () => {
  const h = boot(); let r = await pair(h, "club_club"); const p = raw(h, r).puzzle.rounds[0].answers[0];
  assert.equal(r.answers, undefined); assert.equal(r.puzzle, undefined); assert.equal(r.seed, undefined);
  await assert.rejects(act(h, "mallory", r), {code: "permission-denied"});
  await assert.rejects(act(h, "alice", r, "answer", {playerId: p, score: 99}), {code: "invalid-argument"});
  const request = {...base(r.mode), roomId: r.id, action: "answer", actionId: id(), playerId: p};
  await Promise.all([h.call("actPvp", request, auth("alice")), h.call("actPvp", request, auth("alice"))]);
  r = await act(h, "bob", r); assert.equal(r.scores.alice, 1);
  await assert.rejects(act(h, "bob", r, "answer", {playerId: p}), {code: "already-exists"});
  await assert.rejects(h.call("actPvp", {...request, playerId: "1"}, auth("alice")), {code: "invalid-argument"});
});
test("GC02-06/SEC06: wrong type, wrong turn, invalid player and stale claims cannot seize cells", async () => {
  const h = boot(); let r = await pair(h, "grid_classic"); const u = r.turnUid;
  const other = u === "alice" ? "bob" : "alice"; const g = raw(h, r).puzzle;
  await assert.rejects(act(h, other, r, "answer", {targetId: 0, playerId: g.witness[0]}), {code: "permission-denied"});
  await assert.rejects(act(h, u, r, "answer", {targetId: 0, playerId: "invalid"}), {code: "invalid-argument"});
  r = await act(h, u, r, "answer", {targetId: 0, playerId: g.witness[0]}); assert.equal(r.owners[0].uid, u);
  await assert.rejects(act(h, other, r, "answer", {targetId: 0, playerId: g.witness[1]}), {code: "invalid-argument"});
  await assert.rejects(act(h, other, {...r, revision: 0}, "answer", {targetId: 1, playerId:
      g.witness[1]}), {code: "aborted"});
});
test("GR01-06: both players have five equal rounds; opponent answer/used ID hidden until closure", async () => {
  const h = boot(); let r = await pair(h, "grid_random"); legacyRandom(h, r); const q = raw(h, r);
  const used = new Set();
  for (let i = 0; i < 5; i++) {
    for (const t of [q.startsAt + i * 32000 - 1000, q.startsAt + i * 32000 + 100]) {
      if (t < q.startsAt) continue; h.setTime(new Date(t).toISOString()); await act(h, "alice", r); r =
          await act(h, "bob", r);
    }
    // The best-known unused answer: no rarity bonus, so both score one point a round.
    const answer = [...q.puzzle.rounds[i].answers].sort((a, b) => c.players[a].rank - c.players[b].rank)
        .find((p) => !used.has(p)); used.add(answer);
    r = await act(h, "alice", r, "answer", {playerId: answer, round: i});
    const peer = await act(h, "bob", r); assert.equal(peer.rounds[i], undefined);
    assert.deepEqual(peer.used, {}); assert.equal(peer.scores.alice, i);
    r = await act(h, "bob", r, "answer", {playerId: answer, round: i});
    assert.equal(r.scores.alice, i + 1); assert.equal(r.scores.bob, i + 1);
    h.setTime(new Date(q.startsAt + i * 32000 + 20000).toISOString()); await act(h, "alice", r); await act(h, "bob", r);
  }
  h.setTime(new Date(q.endsAt + 1).toISOString()); r = await act(h, "alice", r);
  assert.equal(r.status, "finished"); assert.equal(r.result, "draw"); assert.equal(h.read("rankedState"), null);
});
test("friend Club modes: readying without a choice picks a playable one, so the match starts", async () => {
  for (const mode of ["club_club", "club_country"]) {
    const h = boot();
    let r = await enter(h, "alice", mode, "create");
    r = await enter(h, "bob", mode, "join", {code: r.id});
    assert.equal(r.status, "ready"); assert.ok(r.pairOptions.length > 0);
    // Bob picks; Alice only presses ready: she gets a choice that pairs with his.
    const pick = r.pairOptions[0];
    r = await act(h, "bob", r, "choose", {choice: pick});
    r = await act(h, "alice", r, "ready");
    const room = raw(h, r);
    assert.equal(room.choices.right, pick); assert.ok(room.choices.left);
    assert.ok(E.pairOptions(c, mode, "left", pick).includes(room.choices.left));
    r = await act(h, "bob", r, "ready");
    assert.equal(r.status, "countdown", mode);
    // Neither chooses: both still get a playable pair.
    const h2 = boot();
    let q = await enter(h2, "alice", mode, "create");
    q = await enter(h2, "bob", mode, "join", {code: q.id});
    q = await act(h2, "alice", q, "ready"); q = await act(h2, "bob", q, "ready");
    assert.equal(q.status, "countdown", mode);
    const both = raw(h2, q).choices;
    assert.ok(E.pairOptions(c, mode, "right", both.left).includes(both.right));
  }
});
test("Çinko and Random Five boards use only well-known clubs, countries and top leagues", () => {
  const grid = new Set(c.gridClubs);
  const top = ["Premier League", "LaLiga", "Serie A", "Bundesliga", "Ligue 1", "Süper Lig", "Eredivisie",
    "Liga Portugal"];
  for (const b of c.cinko) {
    for (const k of b.criteria) {
      const x = c.criteria[k];
      if (x.type === "club") assert.ok(grid.has(k), x.label);
      if (x.type === "country") assert.ok(c.countryOptions.slice(0, 45).includes(k), x.label);
      if (x.type === "league") assert.ok(top.includes(x.label), x.label);
    }
  }
  // No rare national team on a Çinko board.
  const countries = new Set(c.cinko.flatMap((b) => b.criteria).filter((k) => k.startsWith("country:")));
  for (const k of ["country:trinidadandtobago", "country:curacao", "country:moldova"]) assert.ok(!countries.has(k));
  for (const b of c.five) assert.ok(b.clubs.every((k) => grid.has(k)));
});
test("Grid boards and Random Grid pairs use only the best-known clubs", () => {
  const grid = new Set(c.gridClubs); assert.equal(grid.size, 50);
  // The pool leads with the most famous clubs; no obscure league side.
  for (const name of ["Real Madrid", "FC Barcelona", "Manchester United", "Bayern Munich", "Galatasaray"]) {
    assert.ok(c.gridClubs.some((k) => c.criteria[k].label === name), name);
  }
  for (const name of ["Dundee United FC", "Zorya Lugansk", "Aberdeen FC"]) {
    assert.ok(!c.clubOptions.some((k) => c.criteria[k].label === name), name);
  }
  const clubsOf = (ks) => ks.filter((k) => k.startsWith("club:"));
  for (const g of c.grids) assert.ok(clubsOf([...g.rows, ...g.cols]).every((k) => grid.has(k)), g.id);
  for (let i = 0; i < 40; i++) {
    const r = E.hydrate({mode: "grid_random", host: "a", guest: "b", seed: "fame" + i, dataRevision: c.version});
    E.start(r, c, 0); r.status = "playing";
    E.move(c, r, r.turnUid, {action: "draw"}, 6000);
    assert.ok(clubsOf(r.pending.criteria).every((k) => grid.has(k)), r.pending.criteria.join());
  }
});
test("Grid Random board: only the player to move draws a pair, and both see it", () => {
  const r = boardRoom("draw"); assert.equal(r.randomBoard, 1); assert.equal(r.endsAt - r.startsAt, 30 * 45000);
  const t = r.turnUid; const o = t === "a" ? "b" : "a";
  assert.throws(() => E.move(c, r, o, {action: "draw"}, 6000), {code: "permission-denied"});
  assert.deepEqual(E.move(c, r, t, {action: "draw"}, 6000), {accepted: true, drawn: true});
  const v = E.view(c, r, o, 6000);
  assert.equal(v.randomBoard, 1); assert.deepEqual(v.anchors, [2, 4, 6]);
  assert.equal(v.pending.criteria.length, 2); assert.ok(v.pending.criteria.every((k) => k.label));
  assert.deepEqual(v.rows, [null, null, null]); assert.deepEqual(v.cols, [null, null, null]);
  assert.throws(() => E.move(c, r, t, {action: "draw"}, 6100), {code: "failed-precondition"});
  // A drawn pair binds the move: it goes on an anchor, not on another cell.
  const [a, b] = r.pending.criteria;
  assert.throws(() => E.move(c, r, t, {targetId: 0, playerId: fits(a, b)}, 6200), {code: "failed-precondition"});
});
test("Grid Random board: a right answer takes the anchor and opens its row and column", () => {
  const r = boardRoom("anchor"); const t = r.turnUid; const o = t === "a" ? "b" : "a";
  E.move(c, r, t, {action: "draw"}, 6000); const [a, b] = r.pending.criteria; const id = fits(a, b);
  assert.deepEqual(E.move(c, r, t, {targetId: 4, playerId: id, swap: true}, 7000), {accepted: true, correct: true});
  const v = E.view(c, r, o, 7000);
  assert.equal(v.owners[4].uid, t); assert.equal(v.owners[4].player.id, E.player(c, id).id);
  assert.equal(v.rows[1].id, b); assert.equal(v.cols[1].id, a); assert.equal(v.pending, null);
  assert.equal(r.turnUid, o); assert.equal(r.scores[t], 1);
  // The next pair never repeats a criterion already on the board.
  E.move(c, r, o, {action: "draw"}, 8000);
  assert.ok(!r.pending.criteria.some((k) => [a, b].includes(k)));
});
test("Grid Random board: a wrong answer or a timeout drops the pair and passes the turn", () => {
  const r = boardRoom("wrong"); const t = r.turnUid; const o = t === "a" ? "b" : "a";
  E.move(c, r, t, {action: "draw"}, 6000); const [a, b] = r.pending.criteria;
  assert.deepEqual(E.move(c, r, t, {targetId: 2, playerId: misfit(a, b)}, 7000), {accepted: true, correct: false});
  assert.equal(r.pending, null); assert.equal(r.turnUid, o); assert.equal(r.owners[2], undefined);
  assert.equal(E.view(c, r, t, 7000).gridWrong[t], 1);
  // Anchors need a drawn pair; other cells need both their axes.
  assert.throws(() => E.move(c, r, o, {targetId: 2, playerId: fits(a, b)}, 7500), {code: "failed-precondition"});
  assert.throws(() => E.move(c, r, o, {targetId: 0, playerId: fits(a, b)}, 7500), {code: "failed-precondition"});
  E.move(c, r, o, {action: "draw"}, 8000);
  r.presence = {a: 60000, b: 60000}; E.advance(r, 7000 + 45000 + 1);
  assert.equal(r.pending, null); assert.equal(r.turnUid, t);
});
test("Grid Random board: three anchors on the diagonal win; open cells and dead crossings follow the axes", () => {
  const r = boardRoom("diagonal"); const t = r.turnUid; const o = t === "a" ? "b" : "a";
  let time = 6000;
  for (const anchor of [2, 4, 6]) {
    E.move(c, r, t, {action: "draw"}, time += 100); const [a, b] = r.pending.criteria;
    E.move(c, r, t, {targetId: anchor, playerId: fits(a, b, Object.keys(r.used))}, time += 100);
    if (anchor === 6) break;
    // The rival lets it happen with a wrong pair answer.
    E.move(c, r, o, {action: "draw"}, time += 100); const [x, y] = r.pending.criteria;
    E.move(c, r, o, {targetId: [2, 4, 6].find((i) => !r.owners[i]), playerId: misfit(x, y)}, time += 100);
    if (anchor === 4) {
      // Rows 0-1 and columns 1-2 are open: each open crossing either has an unused answer or is dead.
      const v = E.view(c, r, t, time);
      for (const i of [1, 5]) {
        const row = v.rows[Math.floor(i / 3)].id; const col = v.cols[i % 3].id;
        const any = fits(row, col, Object.keys(r.used));
        assert.equal(v.dead.includes(i), !any, `cell ${i}`);
      }
      assert.ok(!v.dead.includes(0) && !v.dead.includes(3), "cells without both axes are not dead");
    }
  }
  assert.equal(r.status, "finished"); assert.equal(r.winnerUid, t); assert.equal(r.reason, "Çizgi tamamlandı.");
});
test("Grid Random board: drawing goes through the online move with the turn's revision", async () => {
  const h = boot(); let r = await pair(h, "grid_random"); assert.equal(r.randomBoard, 1);
  const t = r.turnUid; const o = t === "alice" ? "bob" : "alice";
  await assert.rejects(act(h, o, r, "draw"), {code: "permission-denied"});
  r = await act(h, t, r, "draw"); assert.equal(r.pending.criteria.length, 2);
  const peer = await act(h, o, r); assert.deepEqual(peer.pending, r.pending);
  const [a, b] = raw(h, r).pending.criteria;
  r = await act(h, t, peer, "answer", {targetId: 6, playerId: fits(a, b), swap: false});
  assert.equal(r.owners[6].uid, t); assert.equal(r.rows[2].id, a); assert.equal(r.cols[0].id, b);
});
test("Random Five (single-board rooms) lists found players live: which clubs, points and second", () => {
  const r = legacyFive("five-live");
  const clubs = r.puzzle.clubs;
  const fit = (id) => clubs.filter((k) => E.matches(c, c.players[id], k));
  // The best-covered player of the board.
  const best = Object.keys(c.players).map((id) => [id, fit(id).length]).sort((x, y) => y[1] - x[1])[0][0];
  const receipt = E.move(c, r, "a", {playerId: best}, 7000);
  const v = E.view(c, r, "b", 7000);
  assert.equal(v.status, "playing"); assert.equal(v.found.length, 1);
  const f = v.found[0];
  assert.equal(f.uid, "a"); assert.equal(f.second, 2); assert.equal(f.points, receipt.points);
  assert.deepEqual(f.clubIds, fit(best)); assert.equal(f.clubs, fit(best).length);
  assert.equal(receipt.points, E.FIVE_POINTS[fit(best).length]);
});
test("Çinko keeps the last five moves, newest first, with players and passes", () => {
  const r = E.hydrate({mode: "cinko", host: "a", guest: "b", seed: "log", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing";
  const fit = (i) => Object.keys(c.players).find((id) => !r.used[id] &&
    E.matches(c, c.players[id], r.puzzle.criteria[i]));
  let time = 6000; const next = () => (time += 500);
  for (let n = 0; n < 6; n++) {
    const who = r.turnUid;
    if (n === 2) E.move(c, r, who, {action: "pass"}, next());
    else {
      const i = E.view(c, r, who, time).open[0];
      E.move(c, r, who, {playerId: fit(i), cells: [i]}, next());
    }
  }
  const v = E.view(c, r, "a", time);
  assert.equal(v.moves.length, 5);
  assert.ok(v.moves[0].player.name); assert.equal(v.moves[0].points, 1);
  assert.equal(v.moves[0].correct.length, 1);
  assert.deepEqual(v.moves.map((m) => m.pass === true), [false, false, false, true, false]);
  // A timed-out turn is logged as a pass too.
  r.presence = {a: time + 46000, b: time + 46000}; E.advance(r, time + 45001);
  assert.equal(E.view(c, r, "a", time + 45001).moves[0].timeout, true);
});
test("Loto bingo: filling the last cell of a row or column earns +2 for each line", () => {
  const room = (seed) => {
    const r = E.hydrate({mode: "loto", host: "a", guest: "b", seed, dataRevision: c.version});
    E.start(r, c, 0); r.status = "playing"; return r;
  };
  const r = room("bingo"); assert.equal(r.lotoRules, 2);
  const {criteria, players} = r.puzzle;
  const fitting = (i) => players.find((id) => !r.used[id] && E.matches(c, c.players[id], criteria[i]));
  // Row 0 has cells 0-2 taken by the rival; the 4th completes it.
  for (const k of [0, 1, 2]) r.owners[k] = {uid: "b", playerId: "x" + k};
  const id = fitting(3); assert.ok(id);
  const receipt = E.move(c, r, "a", {playerId: id, targetId: 3}, 6000);
  assert.deepEqual(receipt, {accepted: true, correct: true, points: 1 + E.LOTO_LINE_BONUS, lines: ["r0"]});
  assert.equal(r.scores.a, 3); assert.deepEqual(r.lotoLines, {r0: "a"});
  const v = E.view(c, r, "b", 6000); assert.deepEqual(v.lotoLines, {r0: "a"}); assert.equal(v.lineBonus, 2);
  // Row and column at once: +4.
  const q = room("bingo-both"); const fit = (i) => q.puzzle.players.find((x) =>
    E.matches(c, c.players[x], q.puzzle.criteria[i]));
  for (const k of [12, 13, 14, 3, 7, 11]) q.owners[k] = {uid: "b", playerId: "y" + k};
  const p = fit(15);
  if (p) {
    const both = E.move(c, q, "a", {playerId: p, targetId: 15}, 6000);
    assert.deepEqual(both.lines, ["r3", "c3"]); assert.equal(q.scores.a, 5);
  }
  // A wrong move or a cell that completes nothing earns no bonus.
  const w = room("bingo-none"); const lone = w.puzzle.players.find((x) =>
    E.matches(c, c.players[x], w.puzzle.criteria[5]));
  assert.deepEqual(E.move(c, w, "a", {playerId: lone, targetId: 5}, 6000), {accepted: true, correct: true, points: 1});
  // Rooms started before the rule: no bonus.
  const old = room("bingo-old"); delete old.lotoRules;
  for (const k of [0, 1, 2]) old.owners[k] = {uid: "b", playerId: "x" + k};
  const o = old.puzzle.players.find((x) => E.matches(c, c.players[x], old.puzzle.criteria[3]));
  assert.equal(E.move(c, old, "a", {playerId: o, targetId: 3}, 6000).points, 1);
});
test("Loto ends as soon as no remaining player fits an empty cell", () => {
  const r = E.hydrate({mode: "loto", host: "a", guest: "b", seed: "stuck", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing";
  const {criteria, players} = r.puzzle;
  const fit = (id, i) => E.matches(c, c.players[id], criteria[i]);
  // Two open cells i, j; p fits j, and q (the last player left) fits neither.
  let found = null;
  for (const p of players) {
    for (const q of players) {
      if (p === q) continue;
      for (let j = 0; j < 16 && !found; j++) {
        for (let i = 0; i < 16 && !found; i++) {
          if (i !== j && fit(p, j) && !fit(q, i) && !fit(q, j)) found = {p, q, i, j};
        }
      }
    }
  }
  assert.ok(found, "a stuck ending exists on this board");
  const {p, q, i, j} = found;
  criteria.forEach((_, k) => {
    if (k !== i && k !== j) r.owners[k] = {uid: "a", playerId: "x" + k};
  });
  for (const id of players) if (id !== p && id !== q) r.used[id] = {uid: "a", playerId: id};
  const live = E.hydrate(structuredClone(r));
  E.move(c, live, "b", {playerId: p, targetId: j}, 6000);
  assert.equal(live.status, "finished"); assert.equal(live.reason, "Kalan futbolcular boş hücrelere uymuyor.");
  // q fitting the other open cell keeps the match going.
  const ok = players.flatMap((x) => players.map((y) => [x, y])).flatMap(([x, y]) =>
    criteria.map((_, a) => [x, y, a])).flatMap(([x, y, a]) => criteria.map((_, b) => [x, y, a, b]))
      .find(([x, y, a, b]) => x !== y && a !== b && fit(x, b) && fit(y, a));
  const [x, y, a, b] = ok; const go = E.hydrate({...structuredClone(r), owners: {}, used: {}});
  criteria.forEach((_, k) => {
    if (k !== a && k !== b) go.owners[k] = {uid: "a", playerId: "x" + k};
  });
  for (const id of players) if (id !== x && id !== y) go.used[id] = {uid: "a", playerId: id};
  E.move(c, go, "b", {playerId: x, targetId: b}, 6000); assert.equal(go.status, "playing");
});
test("GR07: a rare answer earns +1 in Grid Random; equal reverse scores go to fewer wrong answers", () => {
  const r = legacyRoom("rare"); assert.equal(r.gridRules, 2);
  const all = [...r.puzzle.rounds[0].answers].sort((x, y) => c.players[x].rank - c.players[y].rank ||
    x.localeCompare(y));
  E.move(c, r, "a", {playerId: all[0], round: 0}, 6000);
  E.move(c, r, "b", {playerId: all.at(-1), round: 0}, 6000);
  assert.equal(r.scores.a, 1); assert.equal(r.scores.b, 1 + E.GRID_RARE_BONUS);
  assert.equal(E.view(c, r, "a", 6000).rareBonus, 1);
  const g = E.hydrate({mode: "grid_reverse", host: "a", guest: "b", seed: "tie", dataRevision: c.version});
  E.start(g, c, 0); g.status = "playing";
  const wrongBy = g.turnUid;
  const wrong = Object.keys(c.criteria).find((k) => !g.puzzle.witness.slice(0, 3).every((id) =>
    E.matches(c, c.players[id], k)));
  E.move(c, g, wrongBy, {targetId: "r0", criterionId: wrong}, 6000);
  assert.equal(E.view(c, g, wrongBy, 6000).gridWrong[wrongBy], 1);
  g.scores = {a: 3, b: 3}; E.finish(g, "finished", "test", 7000);
  assert.equal(g.winnerUid, wrongBy === "a" ? "b" : "a");
  const done = E.view(c, g, "a", 7000);
  assert.equal(Object.keys(done.accepted).length, 6);
  assert.ok(Object.values(done.accepted).every((labels) => labels.length));
});
test("GT01-05: reverse axes require all three canonical relationships; 4 axes ends game", () => {
  const r = E.hydrate({mode: "grid_reverse", host: "a", guest: "b", seed: "reverse", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; const u = r.turnUid;
  const result = E.move(c, r, u, {targetId: "r0", criterionId: r.puzzle.rows[0]}, 5001);
  assert(result.correct); assert.equal(r.owners.r0.uid, u);
  assert.throws(() => E.move(c, r, r.turnUid, {targetId: "r7", criterionId: r.puzzle.rows[0]}, 5002));
});
test("RF01-05/CI02-04: server computes club points and all eligible cells; indexes are rejected", async () => {
  // This assertion needs a multi-club witness; an arbitrary random draw need not have one.
  const h = boot(); let r = await pair(h, "random_five", false, ["alice", "bob"], "multi-club-score");
  const q = raw(h, r).puzzle.boards[0];
  const p = Object.values(c.players).find((p) => q.filter((k) => E.matches(c, p, k)).length >= 2);
  r = await act(h, "alice", r, "answer", {playerId: p.id, round: 0});
  r = await act(h, "bob", r, "answer", {playerId: fiveNone(q), round: 0});
  assert.equal(r.scores.alice, E.FIVE_POINTS[q.filter((k) => E.matches(c, p, k)).length]);
  const cinko = await pair(boot(), "cinko"); assert.equal(cinko.criteria.length, 25);
  const h2 = boot(); const cr = await pair(h2, "cinko");
  await assert.rejects(act(h2, cr.turnUid, cr, "answer", {playerId: p.id, indexes: [0, 1, 2]}), {code:
      "invalid-argument"});
});
test("Loto ends when both players used up their wrong moves", () => {
  const r = E.hydrate({mode: "loto", host: "a", guest: "b", seed: "loto-wrong", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; const q = r.puzzle;
  // A board player on a cell it does not fit.
  const [id, cell] = q.players.flatMap((p) => q.criteria.map((k, i) => [p, i]))
      .find(([p, i]) => !E.matches(c, c.players[p], q.criteria[i]));
  let t = r.startsAt;
  for (const u of ["a", "b"]) {
    for (let n = 0; n < E.PENALTY.loto.maxWrong; n++) {
      t += E.PENALTY.loto.lockMs + 1; E.move(c, r, u, {playerId: id, targetId: cell}, t);
    }
    if (u === "a") assert.equal(r.status, "playing");
  }
  assert.equal(r.status, "finished"); assert.equal(r.reason, "İki oyuncunun da yanlış hakkı bitti.");
  assert.ok(r.finishedAt < r.endsAt);
});
test("Loto boards: best-known clubs, football countries, top leagues and well-known names", () => {
  const grid = new Set(c.gridClubs);
  const names = new Map(); for (const p of Object.values(c.players)) names.set(p.name, (names.get(p.name) || 0) + 1);
  for (const b of c.loto) {
    for (const k of b.criteria) {
      const x = c.criteria[k];
      if (x.type === "club") assert.ok(grid.has(k), x.label);
      if (x.type === "league") assert.notEqual(x.label, "1. Lig");
    }
    for (const id of b.players) {
      assert.ok(c.players[id].rating >= 75, c.players[id].name); assert.equal(names.get(c.players[id].name), 1);
    }
  }
});
test("LO02-06: only pinned stone and correct cell accepted; 180s is server owned", async () => {
  const h = boot(); let r = await pair(h, "loto"); const q = raw(h, r).puzzle;
  assert.equal(r.endsAt - r.startsAt, 180000);
  const sol = lotoSolution(q); const cell = Object.keys(sol).find((k) => sol[k] === q.players[0]);
  r = await act(h, "alice", r, "answer", {targetId: Number(cell), playerId: q.players[0]});
  assert.equal(r.owners[cell].playerId, q.players[0]);
  h.setTime(h.now + 500);
  const other = Number(Object.keys(sol).find((k) => k !== cell));
  await assert.rejects(act(h, "bob", r, "answer", {targetId: other, playerId: q.players[0]}), {code: "already-exists"});
});
test("CM01-06: budget, unique positions, secret XI, deterministic two-team referee", async () => {
  const h = boot(); let r = await pair(h, "club_manager"); legacyManager(h, r); const q = raw(h, r);
  const ids = Object.entries(E.FORMATIONS["433"]).flatMap(([pos, count]) => q.puzzle.pool.map((id) => c.players[id])
      .filter((p) => p.position === pos).sort((a, b) => a.cost - b.cost).slice(0, count).map((p) => p.id));
  const input = {playerIds: ids, formation: "433", tactics: {press: .5, tempo: .5, width: .5}};
  await assert.rejects(act(h, "alice", r, "squad", {...input, playerIds: Array(11).fill(ids[0])}), {
    code: "invalid-argument"});
  r = await act(h, "alice", r, "squad", input); const peer = await act(h, "bob", r);
  assert.equal(peer.squads, undefined); assert.equal(peer.mySquad, null);
  r = await act(h, "bob", r, "squad", input); assert.equal(r.status, "finished");
  const done = raw(h, r); assert.deepEqual(E.simulate(c, done), done.simulation);
});
test("CM08: binding budget, cyclic tactics, penalties on a draw, forfeit for a missing XI", async () => {
  for (let i = 0; i < 20; i++) {
    const q = E.puzzle(c, "club_manager", "cm08-" + i); const ps = q.pool.map((id) => c.players[id]);
    let best = 0; let cheap = 0;
    for (const [pos, n] of Object.entries(E.FORMATIONS["433"])) {
      const g = ps.filter((p) => p.position === pos);
      best += [...g].sort((a, b) => b.rating - a.rating).slice(0, n).reduce((x, p) => x + p.cost, 0);
      cheap += [...g].sort((a, b) => a.cost - b.cost).slice(0, n).reduce((x, p) => x + p.cost, 0);
    }
    assert.ok(best > q.budget, String(best)); assert.ok(cheap <= q.budget, String(cheap));
    assert.ok(ps.filter((p) => p.cost >= 14).length >= 7);
  }
  const P = {press: 1, tempo: 0, width: 0}; const T = {press: 0, tempo: 1, width: 0};
  const W = {press: 0, tempo: 0, width: 1}; const all = {press: 1, tempo: 1, width: 1};
  assert.ok(E.counter(P, T) > E.counter(T, P)); assert.ok(E.counter(T, W) > E.counter(W, T));
  assert.ok(E.counter(W, P) > E.counter(P, W));
  for (const t of [P, T, W, {press: .5, tempo: .5, width: .5}]) assert.equal(E.counter(all, t), E.counter(t, all));
  // A draw in normal time is decided on penalties.
  const q = E.puzzle(c, "club_manager", "cm08");
  const ids = Object.entries(E.FORMATIONS["433"]).flatMap(([pos, n]) => q.pool.map((id) => c.players[id])
      .filter((p) => p.position === pos).sort((a, b) => a.cost - b.cost).slice(0, n).map((p) => p.id));
  const squad = {playerIds: ids, formation: "433", tactics: {press: .5, tempo: .5, width: .5}};
  let pens = 0;
  for (let i = 0; i < 40; i++) {
    const r = E.hydrate({mode: "club_manager", host: "a", guest: "b", seed: "pen" + i, managerRules: 2});
    r.squads = {a: squad, b: squad}; const sim = E.simulate(c, r);
    if (sim.goals.a === sim.goals.b) {
      pens++; assert.notEqual(sim.penalties.a, sim.penalties.b);
    } else assert.equal(sim.penalties, undefined);
  }
  assert.ok(pens > 0);
  // Only one side locked its XI: it wins by forfeit at the deadline.
  const h = boot(); let r = await pair(h, "club_manager"); legacyManager(h, r); const pool = raw(h, r).puzzle.pool;
  const mine = Object.entries(E.FORMATIONS["433"]).flatMap(([pos, n]) => pool.map((id) => c.players[id])
      .filter((p) => p.position === pos).sort((a, b) => a.cost - b.cost).slice(0, n).map((p) => p.id));
  r = await act(h, "alice", r, "squad", {...squad, playerIds: mine});
  // The rival sees that the XI is locked, never which XI.
  const peer = await act(h, "bob", r);
  assert.equal(peer.rivalLocked, true); assert.equal(peer.submitted, false); assert.equal(peer.squads, undefined);
  assert.equal(r.rivalLocked, false);
  const end = raw(h, r).endsAt;
  for (let t = raw(h, r).startsAt + 20000; t < end; t += 20000) {
    h.setTime(new Date(t).toISOString()); await act(h, "alice", r); await act(h, "bob", r);
  }
  h.setTime(new Date(end + 1).toISOString()); r = await act(h, "alice", r);
  assert.equal(r.status, "forfeit"); assert.equal(r.result, "win");
});
test("NET01-05/CORE07: reconnect clock, 30s absence, simultaneous offline and queue timeout", async () => {
  const h = boot(); let r = await pair(h, "random_five"); const start = r.startsAt;
  h.setTime(new Date(start + 20000).toISOString()); r = await act(h, "alice", r); assert.equal(r.startsAt, start);
  h.setTime(new Date(start + 31000).toISOString()); r = await act(h, "alice", r);
  assert.equal(r.status, "forfeit"); assert.equal(r.winnerUid, "alice");
  const h2 = boot(); r = await pair(h2, "club_club");
  h2.setTime(new Date(r.startsAt + 31000).toISOString()); r = await act(h2, "alice", r); assert.equal(
      r.status, "cancelled");
  const h3 = boot(); r = await enter(h3, "alice", "cinko", "search", {playKind: "ranked"});
  h3.setTime(new Date(r.serverNow + 31000).toISOString()); r = await act(h3, "alice", r); assert.equal(
      r.status, "expired");
  assert.equal(h3.read("pvpV1/cinko/queue/alice"), null);
});
test("EC01/02/05/06/08: friend/guest/forfeit cannot farm rewards; retired attestation blocked", async () => {
  const h = boot(); let r = await pair(h, "random_five"); r = await act(h, "alice", r, "leave");
  assert.equal(r.status, "forfeit"); assert.equal(h.read("rankedState"), null);
  await assert.rejects(h.call("submitRankedResult", {mode: "five", matchId: "old"}, auth("alice")), {
    code: "failed-precondition"});
  h.setLinked("guest", false);
  await assert.rejects(enter(h, "guest", "cinko", "create"), {code: "permission-denied"});
});

async function finishRanked(h, r, opponent, {losePayment = false} = {}) {
  const q = raw(h, r).puzzle;
  const answers = Object.values(c.players).filter((p) => q.rounds[0].criteria.every((k) => E.matches(c, p, k)));
  r = await act(h, "alice", r, "answer", {playerId: answers[0].id});
  const wrong = Object.values(c.players).find((p) => !q.rounds[0].criteria.every((k) => E.matches(c, p, k)));
  r = await act(h, opponent, r, "answer", {playerId: wrong.id});
  for (let t = r.startsAt + 20000; t < r.endsAt; t += 20000) {
    h.setTime(t); await act(h, "alice", r); r = await act(h, opponent, r);
  }
  h.setTime(r.endsAt + 1);
  if (losePayment) h.failNext("economyState/alice");
  return act(h, "alice", r);
}
test("EC03-05/09: three paid results across modes, central K32 Elo and idempotent wallet", async () => {
  const h = boot();
  for (let i = 0; i < 4; i++) {
    let r = await pair(h, i % 2 ? "club_country" : "club_club", true, ["alice", "bob" + i]);
    r = await finishRanked(h, r, "bob" + i);
    assert.equal(r.reward.coins, i < 3 ? 3 : 0); assert.equal(r.reward.xp, i < 3 ? 6 : 0);
    if (!i) assert.equal(r.reward.eloDelta, 16);
    const coins = h.read("economyState/alice/balances/coins");
    await Promise.all([act(h, "alice", r), act(h, "bob" + i, r)]);
    assert.equal(h.read("economyState/alice/balances/coins"), coins);
  }
  assert.equal(h.read("economyState/alice/balances/coins"), 9);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 18);
});
test("EC05/07: earlier ranked generation consumes shared caps and interrupted payment is repaired", async () => {
  const h = boot(); const day = require("../rewarded_ads").dayKey(h.now);
  for (let i = 0; i < 2; i++) {
    h.seed(`rankedState/settlements/career_race/old${i}`, {
      serverValidated: true, settledAt: h.now, player1Uid: "alice", player2Uid: "old" + i,
      rewardEligible: {alice: true}, player1Result: "win", participants: {alice: true},
    });
  }
  let r = await pair(h, "club_club", true);
  await assert.rejects(finishRanked(h, r, "bob", {losePayment: true}), /Simulated interrupted write/);
  assert.equal(h.read(`rankedState/pvpDaily/alice/${day}/xp`), 2);
  await h.call("reconcilePvp");
  r = await act(h, "alice", r);
  assert.equal(r.reward.coins, 3); assert.equal(r.reward.xp, 2);
  await h.call("reconcilePvp");
  assert.equal(h.read("economyState/alice/balances/coins"), 3);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 2);
});
test("friend rematch requires both consents and swaps roles", async () => {
  const h = boot(); let r = await pair(h, "club_country");
  r = await act(h, "alice", r, "leave");
  r = await act(h, "alice", r, "rematch"); assert.equal(r.nextRoom, null);
  r = await act(h, "bob", r, "rematch"); assert.ok(r.nextRoom);
  const next = await enter(h, "alice", "club_country", "resume");
  assert.equal(next.host, "bob"); assert.equal(next.guest, "alice");
  assert.equal(next.series.game, 1); assert.equal(next.series.limit, 1);
  assert.deepEqual(next.ready, {}); assert.equal(h.read("rankedState"), null);
});
// A three-game series room: the first game is played with series3.
async function seriesPair(h, mode) {
  let r = await enter(h, "alice", mode, "create", {profile: "series3"});
  r = await enter(h, "bob", mode, "join", {code: r.id});
  r = await act(h, "alice", r, "ready"); r = await act(h, "bob", r, "ready");
  h.setTime(new Date(r.startsAt + 100).toISOString());
  await act(h, "alice", r); return act(h, "bob", r);
}
async function readyBoth(h, r) {
  r = await act(h, r.host, r, "ready"); r = await act(h, r.guest, r, "ready");
  h.setTime(new Date(r.startsAt + 100).toISOString());
  return act(h, "alice", r);
}
test("SERIES: the next game opens by itself, roles swap, first to two wins ends the series", async () => {
  const h = boot(); let r = await seriesPair(h, "grid_classic");
  assert.equal(r.series.limit, 3); assert.equal(r.series.game, 1);
  r = await act(h, "alice", r, "leave"); // Game 1 to bob.
  assert.equal(r.series.over, false); assert.deepEqual(r.series.results, ["bob"]); assert.ok(r.nextRoom);
  const seen = await act(h, "bob", r); assert.equal(seen.nextRoom, r.nextRoom);
  let g2 = await enter(h, "alice", "grid_classic", "resume");
  assert.equal(g2.id, r.nextRoom); assert.equal(g2.status, "ready");
  assert.equal(g2.host, "bob"); assert.equal(g2.series.game, 2); assert.equal(g2.series.wins.bob, 1);
  g2 = await readyBoth(h, g2); assert.equal(g2.status, "playing");
  g2 = await act(h, "alice", g2, "leave"); // Game 2 to bob: 2-0.
  assert.equal(g2.series.over, true); assert.equal(g2.series.winner, "bob");
  assert.deepEqual(g2.series.results, ["bob", "bob"]); assert.equal(g2.nextRoom, null);
  g2 = await act(h, "alice", g2, "rematch"); g2 = await act(h, "bob", g2, "rematch");
  const fresh = await enter(h, "alice", "grid_classic", "resume");
  assert.equal(fresh.series.game, 1); assert.equal(fresh.series.limit, 3);
  assert.deepEqual(fresh.series.wins ?? {}, {});
  assert.equal(fresh.series.over, undefined);
});
test("SERIES: 1-1 goes to a third game; leaving between games gives that game to the rival", async () => {
  const h = boot(); const r = await seriesPair(h, "grid_classic");
  await act(h, "alice", r, "leave"); // bob 1-0
  let g2 = await enter(h, "alice", "grid_classic", "resume"); g2 = await readyBoth(h, g2);
  g2 = await act(h, "bob", g2, "leave"); // alice 1-1
  assert.equal(g2.series.over, false); assert.ok(g2.nextRoom);
  const g3 = await enter(h, "bob", "grid_classic", "resume");
  assert.equal(g3.series.game, 3); assert.equal(g3.host, "alice"); assert.equal(g3.status, "ready");
  const end = await act(h, "bob", g3, "leave");
  assert.equal(end.status, "forfeit"); assert.equal(end.winnerUid, "alice");
  assert.equal(end.series.over, true); assert.equal(end.series.winner, "alice");
  assert.deepEqual(end.series.results, ["bob", "alice", "alice"]); assert.equal(end.nextRoom, null);
});
test("SERIES: a single game never opens a next room on its own", async () => {
  const h = boot(); let r = await pair(h, "grid_classic");
  r = await act(h, "alice", r, "leave"); assert.equal(r.nextRoom, null);
  assert.equal(r.series.results, undefined);
});
test("CORE06: autocomplete order is independent of room criteria and is drawn from the full snapshot", async () => {
  const h = boot(); const r = await pair(h, "club_country");
  const a = await h.call("searchPvp", {...base(r.mode), query: "ronaldo"}, auth("alice"));
  const b = await h.call("searchPvp", {...base(r.mode), query: "ronaldo", roomId: r.id}, auth("alice"));
  assert.deepEqual(a, b); assert.ok(a.players.length > 0);
});
test("Club-Club shows the found players live and ends once every shared player is found", async () => {
  const h = boot(); let r = await pair(h, "club_club"); const answers = raw(h, r).puzzle.rounds[0].answers;
  assert.equal(r.answerCount, answers.length); assert.deepEqual(r.found, []);
  let time = r.startsAt + 1000;
  for (const [i, playerId] of answers.entries()) {
    time += 500; h.setTime(new Date(time).toISOString());
    r = await act(h, i % 2 ? "bob" : "alice", r, "answer", {playerId});
    if (i === 0) {
      assert.equal(r.status, "playing"); assert.equal(r.found.length, 1);
      assert.equal(r.found[0].uid, "alice"); assert.ok(r.found[0].name);
      assert.equal(r.found[0].second, 1);
    }
  }
  assert.equal(r.status, "finished"); assert.equal(r.reason, "Tüm ortak futbolcular bulundu.");
  assert.equal(r.found.length, answers.length);
  // In the order found, each with its second of the match.
  assert.deepEqual(r.found.map((p) => p.id), answers.map((x) => E.player(c, x).id));
  assert.deepEqual(r.found.map((p) => p.second), answers.map((_, i) => Math.floor((1500 + i * 500) / 1000)));
});
test("Grid views name the players and criteria on the board", () => {
  const room = (mode) => {
    const r = E.hydrate({mode, host: "a", guest: "b", seed: "names-" + mode, dataRevision: c.version});
    E.start(r, c, 0); r.status = "playing"; return r;
  };
  // Classic: a taken cell carries its player.
  const g = room("grid_classic"); const t = g.turnUid;
  const id = g.puzzle.witness[0];
  E.move(c, g, t, {playerId: id, targetId: 0}, 6000);
  assert.equal(E.view(c, g, "a", 6000).owners[0].player.name, c.players[id].name);
  // Random: a closed round shows both answers by name.
  const q = legacyRoom("names-grid_random"); const pick = q.puzzle.rounds[0].answers[0];
  E.move(c, q, "a", {playerId: pick, round: 0}, 6000); E.move(c, q, "b", {playerId: pick, round: 0}, 6500);
  const round = E.view(c, q, "a", 7000).rounds[0];
  assert.equal(round.a.player.name, c.players[pick].name); assert.equal(round.b.player.name, c.players[pick].name);
  // Reverse: a solved axis carries its criterion (label and type for the badge).
  const v = room("grid_reverse"); const ids = v.puzzle.witness.slice(0, 3);
  const k = Object.keys(c.criteria).find((x) => /^(club|country):/.test(x) &&
    ids.every((p) => E.matches(c, c.players[p], x)));
  E.move(c, v, v.turnUid, {targetId: "r0", criterionId: k}, 6000);
  assert.deepEqual(E.view(c, v, "a", 6000).owners.r0.criterion, c.criteria[k]);
});
test("search matches each typed word, so a full first name finds a short one", async () => {
  const h = boot(); const r = await pair(h, "club_club");
  const names = async (query) => (await h.call("searchPvp", {...base(r.mode), query, roomId: r.id},
      auth("alice"))).players.map((p) => p.name);
  assert.ok((await names("Daniel alves")).includes("Dani Alves"));
  assert.equal((await names("Jose sosa"))[0], "José Sosa");
  assert.equal((await names("dani alves"))[0], "Dani Alves");
  assert.deepEqual(await names("zz qq"), []);
});
test("CM: deterministic result is independent of squad submission order and list order", () => {
  const r = E.hydrate({mode: "club_manager", host: "a", guest: "b", seed: "manager", dataRevision: c.version});
  E.start(r, c, 0);
  const ids = Object.entries(E.FORMATIONS["433"]).flatMap(([pos, n]) => r.puzzle.pool.map((id) => c.players[id])
      .filter((p) => p.position === pos).sort((a, b) => a.cost - b.cost).slice(0, n).map((p) => p.id));
  const input = {playerIds: ids, formation: "433", tactics: {press: .8, tempo: .2, width: .5}};
  const a = E.validateXi(c, r, input); const b = E.validateXi(c, r, {...input, playerIds: [...ids].reverse()});
  assert.deepEqual(a, b);
  r.squads = {a, b}; const first = E.simulate(c, r); r.squads = {b, a};
  assert.deepEqual(E.simulate(c, r), first);
});

test("NET03: unavailable pinned catalog neutrally cancels without revealing answers or awarding", async () => {
  const h = boot(); let r = await pair(h, "club_club", true);
  h.seed(`pvpV1/club_club/rooms/${r.id}/dataRevision`, "missing-archive");
  r = await act(h, "alice", r);
  assert.equal(r.status, "cancelled"); assert.equal(r.winnerUid, null);
  assert.equal(r.reward.coins, 0); assert.equal(r.reward.eloDelta, 0);
  assert.equal(r.answers, undefined); assert.equal(h.read("rankedState"), null);
});
test("CM07: Manager ranked follows the same rollout flag as every other mode", async () => {
  const h = boot();
  const s = await h.call("getPvp", base("club_manager"), auth("alice"));
  assert.equal(s.availability.friendEnabled, true); assert.equal(s.availability.rankedEnabled, true);
  const r = await pair(h, "club_manager", true);
  assert.equal(r.playKind, "ranked"); assert.equal(r.managerRules, 3);
});

test("new blocks and revoked links are respected even after a room/queue was created", async () => {
  const h = boot(); const r = await enter(h, "alice", "club_country", "create");
  h.seed("blocks/alice/bob", true);
  await assert.rejects(enter(h, "bob", "club_country", "join", {code: r.id}), {code: "permission-denied"});
  const h2 = boot(); const q = await enter(h2, "alice", "cinko", "search", {playKind: "ranked"});
  h2.seed("blocks/alice/bob", true);
  const separate = await enter(h2, "bob", "cinko", "search", {playKind: "ranked"});
  assert.notEqual(separate.id, q.id); assert.equal(separate.guest, null);
  h2.setLinked("alice", false); h2.setLinked("bob", false);
  const third = await enter(h2, "carol", "cinko", "search", {playKind: "ranked"});
  assert.equal(third.guest, null);
});
test("simultaneous arrivals still share one atomic ranked room", async () => {
  const h = boot();
  await Promise.all([enter(h, "alice", "grid_random", "search", {playKind: "ranked"}),
    enter(h, "bob", "grid_random", "search", {playKind: "ranked"})]);
  const a = h.read("pvpV1/grid_random/active/alice");
  assert.equal(h.read("pvpV1/grid_random/active/bob"), a);
  assert.equal(h.read(`pvpV1/grid_random/rooms/${a}/status`), "ready");
});

for (const mode of E.MODES) {
  for (const ranked of [false, true]) {
    test(`${mode}/${ranked ? "ranked" : "friend"}: enter, ready, resume and leave preserve the mode`, async () => {
      const h = boot();
      const r = await pair(h, mode, ranked);
      assert.equal(r.mode, mode); assert.equal(r.playKind, ranked ? "ranked" : "friend");
      assert.equal(r.status, "playing");
      const resumed = await enter(h, "alice", mode, "resume", {playKind: r.playKind});
      assert.equal(resumed.id, r.id); assert.equal(resumed.startsAt, r.startsAt);
      const end = await act(h, "alice", resumed, "leave");
      assert.equal(end.status, "forfeit");
      assert.equal(h.read("economyState/alice/balances/coins"), null);
    });
  }
}
test("LO07: a wrong Loto move locks 3 s; eight wrong moves end that player's moves; 400 ms gap", async () => {
  const h = boot(); let r = await pair(h, "loto"); const q = raw(h, r).puzzle;
  h.setTime(Math.max(h.now, r.startsAt) + 10);
  const wrongCell = (p) => q.criteria.findIndex((k, i) => !E.matches(c, c.players[p], k) && !raw(h, r).owners?.[i]);
  const p0 = q.players[0];
  r = await act(h, "alice", r, "answer", {targetId: wrongCell(p0), playerId: p0});
  assert.equal(r.wrongMoves.alice, 1); assert.ok(r.lockUntil > h.now);
  await assert.rejects(act(h, "alice", r, "answer", {targetId: wrongCell(p0), playerId: p0}),
      {code: "resource-exhausted"});
  for (let i = 1; i < E.PENALTY.loto.maxWrong; i++) {
    h.setTime(h.now + E.PENALTY.loto.lockMs + 1);
    r = await act(h, "alice", r, "answer", {targetId: wrongCell(p0), playerId: p0});
  }
  assert.equal(r.wrongMoves.alice, 8);
  h.setTime(h.now + E.PENALTY.loto.lockMs + 1);
  const sol = lotoSolution(q); const cell = Number(Object.keys(sol).find((k) => sol[k] === p0));
  await assert.rejects(act(h, "alice", r, "answer", {targetId: cell, playerId: p0}), {code: "resource-exhausted"});
  r = await act(h, "bob", r, "answer", {targetId: cell, playerId: p0});
  await assert.rejects(act(h, "bob", r, "answer", {targetId: 0, playerId: q.players[1]}), {code: "resource-exhausted"});
});
test("LO08: equal Loto scores go to fewer wrong moves, then the earlier last correct move", () => {
  const r = {mode: "loto", host: "a", guest: "b", moveStats: {a: {wrong: 1, lastCorrectAt: 5}, b: {wrong: 0}}};
  assert.equal(E.raceTieBreak(r), "b");
  r.moveStats.b.wrong = 1; r.moveStats.b.lastCorrectAt = 9; assert.equal(E.raceTieBreak(r), "a");
  r.moveStats.b.lastCorrectAt = 5; assert.equal(E.raceTieBreak(r), null);
});
test("PA01: friend pair modes only offer and accept choices that make a playable pair", async () => {
  for (const mode of ["club_club", "club_country"]) {
    const h = boot(); let r = await enter(h, "alice", mode, "create");
    r = await enter(h, "bob", mode, "join", {code: r.id});
    const p = c.pairs.find((p) => p.answers.length >= E.PAIR_MIN_ANSWERS && p.criteria[1].startsWith(
        mode === "club_club" ? "club:" : "country:"));
    r = await act(h, "alice", r, "choose", {choice: p.criteria[0]});
    const view = await act(h, "bob", r);
    assert.ok(view.pairOptions.includes(p.criteria[1]));
    const options = mode === "club_country" ? c.countryOptions : c.clubOptions;
    assert.ok(view.pairOptions.length < options.length);
    const bad = options.find((id) => !view.pairOptions.includes(id));
    await assert.rejects(act(h, "bob", view, "choose", {choice: bad}), {code: "failed-precondition"});
    r = await act(h, "bob", view, "choose", {choice: p.criteria[1]});
    r = await act(h, "alice", r, "ready"); r = await act(h, "bob", r, "ready");
    assert.equal(r.status, "countdown");
  }
});
test("PA02: a wrong pair guess locks 2 s, ten end the guessing, missed players shown", async () => {
  const h = boot(); let r = await pair(h, "club_country"); const q = raw(h, r).puzzle.rounds[0];
  const wrong = Object.keys(c.players).filter((id) => !q.answers.includes(id));
  r = await act(h, "alice", r, "answer", {playerId: wrong[0]});
  assert.equal(r.wrongMoves.alice, 1); assert.equal(r.maxWrong, 10);
  await assert.rejects(act(h, "alice", r, "answer", {playerId: q.answers[0]}), {code: "resource-exhausted"});
  for (let i = 1; i < 10; i++) {
    h.setTime(h.now + E.PENALTY.club_country.lockMs + 1);
    r = await act(h, "alice", r, "answer", {playerId: wrong[i]});
  }
  h.setTime(h.now + E.PENALTY.club_country.lockMs + 1);
  await assert.rejects(act(h, "alice", r, "answer", {playerId: q.answers[0]}), {code: "resource-exhausted"});
  r = await act(h, "bob", r, "answer", {playerId: q.answers[0]}); assert.equal(r.scores.bob, 1);
  await assert.rejects(act(h, "bob", r, "answer", {playerId: q.answers[1]}), {code: "resource-exhausted"});
  for (let t = h.now + 20000; t < r.endsAt; t += 20000) {
    h.setTime(t); await act(h, "alice", r); await act(h, "bob", r);
  }
  h.setTime(r.endsAt + 10); r = await act(h, "bob", r);
  assert.equal(r.status, "finished"); assert.equal(r.winnerUid, "bob");
  assert.equal(r.missed.length, Math.min(12, q.answers.length - 1));
  assert.ok(!r.missed.some((p) => p.id === q.answers[0]));
  assert.deepEqual(r.found.map((p) => [p.id, p.uid]), [[q.answers[0], "bob"]]);
});
test("PA03: random pairs have 6+ answers, 3+ well-known answers and no country dominates", () => {
  const countries = {};
  for (let i = 0; i < 400; i++) {
    for (const mode of ["club_club", "club_country"]) {
      const p = E.puzzle(c, mode, "seed" + i).rounds[0];
      assert.ok(p.answers.length >= 6);
      assert.ok(p.answers.filter((id) => c.players[id].rank <= E.POPULAR_RANK).length >= 3);
      if (mode === "club_country") countries[p.criteria[1]] = (countries[p.criteria[1]] || 0) + 1;
    }
  }
  assert.ok(Object.keys(countries).length >= 30, String(Object.keys(countries).length));
  assert.ok(Math.max(...Object.values(countries)) <= 400 * .1, JSON.stringify(countries));
});
test("CI07: Çinko uses the Botla Oyna rules: connected cells, +1/-1, one use per player, pass", async () => {
  const h = boot(); let r = await pair(h, "cinko"); const q = raw(h, r).puzzle;
  assert.equal(r.cinkoRules, 2); assert.equal(r.open.length, 25);
  const u = r.turnUid; const o = u === "alice" ? "bob" : "alice";
  // A player who fits cell i but not its right-hand neighbour j.
  let pick = null;
  for (let i = 0; i < 25 && !pick; i++) {
    if (i % 5 === 4) continue;
    const p = Object.values(c.players).find((p) => p.rank <= 3000 && E.matches(c, p, q.criteria[i]) &&
      !E.matches(c, p, q.criteria[i + 1]));
    if (p) pick = {p, i, j: i + 1};
  }
  await assert.rejects(act(h, u, r, "answer", {playerId: pick.p.id, cells: [0, 6]}), {code: "invalid-argument"});
  await assert.rejects(act(h, u, r, "answer", {playerId: pick.p.id}), {code: "invalid-argument"});
  r = await act(h, u, r, "answer", {playerId: pick.p.id, cells: [pick.i, pick.j]});
  assert.equal(r.scores[u], 0); assert.equal(r.scores[o], 1);
  assert.equal(r.owners[pick.i].uid, u); assert.equal(r.owners[pick.j], undefined);
  assert.deepEqual([r.lastMove.correct, r.lastMove.wrong, r.lastMove.player.id], [[pick.i], [pick.j], pick.p.id]);
  assert.equal(r.turnUid, o);
  await assert.rejects(act(h, o, r, "answer", {playerId: pick.p.id, cells: [pick.j]}), {code: "already-exists"});
  r = await act(h, o, r, "pass"); assert.equal(r.turnUid, u); assert.equal(r.passes, 1);
  r = await act(h, u, r, "pass"); r = await act(h, o, r, "pass");
  assert.equal(r.status, "playing");
  r = await act(h, u, r, "pass");
  assert.equal(r.status, "finished"); assert.equal(r.reason, "İki oyuncu da üst üste pas geçti.");
  // The second player's starting point decides an otherwise level match.
  assert.equal(r.winnerUid, o);
});
test("CI08: a timed-out Çinko turn counts as a pass", async () => {
  const h = boot(); let r = await pair(h, "cinko"); const u = r.turnUid;
  h.setTime(r.turnDeadline - 20000); await act(h, "alice", r); await act(h, "bob", r);
  h.setTime(r.turnDeadline + 10); await act(h, "alice", r); r = await act(h, "bob", r);
  assert.equal(r.passes, 1); assert.equal(r.lastMove.timeout, true); assert.equal(r.lastMove.uid, u);
  assert.notEqual(r.turnUid, u);
});
test("RF07: Random Five boards are checked and 3+ clubs earn a bonus; single-board rooms still finish", () => {
  const fit = (clubs, p) => clubs.filter((k) => E.matches(c, p, k)).length;
  for (let i = 0; i < 20; i++) {
    const q = E.puzzle(c, "random_five", "five" + i);
    assert.equal(q.boards.length, E.FIVE_ROUNDS);
    // Every five is a checked board; the five boards share no club.
    assert.equal(new Set(q.boards.flat()).size, 25);
    for (const clubs of q.boards) {
      const n = Object.values(c.players).map((p) => fit(clubs, p));
      assert.ok(Math.max(...n) >= 4); assert.ok(n.filter((x) => x >= 3).length >= 4);
      assert.ok(n.filter((x) => x >= 2).length >= 20);
    }
  }
  assert.deepEqual(E.FIVE_POINTS, [0, 1, 2, 4, 6, 8]);
  // A room started before the rounds keeps its single board and race rules.
  const r = legacyFive("five-legacy"); const clubs = r.puzzle.clubs;
  const four = Object.values(c.players).find((p) => fit(clubs, p) >= 4);
  E.move(c, r, "a", {playerId: four.id}, 6000);
  assert.equal(r.scores.a, E.FIVE_POINTS[fit(clubs, four)]);
  const none = Object.values(c.players).find((p) => !fit(clubs, p));
  E.move(c, r, "b", {playerId: none.id}, 6500);
  assert.equal(E.view(c, r, "b", 6500).wrongMoves.b, 1);
  assert.throws(() => E.move(c, r, "b", {playerId: four.id}, 7000), {code: "resource-exhausted"});
  r.presence = {a: r.endsAt, b: r.endsAt}; E.advance(r, r.endsAt + 10);
  const v = E.view(c, r, "b", r.endsAt + 10);
  assert.equal(v.status, "finished"); assert.equal(v.winnerUid, "a");
  assert.deepEqual(v.found.map((p) => [p.id, p.uid]), [[four.id, "a"]]);
  assert.ok(v.missed.length > 0 && v.missed.every((p) => p.clubs >= 2 && p.id !== four.id));
});
test("Random Five rounds: one hidden guess each per five, the reveal, then a new five", async () => {
  const h = boot(); let r = await pair(h, "random_five");
  assert.equal(r.fiveRules, 3); assert.equal(r.totalRounds, 5);
  h.setTime(r.startsAt + 3000); r = await act(h, "alice", r);
  assert.equal(r.round, 0); assert.equal(r.criteria.length, 5);
  const boards = raw(h, r).puzzle.boards;
  assert.deepEqual(r.criteria.map((k) => k.id), boards[0]);
  const best = fiveBest(boards[0]);
  r = await act(h, "alice", r, "answer", {playerId: best, round: 0});
  assert.equal(r.myAnswer.id, best); assert.equal(r.myAnswer.points, E.FIVE_POINTS[fiveFit(boards[0], best)]);
  // One guess per five.
  await assert.rejects(act(h, "alice", r, "answer", {playerId: fiveNone(boards[0]), round: 0}),
      {code: "already-exists"});
  // The rival sees that a guess is in, never which one or its points.
  let b = await act(h, "bob", r);
  assert.equal(b.rivalAnswered, true); assert.equal(b.myAnswer, null);
  assert.deepEqual(b.scores, {alice: 0, bob: 0}); assert.deepEqual(b.used, {}); assert.deepEqual(b.rounds, []);
  b = await act(h, "bob", b, "answer", {playerId: fiveNone(boards[0]), round: 0});
  // Both answered: the round closes at once and both answers open.
  assert.equal(b.roundClosed, true); assert.equal(b.nextRoundAt, h.now + E.FIVE_REVEAL_MS);
  assert.equal(b.scores.alice, E.FIVE_POINTS[fiveFit(boards[0], best)]); assert.equal(b.scores.bob, 0);
  const first = b.rounds[0];
  assert.equal(first.answers.alice.id, best); assert.equal(first.answers.bob.points, 0);
  assert.equal(first.answers.alice.clubIds.length, fiveFit(boards[0], best));
  assert.equal(first.best.length, 3); assert.ok(first.best[0].clubs >= first.best[2].clubs);
  await assert.rejects(act(h, "bob", b, "answer", {playerId: best, round: 0}), {code: "failed-precondition"});
  // 4 s later the next five is in, sharing no club with the first.
  h.setTime(b.nextRoundAt); r = await act(h, "alice", r);
  assert.equal(r.round, 1); assert.deepEqual(r.criteria.map((k) => k.id), boards[1]);
  assert.equal(r.roundClosed, false); assert.equal(r.rivalAnswered, false);
  assert.ok(boards[1].every((k) => !boards[0].includes(k)));
  // A stale round number (the previous five) is refused, not counted for the new one.
  await assert.rejects(act(h, "alice", r, "answer", {playerId: fiveBest(boards[1], [best]), round: 0}),
      {code: "failed-precondition"});
  // A name is used once per player.
  if (fiveFit(boards[1], best)) {
    await assert.rejects(act(h, "alice", r, "answer", {playerId: best, round: 1}), {code: "already-exists"});
  }
});
test("Random Five rounds close at 25 s without answers; five rounds end the match", () => {
  const r = E.hydrate({mode: "random_five", host: "a", guest: "b", seed: "five-clock", dataRevision: c.version});
  E.start(r, c, 0); const t0 = r.startsAt;
  assert.equal(r.endsAt - t0, 5 * E.FIVE_ANSWER_MS + 4 * E.FIVE_REVEAL_MS);
  const at = (t) => {
    r.presence = {a: t, b: t}; E.advance(r, t); return E.view(c, r, "a", t);
  };
  let v = at(t0 + E.FIVE_ANSWER_MS - 1); assert.equal(v.round, 0); assert.equal(v.roundClosed, false);
  v = at(t0 + E.FIVE_ANSWER_MS); assert.equal(v.roundClosed, true); assert.equal(v.rounds[0].answers.a.timeout, true);
  // a answers round 2 only; b never does.
  const start2 = t0 + 2 * (E.FIVE_ANSWER_MS + E.FIVE_REVEAL_MS);
  v = at(start2 + 1000); assert.equal(v.round, 2);
  const id = fiveBest(r.puzzle.boards[2]); E.move(c, r, "a", {playerId: id, round: 2}, start2 + 2000);
  v = at(r.endsAt - 1); assert.equal(v.status, "playing"); assert.equal(v.round, 4);
  v = at(r.endsAt);
  assert.equal(v.status, "finished"); assert.equal(v.reason, "Beş tur tamamlandı.");
  assert.equal(v.rounds.length, 5); assert.equal(v.winnerUid, "a");
  assert.equal(v.scores.a, E.FIVE_POINTS[fiveFit(r.puzzle.boards[2], id)]); assert.equal(v.scores.b, 0);
});
test("Random Five rounds: equal points go to more rounds scored, then the faster answers", () => {
  const room = (seed) => {
    const r = E.hydrate({mode: "random_five", host: "a", guest: "b", seed, dataRevision: c.version});
    E.start(r, c, 0); r.status = "playing"; return r;
  };
  const r = room("five-tie"); let t = r.startsAt; const q = r.puzzle.boards;
  // The same points in each round: a answers faster in every one.
  for (let i = 0; i < 5; i++) {
    const id = fiveBest(q[i]); const other = Object.keys(c.players).find((x) => x !== id &&
      fiveFit(q[i], x) === fiveFit(q[i], id));
    E.move(c, r, "a", {playerId: id, round: i}, t + 1000);
    E.move(c, r, "b", {playerId: other || id, round: i}, t + 5000);
    t += 5000 + E.FIVE_REVEAL_MS; r.presence = {a: t, b: t}; E.advance(r, t);
  }
  assert.equal(r.status, "finished"); assert.equal(r.scores.a, r.scores.b); assert.equal(r.winnerUid, "a");
});
// ---- Club Manager draft (managerRules 3) ----
function draftRoom(seed) {
  const r = E.hydrate({mode: "club_manager", host: "a", guest: "b", seed, dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; return r;
}
// Picks the whole draft: each side takes its chooser's pick from the legal ones.
function playDraft(r, choose = {a: (L) => L[0], b: (L) => L[0]}) {
  let t = r.startsAt;
  while (r.draft.k < E.DRAFT_PICKS) {
    t += 500; const u = r.turnUid; E.move(c, r, u, {action: "pick", playerId: choose[u](E.legalPicks(r, u), r)}, t);
  }
  return t;
}
test("Club Manager draft pool: 36 known players, three anchor clubs, every position covered", () => {
  for (let i = 0; i < 15; i++) {
    const q = draftRoom("pool" + i).puzzle;
    assert.equal(q.pool.length, 36); assert.equal(new Set(q.pool).size, 36);
    const n = {GK: 0, DEF: 0, MID: 0, ATT: 0};
    for (const id of q.pool) {
      n[q.meta[id].position]++; assert.ok(c.players[id].rating >= 76 && c.players[id].rank <= 5000);
    }
    assert.deepEqual(n, {GK: 4, DEF: 11, MID: 12, ATT: 9});
    assert.equal(q.anchors.length, 3);
    for (const a of q.anchors) {
      assert.ok(q.pool.filter((id) => c.players[id].clubs.includes(a.id.slice(5))).length >= 3, a.label);
    }
    assert.ok(q.links.some(([, , , type]) => type === "club" || type === "both"));
  }
});
test("Club Manager draft: snake order, one turn at a time, taken players and full positions refused", () => {
  const r = draftRoom("snake"); const first = r.turnUid; const second = first === "a" ? "b" : "a";
  const order = []; let t = r.startsAt;
  assert.throws(() => E.move(c, r, second, {action: "pick", playerId: r.puzzle.pool[0]}, t + 100),
      {code: "permission-denied"});
  const gk = r.puzzle.pool.filter((id) => r.puzzle.meta[id].position === "GK");
  E.move(c, r, first, {action: "pick", playerId: gk[0]}, t += 500); order.push(first);
  assert.throws(() => E.move(c, r, second, {action: "pick", playerId: gk[0]}, t += 100), {code: "already-exists"});
  E.move(c, r, second, {action: "pick", playerId: gk[1]}, t += 500); order.push(second);
  // One goalkeeper per side: a second one is not a legal pick.
  assert.throws(() => E.move(c, r, second, {action: "pick", playerId: gk[2]}, t += 500), {code: "failed-precondition"});
  assert.ok(!E.legalPicks(r, second).includes(gk[2]));
  while (r.draft.k < E.DRAFT_PICKS) {
    order.push(r.turnUid); E.move(c, r, r.turnUid, {action: "pick", playerId: E.legalPicks(r, r.turnUid)[0]}, t += 500);
  }
  assert.deepEqual(order.slice(0, 6), [first, second, second, first, first, second]);
  for (const u of ["a", "b"]) {
    assert.equal(r.draft.picks[u].length, 11); assert.ok(E.FORMATIONS[E.formationOf(r.puzzle, r.draft.picks[u])]);
  }
  assert.ok(r.plan); assert.equal(r.turnUid, null);
});
test("Club Manager draft: a missed pick takes the best legal player; a missed plan keeps the best captain", () => {
  const r = draftRoom("clock"); const u = r.turnUid;
  const best = E.legalPicks(r, u).sort((x, y) => r.puzzle.meta[y].rating - r.puzzle.meta[x].rating)[0];
  r.presence = {a: r.draft.deadline, b: r.draft.deadline}; E.advance(r, r.draft.deadline);
  assert.deepEqual(r.draft.picks[u], [best]); assert.equal(r.draft.log[0].auto, true);
  assert.notEqual(r.turnUid, u);
  // Nobody picks again: the clock drafts both teams, then plays the match.
  let t = r.draft.deadline;
  while (r.status === "playing") {
    t += 10000; r.presence = {a: t, b: t}; E.advance(r, t);
  }
  assert.equal(r.status, "finished"); assert.ok(r.finishedAt <= r.endsAt);
  for (const side of ["a", "b"]) {
    const ids = r.draft.picks[side]; assert.equal(ids.length, 11);
    const top = [...ids].sort((x, y) => r.puzzle.meta[y].rating - r.puzzle.meta[x].rating)[0];
    assert.equal(r.plan.choices[side].captain, top); assert.equal(r.plan.choices[side].plan, null);
  }
});
test("Club Manager plan: hidden until both lock, own captain only, match events add up", () => {
  const r = draftRoom("plan"); const t = playDraft(r);
  assert.throws(() => E.move(c, r, "a", {action: "plan", plan: "attack", captain: r.draft.picks.b[0]}, t + 100),
      {code: "invalid-argument"});
  assert.throws(() => E.move(c, r, "a", {action: "plan", plan: "tiki", captain: r.draft.picks.a[0]}, t + 100),
      {code: "invalid-argument"});
  E.move(c, r, "a", {action: "plan", plan: "attack", captain: r.draft.picks.a[0]}, t + 200);
  const peer = E.view(c, r, "b", t + 300);
  assert.equal(peer.rivalPlanned, true); assert.equal(peer.myPlan, null); assert.equal(peer.planChoices, undefined);
  assert.equal(peer.phase, "plan");
  E.move(c, r, "b", {action: "plan", plan: "possession", captain: r.draft.picks.b[1]}, t + 400);
  assert.equal(r.status, "finished");
  const s = r.simulation; const v = E.view(c, r, "a", t + 500);
  assert.equal(v.simulation.rules, 3); assert.equal(v.planChoices.b.plan, "possession");
  for (const u of ["a", "b"]) {
    assert.equal(s.events.filter((e) => e.type === "goal" && e.uid === u).length, s.goals[u]);
    assert.equal(r.scores[u], s.goals[u]);
    for (const e of s.events.filter((x) => x.uid === u)) {
      assert.ok(r.draft.picks[u].includes(e.playerId)); assert.ok(e.minute >= 1 && e.minute <= 90);
      if (e.assistId) assert.ok(r.draft.picks[u].includes(e.assistId) && e.assistId !== e.playerId);
    }
  }
  // Attack beats possession.
  assert.ok(s.edge.a > s.edge.b - .01);
  assert.ok([...r.draft.picks.a, ...r.draft.picks.b].includes(s.mvp));
  if (s.goals.a === s.goals.b) assert.notEqual(s.penalties.a, s.penalties.b);
  // The same picks and plans always play the same match.
  const again = draftRoom("plan"); playDraft(again);
  E.move(c, again, "a", {action: "plan", plan: "attack", captain: again.draft.picks.a[0]}, t + 200);
  E.move(c, again, "b", {action: "plan", plan: "possession", captain: again.draft.picks.b[1]}, t + 400);
  assert.deepEqual(again.simulation, s);
});
test("Club Manager: the stronger draft wins most matches (power matters more than luck)", () => {
  let wins = 0; const n = 60;
  for (let i = 0; i < n; i++) {
    const r = draftRoom("strength" + i); const m = r.puzzle.meta;
    const t = playDraft(r, {a: (L) => [...L].sort((x, y) => m[y].rating - m[x].rating)[0],
      b: (L) => [...L].sort((x, y) => m[x].rating - m[y].rating)[0]});
    E.move(c, r, "a", {action: "plan", plan: "possession", captain: r.draft.picks.a[0]}, t + 100);
    E.move(c, r, "b", {action: "plan", plan: "possession", captain: r.draft.picks.b[0]}, t + 200);
    if (r.winnerUid === "a") wins++;
  }
  assert.ok(wins / n >= .65, `${wins}/${n}`);
});
test("Club Manager draft through the room API: pick and plan actions, view of both picks", async () => {
  const h = boot(); let r = await pair(h, "club_manager");
  assert.equal(r.managerRules, 3); assert.equal(r.phase, "draft"); assert.equal(r.pool.length, 36);
  h.setTime(r.startsAt + 1000); r = await act(h, "alice", r);
  const me = r.turnUid; const rival = me === "alice" ? "bob" : "alice";
  let mine = await act(h, me, r); assert.ok(mine.legal.length > 0);
  mine = await act(h, me, mine, "pick", {playerId: mine.legal[0]});
  assert.deepEqual(mine.picks[me], [mine.lastPick.playerId]);
  const theirs = await act(h, rival, mine); assert.equal(theirs.turnUid, rival);
  assert.deepEqual(theirs.picks[me], mine.picks[me]);
});
