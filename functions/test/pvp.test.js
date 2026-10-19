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
async function pair(h, mode, ranked = false, names = ["alice", "bob"]) {
  const [a, b] = names; const extra = {playKind: ranked ? "ranked" : "friend"};
  let r = await enter(h, a, mode, ranked ? "search" : "create", extra);
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
  assert.equal(c.grids.length, 60); assert.equal(c.cinko.length, 40); assert.equal(c.loto.length, 40);
  for (const g of c.grids) {
    for (let i = 0; i < 9; i++) {
      assert(E.matches(c, c.players[g.witness[i]], g.rows[Math.floor(i / 3)]));
      assert(E.matches(c, c.players[g.witness[i]], g.cols[i % 3]));
      assert(g.answers[i].length >= 3);
    }
  }
  for (const g of c.loto) {
    assert.equal(new Set(g.players).size, 16);
    g.players.forEach((p, i) => assert(E.matches(c, c.players[p], g.criteria[i])));
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
    const answer = q.puzzle.rounds[i].answers.find((p) => !used.has(p)); used.add(answer);
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
test("GT01-05: reverse axes require all three canonical relationships; 4 axes ends game", () => {
  const r = E.hydrate({mode: "grid_reverse", host: "a", guest: "b", seed: "reverse", dataRevision: c.version});
  E.start(r, c, 0); r.status = "playing"; const u = r.turnUid;
  const result = E.move(c, r, u, {targetId: "r0", criterionId: r.puzzle.rows[0]}, 5001);
  assert(result.correct); assert.equal(r.owners.r0.uid, u);
  assert.throws(() => E.move(c, r, r.turnUid, {targetId: "r7", criterionId: r.puzzle.rows[0]}, 5002));
});
test("RF01-05/CI02-04: server computes club points and all eligible cells; indexes are rejected", async () => {
  const h = boot(); let r = await pair(h, "random_five"); const q = raw(h, r).puzzle;
  const p = Object.values(c.players).find((p) => q.clubs.filter((k) => E.matches(c, p, k)).length >= 2);
  r = await act(h, "alice", r, "answer", {playerId: p.id});
  assert.equal(r.scores.alice, q.clubs.filter((k) => E.matches(c, p, k)).length);
  const cinko = await pair(boot(), "cinko"); assert.equal(cinko.criteria.length, 25);
  const h2 = boot(); const cr = await pair(h2, "cinko");
  await assert.rejects(act(h2, cr.turnUid, cr, "answer", {playerId: p.id, indexes: [0, 1, 2]}), {code:
      "invalid-argument"});
});
test("LO02-06: only pinned stone and correct cell accepted; 180s is server owned", async () => {
  const h = boot(); let r = await pair(h, "loto"); const q = raw(h, r).puzzle;
  assert.equal(r.endsAt - r.startsAt, 180000);
  r = await act(h, "alice", r, "answer", {targetId: 0, playerId: q.players[0]});
  assert.equal(r.owners[0].playerId, q.players[0]);
  await assert.rejects(act(h, "bob", r, "answer", {targetId: 1, playerId: q.players[0]}), {code: "already-exists"});
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
test("NET01-05/CORE07: reconnect clock, 30s absence, simultaneous offline and queue timeout", async () => {
  const h = boot(); let r = await pair(h, "random_five"); const start = r.startsAt;
  h.setTime(new Date(start + 20000).toISOString()); r = await act(h, "alice", r); assert.equal(r.startsAt, start);
  h.setTime(new Date(start + 31000).toISOString()); r = await act(h, "alice", r);
  assert.equal(r.status, "forfeit"); assert.equal(r.winnerUid, "alice");
  const h2 = boot(); r = await pair(h2, "club_club");
  h2.setTime(new Date(r.startsAt + 31000).toISOString()); r = await act(h2, "alice", r); assert.equal(
      r.status, "cancelled");
  const h3 = boot(); r = await enter(h3, "alice", "club_manager", "search", {playKind: "ranked"});
  h3.setTime(new Date(r.serverNow + 31000).toISOString()); r = await act(h3, "alice", r); assert.equal(
      r.status, "expired");
  assert.equal(h3.read("pvpV1/club_manager/queue/alice"), null);
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
