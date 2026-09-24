"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../store_collection");
const funded = (coins = 1000) => harness({economyState: {alice: {balances: {coins}}}});
const buy = (h, id = "boost_first_letter_3", requestId = "request_1234567890", price = 65) =>
  h.call("purchaseEconomyOffer", {offerId: id, requestId, expectedPriceCoins: price});
const use = (h, roundId = "round_1234567890_ab", modeId = "futbol_lingo") =>
  h.call("consumeStoreBoost", {itemId: "boost_first_letter", roundId, modeId});

test("catalog exposes server prices, solo modes and unique stable item definitions", async () => {
  const c = await funded().call("getStoreCatalog");
  assert.equal(c.offers.length, catalog.offers.length + 4);
  assert.equal(new Set(c.offers.map((o) => o.offerId)).size, c.offers.length);
  assert.equal(catalog.offers.filter((o) => o.itemType === "kit").length, 6);
  assert.equal(catalog.offers.filter((o) => o.itemType === "avatar").length, 33);
  for (const o of catalog.offers) {
    assert.ok(Number.isSafeInteger(o.priceCoins) && o.priceCoins > 0);
    if (o.itemType === "boost") assert.deepEqual(o.modes, ["futbol_lingo", "mystery_player", "transfer_detective"]);
  }
});
test("duplicate concurrent purchase charges and grants exactly once, independent orders add stock", async () => {
  const h = funded();
  await Promise.all([buy(h), buy(h)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 935);
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 3);
  await buy(h, undefined, "another_request_123456");
  assert.equal(h.read("economyState/alice/balances/coins"), 870);
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 6);
});
test("projection failure retries repair receipt without a second debit", async () => {
  const h = funded();
  h.failNext("");
  await assert.rejects(buy(h));
  const result = await buy(h);
  assert.equal(result.replayed, true);
  assert.equal(h.read("walletBalances/alice/coins"), 935);
  assert.equal(h.read("inventory/alice/boost_first_letter/quantity"), 3);
});
test("quotes, insufficient balances, stock limits and reused keys cannot overcharge", async () => {
  const poor = funded(24);
  await assert.rejects(buy(poor), {code: "failed-precondition"});
  assert.equal(poor.read("economyState/alice/balances/coins"), 24);
  const h = funded();
  await assert.rejects(buy(h, undefined, undefined, 1), {code: "failed-precondition"});
  await buy(h);
  await assert.rejects(buy(h, "boost_last_letter_3"), {code: "invalid-argument"});
  assert.equal(h.read("economyState/alice/balances/coins"), 935);
  h.seed("economyState/alice/inventory/boost_first_letter/quantity", 99);
  await assert.rejects(buy(h, undefined, "new_request_123456789"), {code: "resource-exhausted"});
});
test("one-time cosmetics cannot be double charged and equip requires canonical ownership", async () => {
  const h = funded();
  await assert.rejects(h.call("equipStoreItem", {itemId: "kit_midnight"}), {code: "permission-denied"});
  await Promise.all([
    buy(h, "kit_midnight", "kit_request_123456", 250),
    buy(h, "kit_midnight", "kit_request_987654", 250),
  ]);
  assert.equal(h.read("economyState/alice/balances/coins"), 750);
  await h.call("equipStoreItem", {itemId: "kit_midnight"});
  assert.equal(h.read("users/alice/kitId"), "kit_midnight");
  await h.call("equipStoreItem", {itemId: "kit_none"});
  assert.equal(h.read("users/alice/kitId"), "");
  const avatar = catalog.offers.find((o) => o.itemType === "avatar");
  await buy(h, avatar.offerId, "avatar_request_123456", avatar.priceCoins);
  await h.call("equipStoreItem", {itemId: avatar.itemId});
  assert.equal(h.read("users/alice/avatarId"), avatar.itemId);
  assert.equal(h.read("users/alice/ownedAvatars/" + avatar.itemId), true);
});
test("consumption is idempotent per round, cannot go negative or target ranked modes", async () => {
  const h = funded();
  await buy(h);
  await Promise.all([use(h), use(h)]);
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 2);
  await assert.rejects(use(h, undefined, "ranked"), {code: "invalid-argument"});
  await use(h, "round_222222222222");
  await use(h, "round_333333333333");
  await assert.rejects(use(h, "round_444444444444"), {code: "failed-precondition"});
  await use(h);
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 0);
});
test("failed consume projection can replay safely after other economy transactions", async () => {
  const h = funded();
  await buy(h);
  h.failNext("");
  await assert.rejects(use(h));
  await buy(h, "kit_midnight", "kit_request_123456", 250);
  await use(h);
  assert.equal(h.read("inventory/alice/boost_first_letter/quantity"), 2);
});
test("all store mutations require an authenticated linked account", async () => {
  const h = funded();
  for (const name of ["consumeStoreBoost", "equipStoreItem", "purchaseEconomyOffer"]) {
    await assert.rejects(h.call(name, {}, null), {code: "unauthenticated"});
    await assert.rejects(h.call(name, {}, {uid: "alice", token: {firebase: {sign_in_provider: "anonymous"}}}));
  }
});
