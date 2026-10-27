"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const S = require("../bot_support");
let seq = 26000;
const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice/botSupport";
const setup = () => harness({runtimeConfig: {boosts: {enabled: true, betaUids: {alice: true},
  readyModes: Object.fromEntries(S.MODES.map((m) => [m, true]))}}, economyState: {alice: {balances: {coins: 1000}}}},
{omitEmptyObjects: true});
const load = async (h, mode) => (await h.call("getBotSupport", {mode})).session;
const start = async (h, mode, extra = {}) => (await h.call("actBotSupport", {mode, action: "start",
  requestId: id(), version: S.VERSION, ...extra})).session;
const input = (r, action, extra = {}) => ({mode: r.mode, sessionId: r.id, revision: r.revision,
  version: r.version, action, requestId: id(), ...extra});
const act = async (h, r, action, extra) => (await h.call("actBotSupport", input(r, action, extra))).session;
const raw = (h, r) => h.read(root + "/sessions/" + r.id);
const pay = {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25};
const coins = (h) => h.read("economyState/alice/balances/coins");

test("four bot IDs start isolated sessions without answers, rewards or online IDs", async () => {
  const h = setup();
  for (const mode of S.MODES) {
    const r = await start(h, mode, {clubId: "club:141"});
    assert.equal(r.mode, mode);
    assert.equal(r.rewardCoins, 0);
    assert.equal(r.rewardXp, 0);
    assert.equal(r.support.adLimit, 2);
    const text = JSON.stringify(r);
    for (const leak of ["\"seed\"", "\"queue\"", "\"players\"", "\"rounds\"", "countries", "\"position\""]) {
      assert.equal(text.includes(leak), false, mode + " leaks " + leak);
    }
  }
  assert.equal((await load(h, "bot_loto")).support.products.find((p) => p.id === "boost_basic").ads, false);
  for (const mode of ["loto", "cinko", "random_five", "bot_grid_classic"]) await assert.rejects(start(h, mode));
  await assert.rejects(start(h, "bot_cinko"));
  h.setLinked("alice", false);
  await assert.rejects(start(h, "bot_random_five"));
  await assert.rejects(start(setup(), "bot_cinko", {version: "forged"}));
  await assert.rejects(start(setup(), "bot_team_race", {clubId: "club:forged"}));
});

test("Loto keeps per-player clocks, hides correctness until the end and scores +10", async () => {
  const h = setup();
  let r = await start(h, "bot_loto", {difficulty: "hard"});
  assert.equal(r.seconds, 12);
  assert.equal(r.index, 0);
  assert.equal(r.current.country, undefined);
  const queue = raw(h, r).board.queue; const criteria = raw(h, r).board.criteria;
  const valid = (pid) => criteria.map((k, i) => S.matches(pid, k) ? i : -1).filter((i) => i >= 0);
  r = await act(h, r, "hint", {target: 0, ...pay});
  assert.match(r.hints.player_0, /milliyeti/);
  assert.equal(coins(h), 975);
  await assert.rejects(act(h, r, "hint", {target: 0, ...pay}));
  await assert.rejects(h.context.lbBotSupportService().prepareHint("alice", "bot_support_hint",
      {sessionId: r.id, target: 0, boostId: "boost_basic"}));
  const cell = valid(queue[0])[0];
  r = await act(h, r, "place", {index: 0, target: cell});
  assert.equal(r.index, 1);
  assert.equal(r.placements[cell].correct, undefined);
  await assert.rejects(act(h, r, "place", {index: 0, target: (cell + 1) % 16}));
  await assert.rejects(act(h, r, "place", {index: 1, target: cell}));
  r = await act(h, r, "pass", {index: 1});
  h.setTime(h.now + 12001);
  r = await load(h, r.mode);
  assert.equal(r.index, 3);
  assert.equal(r.timedOut, 1);
  r = await act(h, r, "pause");
  h.setTime(h.now + 60000);
  r = await load(h, r.mode);
  assert.equal(r.index, 3);
  await assert.rejects(act(h, r, "place", {index: 3, target: 0}));
  r = await act(h, r, "resume");
  const used = new Set([cell]);
  for (let i = r.index; i < 16; i++) {
    const target = valid(queue[i]).find((c) => !used.has(c)) ?? [...Array(16).keys()].find((c) => !used.has(c));
    used.add(target); r = await act(h, r, "place", {index: i, target});
  }
  assert.equal(r.finished, true);
  assert.equal(r.completed, true);
  const correct = Object.values(r.placements).filter((p) => p.correct).length;
  assert.equal(r.userScore, correct * 10);
  assert.equal(Object.keys(r.botPlacements).length <= 16, true);
  assert.equal(h.read(root + "/records/bot_loto:hard"), null);
  assert.equal(h.read(root + "/assistedRecords/bot_loto:hard/completed"), 1);
  assert.equal(coins(h), 975);
});

