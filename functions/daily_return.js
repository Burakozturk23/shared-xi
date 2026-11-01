"use strict";
// Faz 2: Günlük Dönüş. Everything here is off until runtimeConfig/dailyReturn
// says otherwise, and adds supports, never coins (the coin budget stays as is).
//   {enabled, loopSupports, streakProtection, allMissionsBonus}
const MAX_STOCK = 99;
// Day 3 and day 7 of the existing 7-day check-in loop.
const LOOP_SUPPORTS = Object.freeze({3: "boost_basic", 7: "boost_strong"});
const PROTECTION_EVERY_DAYS = 7;
const BONUS_WEEKLY_LIMIT = 2;
const BONUS_ITEM = "boost_basic";

/**
 * The live switches. Supports are only given where typed supports are live for
 * the player (`boostsLive`, from runtimeConfig/boosts), so a support never lands
 * in a bag that cannot use it; the missed-day cover does not depend on it.
 */
function policy(raw, boostsLive = false) {
  const on = raw?.enabled === true;
  return {enabled: on, loopSupports: on && boostsLive && raw.loopSupports === true,
    streakProtection: on && raw.streakProtection === true,
    allMissionsBonus: on && boostsLive && raw.allMissionsBonus === true};
}

const OFF = Object.freeze(policy(null));

/** The support a loop day adds, or null. */
function loopSupport(dayIndex, p = OFF) {
  return p.loopSupports ? LOOP_SUPPORTS[dayIndex] || null : null;
}

/** Support per loop day, for the 7-day strip. */
function loopSchedule(p = OFF) {
  return [1, 2, 3, 4, 5, 6, 7].map((day) => loopSupport(day, p));
}

const dayDiff = (from, to) => Math.round((Date.parse(to + "T00:00:00Z") - Date.parse(from + "T00:00:00Z")) / 86400000);

/**
 * Whether the free once-a-week cover applies: exactly one day missed (gap 2)
 * and no cover used in the last seven days.
 */
function freeProtection(daily, dayKey, p = OFF) {
  if (!p.streakProtection || !daily.lastClaimDay || daily.lastClaimDay >= dayKey) return false;
  if (dayDiff(daily.lastClaimDay, dayKey) !== 2 || !(daily.currentStreak > 0)) return false;
  return !daily.lastProtectedDay || dayDiff(daily.lastProtectedDay, dayKey) >= PROTECTION_EVERY_DAYS;
}

/** The first day the free cover can be used again. */
function protectionReadyOn(daily) {
  if (!daily.lastProtectedDay) return "";
  const d = new Date(daily.lastProtectedDay + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + PROTECTION_EVERY_DAYS);
  return d.toISOString().slice(0, 10);
}

/** Monday of the day's week (Istanbul day keys). */
function weekOf(dayKey) {
  const d = new Date(dayKey + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7);
  return d.toISOString().slice(0, 10);
}

/** Coins paid for a support that does not fit: half its store price, rounded down. */
function overflowCoins(itemId) {
  const product = require("./boosts").products[itemId];
  return product ? Math.floor(product.priceCoins / 2) : 0;
}

/**
 * Adds one support to the economy state under a receipt key. Same key twice
 * changes nothing. When the bag is full (99) the support turns into half its
 * store price in coins, credited in the same transaction with its own claim
 * (ledger source "support_overflow"), and the receipt says so (`full`, `coins`).
 */
function grantSupport(e, key, itemId, source, sourceId, now, extra = {}) {
  if (e.storeUses[key]) return {granted: false, receipt: e.storeUses[key]};
  const item = e.inventory[itemId]; const quantity = item?.quantity || 0;
  const full = quantity >= MAX_STOCK;
  let coins = 0;
  if (!full) {
    e.inventory[itemId] = {...item, itemId, itemType: "boost", quantity: quantity + 1,
      sourceType: source, sourceId, acquiredAt: item?.acquiredAt || now};
  } else if ((coins = overflowCoins(itemId)) > 0 && !e.claims["support_overflow__" + key]) {
    // Own claim id: the coin reward of the same day may already use `key` (daily_reward__<day>).
    const claimId = "support_overflow__" + key; const balanceBefore = e.balances.coins;
    e.balances.coins += coins; e.lifetimeEarned += coins;
    e.claims[claimId] = {txId: claimId, sourceType: "support_overflow", sourceId: itemId, amount: coins,
      balanceBefore, balanceAfter: e.balances.coins, claimedAt: now, economyConfigId: "daily-return-v1"};
  }
  e.storeUses[key] = {itemId, source, sourceId, usedAt: now, full, coins, ...extra};
  e.updatedAt = now;
  return {granted: !full, receipt: e.storeUses[key]};
}

/** All-missions bonuses already given in the day's week. */
function bonusesThisWeek(e, dayKey) {
  const week = weekOf(dayKey);
  return Object.entries(e.storeUses || {}).filter(([key, r]) => key.startsWith("all_daily__") && r?.week === week)
      .length;
}

/**
 * The all-missions bonus for a day: once a day, at most two a week. Returns
 * null when nothing is due (off, already given, or the weekly limit is used).
 */
function grantAllMissionsBonus(e, dayKey, now, p = OFF) {
  if (!p.allMissionsBonus) return null;
  const key = "all_daily__" + dayKey;
  if (e.storeUses[key]) return {granted: false, receipt: e.storeUses[key]};
  if (bonusesThisWeek(e, dayKey) >= BONUS_WEEKLY_LIMIT) return null;
  return grantSupport(e, key, BONUS_ITEM, "all_missions_bonus", dayKey, now, {week: weekOf(dayKey)});
}

module.exports = {LOOP_SUPPORTS, PROTECTION_EVERY_DAYS, BONUS_WEEKLY_LIMIT, BONUS_ITEM, MAX_STOCK, OFF, policy,
  overflowCoins,
  loopSupport, loopSchedule, freeProtection, protectionReadyOn, weekOf, grantSupport, bonusesThisWeek,
  grantAllMissionsBonus};
