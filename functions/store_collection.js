"use strict";
const crypto = require("node:crypto");
const catalog = require("./config/store_collection.json");
const offers = Object.fromEntries(catalog.offers.map((o) => [o.offerId, Object.freeze(o)]));
const avatarIds = catalog.offers.filter((o) => o.itemType === "avatar").map((o) => o.itemId);
const modes = new Set(["futbol_lingo", "mystery_player", "transfer_detective"]);
const boosts = new Set(["boost_first_letter", "boost_last_letter", "boost_anagram"]);
const MAX_STOCK = 99;
function validKey(key) {
  return typeof key === "string" && /^[a-zA-Z0-9_-]{16,80}$/.test(key);
}
function createStore({db, normalize, project, HttpsError, now = Date.now}) {
  function error(code, message) {
    throw new HttpsError(code, message);
  }
  async function purchase(uid, data) {
    const offer = offers[data.offerId];
    if (!offer || !offer.enabled) error("not-found", "Offer unavailable.");
    if (!validKey(data.requestId)) error("invalid-argument", "A stable request ID is required.");
    if (!Number.isSafeInteger(data.expectedPriceCoins)) error("invalid-argument", "A price quote is required.");
    const key = "store__" + data.requestId;
    const nonce = crypto.randomUUID();
    const stamp = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      const state = normalize(raw);
      if (state.purchases[key]) return state;
      if (offer.oneTime && state.inventory[offer.itemId]) return state;
      if (offer.priceCoins !== data.expectedPriceCoins || state.balances.coins < offer.priceCoins) return state;
      const old = state.inventory[offer.itemId];
      const quantity = offer.itemType === "boost" ? (old?.quantity || 0) + offer.units : 1;
      if (quantity > MAX_STOCK) return state;
      const balanceBefore = state.balances.coins;
      state.balances.coins -= offer.priceCoins;
      state.lifetimeSpent += offer.priceCoins;
      state.purchases[key] = {
        txId: key, offerId: offer.offerId, itemId: offer.itemId, itemType: offer.itemType,
        priceCoins: offer.priceCoins, balanceBefore, balanceAfter: state.balances.coins,
        purchasedAt: stamp, nonce, economyConfigId: "store-collection-" + catalog.version,
      };
      state.inventory[offer.itemId] = {
        itemId: offer.itemId, itemType: offer.itemType, quantity,
        sourceType: "purchase", sourceId: offer.offerId, acquiredAt: old?.acquiredAt || stamp,
      };
      state.createdAt ||= stamp;
      state.updatedAt = stamp;
      return state;
    });
    const state = normalize(tx.snapshot.val());
    const receipt = state.purchases[key];
    const item = state.inventory[offer.itemId];
    if (receipt && receipt.offerId !== offer.offerId) error("invalid-argument", "Request ID already used.");
    if (!receipt && !(offer.oneTime && item)) {
      if (offer.priceCoins !== data.expectedPriceCoins) error("failed-precondition", "Fiyat güncellendi.");
      if ((item?.quantity || 0) + offer.units > MAX_STOCK) error("resource-exhausted", "Stock limit reached.");
      error("failed-precondition", "Insufficient coin balance.");
    }
    await project(db, uid, state);
    return {ok: true, purchased: receipt?.nonce === nonce, alreadyOwned: !receipt && !!item,
      replayed: !!receipt && receipt.nonce !== nonce, coins: state.balances.coins,
      priceCoins: receipt?.priceCoins || 0, item};
  }
  async function consume(uid, data) {
    if (!boosts.has(data.itemId) || !modes.has(data.modeId) || !validKey(data.roundId)) {
      error("invalid-argument", "Unsupported boost or mode.");
    }
    const key = data.modeId + "__" + data.roundId + "__" + data.itemId;
    const stamp = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      const state = normalize(raw);
      if (state.storeUses[key]) return state;
      const item = state.inventory[data.itemId];
      if (!item || item.itemType !== "boost" || !(item.quantity > 0)) return state;
      state.inventory[data.itemId] = {...item, quantity: item.quantity - 1};
      state.storeUses[key] = {itemId: data.itemId, modeId: data.modeId, usedAt: stamp};
      state.updatedAt = stamp;
      return state;
    });
    const state = normalize(tx.snapshot.val());
    if (!state.storeUses[key]) error("failed-precondition", "No boost stock.");
    await project(db, uid, state);
    return {ok: true, consumed: true, quantity: state.inventory[data.itemId].quantity};
  }
  async function equip(uid, data) {
    const itemId = data.itemId;
    if (itemId === "kit_none") {
      await db.ref("users/" + uid).update({kitId: "", updatedAt: now()});
      return {ok: true};
    }
    const state = normalize((await db.ref("economyState/" + uid).get()).val());
    const item = state.inventory[itemId];
    if (!item || !["avatar", "kit"].includes(item.itemType)) error("permission-denied", "Item not owned.");
    // Repair ownership projections before selecting; inventory is canonical and server-only.
    await project(db, uid, state);
    await db.ref("users/" + uid).update({[item.itemType === "avatar" ? "avatarId" : "kitId"]: itemId,
      updatedAt: now()});
    return {ok: true};
  }
  return {purchase, consume, equip};
}
module.exports = {catalog, offers, avatarIds, createStore, MAX_STOCK};
