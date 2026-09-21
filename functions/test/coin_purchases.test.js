"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const vm = require("node:vm");
const {harness} = require("./support/economy_harness");
const {createService, hash, accountId, PRODUCTS} = require("../coin_purchases");
const sku = "linkball_coins_500";
const token = "test-purchase-token-never-real";
function setup() {
  const h = harness();
  const purchase = {purchaseState: 0, consumptionState: 0,
    obfuscatedExternalAccountId: accountId("alice"), productId: sku, quantity: 1};
  let consumes = 0;
  let failConsume = false;
  class ErrorType extends Error {
    constructor(code, message) {
      super(message); this.code = code;
    }
  }
  const service = createService({db: h.db,
    normalize: vm.runInContext("lbEconomyState", h.context),
    project: vm.runInContext("lbEconomyProject", h.context), ErrorType, now: () => h.now,
    play: {get: async () => ({...purchase}), consume: async () => {
      consumes++;
      if (failConsume) throw new Error("network");
      purchase.consumptionState = 1;
    }},
  });
  return {h, service, purchase, consumes: () => consumes, fail: (v) => {
    failConsume = v;
  }};
}
test("coin SKU contract", () => assert.deepEqual(Object.values(PRODUCTS), [500, 1400, 3200]));
test("Play ProductPurchaseV2 is normalized fail-closed", () => {
  const h = harness();
  const normalizeV2 = vm.runInContext("lbNormalizeCoinPurchaseV2", h.context);
  const base = {
    purchaseStateContext: {purchaseState: "PURCHASED"},
    testPurchaseContext: {fopType: "TEST"},
    obfuscatedExternalAccountId: accountId("alice"),
    productLineItem: [{
      productId: sku,
      productOfferDetails: {
        quantity: 1,
        consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
      },
    }],
  };
  const purchased = normalizeV2(base);
  assert.equal(purchased.purchaseState, 0);
  assert.equal(purchased.consumptionState, 0);
  assert.equal(purchased.productId, sku);
  assert.equal(purchased.quantity, 1);
  assert.equal(purchased.purchaseType, 0);
  assert.equal(purchased.obfuscatedExternalAccountId, accountId("alice"));

  assert.equal(normalizeV2({
    ...base,
    purchaseStateContext: {purchaseState: "CANCELLED"},
  }).purchaseState, 1);
  assert.equal(normalizeV2({
    ...base,
    purchaseStateContext: {purchaseState: "PENDING"},
  }).purchaseState, 2);
  assert.equal(normalizeV2({
    ...base,
    purchaseStateContext: {purchaseState: "PURCHASE_STATE_UNSPECIFIED"},
  }).purchaseState, -1);
  assert.equal(normalizeV2({
    ...base,
    productLineItem: [],
  }).consumptionState, -1);
  assert.equal(normalizeV2({
    ...base,
    productLineItem: [
      ...base.productLineItem,
      {...base.productLineItem[0], productId: "unexpected"},
    ],
  }).quantity, 2);
});
test("verified purchase grants once across concurrent callbacks and later restore", async () => {
  const {h, service} = setup();
  await Promise.all(Array.from({length: 5}, () => service.verify("alice", sku, token)));
  await service.verify("alice", sku, token);
  assert.equal(h.read("economyState/alice/balances/coins"), 500);
  assert.equal(Object.keys(h.read("economyState/alice/claims")).length, 1);
  assert.equal(h.read("walletBalances/alice/coins"), 500);
});
for (const state of [1, 2, undefined, "0"]) {
  test("non-purchased state cannot grant: " + state, async () => {
    const {h, service, purchase} = setup(); purchase.purchaseState = state;
    await assert.rejects(service.verify("alice", sku, token));
    assert.equal(h.read("economyState/alice"), null);
  });
}
for (const edit of [
  (p) => p.obfuscatedExternalAccountId = accountId("bob"),
  (p) => delete p.obfuscatedExternalAccountId,
  (p) => p.quantity = 2,
  (p) => p.productId = "another_product",
  (p) => p.consumptionState = 1,
]) {
  test("mismatched/unknown/consumed purchase fails closed: " + edit.toString(), async () => {
    const {h, service, purchase} = setup(); edit(purchase);
    await assert.rejects(service.verify("alice", sku, token));
    assert.equal(h.read("economyState/alice"), null);
  });
}
test("cross-account token replay fails even with altered account data", async () => {
  const {h, service, purchase} = setup();
  await service.verify("alice", sku, token);
  purchase.obfuscatedExternalAccountId = accountId("bob");
  await assert.rejects(service.verify("bob", sku, token));
  assert.equal(h.read("economyState/bob"), null);
});
test("consume outage retries from durable work without duplicate grant", async () => {
  const {h, service, fail} = setup(); fail(true);
  await assert.rejects(service.verify("alice", sku, token));
  assert.equal(h.read("economyState/alice/balances/coins"), 500);
  assert.equal(h.read("coinPurchaseWork/" + hash(token)), true);
  fail(false);
  await service.retry(hash(token));
  assert.equal(h.read("economyState/alice/balances/coins"), 500);
  assert.equal(h.read("coinPurchaseWork/" + hash(token)), null);
});
test("projection outage is repaired before consumption", async () => {
  const {h, service, consumes} = setup(); h.failNext("");
  await assert.rejects(service.verify("alice", sku, token));
  assert.equal(consumes(), 0);
  assert.equal(h.read("economyState/alice/balances/coins"), 500);
  await service.retry(hash(token));
  assert.equal(h.read("walletBalances/alice/coins"), 500);
});
test("refund is idempotent and retains a deficit after coins were spent", async () => {
  const {h, service} = setup(); await service.verify("alice", sku, token);
  h.seed("economyState/alice/balances/coins", 100);
  await service.revoke(hash(token)); await service.revoke(hash(token));
  assert.equal(h.read("economyState/alice/balances/coins"), -400);
  await h.call("syncMyWallet");
  assert.equal(h.read("economyState/alice/balances/coins"), -400);
  assert.equal(h.read("economyLedger/alice/play_refund__" + hash(token) + "/type"), "refund");
  await assert.rejects(service.verify("alice", sku, token));
});
test("refund before wallet grant prevents delayed grant", async () => {
  const {h, service} = setup();
  h.failNext("economyState/alice");
  await assert.rejects(service.verify("alice", sku, token));
  await service.revoke(hash(token));
  await assert.rejects(service.verify("alice", sku, token));
  assert.equal(h.read("economyState/alice/balances/coins"), 0);
});
test("deleted-account tombstone cannot be reclaimed", async () => {
  const {h, service} = setup();
  h.seed("coinPurchaseTokens/" + hash(token), {deleted: true});
  await assert.rejects(service.verify("alice", sku, token));
  assert.equal(h.read("economyState/alice"), null);
});
test("rate limits bound repeated Google verification", async () => {
  const {service} = setup();
  for (let i = 0; i < 20; i++) await service.verify("alice", sku, token);
  await assert.rejects(service.verify("alice", sku, token), (e) => e.code === "resource-exhausted");
});
test("callable rejects guests and anonymous accounts", async () => {
  const h = harness();
  await assert.rejects(h.call("verifyCoinPurchase", {}, null));
  await assert.rejects(h.call("getCoinPurchaseCatalog", {}, {uid: "guest", token: {}}));
});
