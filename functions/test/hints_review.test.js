"use strict";
// Final-review findings for İpucu v2 (each test failed before its fix).
const {test} = require("node:test");
const assert = require("node:assert/strict");
const H = require("../hints");
const {harness} = require("./support/economy_harness");

const T = 1000000;
H.register({
  modes: ["review_mode"],
  catalog: {review_mode: [{id: "a", label: "Milliyet", type: "milliyet"}, {id: "c", label: "İlk harf", type: "isim"}]},
  board: (run) => run.boardId,
  items() {
    return this.catalog.review_mode;
  },
  reveal: (run, id) => ({text: "metin " + id}),
});
const policy = {enabled: true, version: 2, readyModes: {review_mode: true}};
const wallet = (inventory = {}) => ({balances: {coins: 1000}, inventory: Object.fromEntries(
    Object.entries(inventory).map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}])),
storeUses: {}, purchases: {}, lifetimeSpent: 0});
const run = (extra = {}) => {
  const r = {id: "r1", mode: "review_mode", boardId: "b1", expiresAt: T + 9e6, adGranted: 0, ...extra};
  H.pin(r, policy, null, T); return r;
};

test("#3 a strong item is not offered an ad the run cannot complete", () => {
  const daily = run({entry: "daily"});
  assert.throws(() => H.adBenefit(daily, "c", {amount: 0, context: {}}), {code: "resource-exhausted"});
  assert.ok(H.adBenefit(daily, "a", {amount: 0, context: {}}).requireVerifiedAd);
  const open = run({adGranted: 1});
  assert.throws(() => H.adBenefit(open, "c", {amount: 0, context: {}}), {code: "resource-exhausted"});
  // A credit already started may be completed.
  const started = run();
  H.grantAd(started, {id: "x1", context: H.adBenefit(started, "c", {amount: 0, context: {}}).context});
  assert.ok(H.adBenefit(started, "c", {amount: 0, context: {}}).requireVerifiedAd);
});

test("#3 a half strong credit never becomes a whole strong unit", () => {
  const r = run();
  H.grantAd(r, {id: "x2", context: H.adBenefit(r, "c", {amount: 0, context: {}}).context});
  const e = wallet(); r.boardId = "b2"; H.recoverUnused(e, r, T + 1);
  assert.equal(e.inventory.hint_isim, undefined);
  assert.equal(H.pending(r), true);
  const light = run({id: "r2"});
  H.grantAd(light, {id: "x3", context: H.adBenefit(light, "a", {amount: 0, context: {}}).context});
  const w = wallet(); light.boardId = "b2"; H.recoverUnused(w, light, T + 1);
  assert.equal(w.inventory.hint_milliyet.quantity, 1);
  assert.equal(H.pending(light), false);
});

test("#7 story: eliminating the only wrong option is not offered", () => {
  const story = require("../hints/story_choice").story();
  const r = {hintTarget: "t1"};
  const one = {id: "t1", options: [{id: "a", label: "A"}, {id: "b", label: "B"}, {id: "c", label: "C"},
    {id: "d", label: "D"}], answerKeys: ["a", "b", "c"]};
  assert.equal(story.items(r, {task: one}).some((i) => i.id === "bir_yanlis"), false);
  const two = {...one, answerKeys: ["a", "b"]};
  assert.equal(story.items(r, {task: two}).some((i) => i.id === "bir_yanlis"), true);
});

test("#9 an open v1 run keeps its old stock until it ends", () => {
  const e = wallet({boost_basic: 2});
  e.careerTransfer = {sessions: {old: {id: "old", boostPolicy: {version: 1}, finished: false, expiresAt: T + 9e6}}};
  H.pin({id: "n", mode: "review_mode", expiresAt: T + 9e6}, policy, e, T);
  assert.equal(e.inventory.boost_basic.quantity, 2);
  e.careerTransfer.sessions.old.finished = true;
  H.pin({id: "n2", mode: "review_mode", expiresAt: T + 9e6}, policy, e, T);
  assert.equal(e.inventory.hint_milliyet.quantity, 2);
});

test("#10 a session holding a v2 ad credit is kept by pruning", () => {
  assert.equal(H.pending({hintAdCredits: {a: {n: 1}}}), true);
  assert.equal(H.pending({hintAdCredits: {}}), false);
  assert.equal(H.pending({}), false);
});

test("#6 v2 Sahte Kulüp closes the free 50/50 and trace", async () => {
  const fc = require("../fake_club").catalog;
  const h = harness({runtimeConfig: {boosts: {enabled: true, version: 2, betaUids: {alice: true},
    readyModes: {fake_endless: true}}, fakeClub: {dataEnabled: true, soloEnabled: true}},
  economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
  const s = (await h.call("startFakeClub", {mode: "fake_endless", version: fc.version,
    requestId: "a".repeat(32)})).session;
  for (const action of ["fifty", "trace"]) {
    await assert.rejects(h.call("actFakeClub", {mode: s.mode, version: fc.version, sessionId: s.id,
      questionId: s.question.questionId, revision: s.revision, requestId: (action === "fifty" ? "b" : "c").repeat(32),
      action}), {code: "failed-precondition"});
  }
});

test("#11 after a rollback, rewards follow the live flag, not the wallet marker", () => {
  const dailyReturn = require("../daily_return");
  const e = {inventory: {}, storeUses: {}, balances: {coins: 0}, hintsVersion: 2};
  H.markWallet(e, false);
  dailyReturn.grantSupport(e, "k1", "boost_basic", "daily_reward", "d1", 1);
  assert.equal(e.inventory.boost_basic.quantity, 1);
  H.markWallet(e, true);
  dailyReturn.grantSupport(e, "k2", "boost_basic", "daily_reward", "d2", 1);
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
});

test("#8 Grid does not sell what the row or column already says", () => {
  const grid = require("../hints/grid").make({
    catalog: {players: {p1: {rank: 1, countries: ["Fransa"], position: "ATT", clubs: ["1"], name: "Ali"}},
      clubs: {1: {name: "X", league: "L", rank: 1}}, criteria: {}},
    kind: () => "classic", answers: () => ["p1"], common: () => [], axisIds: () => [], matches: () => false,
    targetKey: () => "cell_0"});
  const ids = (rows, cols) => grid.items({mode: "solo_grid_classic", id: "g", rows, cols}, {target: 0})
      .map((i) => i.id);
  assert.ok(!ids({0: "country:fransa"}, {0: "club:2"}).includes("milliyet"));
  assert.ok(!ids({0: "club:2"}, {0: "position:ATT"}).includes("mevki"));
  assert.ok(ids({0: "club:2"}, {0: "club:3"}).includes("milliyet"));
});
