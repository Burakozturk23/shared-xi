"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const G = require("../grid_support");
let seq = 18000;
const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice/gridSupport";
const setup = () => harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
  readyModes: Object.fromEntries(G.MODES.map((m) => [m, true]))}}, economyState: {alice: {balances: {coins: 1000}}}},
{omitEmptyObjects: true});
const load = async (h, mode) => h.call("getGridSupport", {mode});
const start = async (h, mode, extra = {}) => (await h.call("actGridSupport", {mode, action: "start",
  requestId: id(), version: G.catalog.version, ...extra})).session;
const input = (r, action, extra = {}) => ({mode: r.mode, sessionId: r.id, revision: r.revision,
  version: r.version, action, requestId: id(), ...extra});
const act = async (h, r, action, extra) => (await h.call("actGridSupport", input(r, action, extra))).session;
const raw = (h, r) => h.read(root + "/sessions/" + r.id);
const pay = {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25};
test("six Grid IDs use isolated canonical runs, restricted modes and forged catalog fail", async () => {
  const h = setup();
  for (const mode of G.MODES) {
    const r = await start(h, mode);
    assert.equal(r.mode, mode);
    assert.equal(r.support.adLimit, 2);
    assert.equal(r.rewardCoins, 0);
    assert.equal(r.rewardXp, 0);
    assert.equal(JSON.stringify(r).includes("\"answers\""), false);
    assert.equal(r.seed, undefined);
    if (mode.endsWith("reverse")) {
      assert.deepEqual(r.rows, []);
      assert.equal(r.witnesses.length, 9);
    }
  }
  await assert.rejects(start(h, "grid_classic"));
  await assert.rejects(start(h, "solo_grid_classic", {version: "forged"}));
  h.setLinked("alice", false);
  await assert.rejects(start(h, "solo_grid_random"));
});
test("Grid debit survives projection loss, stale fingerprint and account attacks", async () => {
  const h = setup();
  let r = await start(h, "solo_grid_classic");
  const req = input(r, "hint", {target: 0, ...pay});
  h.failNext("");
  await assert.rejects(h.call("actGridSupport", req));
  const a = await h.call("actGridSupport", req);
  r = a.session;
  assert.equal(r.assisted, true);
  assert.ok(r.hints.cell_0);
  assert.equal(h.read("economyState/alice/balances/coins"), 975);
  await assert.rejects(h.call("actGridSupport", {...req, target: 1}));
  await assert.rejects(act(h, r, "hint", {target: 0, ...pay}));
  await assert.rejects(act(h, r, "hint", {target: 1, ...pay, revision: 0}));
  await assert.rejects(act(h, r, "hint", {target: 1, ...pay, boostId: "boost_strong"}));
  await assert.rejects(h.call("actGridSupport", input(r, "finish"), "bob"));
  const witnesses = raw(h, r).puzzle.witness;
  for (let i = 0;
    i < 9;
    i++) r = await act(h, r, "guess", {target: i, playerId: witnesses[i]});
  assert.equal(r.completed, true);
  assert.equal(r.masteryEligible, false);
  assert.equal(h.read(root + "/records/solo_grid_classic:medium"), null);
  assert.equal(h.read(root + "/assistedRecords/solo_grid_classic:medium/completed"), 1);
  assert.equal(h.read("economyState/alice/balances/coins"), 975);
});
test("reverse Grid accepts every real alternate criterion and refuses forged IDs", async () => {
  const h = setup();
  let r = await start(h, "solo_grid_reverse");
  r = await act(h, r, "hint", {target: 0, ...pay});
  assert.ok(r.hints.axis_0);
  for (let i = 0;
    i < 6;
    i++) {
    const options = G.common(raw(h, r), i);
    assert.ok(options.length);
    r = await act(h, r, "guess", {target: i, answer: "club:forged"});
    assert.equal(r.axes[i], undefined);
    const chosen = options.at(-1);
    r = await act(h, r, "guess", {target: i, answer: chosen.id});
    assert.equal(r.axes[i].criterionId, chosen.id);
  }
  assert.equal(r.completed, true);
  assert.equal(r.userScore, 240);
});
test("random Grid preserves three anchor pairs, orientation, unused-player and revision rules", async () => {
  const h = setup();
  let r = await start(h, "solo_grid_random");
  for (const target of [2, 4, 6]) {
    r = await act(h, r, "generate");
    const pair = r.pending.criteria.map((c) => c.id);
    const playerId = G.answers(raw(h, r), "pending")[0];
    r = await act(h, r, "guess", {target: "pending", playerId});
    await assert.rejects(act(h, r, "hint", {target: "pending", ...pay}));
    await assert.rejects(act(h, r, "place", {target: 0}));
    r = await act(h, r, "place", {target, swap: true});
    assert.equal(r.rows[target / 3 | 0].id, pair[1]);
    assert.equal(r.cols[target % 3].id, pair[0]);
    assert.equal(r.cells[target].player.id, playerId);
  }
  assert.equal(r.roundsUsed, 3);
  await assert.rejects(act(h, r, "generate"));
  r = await act(h, r, "finish");
  assert.equal(r.completed, false);
  assert.equal(h.read(root + "/records/solo_grid_random:medium"), null);
});
test("Grid verified ads are scoped to target, limited to two and recovered on target close/expiry", async () => {
  const h = setup();
  let r = await start(h, "solo_grid_classic");
  const svc = h.context.lbGridSupportService();
  const benefit = await svc.prepareHint("alice", "grid_support_hint", {
    sessionId: r.id, target: 0, boostId: "boost_basic"});
  const receipt = {id: "aa".repeat(24), context: benefit.context};
  await svc.settleHint("alice", receipt);
  await svc.settleHint("alice", receipt);
  r = (await load(h, r.mode)).session;
  assert.equal(r.adGranted, 1);
  await assert.rejects(act(h, r, "hint", {target: 1, boostId: "boost_basic", paymentSource: "ad"}));
  r = await act(h, r, "guess", {target: 0, playerId: raw(h, r).puzzle.witness[0]});
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 1);
  const second = await svc.prepareHint("alice", "grid_support_hint", {
    sessionId: r.id, target: 1, boostId: "boost_basic"});
  await svc.settleHint("alice", {id: "bb".repeat(24), context: second.context});
  await assert.rejects(svc.prepareHint("alice", "grid_support_hint", {
    sessionId: r.id, target: 2, boostId: "boost_basic"}));
  h.setTime(h.now + 86400001);
  r = (await load(h, r.mode)).session;
  assert.equal(r.finished, true);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 2);
});
test("bot Grid turn is server-owned, completes separate assisted result without rewards", async () => {
  const h = setup();
  let r = await start(h, "bot_grid_reverse");
  r = await act(h, r, "hint", {target: 0, ...pay});
  for (let step = 0;
    !r.finished && step < 6;
    step++) {
    const target = Array.from({length: 6}, (_, i) => i).find((i) => !r.axes[i]);
    r = await act(h, r, "guess", {target, answer: G.common(raw(h, r), target)[0].id});
    if (!r.finished) {
      assert.equal(r.turn, "bot");
      await assert.rejects(act(h, r, "hint", {target: 5, ...pay}));
      h.setTime(h.now + 2500);
      r = (await load(h, r.mode)).session;
    }
  }
  assert.equal(r.completed, true);
  assert.equal(r.userScore + r.botScore, 6);
  assert.equal(h.read(root + "/assistedRecords/bot_grid_reverse:medium/completed"), 1);
  assert.equal(h.read("economyState/alice/balances/coins"), 975);
});
test("popular and league pools generate nine distinct witnesses without restricting broad answers", () => {
  const pools = [[11, 631, 31, 281, 985, 148], [131, 418, 13, 368, 681, 1049], [5, 46, 506, 6195, 12, 398],
    [27, 16, 15, 23826, 24, 18], [583, 1041, 244, 162, 1082], [141, 36, 114, 449]];
  for (const ids of pools) {
    const pool = ids.map((id) => "club:" + id).filter((id) => G.catalog.criteria[id]);
    for (const seed of ["one", "two"]) {
      const puzzle = G.makePuzzle({pool, seed, minimumAnswers: 2});
      assert.equal(new Set(puzzle.witness).size, 9);
      assert.ok(puzzle.rows.every((id) => pool.includes(id)));
      for (let i = 0; i < 9; i++) {
        assert.ok(puzzle.answers[i].length >= 2); assert.ok(puzzle.answers[i].includes(puzzle.witness[i]));
      }
    }
  }
});
test("classic and random bots advance only at server deadlines; start replay cannot replace the board", async () => {
  for (const mode of ["bot_grid_classic", "bot_grid_random"]) {
    const h = setup();
    const req = {mode, action: "start", version: G.catalog.version, difficulty: "hard", requestId: id()};
    let r = (await h.call("actGridSupport", req)).session;
    assert.deepEqual((await h.call("actGridSupport", req)).session, r);
    await assert.rejects(h.call("actGridSupport", {...req, difficulty: "easy"}));
    if (mode.endsWith("random")) {
      r = await act(h, r, "generate");
      r = await act(h, r, "guess", {target: "pending", playerId: G.answers(raw(h, r), "pending")[0]});
      r = await act(h, r, "place", {target: 2, swap: false});
    } else r = await act(h, r, "guess", {target: 0, playerId: raw(h, r).puzzle.witness[0]});
    assert.equal(r.turn, "bot");
    const revision = r.revision;
    assert.equal((await load(h, mode)).session.revision, revision);
    h.setTime(h.now + 2200); r = (await load(h, mode)).session;
    assert.equal(r.turn, "user"); assert.equal(r.revision, revision + 1);
    assert.ok(r.botScore === 0 || r.botScore === 1);
    assert.equal(h.read("economyState/alice/balances/coins"), 1000);
  }
});
