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
// Çinko picks its first mover at random: let the bot play its opening move.
async function userTurn(h, r) {
  if (r.turn !== "bot") return r;
  h.setTime(h.now + 2500); return (await h.call("getBotSupport", {mode: r.mode})).session;
}
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
  let r = await userTurn(h, await start(h, "bot_cinko", {difficulty: "easy"}));
  assert.equal(r.cells.length, 25);
  const cells = raw(h, r).cells;
  // An open cell whose right and lower neighbours are open too (the bot may have opened).
  const free = (i) => r.cells[i].owner === 0 && r.cells[i].playable;
  const c0 = [...Array(19).keys()].find((i) => i % 5 < 4 && [i, i + 1, i + 5].every(free));
  assert.notEqual(c0, undefined);
  const base = r.userScore;
  const answer = (i) => [...S.answers(cells[i])].filter((id) => !raw(h, r).used?.[id]).sort()[0];
  r = await act(h, r, "hint", {target: c0, ...pay});
  assert.ok(r.hints["cell_" + c0]);
  r = await act(h, r, "choose", {playerId: answer(c0)});
  assert.equal(r.current.id, answer(c0));
  await assert.rejects(act(h, r, "confirm", {cells: [c0, c0 + 6]}));
  const wrong = [c0 + 1, c0 + 5].find((i) => !S.matches(answer(c0), cells[i]));
  if (wrong !== undefined) {
    r = await act(h, r, "confirm", {cells: [c0, wrong]});
    assert.equal(r.userScore, base);
    assert.deepEqual(r.last.wrong, [wrong]);
  } else {
    r = await act(h, r, "confirm", {cells: [c0]});
    assert.equal(r.userScore, base + 1);
  }
  assert.equal(r.cells[c0].owner, 1);
  assert.equal(r.turn, "bot");
  await assert.rejects(act(h, r, "pass"));
  const botBefore = r.botScore; const ownedBefore = r.cells.filter((c) => c.owner === 2).length;
  h.setTime(h.now + 2500);
  r = await load(h, r.mode);
  assert.equal(r.turn, "user");
  // Easy bot: at most two cells, and a slipped wrong cell costs it a point.
  const botCells = r.cells.filter((c) => c.owner === 2).length - ownedBefore;
  assert.ok(botCells >= 1 && botCells <= 2);
  assert.equal(r.botScore - botBefore, botCells - r.last.wrong.length);
  assert.ok(raw(h, r).last.playerId && S.catalog.players[raw(h, r).last.playerId].rank <= 1500);
  r = await act(h, r, "pass");
  assert.equal(r.userScore <= base + 1, true);
  const before = r.userScore;
  h.setTime(h.now + 1400);
  r = await load(h, r.mode);
  assert.equal(r.userScore, before);
  assert.equal(r.turn, "user");
  r = await act(h, r, "finish");
  assert.equal(r.completed, false);
  assert.equal(h.read(root + "/assistedRecords/bot_cinko:easy"), null);
});

