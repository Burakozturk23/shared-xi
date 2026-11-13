"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const P = require("../price_config");
const B = require("../boosts");
const {harness} = require("./support/economy_harness");

const clone = (x) => JSON.parse(JSON.stringify(x));
const policy = {enabled: true, betaUids: {alice: true}, readyModes: Object.fromEntries(
    Object.keys(B.modes).map((m) => [m, true]))};
let n = 0; const id = () => "price_request_" + (++n).toString().padStart(8, "0");

test("defaults equal today's support prices and the flag starts off", () => {
  assert.equal(P.DEFAULT_PRICES.enabled, false);
  assert.equal(P.boostPrices(P.DEFAULT_PRICES), null);
  for (const offer of B.offers) {
    const p = P.defaults.boosts[offer.itemId];
    assert.equal(offer.priceCoins, offer.units > 1 ? p.pack : p.single, offer.offerId);
  }
  assert.deepEqual(Object.keys(P.defaults.boosts).sort(), [...new Set(B.offers.map((o) => o.itemId))].sort());
});

test("only a whole, sane price snapshot is accepted", () => {
  const on = clone(P.defaults); on.enabled = true;
  assert.equal(P.validatePrices(JSON.stringify(on)).enabled, true);
  for (const edit of [
    (v) => delete v.boosts.boost_basic,
    (v) => v.boosts.boost_new = {single: 1, pack: 2},
    (v) => v.boosts.boost_basic.single = 0,
    (v) => v.boosts.boost_basic.single = 2.5,
    (v) => v.boosts.boost_basic.pack = 75, // three singles: no pack discount
    (v) => v.boosts.boost_basic.pack = 25,
    (v) => v.enabled = "yes",
    (v) => v.schemaVersion = 2,
    (v) => v.extra = true,
  ]) {
    const v = clone(P.defaults); edit(v);
    assert.throws(() => P.validatePrices(v));
  }
});

test("offer prices follow the snapshot only while it is enabled", () => {
  const on = P.validatePrices({...clone(P.defaults), enabled: true,
    boosts: {...clone(P.defaults.boosts), boost_basic: {single: 20, pack: 50}}});
  const single = B.offers.find((o) => o.offerId === "boost_basic_1");
  const pack = B.offers.find((o) => o.offerId === "boost_basic_3");
  assert.equal(P.offerPrice(single, P.DEFAULT_PRICES), 25);
  assert.equal(P.offerPrice(single, on), 20);
  assert.equal(P.offerPrice(pack, on), 50);
  assert.equal(P.offerPrice({itemType: "avatar", itemId: "boost_basic", priceCoins: 300}, on), 300);
});

function setup() {
  return harness({runtimeConfig: {boosts: policy},
    economyState: {alice: {balances: {coins: 1000}}}}, {omitEmptyObjects: true});
}

test("flag off: catalog and purchase keep the boosts.js price", async () => {
  const h = setup();
  const offers = (await h.call("getStoreCatalog")).offers;
  assert.equal(offers.find((o) => o.offerId === "boost_basic_3").priceCoins, 65);
  await h.call("purchaseEconomyOffer", {offerId: "boost_basic_3", expectedPriceCoins: 65, requestId: id()});
  assert.equal(h.read("economyState/alice/balances/coins"), 935);
});

test("flag on: catalog shows the new price, purchase charges it and refuses the old quote", async () => {
  const h = setup();
  h.setPrices((v) => {
    v.enabled = true; v.boosts.boost_basic = {single: 20, pack: 50};
  });
  const offers = (await h.call("getStoreCatalog")).offers;
  assert.equal(offers.find((o) => o.offerId === "boost_basic_3").priceCoins, 50);
  assert.equal(offers.find((o) => o.offerId === "boost_strong_1").priceCoins, 60);
  await assert.rejects(h.call("purchaseEconomyOffer", {offerId: "boost_basic_3", expectedPriceCoins: 65,
    requestId: id()}), /Fiyat güncellendi/);
  assert.equal(h.read("economyState/alice/balances/coins"), 1000);
  await h.call("purchaseEconomyOffer", {offerId: "boost_basic_3", expectedPriceCoins: 50, requestId: id()});
  assert.equal(h.read("economyState/alice/balances/coins"), 950);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 3);
});

test("a broken price value falls back to the defaults, not to zero", async () => {
  const h = setup();
  h.setPrices((v) => {
    v.enabled = true; v.boosts.boost_basic = {single: -1, pack: 50};
  });
  const offers = (await h.call("getStoreCatalog")).offers;
  assert.equal(offers.find((o) => o.offerId === "boost_basic_1").priceCoins, 25);
});

test("in-game coin payment charges the price pinned when the run started", () => {
  const live = {...policy, prices: {...clone(P.defaults.boosts), boost_basic: {single: 20, pack: 50}}};
  const run = {id: "run-1", mode: "career", expiresAt: 10000};
  B.pin(run, live);
  assert.equal(run.boostPolicy.products.boost_basic.priceCoins, 20);
  const e = {balances: {coins: 100}, lifetimeSpent: 0, purchases: {}, storeUses: {}, inventory: {}};
  const input = {boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25, requestId: "r1"};
  assert.throws(() => B.consume(e, run, input, "boost_basic", "x", {text: "x"}, 1), /Fiyatı yenileyip/);
  B.consume(e, run, {...input, expectedPriceCoins: 20}, "boost_basic", "x", {text: "x"}, 1);
  assert.equal(e.balances.coins, 80);
  // A run pinned without live prices keeps the catalog price.
  const old = {id: "run-2", mode: "career", expiresAt: 10000};
  B.pin(old, policy);
  assert.equal(old.boostPolicy.products.boost_basic.priceCoins, 25);
});

test("publish plan: a valid new snapshot lists its changes; same revision or no change is refused", () => {
  const {plan} = require("../tools/prices_publish");
  const next = clone(P.defaults);
  next.revision = "prices-test-2"; next.enabled = true; next.boosts.boost_strong = {single: 50, pack: 130};
  const ok = plan(P.DEFAULT_PRICES, next);
  assert.deepEqual(ok.errors, []);
  assert.deepEqual(ok.changes, ["bayrak: kapalı → açık", "boost_strong tek: 60 → 50", "boost_strong 3'lü: 150 → 130"]);
  assert.ok(plan(null, {...next, revision: P.defaults.revision}).errors
      .some((e) => e.startsWith("revision değişmeli")));
  assert.ok(plan(P.DEFAULT_PRICES, {...clone(P.defaults), revision: "x-2"}).errors.includes("Değişiklik yok."));
  const bad = clone(next); bad.boosts.boost_basic.pack = 80;
  assert.ok(plan(P.DEFAULT_PRICES, bad).errors[0].startsWith("Geçersiz fiyat dosyası"));
});