test("Team Race rounds need every shared player, bot claims only at server deadlines", async () => {
  const h = setup();
  let r = await start(h, "bot_team_race", {clubId: "club:418", difficulty: "easy"});
  assert.equal(r.club.id, "club:418");
  assert.ok(r.total >= 3 && r.total <= 12);
  const svc = h.context.lbBotSupportService();
  await assert.rejects(act(h, r, "guess", {round: 0, playerId: raw(h, r).race.players[0]}));
  h.setTime(h.now + 3000);
  const benefit = await svc.prepareHint("alice", "bot_support_hint", {sessionId: r.id, target: 0,
    boostId: "boost_basic"});
  await svc.settleHint("alice", {id: "cc".repeat(24), context: benefit.context});
  r = await load(h, r.mode);
  assert.equal(r.adGranted, 1);
  r = await act(h, r, "guess", {round: 0, playerId: "3"});
  assert.equal(r.userFound, 0);
  let rounds = 0;
  while (!r.finished && rounds < 12) {
    const race = raw(h, r).race;
    if (r.over) {
      r = await act(h, r, "next"); rounds++; h.setTime(h.now + 3000); continue;
    }
    const next = race.players.find((p) => !race.found?.[p]);
    r = await act(h, r, "guess", {round: r.round, playerId: next});
    await assert.rejects(act(h, r, "guess", {round: r.round + 1, playerId: next}));
  }
  assert.equal(r.finished, true);
  assert.equal(r.userScore, 3);
  assert.equal(r.winner, 1);
  // The unused ad credit for round 0 moved to stock when that round closed.
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 1);
  assert.equal(h.read(root + "/records/bot_team_race:easy/wins"), 1);
  assert.equal(coins(h), 1000);
  const second = await start(h, "bot_team_race", {clubId: "club:141", difficulty: "hard"});
  h.setTime(h.now + 3000 + 4600 * 4);
  const after = await load(h, second.mode);
  assert.ok(after.botFound >= 1);
  assert.equal(after.userFound, 0);
});

test("Çinko enforces connected cells, -1 wrong, 0 pass and capped bot groups", async () => {
  const h = setup();
  let r = await start(h, "bot_cinko", {difficulty: "easy"});
  assert.equal(r.cells.length, 25);
  const cells = raw(h, r).cells;
  const answer = (i) => [...S.answers(cells[i])].sort()[0];
  r = await act(h, r, "hint", {target: 0, ...pay});
  assert.ok(r.hints.cell_0);
  r = await act(h, r, "choose", {playerId: answer(0)});
  assert.equal(r.current.id, answer(0));
  await assert.rejects(act(h, r, "confirm", {cells: [0, 6]}));
  const wrong = [1, 5].find((i) => !S.matches(answer(0), cells[i]));
  if (wrong !== undefined) {
    r = await act(h, r, "confirm", {cells: [0, wrong]});
    assert.equal(r.userScore, 0);
    assert.deepEqual(r.last.wrong, [wrong]);
  } else {
    r = await act(h, r, "confirm", {cells: [0]});
    assert.equal(r.userScore, 1);
  }
  assert.equal(r.cells[0].owner, 1);
  assert.equal(r.turn, "bot");
  await assert.rejects(act(h, r, "pass"));
  h.setTime(h.now + 2500);
  r = await load(h, r.mode);
  assert.equal(r.turn, "user");
  assert.equal(r.botScore, 1);
  assert.equal(r.cells.filter((c) => c.owner === 2).length, 1);
  r = await act(h, r, "pass");
  assert.equal(r.userScore <= 1, true);
  const before = r.userScore;
  h.setTime(h.now + 1400);
  r = await load(h, r.mode);
  assert.equal(r.userScore, before);
  assert.equal(r.turn, "user");
  r = await act(h, r, "finish");
  assert.equal(r.completed, false);
  assert.equal(h.read(root + "/assistedRecords/bot_cinko:easy"), null);
});