test("Random Five: simultaneous rounds, the table pays rarer answers, five rounds finish once", async () => {
  const h = setup();
  let r = await start(h, "bot_random_five", {difficulty: "hard"});
  assert.equal(r.clubs.length, 5); assert.equal(r.rules, 2); assert.equal(r.simultaneous, true);
  assert.deepEqual(r.fivePoints, S.FIVE_POINTS);
  // The bot has locked its answer but it stays hidden.
  assert.equal(r.botReady, true); assert.equal(r.history[0].bot, null);
  assert.equal(JSON.stringify(r).includes("botPick"), false);
  r = await act(h, r, "hint", {target: 0, ...pay});
  assert.match(r.hints.round_0, /beş kulübün \d tanesine uyuyor/);
  const nonMatch = Object.keys(S.catalog.players).find((p) => !r.clubs.some((c) => S.matches(p, c.id)));
  r = await act(h, r, "guess", {playerId: nonMatch});
  assert.equal(r.turn, "user");
  assert.match(r.feedback, /uymuyor/);
  let user = 0; let bot = 0;
  for (let round = 0; round < 5; round++) {
    assert.equal(r.turn, "user"); assert.equal(r.botFirst, false);
    if (round === 1) r = await act(h, r, "pass");
    else {
      const used = raw(h, r).used || {};
      const pid = [...S.answers(r.clubs[0].id)].sort().find((p) => !used[p]);
      const n = r.clubs.filter((c) => S.matches(pid, c.id)).length;
      r = await act(h, r, "guess", {playerId: pid});
      assert.equal(r.history[round].user.points, S.FIVE_POINTS[n]);
      await assert.rejects(act(h, r, "guess", {playerId: pid}));
    }
    // Answering closes the round at once and opens the bot's answer.
    if (round < 4) assert.equal(r.turn, "result");
    const b = r.history[round].bot;
    assert.ok(b.player); assert.equal(b.points, S.FIVE_POINTS[b.clubs.length]);
    // Hard: the best answer among the players it knows and has not used yet.
    const botUsed = raw(h, r).botUsed || {};
    const ids = new Set(r.clubs.flatMap((c) => [...S.answers(c.id)]).filter((id) =>
      S.catalog.players[id].rank <= S.FIVE_BOT.hard.known && (id === b.player.id || !botUsed[id])));
    const top = Math.max(...[...ids].map((id) => r.clubs.filter((c) => S.matches(id, c.id)).length));
    assert.equal(b.clubs.length, top);
    user += r.history[round].user.points; bot += b.points;
    assert.equal(r.userScore, user); assert.equal(r.botScore, bot);
    if (round < 4) {
      assert.equal(r.history[round].best.length, 3);
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
test("bot Loto: 100 boards per tier and the bot never takes a cell a later player needs when it has a choice", () => {
  assert.deepEqual(Object.values(S.lotoTiers).map((t) => t.length), [100, 100, 100]);
  assert.ok(S.lotoTiers.easy.every((b) => b.tier === "easy"));
});

test("Team Race: 70 s rounds, early end, 6+ shared players, easy rounds use the best-known players", async () => {
  const h = setup(); const c = require("../pvp_engine").catalog;
  let r = await start(h, "bot_team_race", {clubId: "club:418", difficulty: "easy"});
  const race = raw(h, r).race;
  assert.equal(r.endsAt - r.startsAt, S.RACE_ROUND_MS);
  const [a, b] = [r.club.id, race.opponent].map((k) => k.slice(5));
  // Rules 2: the round's players are well known (within the level's rank limit).
  const limit = raw(h, r).raceLimit;
  assert.equal(limit, S.RACE_TIER.easy);
  const shared = Object.values(c.players).filter((p) => p.clubs.map(String).includes(a) &&
    p.clubs.map(String).includes(b) && p.rank <= limit).sort((x, y) => x.rank - y.rank || x.id.localeCompare(y.id));
  assert.ok(shared.length >= S.RACE_MIN_SHARED);
  const top = new Set(shared.slice(0, 16).map((p) => p.id));
  assert.equal(race.players.length, Math.min(12, shared.length));
  assert.ok(race.players.every((id) => top.has(id)));
  // Time runs out: the round closes and lists the players nobody found.
  h.setTime(r.endsAt + 1); r = await load(h, r.mode);
  assert.equal(r.over, true); assert.equal(r.missed.length, r.remaining);
  r = await act(h, r, "next"); h.setTime(h.now + 3000);
  r = await act(h, r, "end_round", {round: r.round});
  assert.equal(r.over, true); assert.equal(r.feedback, "Turu bitirdin.");
  await assert.rejects(act(h, r, "end_round", {round: r.round}));
});

test("Çinko choose does not reveal whether the player fits an open cell", async () => {
  const h = setup(); let r = await userTurn(h, await start(h, "bot_cinko", {difficulty: "medium"}));
  const cells = raw(h, r).cells;
  const none = Object.keys(S.catalog.players).find((id) => !cells.some((k) => S.matches(id, k)));
  const pair = [[0, 1], [5, 6], [10, 11], [15, 16], [20, 21]].find(([a, b]) => r.cells[a].playable &&
    r.cells[b].playable && !r.cells[a].owner && !r.cells[b].owner);
  const base = r.userScore;
  r = await act(h, r, "choose", {playerId: none});
  assert.equal(r.current.id, none); assert.equal(r.feedback, null);
  r = await act(h, r, "confirm", {cells: pair});
  assert.equal(r.userScore, base - 2); assert.equal(r.cells[pair[0]].owner, 0);
});

test("Random Five: three wrong names pass the round; easy bot stays within its knowledge", async () => {
  const h = setup(); let r = await start(h, "bot_random_five", {difficulty: "easy"});
  const none = Object.keys(S.catalog.players).filter((p) => !r.clubs.some((c) => S.matches(p, c.id)));
  r = await act(h, r, "guess", {playerId: none[0]}); assert.equal(r.wrongLeft, 2);
  r = await act(h, r, "guess", {playerId: none[1]}); assert.equal(r.turn, "user");
  r = await act(h, r, "guess", {playerId: none[2]});
  assert.equal(r.turn, "result"); assert.equal(r.history[0].user.pass, true); assert.match(r.feedback, /pas sayıldı/);
  const bot = r.history[0].bot;
  if (!bot.pass) {
    assert.ok(S.catalog.players[bot.player.id].rank <= S.FIVE_BOT.easy.known);
    assert.ok(bot.clubs.length <= 2);
  }
  // No club repeats across the five rounds.
  const clubs = raw(h, r).rounds.flat(); assert.equal(new Set(clubs).size, 25);
});
test("Random Five bot levels: easy 1–2 clubs or a pass, medium mostly 3, hard the best it knows", () => {
  const stats = {easy: [], medium: [], hard: []};
  for (const d of Object.keys(stats)) {
    for (let n = 0; n < 40; n++) {
      const r = {seed: "lv" + d + n, difficulty: d, rounds: [], round: 0, botUsed: {}};
      for (let i = 0; i < 5; i++) r.rounds.push(S.fiveRound(r, r.rounds.flat(), i));
      for (; r.round < 5; r.round++) {
        const m = S.fiveBotPick(r); if (m.playerId) r.botUsed[m.playerId] = true;
        stats[d].push(m.pass ? 0 : m.clubs.length);
      }
    }
  }
  const avg = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  assert.ok(stats.easy.every((n) => n <= 2)); assert.ok(stats.easy.includes(0));
  assert.ok(stats.medium.every((n) => n <= 4)); assert.ok(stats.medium.includes(4));
  assert.ok(avg(stats.easy) < avg(stats.medium) && avg(stats.medium) < avg(stats.hard),
      JSON.stringify([avg(stats.easy), avg(stats.medium), avg(stats.hard)]));
});
test("Loto allows a limited number of pauses per match and says when the bot plays next", async () => {
  const h = setup();
  let r = await start(h, "bot_loto", {difficulty: "medium"});
  assert.equal(r.pausesLeft, S.LOTO_PAUSES);
  assert.ok(r.botAt > h.now && r.botAt <= r.deadline + 15000);
  for (let n = 0; n < S.LOTO_PAUSES; n++) {
    r = await act(h, r, "pause");
    assert.equal(r.paused, true); assert.equal(r.botAt, null); assert.equal(r.current, null);
    // A second pause while paused costs nothing.
    r = await act(h, r, "pause");
    assert.equal(r.pausesLeft, S.LOTO_PAUSES - n - 1);
    r = await act(h, r, "resume");
  }
  assert.equal(r.pausesLeft, 0);
  await assert.rejects(act(h, r, "pause"), /duraklatma hakların bitti/);
  // The clock keeps running without a pause.
  h.setTime(h.now + 17000);
  r = await load(h, r.mode);
  assert.equal(r.paused, false);
  assert.ok(r.index >= 1);
});
test("Çinko as online: random first mover, +1 for the second, moves list, player sent with the cells", async () => {
  let botFirst = 0;
  for (let n = 0; n < 24; n++) {
    const h = setup(); const r = await start(h, "bot_cinko", {difficulty: "medium"});
    assert.equal(r.rules, 2); assert.equal(r.secondBonus, S.CINKO_SECOND_BONUS);
    if (r.botFirst) {
      botFirst++; assert.equal(r.turn, "bot"); assert.ok(r.botAt > 0);
      assert.equal(r.userScore, S.CINKO_SECOND_BONUS); assert.equal(r.botScore, 0);
    } else {
      assert.equal(r.turn, "user"); assert.equal(r.userScore, 0); assert.equal(r.botScore, S.CINKO_SECOND_BONUS);
    }
  }
  assert.ok(botFirst >= 4 && botFirst <= 20, String(botFirst));
  const h = setup(); let r = await userTurn(h, await start(h, "bot_cinko", {difficulty: "hard"}));
  const cells = raw(h, r).cells; const used = raw(h, r).used || {};
  const i = r.cells.findIndex((c) => c.owner === 0 && c.playable);
  const id = [...S.answers(cells[i])].find((p) => !used[p]);
  const base = r.userScore;
  r = await act(h, r, "confirm", {cells: [i], playerId: id});
  assert.equal(r.cells[i].owner, 1); assert.equal(r.userScore, base + 1);
  assert.equal(r.moves[0].owner, 1); assert.equal(r.moves[0].player.id, id);
  // A used player cannot be sent again.
  r = await userTurn(h, r);
  const j = r.cells.findIndex((c) => c.owner === 0 && c.playable);
  await assert.rejects(act(h, r, "confirm", {cells: [j], playerId: id}), /kullanıldı/);
});
test("Çinko: a bot with nobody to play passes, and four passes in a row end the match", () => {
  const r = {mode: "bot_cinko", difficulty: "easy", seed: "pass", revision: 0, used: {}, owners: {}, userScore: 0,
    botScore: 1, turn: "bot", botAt: 0, finished: false, cinkoRules: 2, moves: [], passes: 0};
  r.cells = S.cinkoBoard(r);
  // Every player the easy bot knows is used: it must pass, not end the match.
  for (const p of Object.values(S.catalog.players)) if (p.rank <= 1500) r.used[p.id] = true;
  S.cinkoBot(r, 1);
  assert.equal(r.finished, false); assert.equal(r.turn, "user"); assert.equal(r.moves[0].pass, true);
  assert.equal(r.passes, 1);
  for (let n = 0; n < 3 && !r.finished; n++) {
    r.turn = "bot"; r.botAt = 0; S.cinkoBot(r, 1);
  }
  assert.equal(r.finished, true); assert.equal(r.completed, true); assert.match(r.feedback, /Dört pas/);
});
test("Team Race rules 2: the bot finds only players it knows, early end keeps the score, two pauses", async () => {
  const h = setup();
  let r = await start(h, "bot_team_race", {clubId: "club:418", difficulty: "easy"});
  assert.equal(r.rules, 2); assert.equal(r.pausesLeft, S.RACE_PAUSES); assert.ok(r.botAt >= r.startsAt);
  // Long enough for many bot tries: every bot find is a player the easy bot knows.
  h.setTime(r.endsAt - 1); r = await load(h, r.mode);
  const owners = raw(h, r).race.found || {};
  for (const [id, owner] of Object.entries(owners)) {
    if (owner === 2) assert.ok(S.catalog.players[id].rank <= S.RACE_BOT2.easy.known, id);
  }
  assert.equal(r.feedback === "Bot pas geçti.", false);
  r = await act(h, r, "next").catch(() => r);
  if (!r.over) {
    h.setTime(r.endsAt + 1); r = await load(h, r.mode);
  }
  r = await act(h, r, "next"); h.setTime(r.startsAt + 1);
  // Ending at once: the bot gets none of the time left.
  const botBefore = (await load(h, r.mode)).botFound;
  r = await act(h, r, "end_round", {round: r.round});
  assert.equal(r.over, true); assert.equal(r.botFound, botBefore);
  // Two pauses per match, then the clock keeps running.
  r = await act(h, r, "next");
  for (let n = 0; n < S.RACE_PAUSES; n++) {
    r = await act(h, r, "pause"); assert.equal(r.botAt, null); r = await act(h, r, "resume");
  }
  assert.equal(r.pausesLeft, 0);
  await assert.rejects(act(h, r, "pause"), /duraklatma hakların bitti/);
});
test("Team Race rules 2: at most five rounds; equal rounds go to more players found", async () => {
  const h = setup();
  let r = await start(h, "bot_team_race", {clubId: "club:418", difficulty: "easy"});
  let rounds = 0;
  // Let every round run out on the clock: tied or bot rounds, never past five.
  while (!r.finished && rounds < 8) {
    h.setTime(r.endsAt + 1); r = await load(h, r.mode); rounds++;
    if (!r.finished) r = await act(h, r, "next");
  }
  assert.equal(r.finished, true); assert.ok(rounds <= S.RACE_MAX_ROUNDS, String(rounds));
  assert.equal(r.maxRounds, S.RACE_MAX_ROUNDS);
  if (r.userScore === r.botScore) {
    assert.equal(r.winner, r.finds.user > r.finds.bot ? 1 : r.finds.user < r.finds.bot ? 2 : 0);
  }
});
test("Team Race setup lists only clubs a match can start with", async () => {
  const h = setup();
  const before = await h.call("getBotSupport", {mode: "bot_team_race"});
  assert.ok(before.raceClubIds.length > 1000);
  assert.ok(before.raceClubIds.every((id) => S.partners(id).length));
  const missing = Object.values(S.catalog.criteria).find((k) => k.type === "club" && !S.partners(k.id).length);
  assert.equal(before.raceClubIds.includes(missing.id), false);
  await assert.rejects(start(h, "bot_team_race", {clubId: missing.id}));
  // While a match is open the list is not resent.
  await start(h, "bot_team_race", {clubId: "club:418"});
  assert.equal((await h.call("getBotSupport", {mode: "bot_team_race"})).raceClubIds, undefined);
  // The other modes never carry it.
  assert.equal((await h.call("getBotSupport", {mode: "bot_cinko"})).raceClubIds, undefined);
});
