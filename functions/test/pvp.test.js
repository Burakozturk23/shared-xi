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
  const h = boot(); let r = await pair(h, "grid_random"); const q = raw(h, r); const used = new Set();
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
test("GR07: a rare answer earns +1 in Grid Random; equal reverse scores go to fewer wrong answers", () => {
  const r = E.hydrate({mode: "grid_random", host: "a", guest: "b", seed: "rare", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; assert.equal(r.gridRules, 2);
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
  const q = raw(h, r).puzzle;
  const p = Object.values(c.players).find((p) => q.clubs.filter((k) => E.matches(c, p, k)).length >= 2);
  r = await act(h, "alice", r, "answer", {playerId: p.id});
  assert.equal(r.scores.alice, E.FIVE_POINTS[q.clubs.filter((k) => E.matches(c, p, k)).length]);
  const cinko = await pair(boot(), "cinko"); assert.equal(cinko.criteria.length, 25);
  const h2 = boot(); const cr = await pair(h2, "cinko");
  await assert.rejects(act(h2, cr.turnUid, cr, "answer", {playerId: p.id, indexes: [0, 1, 2]}), {code:
      "invalid-argument"});
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
  const h = boot(); let r = await pair(h, "club_manager"); const q = raw(h, r);
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
  const h = boot(); let r = await pair(h, "club_manager"); const pool = raw(h, r).puzzle.pool;
  const mine = Object.entries(E.FORMATIONS["433"]).flatMap(([pos, n]) => pool.map((id) => c.players[id])
      .filter((p) => p.position === pos).sort((a, b) => a.cost - b.cost).slice(0, n).map((p) => p.id));
  r = await act(h, "alice", r, "squad", {...squad, playerIds: mine});
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
test("friend rematch requires both consents, swaps roles and preserves a three-game series", async () => {
  const h = boot(); let r = await pair(h, "club_country");
  h.seed(`pvpV1/club_country/rooms/${r.id}/series/limit`, 3);
  r = await act(h, "alice", r, "leave");
  r = await act(h, "alice", r, "rematch"); assert.equal(r.nextRoom, null);
  r = await act(h, "bob", r, "rematch"); assert.ok(r.nextRoom);
  const next = await enter(h, "alice", "club_country", "resume");
  assert.equal(next.host, "bob"); assert.equal(next.guest, "alice");
  assert.equal(next.series.game, 2); assert.equal(next.series.wins.bob, 1);
  assert.deepEqual(next.ready, {}); assert.equal(h.read("rankedState"), null);
});
test("CORE06: autocomplete order is independent of room criteria and is drawn from the full snapshot", async () => {
  const h = boot(); const r = await pair(h, "club_country");
  const a = await h.call("searchPvp", {...base(r.mode), query: "ronaldo"}, auth("alice"));
  const b = await h.call("searchPvp", {...base(r.mode), query: "ronaldo", roomId: r.id}, auth("alice"));
  assert.deepEqual(a, b); assert.ok(a.players.length > 0);
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
test("CM07: global ranked rollout alone cannot enable unverified Manager ranked", async () => {
  const h = boot();
  const s = await h.call("getPvp", base("club_manager"), auth("alice"));
  assert.equal(s.availability.friendEnabled, true); assert.equal(s.availability.rankedEnabled, false);
  await assert.rejects(enter(h, "alice", "club_manager", "search", {playKind: "ranked"}),
      {code: "failed-precondition"});
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
      if (mode === "club_manager" && ranked) {
        await assert.rejects(enter(h, "alice", mode, "search", {playKind: "ranked"}), {code: "failed-precondition"});
        return; // The production verification gate must never be bypassed by the menu.
      }
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
test("RF07: Random Five boards are checked, 3+ clubs earn a bonus, wrong names cost, best answers shown", async () => {
  const fit = (q, p) => q.clubs.filter((k) => E.matches(c, p, k)).length;
  for (let i = 0; i < 50; i++) {
    const q = E.puzzle(c, "random_five", "five" + i); const n = Object.values(c.players).map((p) => fit(q, p));
    assert.ok(Math.max(...n) >= 4); assert.ok(n.filter((x) => x >= 3).length >= 4);
    assert.ok(n.filter((x) => x >= 2).length >= 20);
  }
  assert.deepEqual(E.FIVE_POINTS, [0, 1, 2, 4, 6, 8]);
  const h = boot(); let r = await pair(h, "random_five"); const q = raw(h, r).puzzle;
  assert.deepEqual(r.fivePoints, E.FIVE_POINTS);
  const four = Object.values(c.players).find((p) => fit(q, p) >= 4);
  r = await act(h, "alice", r, "answer", {playerId: four.id});
  assert.equal(r.scores.alice, E.FIVE_POINTS[fit(q, four)]);
  const none = Object.values(c.players).find((p) => !fit(q, p));
  r = await act(h, "bob", r, "answer", {playerId: none.id});
  assert.equal(r.wrongMoves.bob, 1); assert.equal(r.scores.bob, 0);
  await assert.rejects(act(h, "bob", r, "answer", {playerId: four.id}), {code: "resource-exhausted"});
  for (let t = h.now + 20000; t < r.endsAt; t += 20000) {
    h.setTime(t); await act(h, "alice", r); await act(h, "bob", r);
  }
  h.setTime(r.endsAt + 10); r = await act(h, "bob", r);
  assert.equal(r.status, "finished"); assert.equal(r.winnerUid, "alice");
  assert.deepEqual(r.found.map((p) => [p.id, p.uid]), [[four.id, "alice"]]);
  assert.ok(r.missed.length > 0 && r.missed.every((p) => p.clubs >= 2 && p.id !== four.id));
  assert.ok(r.missed.every((p, i) => !i || r.missed[i - 1].clubs >= p.clubs));
});
