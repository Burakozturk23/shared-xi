"use strict";
// Faz 4a-b: one avatar draw for the Pro Kasası and the Sezon Rotası, and the
// monthly Kasa itself. Pure state functions over an economyState object; the
// callers run them inside one wallet transaction. Off until runtimeConfig says so.
const crypto = require("node:crypto");
const {grantSupport} = require("./daily_return");

const catalog = require("./config/store_collection.json").offers.filter((o) => o.enabled);
// Only avatars and kits players can buy; retired ones never come out of a draw.
const AVATARS = Object.freeze(catalog.filter((o) => o.itemType === "avatar")
    .map((o) => Object.freeze({itemId: o.itemId, price: o.priceCoins, title: o.title})));
const KITS = Object.freeze(catalog.filter((o) => o.itemType === "kit")
    .map((o) => Object.freeze({itemId: o.itemId, price: o.priceCoins, title: o.title})));
// Kasa: 12 Temel + 4 Güçlü + 2 Bağlantı + 2 Tek seçenek ele + 1 avatar (450 tier).
const CRATE = Object.freeze({boost_basic: 12, boost_strong: 4, boost_connection: 2, boost_eliminate: 2});
const CRATE_TIER = 450;
// Sezon: whole pool, a 300 avatar weighs 3 and a 450 avatar 2.
const SEASON_WEIGHTS = Object.freeze({300: 3, 450: 2});
const FALLBACK_COINS = 300;
const OPEN_AFTER_MS = 48 * 3600000;

/** A stable number in [0, 1) for this player and receipt: a retry draws the same. */
function roll(uid, key) {
  return parseInt(crypto.createHash("sha256").update(uid + "|" + key).digest("hex").slice(0, 13), 16) / 2 ** 52;
}

/** The avatars a draw may give now (owned ones never), with their weights. */
function pool(e, mode) {
  const free = AVATARS.filter((a) => !(e.inventory?.[a.itemId]?.quantity > 0));
  if (mode === "crate") {
    const tier = free.filter((a) => a.price === CRATE_TIER);
    // The 450 tier first; once it is all owned the Kasa falls back to the 300 tier.
    const rows = tier.length ? tier : free.filter((a) => a.price !== CRATE_TIER);
    return rows.map((a) => ({...a, weight: 1}));
  }
  return free.map((a) => ({...a, weight: SEASON_WEIGHTS[a.price] || 1}));
}

/** What a player is told before opening: how many can come out and each tier's chance. */
function odds(e, mode) {
  const rows = pool(e, mode);
  const total = rows.reduce((n, r) => n + r.weight, 0);
  const tiers = {};
  for (const r of rows) {
    const t = tiers[r.price] ||= {price: r.price, count: 0, chance: 0, each: 0};
    t.count++; t.chance += total ? r.weight / total : 0; t.each = total ? r.weight / total : 0;
  }
  const round = (n) => Math.round(n * 10000) / 10000;
  return {mode, count: rows.length, tiers: Object.values(tiers).sort((a, b) => a.price - b.price)
      .map((t) => ({...t, chance: round(t.chance), each: Math.round(t.each * 1e6) / 1e6})),
  fallback: rows.length ? null : (KITS.some((k) => !(e.inventory?.[k.itemId]?.quantity > 0)) ? "kit" : "coins")};
}

/**
 * Draws one avatar under `key` (once: a retry returns the stored result).
 * No avatar left: an unowned kit; no kit left: 300 coins (own claim, ledger
 * source "pro_reward_fallback").
 */
function drawAvatar(e, key, uid, mode, source, now) {
  if (e.storeUses[key]) return e.storeUses[key];
  let rows = pool(e, mode); let kind = "avatar";
  if (!rows.length) {
    rows = KITS.filter((k) => !(e.inventory?.[k.itemId]?.quantity > 0)).map((k) => ({...k, weight: 1}));
    kind = "kit";
  }
  let receipt;
  if (rows.length) {
    const total = rows.reduce((n, r) => n + r.weight, 0);
    let at = roll(uid, key) * total; let pick = rows[rows.length - 1];
    for (const r of rows) {
      if ((at -= r.weight) < 0) {
        pick = r; break;
      }
    }
    e.inventory[pick.itemId] = {itemId: pick.itemId, itemType: kind, quantity: 1, sourceType: source, sourceId: key,
      acquiredAt: now};
    receipt = {kind, itemId: pick.itemId, title: pick.title, price: pick.price, coins: 0, source, usedAt: now};
  } else {
    const claimId = "pro_reward_fallback__" + key; const balanceBefore = e.balances.coins;
    e.balances.coins += FALLBACK_COINS; e.lifetimeEarned += FALLBACK_COINS;
    e.claims[claimId] = {txId: claimId, sourceType: "pro_reward_fallback", sourceId: key, amount: FALLBACK_COINS,
      balanceBefore, balanceAfter: e.balances.coins, claimedAt: now, economyConfigId: "pro-crate-v1"};
    receipt = {kind: "coins", itemId: "", title: "", price: 0, coins: FALLBACK_COINS, source, usedAt: now};
  }
  e.storeUses[key] = receipt; e.updatedAt = now;
  return receipt;
}

/** Calendar month (Istanbul day key) and its last day. */
function monthOf(dayKey) {
  const [y, m] = dayKey.split("-").map(Number);
  const last = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return {month: dayKey.slice(0, 7), endsOn: `${dayKey.slice(0, 7)}-${String(last).padStart(2, "0")}`,
    daysLeft: last - Number(dayKey.slice(8)) + 1};
}

/** When this Pro period's Kasa may be opened: 48 hours after the subscription started. */
function openableAt(premium) {
  return premium.plan === "lifetime" || !premium.startedAt ? 0 : premium.startedAt + OPEN_AFTER_MS;
}

/** Opens the month's Kasa once; a retry returns the same contents. */
function openCrate(e, dayKey, uid, now) {
  const {month} = monthOf(dayKey);
  const base = "pro_crate__" + month;
  if (e.storeUses[base]) return {opened: false, receipt: e.storeUses[base]};
  const supports = {}; let overflowCoins = 0;
  for (const [itemId, count] of Object.entries(CRATE)) {
    for (let i = 1; i <= count; i++) {
      const r = grantSupport(e, `${base}__${itemId}__${i}`, itemId, "pro_crate", month, now).receipt;
      supports[itemId] = (supports[itemId] || 0) + (r.full ? 0 : 1);
      overflowCoins += r.coins || 0;
    }
  }
  const avatar = drawAvatar(e, base + "__avatar", uid, "crate", "pro_crate", now);
  e.storeUses[base] = {month, openedAt: now, supports, overflowCoins, avatar};
  e.updatedAt = now;
  return {opened: true, receipt: e.storeUses[base]};
}

/** Expected coin value of one draw (for the economy report). */
function expectedValue(mode, e = {inventory: {}}) {
  const rows = pool(e, mode); const total = rows.reduce((n, r) => n + r.weight, 0);
  return total ? rows.reduce((n, r) => n + r.price * r.weight, 0) / total : 0;
}

module.exports = {AVATARS, KITS, CRATE, CRATE_TIER, SEASON_WEIGHTS, FALLBACK_COINS, OPEN_AFTER_MS, roll, pool, odds,
  drawAvatar, monthOf, openableAt, openCrate, expectedValue};
