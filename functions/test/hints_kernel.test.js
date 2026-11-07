"use strict";
// İpucu sistemi v2 kernel: pin, view, use, ads, legacy conversion.
const test = require("node:test");
const assert = require("node:assert/strict");
const H = require("../hints");

const T = 1000000;
const fake = {
  modes: ["fake_mode"],
  catalog: {fake_mode: [{id: "a", label: "Milliyet", type: "milliyet"}, {id: "b", label: "Bir ligi", type: "kulup"},
    {id: "c", label: "İlk harf", type: "isim"}]},
  board: (run) => run.boardId,
  items(run) {
    return this.catalog.fake_mode.filter((i) => !(i.id === "b" && run.noB))
        .map((i) => ({...i, why: "neden " + i.id}));
  },
  reveal(run, id) {
    if (id === "b" && run.noB) throw new Error("unproducible");
    return {text: "metin " + id + " " + run.boardId};
  },
};
H.register(fake);
const policy = (extra = {}) => ({enabled: true, version: 2, readyModes: {fake_mode: true}, ...extra});
const wallet = (inventory = {}, coins = 1000) => ({balances: {coins}, inventory: Object.fromEntries(
    Object.entries(inventory).map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}])),
storeUses: {}, purchases: {}, lifetimeSpent: 0});
function pinned(extra = {}) {
  const run = {id: "run1", mode: "fake_mode", boardId: "b1", expiresAt: T + 3600000, adGranted: 0, ...extra};
  assert.equal(H.pin(run, policy(), null, T), true);
  return run;
}
const use = (e, run, itemId, paymentSource = "stock", extra = {}) =>
  H.use(e, run, fake, {itemId, paymentSource, requestId: "req_" + itemId, ...extra}, T + 1);
const credit = (run, itemId, id) =>
  H.grantAd(run, {id, context: H.adBenefit(run, itemId, {amount: 0, context: {}}).context});

test("use spends stock of the item type, reveals, marks Yardımlı", () => {
  const e = wallet({hint_milliyet: 2}); const run = pinned();
  assert.deepEqual(use(e, run, "a"), {itemId: "a", text: "metin a b1"});
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
  assert.equal(run.assisted, true);
  assert.equal(run.masteryEligible, false);
  assert.equal(run.leaderboardEligible, false);
  assert.equal(run.hintUses.b1.a.text, "metin a b1");
});

test("same item twice on one board is refused and charges nothing; a new board allows it", () => {
  const e = wallet({hint_milliyet: 3}); const run = pinned();
  use(e, run, "a");
  assert.throws(() => use(e, run, "a"), {code: "already-exists"});
  assert.equal(e.inventory.hint_milliyet.quantity, 2);
  run.boardId = "b2";
  assert.equal(use(e, run, "a").text, "metin a b2");
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
});

test("different item on the same board is allowed", () => {
  const e = wallet({hint_milliyet: 1, hint_kulup: 1}); const run = pinned();
  use(e, run, "a");
  use(e, run, "b");
  assert.deepEqual(Object.keys(run.hintUses.b1).sort(), ["a", "b"]);
});

test("unproducible item is absent from view and refused by use", () => {
  const e = wallet({hint_kulup: 1}); const run = pinned({noB: true});
  assert.deepEqual(H.view(run, fake).items.map((i) => i.id), ["a", "c"]);
  assert.throws(() => use(e, run, "b"), {code: "failed-precondition"});
  assert.equal(e.inventory.hint_kulup.quantity, 1);
});

test("finished or expired run: nothing is charged", () => {
  const e = wallet({hint_milliyet: 1});
  assert.throws(() => use(e, pinned({finished: true}), "a"), {code: "failed-precondition"});
  assert.throws(() => use(e, pinned({expiresAt: T}), "a"), {code: "failed-precondition"});
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
});

test("joker pays for any item only when the player picks joker", () => {
  const e = wallet({hint_isim: 0, hint_joker: 1}); const run = pinned();
  assert.throws(() => use(e, run, "c"), {code: "resource-exhausted"});
  assert.equal(use(e, run, "c", "joker").text, "metin c b1");
  assert.equal(e.inventory.hint_joker.quantity, 0);
  assert.throws(() => use(e, run, "a", "joker"), {code: "resource-exhausted"});
});

test("coins: exact quoted price only", () => {
  const e = wallet({}, 100); const run = pinned();
  assert.throws(() => use(e, run, "a", "coins", {expectedPriceCoins: 30}), {code: "failed-precondition"});
  assert.equal(e.balances.coins, 100);
  use(e, run, "a", "coins", {expectedPriceCoins: 25});
  assert.equal(e.balances.coins, 75);
  use(e, run, "c", "coins", {expectedPriceCoins: 50});
  assert.equal(e.balances.coins, 25);
  assert.equal(e.lifetimeSpent, 75);
  assert.deepEqual(Object.values(e.purchases).map((p) => [p.itemId, p.priceCoins]),
      [["hint_milliyet", 25], ["hint_isim", 50]]);
  const poor = wallet({}, 10);
  assert.throws(() => use(poor, pinned(), "a", "coins", {expectedPriceCoins: 25}), {code: "resource-exhausted"});
  assert.equal(poor.balances.coins, 10);
});

