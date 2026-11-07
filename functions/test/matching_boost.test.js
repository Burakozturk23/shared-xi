"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const E = require("../arcade_engine");
let sequence = 80000;
const id = () => (++sequence).toString(16).padStart(32, "0");
const root = "economyState/alice";
const setup = () => harness({runtimeConfig: {arcade: {enabled: true, rewardsEnabled: true},
  boosts: {enabled: true, betaUids: {alice: true}, readyModes: {matching: true}}},
economyState: {alice: {balances: {coins: 1000}, inventory: {
  boost_strong: {itemType: "boost", quantity: 3},
}}}}, {omitEmptyObjects: true});
const raw = (h, s) => h.read(`${root}/arcade/sessions/${s.id}`);
const request = (s, extra = {}) => ({mode: "matching", sessionId: s.id, revision: s.revision,
  requestId: id(), ...extra});
const act = async (h, s, extra) => (await h.call("actArcade", request(s, extra))).session;
const hint = {action: "hint", boostId: "boost_strong", paymentSource: "coins", expectedPriceCoins: 60};
async function start(h, difficulty = "easy") {
  const s = (await h.call("prepareArcade", {mode: "matching", difficulty,
    version: E.catalog.version, requestId: id()})).session;
  return act(h, s, {action: "confirm"});
}
async function finish(h, session) {
  let s = session;
  const cards = raw(h, s).board.cards;
  for (let pair = 0; pair < s.board.count; pair++) {
    for (const c of cards.filter((x) => x.pair === pair)) s = await act(h, s, {action: "flip", cardId: c.id});
  }
  return s;
}
test("Matching suggestion charges once, preserves closed cards and survives reconnect", async () => {
  const h = setup(); const s = await start(h); const input = request(s, hint);
  const results = await Promise.all([h.call("actArcade", input), h.call("actArcade", input)]);
  assert.deepEqual(results[0].session.matchingHint, results[1].session.matchingHint);
  const helped = results[0].session;
  assert.equal(h.read(root + "/balances/coins"), 940);
  assert.equal(helped.hints, 1); assert.equal(helped.moves, 0); assert.equal(helped.correct, 0);
  assert.ok(helped.board.cards.every((c) => Object.keys(c).sort().join() === "id,visible"));
  const suggestion = helped.matchingHint.cards;
  assert.equal(suggestion.length, 2); assert.ok(helped.matchingHint.sources.length);
  const cards = raw(h, s).board.cards;
  const [player, club] = suggestion.map((c) => cards.find((x) => x.id === c.id));
  assert.equal(player.pair, club.pair);
  assert.ok(E.catalog.careers.find((c) => c.playerId === player.entityId).clubs.includes(club.entityId));
  suggestion.forEach((c) => assert.equal(cards[c.position - 1].id, c.id));
  assert.equal(helped.support.assisted, true); assert.equal(helped.support.products[0].ads, false);
  await assert.rejects(act(h, helped, hint), {code: "resource-exhausted"});
  const reopened = (await h.call("getArcade", {mode: "matching", reopen: true})).session;
  assert.deepEqual(reopened.matchingHint, helped.matchingHint);
  assert.equal(h.read(root + "/balances/coins"), 940);
});
test("Matching refuses unpaid, ad, stale and foreign-account hints; stock spends atomically", async () => {
  const h = setup(); const s = await start(h);
  for (const extra of [{paymentSource: null}, {paymentSource: "ad"}, {expectedPriceCoins: 25},
    {boostId: "boost_basic"}, {revision: s.revision + 1}]) {
    await assert.rejects(h.call("actArcade", {...request(s, hint), ...extra}));
    assert.equal(raw(h, s).matchingHint, undefined); assert.equal(h.read(root + "/balances/coins"), 1000);
  }
  await assert.rejects(h.call("actArcade", request(s, hint), {uid: "bob"}));
  const helped = await act(h, s, {...hint, paymentSource: "stock"});
  assert.equal(helped.hints, 1); assert.equal(h.read(root + "/inventory/boost_strong/quantity"), 2);
  assert.equal(h.read(root + "/balances/coins"), 1000);
});
test("Matching hint cannot skip an open card or use an unverified historical pair", async () => {
  const h = setup(); let s = await start(h);
  s = await act(h, s, {action: "flip", cardId: s.board.cards[0].id});
  await assert.rejects(act(h, s, hint), {code: "failed-precondition"});
  s = await act(h, s, {action: "pause"}); s = await act(h, s, {action: "resume"});
  const r = raw(h, s); const player = r.board.cards.find((c) => c.type === "player");
  r.board.cards.find((c) => c.type === "club" && c.pair === player.pair).entityId = "not-a-verified-club";
  h.seed(`${root}/arcade/sessions/${s.id}`, r);
  await assert.rejects(act(h, s, hint), {code: "unavailable"});
  assert.equal(h.read(root + "/balances/coins"), 1000); assert.equal(raw(h, s).hints, 0);
});
test("Matching assisted best moves cannot replace normal record or earn mastery twice", async () => {
  const h = setup(); let s = await start(h, "hard");
  s = await act(h, s, hint); s = await finish(h, s);
  const record = `matching__hard__${E.catalog.version}`;
  assert.equal(h.read(`${root}/arcade/records/${record}`), null);
  assert.equal(h.read(`${root}/arcade/records/${record}__assisted/bestMoves`), 12);
  assert.equal(h.read(`${root}/arcade/records/${record}__assisted/assisted`), true);
  assert.equal(h.read(`${root}/arcade/claims/matching:v1:master`), null);
  assert.equal(s.earnedCoins, 2);
  const next = await finish(h, await start(h, "hard"));
  assert.equal(h.read(`${root}/arcade/records/${record}/bestMoves`), 12);
  assert.equal(h.read(`${root}/arcade/records/${record}/assisted`), false);
  assert.equal(next.earnedCoins, 3); // Only mastery: the hard first-clear receipt was already paid.
  const data = await h.call("getArcade", {mode: "matching"});
  assert.ok(data.recent.some((r) => r.assisted)); assert.ok(data.recent.some((r) => !r.assisted));
});
test("Matching existing sessions retain their original rules when pilot is enabled", async () => {
  const h = setup(); h.seed("runtimeConfig/boosts/enabled", false);
  const old = await start(h); assert.equal(old.support, undefined);
  h.seed("runtimeConfig/boosts/enabled", true);
  await assert.rejects(act(h, old, hint), {code: "failed-precondition"});
  assert.equal(h.read(root + "/balances/coins"), 1000);
  const completed = await finish(h, old); assert.equal(completed.won, true);
  assert.equal(completed.matchingHint, undefined);
});
