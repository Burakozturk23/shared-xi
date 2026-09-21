"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

function storeBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_7B_COIN_STORE_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_7B_COIN_STORE_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

test("coin store exposes four canonical premium avatar offers", () => {
  const offers = require("../economy_config").defaults.sinks.cosmetics.offers;
  assert.deepEqual(Object.keys(offers), [
    "avatar_speedster_bolt", "avatar_tactician_board", "avatar_night_owl", "avatar_champion_cup",
  ]);
  assert.deepEqual(Object.values(offers).map((o) => o.itemId), [
    "speedster_bolt", "tactician_board", "night_owl", "champion_cup",
  ]);
  assert.deepEqual(Object.values(offers).map((o) => o.priceCoins), [150, 250, 400, 600]);
  assert.ok(storeBlock().includes("config.sinks.cosmetics.offers"));
});

test("store catalog is server-backed and returns wallet context", () => {
  assert.ok(source.includes("exports.getStoreCatalog"));
  assert.ok(source.includes("await lbStoreCatalog(db, config)"));
  assert.ok(source.includes("wallet: lbEconomyWalletProjection(state)"));
  assert.ok(source.includes("catalogVersion: LB_STORE_CATALOG_VERSION"));
});

test("purchase uses Remote Config prices and compares the displayed quote", () => {
  assert.ok(
      source.includes("config.sinks.cosmetics.offers"),
  );
  assert.ok(source.includes("LB_STORE_COIN_OFFERS[offerId]"));
  assert.ok(source.includes("offer.expectedPriceCoins !== offer.priceCoins"));
  assert.equal(
      source.includes("(request.data || {}).priceCoins"),
      false,
  );
});

test("avatar inventory repairs server-owned profile ownership", () => {
  assert.ok(
      source.includes(
          "LB_SOCIAL_AVATAR_IDS.has(itemId)",
      ),
  );
  assert.ok(
      source.includes(
          "\"users/\" + uid + \"/ownedAvatars/\" + itemId",
      ),
  );
});
