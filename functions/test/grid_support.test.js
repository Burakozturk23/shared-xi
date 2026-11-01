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
// The stored session without the empty maps the database drops.
const state = (h, r) => ({cells: {}, used: {}, rows: {}, cols: {}, ...raw(h, r)});
const pay = {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25};
// Against the bot either side may move first; let the bot play its opening move.
async function userTurn(h, r) {
  if (r.turn !== "bot") return r;
  h.setTime(h.now + 2500); return (await load(h, r.mode)).session;
}
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
  // Six correct axes (6 × 40); five wrong answers cost 10 (the first came at 0 points).
  assert.equal(r.userScore, 190);
  assert.equal(r.wrong, 6);
  assert.equal(r.accepted.length, 6);
  assert.ok(r.accepted.every((labels) => labels.length));
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
  let r = await userTurn(h, await start(h, "bot_grid_reverse"));
  const first = Array.from({length: 6}, (_, i) => i).find((i) => !r.axes[i]);
  r = await act(h, r, "hint", {target: first, ...pay});
  for (let step = 0;
    !r.finished && step < 6;
    step++) {
    const target = Array.from({length: 6}, (_, i) => i).find((i) => !r.axes[i]);
    r = await act(h, r, "guess", {target, answer: G.common(raw(h, r), target)[0].id});
    if (!r.finished) {
      assert.equal(r.turn, "bot");
      await assert.rejects(act(h, r, "hint", {target: 5 - first, ...pay}));
      h.setTime(h.now + 2500);
      r = (await load(h, r.mode)).session;
    }
  }
  assert.equal(r.completed, true);
  // The medium bot may miss an axis, which then stays open for the user.
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
    r = await userTurn(h, r); const opening = r.botScore;
    if (mode.endsWith("random")) {
      r = await act(h, r, "generate");
      r = await act(h, r, "guess", {target: "pending", playerId: G.answers(raw(h, r), "pending")[0]});
      r = await act(h, r, "place", {target: 2, swap: false});
    } else {
      const cell = Array.from({length: 9}, (_, i) => i).find((i) => !r.cells[i]);
      r = await act(h, r, "guess", {target: cell, playerId: G.answers(state(h, r), cell)[0]});
    }
    assert.equal(r.turn, "bot");
    const revision = r.revision;
    assert.equal((await load(h, mode)).session.revision, revision);
    h.setTime(h.now + 2200); r = (await load(h, mode)).session;
    assert.equal(r.turn, "user"); assert.equal(r.revision, revision + 1);
    assert.ok(r.botScore - opening === 0 || r.botScore - opening === 1);
    assert.equal(h.read("economyState/alice/balances/coins"), 1000);
  }
});
test("rules 2 boards are fair: 3+ answers, a well-known answer per cell, one position column", () => {
  for (let n = 0; n < 40; n++) {
    const p = G.makePuzzle({pool: [], seed: "fair" + n, minimumAnswers: 1, rules: 2});
    assert.ok(p.cols.filter((k) => k.startsWith("position:")).length <= 1);
    for (const a of p.answers) {
      assert.ok(a.length >= 3);
      assert.ok(a.some((id) => G.catalog.players[id].rank <= G.POPULAR_RANK));
    }
  }
  // A narrow pool still gets a board through the old floor.
  const pool = [27, 16, 15, 23826, 24, 18].map((id) => "club:" + id).filter((id) => G.catalog.criteria[id]);
  assert.equal(new Set(G.makePuzzle({pool, seed: "narrow", minimumAnswers: 2, rules: 2}).witness).size, 9);
});
test("solo wrong answers cost points, never below zero; bots do not pay it", async () => {
  const h = setup();
  let r = await start(h, "solo_grid_classic");
  assert.equal(r.wrongCost, 5);
  const wrong = (cell) => Object.keys(G.catalog.players).find((p) => !G.answers(state(h, r), cell).includes(p));
  r = await act(h, r, "guess", {target: 0, playerId: wrong(0)});
  assert.equal(r.userScore, 0); assert.equal(r.wrong, 1);
  r = await act(h, r, "guess", {target: 0, playerId: raw(h, r).puzzle.witness[0]});
  assert.ok(r.userScore >= 20);
  const before = r.userScore;
  r = await act(h, r, "guess", {target: 1, playerId: wrong(1)});
  assert.equal(r.userScore, before - 5); assert.match(r.feedback, /−5 puan/);
  r = await act(h, r, "finish");
  assert.ok(Object.keys(r.solutions).length >= 7);
  assert.ok(Object.values(r.solutions).every((p) => p.name));
  const b = await start(h, "bot_grid_classic");
  assert.equal(b.wrongCost, 0);
});
test("search lists clubs and countries for reverse; club labels match without affixes", async () => {
  const h = setup();
  const r = await start(h, "solo_grid_reverse");
  const found = await h.call("searchGridSupport", {mode: r.mode, sessionId: r.id, query: "galata"});
  assert.deepEqual(found.players, []);
  assert.ok(found.criteria.some((k) => k.id.startsWith("club:") && /Galatasaray/.test(k.label)));
  assert.equal(G.labelKey("Galatasaray SK"), G.labelKey("Galatasaray"));
  assert.equal(G.labelKey("FC Porto"), G.labelKey("Porto"));
  assert.notEqual(G.labelKey("Real Madrid"), G.labelKey("Madrid"));
});
test("hard bot blocks a user line, easy never does; the reverse bot misses by difficulty", () => {
  const board = (difficulty, seed) => {
    const puzzle = G.makePuzzle({pool: [], seed: "block", minimumAnswers: 2, rules: 2});
    return {mode: "bot_grid_" + (difficulty === "rev" ? "reverse" : "classic"), difficulty: difficulty === "rev" ?
      "easy" : difficulty, rules: 2, seed, revision: 0, puzzle, rows: {...puzzle.rows}, cols: {...puzzle.cols},
    cells: difficulty === "rev" ? {} : {0: {owner: 1, playerId: puzzle.witness[0]}, 1: {owner: 1,
      playerId: puzzle.witness[1]}}, axes: {}, used: {}, turn: "bot", botAt: 0, userScore: 2, botScore: 0};
  };
  let hard = 0; let easy = 0; let hits = 0; let misses = 0;
  for (let n = 0; n < 60; n++) {
    const a = board("hard", "s" + n); G.botMove(a, 1);
    if (Object.keys(a.cells).length === 3) hard += a.cells[2]?.owner === 2 ? 1 : 0; else hits++;
    const b = board("easy", "s" + n); G.botMove(b, 1);
    easy += b.cells[2]?.owner === 2 ? 1 : 0;
    const c = board("rev", "s" + n); G.botMove(c, 1);
    misses += Object.keys(c.axes).length ? 0 : 1;
  }
  assert.equal(hard + hits, 60 - (60 - hard - hits)); // every hard move that landed blocked
  assert.ok(hard >= 45, String(hard));
  assert.ok(easy <= 15, String(easy));
  assert.ok(misses >= 12 && misses <= 40, String(misses));
});
