"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);
const rulesSource = fs.readFileSync(
    path.join(__dirname, "..", "..", "database.rules.json"),
    "utf8",
);

function economyBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_6B_ECONOMY_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_6B_ECONOMY_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

function transactionsBlock() {
  const block = economyBlock();
  const start = block.indexOf(
      "// LINKBALL_16_6C_ECONOMY_TRANSACTIONS_START",
  );
  const end = block.indexOf(
      "// LINKBALL_16_6C_ECONOMY_TRANSACTIONS_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return block.slice(start, end);
}

test("economy uses one private canonical state and server projections", () => {
  const block = economyBlock();

  assert.ok(block.includes("\"economyState/\" + uid"));
  assert.ok(block.includes("\"walletBalances/\" + uid"));
  assert.ok(block.includes("\"economyLedger/\" + uid"));
  assert.ok(block.includes("\"rewardClaims/\" + uid"));
  assert.ok(block.includes("\"inventory/\" + uid"));
  assert.ok(block.includes("lbEconomyProject("));
});

test("achievement reward claims are server-validated and idempotent", () => {
  const block = economyBlock();

  assert.ok(block.includes("exports.claimAchievementReward"));
  assert.ok(block.includes("\"userAchievements/\" + uid"));
  assert.ok(block.includes("state.claims[claimId]"));
  assert.ok(block.includes("return;"));
  assert.ok(block.includes("alreadyClaimed: !result.granted"));
});

test("wallet mutation prevents negative or client-defined reward amounts", () => {
  const block = economyBlock();

  assert.ok(block.includes("LB_ACHIEVEMENT_COIN_REWARDS"));
  assert.ok(block.includes("Number.isInteger(amount)"));
  assert.ok(block.includes("amount <= 0"));
  assert.ok(block.includes("state.balances.coins + amount"));
});

test("first achievement reward schedule has 28 positive unique ids", () => {
  const block = economyBlock();
  const mapStart = block.indexOf(
      "const LB_ACHIEVEMENT_COIN_REWARDS",
  );
  const mapEnd = block.indexOf("});", mapStart);

  assert.notEqual(mapStart, -1);
  assert.notEqual(mapEnd, -1);

  const mapText = block.slice(mapStart, mapEnd);
  const rows = [...mapText.matchAll(/^\s{2}([a-z0-9_]+): ([0-9]+),$/gm)];

  assert.equal(rows.length, 28);
  assert.equal(
      new Set(rows.map((row) => row[1])).size,
      rows.length,
  );
  assert.ok(rows.every((row) => Number(row[2]) > 0));
});

test("wallet sync repairs projections without granting currency", () => {
  const block = economyBlock();

  assert.ok(block.includes("exports.syncMyWallet"));
  assert.ok(block.includes("lbEconomyEnsure("));
  assert.ok(block.includes("wallet: lbEconomyWalletProjection(state)"));
});

test("coin spend reads server-side offer data and never client price", () => {
  const block = economyBlock();

  assert.ok(block.includes("exports.purchaseEconomyOffer"));
  assert.ok(block.includes("\"economyCatalog/offers/\" + offerId"));
  assert.ok(block.includes("offer.priceCoins"));
  assert.equal(
      block.includes("(request.data || {}).priceCoins"),
      false,
  );
});

test("coin spend is atomic, non-negative, and one-time per item", () => {
  const block = transactionsBlock();

  assert.ok(block.includes("ref.transaction((current) =>"));
  assert.ok(block.includes("state.inventory[offer.itemId]"));
  assert.ok(block.includes("state.balances.coins < offer.priceCoins"));
  assert.ok(
      block.includes(
          "state.balances.coins = balanceAfter",
      ),
  );
  assert.ok(block.includes("state.lifetimeSpent += offer.priceCoins"));
  assert.ok(block.includes("alreadyOwned: true"));
});

test("spends are projected into ledger and canonical inventory", () => {
  const block = economyBlock();

  assert.ok(block.includes("lbEconomySpendLedgerProjection"));
  assert.ok(block.includes("type: \"spend\""));
  assert.ok(block.includes("amount: -purchase.priceCoins"));
  assert.ok(block.includes("lbEconomyInventoryProjection"));
  assert.ok(block.includes("\"inventory/\" + uid + \"/\" + itemId"));
});

test("economy catalog is server-private in RTDB rules", () => {
  const parsed = JSON.parse(rulesSource);

  assert.equal(parsed.rules.economyCatalog[".read"], false);
  assert.equal(parsed.rules.economyCatalog[".write"], false);
  assert.equal(parsed.rules.economyState[".read"], false);
  assert.equal(parsed.rules.economyState[".write"], false);
});
