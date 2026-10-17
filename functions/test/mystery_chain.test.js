"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../mystery_chain");
const {graphOf, shortest, validMove, remaining} = require("../mystery_chain_graph");
const {players} = require("../career_transfer");
const version = catalog.version;
const graph = graphOf(catalog);
let seq = 0;
const id = () => (++seq).toString(16).padStart(32, "0");
const start = async (h, mode, extra = {}) => (await h.call("startMysteryChain",
    {mode, version, requestId: id(), ...extra})).session;
const act = async (h, s, extra) => (await h.call("actMysteryChain", {mode: s.mode, version, requestId: id(),
  sessionId: s.id, revision: s.revision, ...extra})).session;
const raw = (h, s) => h.read(`economyState/alice/mysteryChain/sessions/${s.id}`);
async function solve(h, s) {
  const r = raw(h, s);
  if (s.mode === "mystery") return act(h, s, {action: "guess", playerId: r.puzzle.playerId});
  const route = remaining(graph, {...r, path: r.path || []});
  assert.ok(route?.length);
  for (const step of route) s = await act(h, s, {action: "move", ...step});
  return s;
}
test("M01-M03: complete unique clues, plausible options and exact dated teammate overlap", () => {
  const ct = require("../config/career_transfer_catalog.json");
  for (const p of catalog.mystery) {
    assert.ok(p.country && p.position && p.options.length >= 4);
    assert.equal(new Set(p.hints.map((h) => h.id)).size, 5);
    assert.ok(p.hints.every((h) => h.text && !/Bilinmiyor|Piyasa değeri|veri dönemi sınırlı/.test(h.text)));
    for (const id of p.options) {
      assert.equal(players.get(id).country, p.country);
      if (id !== p.playerId) assert.ok(!players.get(id).clubs.includes(p.onlineClubId));
      assert.equal(players.get(id).position, players.get(p.playerId).position);
    }
    const mate = p.hints[3]; if (mate.id !== "teammate") continue;
    const a = ct.careers.find((x) => x.playerId === p.playerId);
    const b = ct.careers.find((x) => x.playerId === mate.playerId);
    assert.ok(a.stops.some((x) => x.clubId === mate.clubId && x.precision === "date" &&
      b.stops.some((y) => y.clubId === mate.clubId && y.precision === "date" && x.end && y.end &&
        x.start <= mate.start && y.start <= mate.start && x.end >= mate.end && y.end >= mate.end)));
    assert.ok(mate.start < mate.end);
  }
});
test("C01-C03: every catalog PAR is exact; every supplied route obeys unique players and clubs", () => {
  for (const p of [...catalog.mastery, ...catalog.sprint]) {
    assert.equal(shortest(graph, p.start, p.target).length, p.par);
    const r = {puzzle: p, path: []};
    for (const step of p.solution) {
      assert.ok(validMove(graph, r, step.playerId, step.clubId)); r.path.push(step);
    }
    assert.equal(r.path.at(-1).clubId, p.target);
  }
  const tiny = graphOf({graph: [{id: 1, clubs: [1, 2, 3]}, {id: 2, clubs: [3, 4]}]});
  assert.equal(shortest(tiny, 1, 999), null);
  assert.equal(shortest(tiny, 1, 4, [], [1]), null);
  assert.equal(shortest(tiny, 1, 4).length, 2);
});
test("M04-M06: automatic facts are distinct; invalid and repeated guesses do not consume attempts", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let s = await start(h, "mystery");
  assert.equal(s.initial.length, 2); assert.equal(s.player, undefined);
  assert.equal((await h.call("getMysteryChain", {mode: "mystery"})).collection.length, 0);
  await assert.rejects(act(h, s, {action: "guess", answer: "unrecognized"}), {code: "invalid-argument"});
  const p = raw(h, s).puzzle;
  const wrong = [...players.keys()].filter((x) => x !== p.playerId).slice(0, 2);
  s = await act(h, s, {action: "guess", playerId: wrong[0]});
  assert.equal(s.wrong, 1); assert.equal(s.hints[0].id, "period");
  await assert.rejects(act(h, s, {action: "guess", playerId: wrong[0]}), {code: "already-exists"});
  s = await act(h, s, {action: "hint"}); s = await act(h, s, {action: "guess", playerId: wrong[1]});
  assert.equal(new Set(s.hints.map((x) => x.id)).size, 3); assert.equal(s.optionalHints, 1);
  s = await solve(h, s); assert.equal(s.result.coins, 2); assert.equal(s.result.medal, 1);
});
test("M07-M09: atomic energy, persisted account ownership, first failure freezes economy", async () => {
  const h = harness({runtimeConfig: {energy: {enabled: true, percent: 100, sessionModes: ["mystery", "chain"]}}},
      {omitEmptyObjects: true});
  const req = {mode: "mystery", version, requestId: id()};
  const [a, b] = await Promise.all([h.call("startMysteryChain", req), h.call("startMysteryChain", req)]);
  assert.equal(a.session.id, b.session.id); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("getEnergyStatus"); let s = (await h.call("getMysteryChain", {mode: "mystery"})).session;
  const target = raw(h, s).puzzle.id;
  await assert.rejects(h.call("actMysteryChain", {mode: "mystery", version, requestId: id(), sessionId: s.id,
    revision: 0, action: "skip"}, {uid: "bob"}), {code: "not-found"});
  await act(h, s, {action: "skip"});
  s = await solve(h, await start(h, "mystery", {target}));
  assert.equal(s.result.coins, 0); assert.equal(s.result.medal, 4);
  assert.equal((await h.call("getMysteryChain", {mode: "mystery"})).collection[0].firstResult.medal, 0);
});
test("M08: first answer without optional clues earns 6/12 once, expired attempt cannot regain reward", async () => {
  const h = harness(); let s = await solve(h, await start(h, "mystery"));
  assert.equal(s.result.coins, 6); assert.equal(h.read("progressionState/alice/lifetimeXp"), 12);
  s = await start(h, "mystery"); const target = raw(h, s).puzzle.id;
  h.setTime(h.now + 86400001); await h.call("getMysteryChain", {mode: "mystery"});
  s = await solve(h, await start(h, "mystery", {target})); assert.equal(s.result.coins, 0);
});
test("C04-C06: exact PAR earns mastery; undo keeps gold but removes mastery; hints are usable paths", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let s = await start(h, "mastermind");
  assert.equal(s.maxMoves, Math.min(s.par + 3, 8));
  const target = raw(h, s).puzzle.id;
  s = await solve(h, s); assert.equal(s.result.coins, 12); assert.equal(s.result.medal, 4);
  s = await solve(h, await start(h, "mastermind", {target})); assert.equal(s.result.coins, 0);
  s = await start(h, "mastermind"); const first = raw(h, s).puzzle.solution[0];
  s = await act(h, s, {action: "move", ...first});
  await assert.rejects(act(h, s, {action: "move", ...first}), {code: "invalid-argument"});
  s = await act(h, s, {action: "undo"}); s = await solve(h, s);
  assert.equal(s.result.medal, 3); assert.equal(s.result.coins, 8);
  s = await start(h, "mastermind"); s = await act(h, s, {action: "hint"});
  const hint = s.bridgeHint; assert.ok(validMove(graph, raw(h, s), hint.playerId, hint.clubId));
  await assert.rejects(act(h, s, {action: "hint"}), {code: "failed-precondition"});
  s = await act(h, s, {action: "move", playerId: hint.playerId, clubId: hint.clubId}); assert.equal(s.bridgeHint, null);
  s = await act(h, s, {action: "undo"}); assert.equal(s.bridgeHint, null);
});
test("C05: every offered first bridge reaches the target within remaining legal moves", () => {
  for (const p of catalog.mastery) {
    const r = {puzzle: p, path: [], maxMoves: Math.min(p.par + 3, 8)};
    const steps = remaining(graph, r); assert.ok(steps?.length);
    for (const step of steps) {
      assert.ok(validMove(graph, r, step.playerId, step.clubId)); r.path.push(step);
    }
    assert.equal(r.path.at(-1).clubId, p.target);
  }
});
test("C07-C09: one sprint energy, continuous clock, 75s cap, one -10 skip and hard 180s expiry", async () => {
  const h = harness({runtimeConfig: {energy: {enabled: true, percent: 100, sessionModes: ["chain"]}}});
  let s = await start(h, "blitz"); const began = h.now;
  assert.equal(s.endAt, began + 60000);
  for (let i = 0; i < 4; i++) s = await solve(h, s);
  assert.equal(s.endAt, began + 75000); assert.equal(s.chains, 4); assert.equal(s.score, 500);
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await assert.rejects(act(h, s, {action: "hint"}), {code: "failed-precondition"});
  s = await act(h, s, {action: "skip"}); assert.equal(s.endAt, began + 65000); assert.equal(s.streak, 0);
  await assert.rejects(act(h, s, {action: "skip"}), {code: "resource-exhausted"});
  for (let i = 0; i < 25; i++) {
    h.setTime(began + i * 4500); s = await solve(h, s);
  }
  assert.ok(s.endAt <= began + 180000);
  h.setTime(began + 180000);
  s = (await h.call("getMysteryChain", {mode: "blitz"})).session;
  assert.equal(s.finished, true); assert.equal(s.result.medal, 3);
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
});
test("C10: daily sprint thresholds pay only delta, Istanbul midnight opens next day", async () => {
  const h = harness(); h.setTime("2026-10-17T20:50:00Z");
  let s = await start(h, "blitz"); for (let i = 0; i < 2; i++) s = await solve(h, s);
  s = await act(h, s, {action: "finish"}); assert.equal(s.result.coins, 4);
  s = await start(h, "blitz"); for (let i = 0; i < 3; i++) s = await solve(h, s);
  s = await act(h, s, {action: "finish"}); assert.equal(s.result.coins, 2);
  s = await start(h, "blitz"); for (let i = 0; i < 3; i++) s = await solve(h, s);
  s = await act(h, s, {action: "finish"}); assert.equal(s.result.coins, 0);
  h.setTime("2026-10-17T21:00:01Z"); s = await solve(h, await start(h, "blitz"));
  s = await act(h, s, {action: "finish"}); assert.equal(s.result.coins, 2);
});
test("shared 24/48 FIFO budget and interrupted XP outbox repair never duplicate coins", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  await solve(h, await start(h, "mastermind")); await solve(h, await start(h, "mastermind"));
  const s = await start(h, "mystery"); await solve(h, s);
  assert.equal(h.read("economyState/alice/balances/coins"), 24);
  assert.equal((await h.call("getMysteryChain", {mode: "mystery"})).pendingCoins, 6);
  h.setTime(h.now + 86400000); h.failNext("progressionProfiles/alice");
  await assert.rejects(h.call("getMysteryChain", {mode: "mystery"}), /Simulated interrupted write/);
  await h.call("getMysteryChain", {mode: "mastermind"});
  assert.equal(h.read("economyState/alice/balances/coins"), 30);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 60);
});
test("C13: archived graph version preserves active PAR, edges and reward identity", async () => {
  const h = harness(); let s = await start(h, "mastermind"); const before = raw(h, s);
  const old = {...catalog, version: "mc-old"};
  await h.db.ref("mysteryChainCatalogs/mc-old").set(old);
  await h.db.ref(`economyState/alice/mysteryChain/sessions/${s.id}/graphVersion`).set("mc-old");
  s = await solve(h, s); assert.equal(s.graphVersion, "mc-old"); assert.equal(s.par, before.puzzle.par);
  assert.equal(s.result.coins, 12);
  s = await solve(h, await start(h, "mastermind", {target: before.puzzle.id})); assert.equal(s.result.coins, 0);
});
test("invalidated data is removed and charged energy is compensated exactly once", async () => {
  const h = harness({runtimeConfig: {energy: {enabled: true, percent: 100, sessionModes: ["mystery"]}}});
  const s = await start(h, "mystery"); const p = raw(h, s).puzzle;
  await h.db.ref("runtimeConfig/mysteryChain/disabledFiles").set([`mystery__${p.playerId}`]);
  await h.call("getMysteryChain", {mode: "mystery"}); await h.call("getMysteryChain", {mode: "mystery"});
  assert.equal(h.read("economyState/alice/energy/balance"), 6); assert.equal(raw(h, s).voided, true);
  assert.notEqual(raw(h, await start(h, "mystery")).puzzle.playerId, p.playerId);
});
test("M05: verified SSV grants at most two credits; replay, cancellation and Sprint cannot mint hints", async () => {
  const h = harness({}, {omitEmptyObjects: true}); const service = h.context.lbMysteryChainService();
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const ads = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults, units: {android: unit},
    isLinked: async () => false, isPro: async () => false,
    prepareThreeReward: service.prepareHint, settleThreeReward: service.settleHint,
    grantCoins: async () => assert.fail("Hint cannot mint coins"),
  });
  let s = await start(h, "mystery");
  const prepare = () => ads.prepare("alice", "android", "mystery_hint", id(), {sessionId: s.id});
  const event = (t) => ({user_id: "alice", custom_data: t.id, ad_unit: unit, timestamp: h.now,
    transaction_id: id(), reward_amount: "999999"});
  let {ticket} = await prepare(); await ads.cancel("alice", ticket.id);
  await assert.rejects(ads.accept(event(ticket)), {code: "permission-denied"});
  assert.equal(raw(h, s).adCredits, 0);
  for (let i = 0; i < 2; i++) {
    h.setTime(h.now + 31000); ({ticket} = await prepare()); const e = event(ticket);
    await ads.accept(e); await ads.accept(e);
  }
  s = await act(h, s, {action: "hint"}); s = await act(h, s, {action: "hint"});
  s = await act(h, s, {action: "hint"}); assert.equal(s.optionalHints, 3); assert.equal(s.adCredits, 0);
  await assert.rejects(prepare(), {code: "failed-precondition"});
  await assert.rejects(act(h, s, {action: "hint"}), {code: "failed-precondition"});
  const sprint = await start(h, "blitz");
  await assert.rejects(service.prepareHint("alice", "chain_hint", {sessionId: sprint.id}),
      {code: "failed-precondition"});
});
test("M08: concurrent answer retries pay once and reject changed payloads or stale revision", async () => {
  const h = harness(); let s = await start(h, "mystery");
  const req = {mode: s.mode, version, requestId: id(), sessionId: s.id, revision: s.revision,
    action: "guess", playerId: raw(h, s).puzzle.playerId};
  await Promise.all([h.call("actMysteryChain", req), h.call("actMysteryChain", req)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  await assert.rejects(h.call("actMysteryChain", {...req, action: "skip"}), {code: "invalid-argument"});
  s = await start(h, "mastermind"); await act(h, s, {action: "hint"});
  await assert.rejects(act(h, s, {action: "skip"}), {code: "aborted"});
});