test("ad credits: light needs 1, strong needs 2; an adapter can disable ads", () => {
  const e = wallet(); const run = pinned();
  assert.throws(() => use(e, run, "a", "ad"), {code: "resource-exhausted"});
  const benefit = H.adBenefit(run, "a", {amount: 0, context: {sessionId: run.id}});
  assert.equal(benefit.requireVerifiedAd, true);
  assert.equal(benefit.context.itemId, "a");
  assert.equal(benefit.context.sessionId, run.id);
  H.grantAd(run, {id: "ad1", context: benefit.context});
  assert.equal(use(e, run, "a", "ad").text, "metin a b1");
  assert.equal(H.view(run, fake).ads.remaining, 1);

  const strong = pinned({id: "run2"});
  credit(strong, "c", "ad2");
  assert.throws(() => use(e, strong, "c", "ad"), {code: "resource-exhausted"});
  credit(strong, "c", "ad3");
  assert.equal(use(e, strong, "c", "ad").text, "metin c b1");
  assert.throws(() => H.adBenefit(strong, "a", {amount: 0, context: {}}), {code: "resource-exhausted"});

  const noAds = pinned({id: "run3"});
  noAds.hintPolicy.ads = false;
  assert.equal(H.view(noAds, fake).ads.allowed, false);
  assert.throws(() => H.adBenefit(noAds, "a", {amount: 0, context: {}}), {code: "permission-denied"});

  const daily = {id: "run4", mode: "fake_mode", entry: "daily", boardId: "b1", expiresAt: T + 9e6, adGranted: 0};
  H.pin(daily, policy(), null, T);
  assert.equal(H.view(daily, fake).ads.remaining, 1);
});

test("suggested is first unused producible light and strong, in adapter order", () => {
  const e = wallet({hint_milliyet: 1}); const run = pinned();
  assert.deepEqual(H.view(run, fake).suggested, ["a", "c"]);
  use(e, run, "a");
  const v = H.view(run, fake);
  assert.deepEqual(v.suggested, ["b", "c"]);
  assert.deepEqual(v.items.find((i) => i.id === "a"), {id: "a", label: "Milliyet", type: "milliyet",
    strong: false, price: 25, used: true, result: "metin a b1", why: "neden a"});
  assert.equal(v.items.find((i) => i.id === "c").price, 50);
  assert.equal(v.version, 2);
  assert.equal(v.board, "b1");
  assert.equal(v.assisted, true);
});

test("late verified ad becomes stock of its type; at 99 it stays pending", () => {
  const run = pinned();
  const ctx = H.adBenefit(run, "a", {amount: 0, context: {}}).context;
  run.finished = true;
  const e = wallet();
  assert.equal(H.recoverAd(e, run, {id: "late1", context: ctx}, T + 5, true), true);
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
  assert.equal(H.recoverAd(e, run, {id: "late1", context: ctx}, T + 6, true), true); // a retry pays once
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
  const full = wallet({hint_milliyet: 99});
  assert.throws(() => H.recoverAd(full, run, {id: "late2", context: ctx}, T + 5, true),
      {code: "resource-exhausted"});
  // An open run that can still apply it: not recovered here.
  const live = pinned({id: "run6"});
  const liveCtx = H.adBenefit(live, "a", {amount: 0, context: {}}).context;
  assert.equal(H.recoverAd(wallet(), live, {id: "ad7", context: liveCtx}, T + 5, true), false);
  // An unused credit returns to stock when the board changes.
  const open = pinned({id: "run5"});
  credit(open, "a", "ad9");
  const w = wallet();
  open.boardId = "b2";
  H.recoverUnused(w, open, T + 7);
  assert.equal(w.inventory.hint_milliyet.quantity, 1);
  assert.throws(() => use(w, open, "a", "ad"), {code: "resource-exhausted"});
  // Not a v2 receipt: not handled here.
  assert.equal(H.recoverAd(wallet(), run, {id: "v1", context: {boostPolicyVersion: 1}}, T, true), false);
});

test("legacy conversion maps each old item once", () => {
  const e = wallet({boost_basic: 2, boost_eliminate: 1, boost_connection: 1, boost_strong: 1,
    boost_first_letter: 1, boost_last_letter: 2, boost_anagram: 1, hint_milliyet: 98});
  const r = H.convertLegacy(e, T);
  assert.deepEqual({...r.gained}, {hint_milliyet: 1, hint_ele: 1, hint_baglanti: 1, hint_isim: 3, hint_harf: 2});
  assert.equal(r.added, 8);
  assert.equal(e.inventory.hint_milliyet.quantity, 99);
  assert.equal(e.inventory.boost_basic.quantity, 1); // over the cap: stays as it was
  assert.equal(e.inventory.hint_isim.quantity, 3);
  assert.equal(H.convertLegacy(e, T + 1).added, 0);
  const withStock = wallet({boost_basic: 1});
  H.pin({id: "x", mode: "fake_mode", expiresAt: T + 9e6}, policy(), withStock, T);
  assert.equal(withStock.inventory.hint_milliyet.quantity, 1);
});

test("pin: only v2 policy and a ready mode", () => {
  assert.equal(H.pin({id: "y", mode: "fake_mode"}, {enabled: true, readyModes: {fake_mode: true}}, null, T), false);
  assert.equal(H.pin({id: "y", mode: "other"}, policy(), null, T), false);
  assert.equal(H.pin({id: "y", mode: "fake_mode"}, null, null, T), false);
  const r = pinned();
  assert.equal(H.active(r), true);
  assert.equal(H.active({}), false);
});

test("paymentFingerprint covers item, source and quote", () => {
  assert.deepEqual(H.paymentFingerprint({itemId: "a", paymentSource: "coins", expectedPriceCoins: 25}),
      ["a", "coins", 25]);
  assert.deepEqual(H.paymentFingerprint({}), [null, null, null]);
});
