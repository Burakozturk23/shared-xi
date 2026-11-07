"use strict";
const crypto = require("node:crypto");
const catalog = require("./config/store_collection.json");
const B = require("./boosts");
const offers = Object.fromEntries([...catalog.offers, ...B.offers].map((o) => [o.offerId, Object.freeze(o)]));
const avatarIds = catalog.offers.filter((o) => o.itemType === "avatar").map((o) => o.itemId);
const modes = new Set(["futbol_lingo", "mystery_player", "transfer_detective"]);
const boosts = new Set(["boost_first_letter", "boost_last_letter", "boost_anagram"]);
const MAX_STOCK = 99;
// İlk Harf stays on sale with typed supports, but only for the games that take it
// there (Transfer Dedektifi, the anagrams); the classic mode list would point the
// player at games where it cannot be used. No open game: not on sale.
function typedModes(itemId, policy) {
  const id = itemId.replace(/^boost_/, "");
  return Object.entries(B.modes).filter(([m, ids]) => ids.includes(id) && policy?.readyModes?.[m] === true)
      .map(([m]) => m);
}
function typedOffer(offer, policy) {
  if (offer.itemId !== "boost_first_letter") return offer;
  const modes = typedModes(offer.itemId, policy);
  return modes.length ? {...offer, modes,
    subtitle: "Transfer Dedektifi'nde üçüncü ipucu, anagramlarda adın ilk harfi."} : null;
}
function validKey(key) {
  return typeof key === "string" && /^[a-zA-Z0-9_-]{16,80}$/.test(key);
}
function createStore({db, normalize, project, HttpsError, now = Date.now, getPrices = async () => null}) {
  function error(code, message) {
    throw new HttpsError(code, message);
  }
  async function purchase(uid, data) {
    const offer = offers[data.offerId];
    if (!offer || !offer.enabled) error("not-found", "Offer unavailable.");
    // Letter packs (legacyOnly) are for accounts still on the classic letter supports.
    if (offer.legacyOnly && await B.policyFor(db, uid, true)) {
      error("failed-precondition", "Bu destek yeni destek sistemine çevrildi; Coin harcanmadı.");
    }
    if (offer.itemId === "boost_first_letter") {
      const p = await B.policyFor(db, uid, true);
      if (p && !typedModes(offer.itemId, p).length) {
        error("failed-precondition", "Bu destek henüz açılmadı; Coin harcanmadı.");
      }
    }
    if (B.offers.some((o) => o.offerId === offer.offerId)) {
      const p = await B.policyFor(db, uid, true);
      if (!p || !offer.modes.some((m) => p.readyModes?.[m] === true)) {
        error("failed-precondition", "Bu destek henüz açılmadı; Coin harcanmadı.");
      }
    }
    if (!validKey(data.requestId)) error("invalid-argument", "A stable request ID is required.");
    if (!Number.isSafeInteger(data.expectedPriceCoins)) error("invalid-argument", "A price quote is required.");
    // Support prices may come from linkball_prices_v1 (flag off: the catalog price).
    let price = offer.priceCoins;
    if (offer.itemType === "boost") {
      try {
        price = require("./price_config").offerPrice(offer, await getPrices());
      } catch (_) {
        price = offer.priceCoins;
      }
    }
    const key = "store__" + data.requestId;
    const nonce = crypto.randomUUID();
    const stamp = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      const state = normalize(raw);
      if (state.purchases[key]) return state;
      if (offer.oneTime && state.inventory[offer.itemId]) return state;
      if (price !== data.expectedPriceCoins || state.balances.coins < price) return state;
      const old = state.inventory[offer.itemId];
      const quantity = offer.itemType === "boost" ? (old?.quantity || 0) + offer.units : 1;
      if (quantity > MAX_STOCK) return state;
      const balanceBefore = state.balances.coins;
      state.balances.coins -= price;
      state.lifetimeSpent += price;
      state.purchases[key] = {
        txId: key, offerId: offer.offerId, itemId: offer.itemId, itemType: offer.itemType,
        priceCoins: price, balanceBefore, balanceAfter: state.balances.coins,
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
      if (price !== data.expectedPriceCoins) error("failed-precondition", "Fiyat güncellendi.");
      if ((item?.quantity || 0) + offer.units > MAX_STOCK) error("resource-exhausted", "Stock limit reached.");
      error("failed-precondition", "Insufficient coin balance.");
    }
    await project(db, uid, state);
    return {ok: true, purchased: receipt?.nonce === nonce, alreadyOwned: !receipt && !!item,
      replayed: !!receipt && receipt.nonce !== nonce, coins: state.balances.coins,
      priceCoins: receipt?.priceCoins || 0, item};
  }
  // Retired letter supports become the typed ones of the same price, one to one:
  // Son harf (25) -> Temel bilgi (25), Harf karışımı (60) -> Güçlü bilgi (60).
  // What does not fit under the 99 cap stays in the old stock.
  async function convertLegacy(uid) {
    const stamp = now(); const key = "legacy_convert__" + crypto.randomUUID();
    const pairs = [["boost_last_letter", "boost_basic"], ["boost_anagram", "boost_strong"]];
    let result = {added: 0, converted: {}, gained: {}};
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      result = {added: 0, converted: {}, gained: {}};
      const state = normalize(raw);
      for (const [from, to] of pairs) {
        const item = state.inventory[from]; const target = state.inventory[to];
        const take = Math.max(0, Math.min(item?.quantity || 0, MAX_STOCK - (target?.quantity || 0)));
        if (!take) continue;
        state.inventory[from] = {...item, quantity: item.quantity - take};
        state.inventory[to] = {...target, itemId: to, itemType: "boost", quantity: (target?.quantity || 0) + take,
          sourceType: "legacy_conversion", sourceId: "legacy_letters", acquiredAt: target?.acquiredAt || stamp};
        result.converted[from] = take; result.gained[to] = take; result.added += take;
      }
      if (!result.added) return state;
      state.storeUses[key] = {converted: result.converted, gained: result.gained, added: result.added,
        source: "legacy_letter_conversion", usedAt: stamp};
      state.updatedAt = stamp;
      return state;
    });
    const state = normalize(tx.snapshot.val());
    await project(db, uid, state);
    return {ok: true, added: result.added, converted: result.converted, gained: result.gained,
      inventory: Object.fromEntries(["boost_basic", "boost_strong", "boost_last_letter", "boost_anagram"]
          .map((id) => [id, state.inventory[id]?.quantity || 0]))};
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
  return {purchase, consume, equip, convertLegacy};
}
module.exports = {catalog, offers, avatarIds, createStore, typedOffer, MAX_STOCK};
