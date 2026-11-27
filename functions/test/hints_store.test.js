"use strict";
// İpucu v2 store, game guide, legacy conversion and rewards.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const HI = require("../hints/index");
const B = require("../boosts");
let seq = 115000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
const all = Object.fromEntries(Object.keys(B.modes).map((m) => [m, true]));
const v2 = {enabled: true, version: 2, betaUids: {alice: true}, readyModes: all};
const setup = (extra = {}, inventory = {}) => harness({runtimeConfig: {boosts: v2, ...extra},
  economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
      .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const qty = (h, key) => h.read(`${root}/inventory/${key}/quantity`) || 0;
const buy = (h, offerId, price) => h.call("purchaseEconomyOffer", {offerId,
  requestId: "hint_request_" + id().slice(0, 12), expectedPriceCoins: price});

test("every mode's static menu matches its adapter types, and every type works somewhere", () => {
  const menus = HI.menus();
  assert.deepEqual(Object.keys(menus).sort(), Object.keys(B.modes).sort());
  for (const type of ["milliyet", "mevki", "kulup", "donem", "harf", "ele", "isim", "baglanti", "aday"]) {
    assert.ok(HI.modesFor(type).length > 0, type);
  }
  assert.ok(HI.modesFor("isim").includes("transfer"));
  assert.ok(!HI.modesFor("isim").includes("daily_question"));
});

test("v2 store sells 9 types × {1,3} at spec prices with game lists; no boost_*, letter packs or Joker", async () => {
  const h = setup();
  const c = await h.call("getStoreCatalog");
  const hints = c.offers.filter((o) => o.itemId.startsWith("hint_"));
  assert.equal(hints.length, 18);
  assert.ok(!c.offers.some((o) => /^boost_/.test(o.itemId)));
  assert.ok(!c.offers.some((o) => o.itemId === "hint_joker"));
  const isim = hints.find((o) => o.offerId === "hint_isim_1");
  const isim3 = hints.find((o) => o.offerId === "hint_isim_3");
  assert.deepEqual([isim.priceCoins, isim3.priceCoins, isim.category], [50, 130, "Güçlü"]);
  const mil = hints.find((o) => o.offerId === "hint_milliyet_3");
  assert.deepEqual([mil.priceCoins, mil.units, mil.category], [65, 3, "Hafif"]);
  assert.ok(isim.modes.includes("transfer") && isim.modes.includes("daily_anagram"));
  assert.ok(c.boostGuide.length > 30);
  const transfer = c.boostGuide.find((g) => g.modeId === "transfer");
  assert.ok(transfer.supports.some((s) => s.itemId === "hint_isim" && s.effect === "İlk harf"));
});

test("v2 purchase: a hint pack lands in the bag; boost_* and Joker are refused without charging", async () => {
  const h = setup();
  await buy(h, "hint_kulup_3", 65);
  assert.equal(qty(h, "hint_kulup"), 3);
  assert.equal(h.read(root + "/balances/coins"), 935);
  await assert.rejects(buy(h, "boost_basic_1", 25), {code: "failed-precondition"});
  await assert.rejects(buy(h, "boost_first_letter_1", 25), {code: "failed-precondition"});
  await assert.rejects(buy(h, "hint_joker_1", 1), {code: "not-found"});
  assert.equal(h.read(root + "/balances/coins"), 935);
});

test("v1 accounts cannot buy hint packs", async () => {
  const h = harness({runtimeConfig: {boosts: {...v2, version: undefined}}, economyState: {alice: {balances:
    {coins: 1000}}}}, {omitEmptyObjects: true});
  await assert.rejects(buy(h, "hint_kulup_1", 25), {code: "failed-precondition"});
  assert.ok(!(await h.call("getStoreCatalog")).offers.some((o) => o.itemId.startsWith("hint_")));
});

test("v2 store open converts legacy stock once and reports it", async () => {
  const h = setup({}, {boost_basic: 2, boost_strong: 1, boost_first_letter: 1});
  const c = await h.call("getStoreCatalog");
  assert.deepEqual({...c.legacyConverted}, {hint_milliyet: 2, hint_isim: 2});
  assert.equal(qty(h, "hint_milliyet"), 2);
  assert.equal(qty(h, "boost_basic"), 0);
  assert.equal((await h.call("getStoreCatalog")).legacyConverted, null);
});

test("rewards on v2: season Pro steps give Joker, crate 8 Joker + 12 typed, free sources typed", () => {
  const dailyReturn = require("../daily_return");
  const crate = require("../pro_crate");
  const e = {inventory: {}, storeUses: {}, balances: {coins: 0}, hintsVersion: 2};
  dailyReturn.grantSupport(e, "k1", "boost_basic", "daily_reward", "d1", 1);
  dailyReturn.grantSupport(e, "k2", "boost_strong", "daily_reward", "d2", 1);
  assert.equal(e.inventory.hint_milliyet.quantity, 1);
  assert.equal(e.inventory.hint_isim.quantity, 1);
  assert.equal(e.inventory.boost_basic, undefined);
  assert.deepEqual(HI.seasonSupports({boost_strong: 2}, true), {hint_joker: 2});
  assert.deepEqual(HI.seasonSupports({boost_connection: 1, boost_eliminate: 1, boost_basic: 1}, true),
      {hint_joker: 3});
  assert.deepEqual(HI.seasonSupports({boost_strong: 2}, false), {boost_strong: 2});
  const c = {inventory: {}, storeUses: {}, balances: {coins: 0}, hintsVersion: 2};
  crate.openCrate(c, "2026-11-07", "alice", 1);
  const got = Object.fromEntries(Object.entries(c.inventory).filter(([k]) => k.startsWith("hint_"))
      .map(([k, v]) => [k, v.quantity]));
  assert.deepEqual(got, {hint_joker: 8, hint_milliyet: 4, hint_mevki: 4, hint_kulup: 2, hint_harf: 2});
  // v1 wallets keep today's contents.
  const old = {inventory: {}, storeUses: {}, balances: {coins: 0}};
  crate.openCrate(old, "2026-11-07", "alice", 1);
  assert.equal(old.inventory.boost_basic.quantity, 12);
});