test("Random Five edits are free, passes score zero and five rounds finish once", async () => {
  const h = setup();
  let r = await start(h, "bot_random_five", {difficulty: "hard"});
  assert.equal(r.clubs.length, 5);
  r = await act(h, r, "hint", {target: 0, ...pay});
  assert.match(r.hints.round_0, /beş kulübün \d tanesine uyuyor/);
  const nonMatch = Object.keys(S.catalog.players).find((p) => !r.clubs.some((c) => S.matches(p, c.id)));
  r = await act(h, r, "guess", {playerId: nonMatch});
  assert.equal(r.turn, "user");
  assert.match(r.feedback, /uymuyor/);
  for (let round = 0; round < 5; round++) {
    if (round === 1) r = await act(h, r, "pass");
    else {
      const used = raw(h, r).used || {};
      const pid = [...S.answers(r.clubs[0].id)].sort().find((p) => !used[p]);
      r = await act(h, r, "guess", {playerId: pid});
      await assert.rejects(act(h, r, "guess", {playerId: pid}));
    }
    assert.equal(r.turn, "bot");
    h.setTime(h.now + 1500);
    r = await load(h, r.mode);
    if (round < 4) {
      assert.equal(r.turn, "result");
      assert.ok(r.history[round].bot.player);
      r = await act(h, r, "next");
    }
  }
  assert.equal(r.finished, true);
  assert.equal(r.history[1].user.pass, true);
  assert.equal(r.history.length, 5);
  assert.equal(h.read(root + "/assistedRecords/bot_random_five:hard/completed"), 1);
  await assert.rejects(act(h, r, "next"));
});

test("bot support replays survive lost projections; changed payloads and other accounts fail", async () => {
  const h = setup();
  let r = await start(h, "bot_random_five");
  const req = input(r, "hint", {target: 0, ...pay});
  h.failNext("");
  await assert.rejects(h.call("actBotSupport", req));
  r = (await h.call("actBotSupport", req)).session;
  assert.equal(r.assisted, true);
  assert.equal(coins(h), 975);
  assert.deepEqual((await h.call("actBotSupport", req)).session.hints, r.hints);
  await assert.rejects(h.call("actBotSupport", {...req, target: 1}));
  await assert.rejects(h.call("actBotSupport", input(r, "finish"), "bob"));
  const startReq = {mode: "bot_cinko", action: "start", version: S.VERSION, difficulty: "hard", requestId: id()};
  const first = (await h.call("actBotSupport", startReq)).session;
  assert.deepEqual((await h.call("actBotSupport", startReq)).session.cells, first.cells);
  await assert.rejects(h.call("actBotSupport", {...startReq, difficulty: "easy"}));
  assert.equal(coins(h), 975);
});

test("generated boards are solvable for every seed and difficulty", () => {
  for (const seed of ["one", "two", "three"]) {
    const r = {seed};
    const cells = S.cinkoBoard(r);
    assert.equal(new Set(cells).size, 25);
    assert.ok(cells.every((id) => S.answers(id).size >= 2));
    const rounds = [];
    for (let i = 0; i < 5; i++) {
      rounds.push(S.fiveRound(r, rounds.at(-1) || [], i));
      assert.equal(new Set(rounds[i]).size, 5);
    }
    assert.ok(S.partners("club:" + [141, 36, 114, 449][seed.length % 4]).length >= 3);
  }
  for (const tier of Object.values(S.lotoTiers)) {
    for (const board of tier) {
      assert.equal(board.players.length, 16);
      assert.ok(board.players.every((p) => board.criteria.some((k) => S.matches(p, k))));
    }
  }
});
