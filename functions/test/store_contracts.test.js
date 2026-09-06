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
  const block = storeBlock();

  const offerIds = [
    "avatar_speedster_bolt",
    "avatar_tactician_board",
    "avatar_night_owl",
    "avatar_champion_cup",
  ];
  const avatarIds = [
    "speedster_bolt",
    "tactician_board",
    "night_owl",
    "champion_cup",
  ];

  for (const id of offerIds) {
    assert.ok(block.includes(id));
  }

  for (const id of avatarIds) {
    assert.ok(block.includes(`itemId: "${id}"`));
  }

  const prices = [...block.matchAll(/priceCoins: ([0-9]+),/g)]
      .map((row) => Number(row[1]));

  assert.equal(prices.length, 4);
  assert.ok(prices.every((price) => price > 0));
});

test("store catalog is server-backed and returns wallet context", () => {
  assert.ok(source.includes("exports.getStoreCatalog"));
  assert.ok(source.includes("await lbStoreCatalog(db)"));
  assert.ok(source.includes("wallet: lbEconomyWalletProjection(state)"));
  assert.ok(source.includes("catalogVersion: LB_STORE_CATALOG_VERSION"));
});

test("purchase keeps private catalog support with builtin fallback", () => {
  assert.ok(
      source.includes("\"economyCatalog/offers/\" + offerId"),
  );
  assert.ok(source.includes("LB_STORE_COIN_OFFERS[offerId]"));
  assert.ok(source.includes("lbStoreOffer(rawOffer, offerId)"));
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
