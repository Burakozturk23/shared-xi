"use strict";
// Phase 1c: support prices in their own Remote Config parameter
// (linkball_prices_v1), apart from the strict linkball_economy_v1 schema, so a
// bad price value only resets prices. Off by default: while `enabled` is false
// every price stays the one in boosts.js (a test keeps the defaults equal).
const crypto = require("node:crypto");
const defaults = require("./config/linkball_prices.defaults.json");
const PARAMETER = "linkball_prices_v1";
const MAX_PRICE = 10000;

function freeze(value) {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}
freeze(defaults);

const sameKeys = (a, b) => Object.keys(a).sort().join() === Object.keys(b).sort().join();

/** Accepts a whole price snapshot or throws; never a partial update. */
function validatePrices(input) {
  const v = typeof input === "string" ? JSON.parse(input) : JSON.parse(JSON.stringify(input));
  if (!v || typeof v !== "object" || Array.isArray(v) || !sameKeys(v, defaults)) {
    throw new Error("Invalid price keys");
  }
  if (v.schemaVersion !== 1) throw new Error("Unsupported price schema");
  if (typeof v.enabled !== "boolean") throw new Error("Invalid price flag");
  if (typeof v.revision !== "string" || !v.revision.trim() || v.revision.length > 60) {
    throw new Error("Invalid price revision");
  }
  if (!v.boosts || typeof v.boosts !== "object" || !sameKeys(v.boosts, defaults.boosts)) {
    throw new Error("Invalid boost price keys");
  }
  for (const [id, p] of Object.entries(v.boosts)) {
    if (!p || typeof p !== "object" || !sameKeys(p, {single: 0, pack: 0})) throw new Error("Invalid price: " + id);
    for (const n of [p.single, p.pack]) {
      if (!Number.isSafeInteger(n) || n < 1 || n > MAX_PRICE) throw new Error("Invalid price number: " + id);
    }
    // A three-pack must cost more than one and less than three singles.
    if (p.pack <= p.single || p.pack >= p.single * 3) throw new Error("Pack price out of range: " + id);
  }
  const configId = "prices-" + crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex").slice(0, 16);
  return freeze({...v, configId});
}
const DEFAULT_PRICES = validatePrices(defaults);

/** Live support prices by item, or null while the flag is off. */
function boostPrices(config) {
  return config?.enabled === true ? config.boosts : null;
}

/** The price to show and charge for a store offer. */
function offerPrice(offer, config) {
  const p = boostPrices(config)?.[offer.itemId];
  if (!p || offer.itemType !== "boost") return offer.priceCoins;
  return offer.units > 1 ? p.pack : p.single;
}

module.exports = {PARAMETER, defaults, DEFAULT_PRICES, validatePrices, boostPrices, offerPrice};
