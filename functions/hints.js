"use strict";
// İpucu sistemi v2 (docs/superpowers/specs/2026-11-07-ipucu-sistemi-design.md).
// Nine bag types plus the Pro-only Joker. Every menu item of every mode spends
// one bag type; the menus live in hints/<group>.js adapters. Runs pinned with a
// v1 policy keep boosts.js; this kernel only touches runs with hintPolicy v2.
//
// Adapter contract: {modes, catalog: {modeId: [{id, label, type}]},
//   board(run) -> string, items(run, ctx) -> [{id, label, type, why}] (producible, priority order),
//   reveal(run, id, ctx) -> {text, apply?(run)}}
const crypto = require("node:crypto");
const {RewardError} = require("./rewarded_ads");

const VERSION = 2;
const MAX_STOCK = 99;
const specs = [
  ["milliyet", "Milliyet", false], ["mevki", "Mevki", false], ["kulup", "Kulüp", false],
  ["donem", "Dönem", false], ["harf", "Harf", false], ["ele", "Ele", false],
  ["isim", "İsim", true], ["baglanti", "Bağlantı", true], ["aday", "Aday", true],
  ["joker", "Joker", false],
];
const TYPES = Object.freeze(Object.fromEntries(specs.map(([id, title, strong]) =>
  [id, Object.freeze({id, key: "hint_" + id, title, strong})])));
const DEFAULT_PRICES = Object.freeze({light: Object.freeze({single: 25, pack: 65}),
  strong: Object.freeze({single: 50, pack: 130})});
// Old support stock, one to one into the nearest new type (spec §5.2).
const LEGACY = Object.freeze({boost_basic: "milliyet", boost_eliminate: "ele", boost_connection: "baglanti",
  boost_strong: "isim", boost_first_letter: "isim", boost_last_letter: "harf", boost_anagram: "isim"});

const fail = (code, message) => {
  throw new RewardError(code, message);
};
const digest = (x) => crypto.createHash("sha256").update(JSON.stringify(x)).digest("hex");
const modeOf = (run) => run.training === true && ["higher_lower", "blind_ranking"].includes(run.mode) ?
  run.mode + "_training" : run.mode === "burst" ? "burst_" + run.style : run.mode;

/** Coin price of one bag type: live (price_config.hintPrices) or the defaults. Joker is never sold. */
function priceOf(type, prices = null) {
  const t = TYPES[type];
  if (!t || type === "joker") throw new Error("Unsold hint type: " + type);
  const tier = t.strong ? "strong" : "light";
  return {...(prices?.[tier] || DEFAULT_PRICES[tier])};
}

// Adapters register by mode so ad credit can follow the board without the caller.
const adapters = {};
function register(adapter) {
  for (const mode of adapter.modes) adapters[mode] = adapter;
  return adapter;
}
const adapterOf = (run) => adapters[run.hintPolicy?.modeId];
const boardOf = (run) => String(adapterOf(run)?.board(run) ?? "");
const active = (run) => run?.hintPolicy?.version === VERSION;
const adLimit = (run) => run.hintPolicy.daily ? 1 : 2;

function addStock(e, type, count, sourceType, sourceId, time) {
  const key = TYPES[type].key; const item = e.inventory[key]; const quantity = item?.quantity || 0;
  const take = Math.max(0, Math.min(count, MAX_STOCK - quantity));
  if (take) {
    e.inventory[key] = {...item, itemId: key, itemType: "boost", quantity: quantity + take,
      sourceType, sourceId, acquiredAt: item?.acquiredAt || time};
  }
  return take;
}

/** Old support stock into the new types, once per unit; what exceeds the 99 cap stays as it was. */
function convertLegacy(e, time) {
  const result = {added: 0, converted: {}, gained: {}};
  for (const [from, type] of Object.entries(LEGACY)) {
    const item = e.inventory[from];
    if (!(item?.quantity > 0)) continue;
    const take = addStock(e, type, item.quantity, "legacy_conversion", from, time);
    if (!take) continue;
    e.inventory[from] = {...item, quantity: item.quantity - take};
    const key = TYPES[type].key;
    result.converted[from] = take; result.gained[key] = (result.gained[key] || 0) + take; result.added += take;
  }
  if (result.added) {
    e.storeUses["hint_legacy__" + time] = {converted: result.converted, gained: result.gained, added: result.added,
      source: "hint_legacy_conversion", usedAt: time};
    e.updatedAt = time;
  }
  return result;
}

/** Pins v2 hints on a new run when the policy is v2 and the mode is ready; false leaves it to boosts.js. */
function pin(run, policy, e = null, time = Date.now()) {
  const mode = modeOf(run);
  if (policy?.version !== VERSION || policy.readyModes?.[mode] !== true) return false;
  run.hintPolicy = {version: VERSION, modeId: mode, daily: run.entry === "daily", ads: true,
    prices: policy.hintPrices || null};
  run.hintUses = {}; run.hintAdCredits = {}; run.assisted = false;
  if (e) convertLegacy(e, time);
  return true;
}

/** Module entry point at run start: v2 hints when the policy says so, otherwise the v1 supports. */
function pinAny(run, policy, e = null, time = Date.now()) {
  if (!pin(run, policy, e, time)) require("./boosts").pin(run, policy);
}

function listed(run, adapter, ctx) {
  const board = String(adapter.board(run) ?? "");
  const uses = run.hintUses?.[board] || {};
  const items = [...(adapter.items(run, ctx) || [])];
  for (const [id, u] of Object.entries(uses)) {
    if (!items.some((i) => i.id === id)) items.push({id, label: u.label, type: u.type, why: null});
  }
  return {board, uses, items};
}

/** The session's hint menu (no bag: the client reads the wallet). */
function view(run, adapter = adapterOf(run), ctx = {}) {
  if (!active(run) || !adapter) return null;
  const {board, uses, items} = listed(run, adapter, ctx);
  const rows = items.map((i) => ({id: i.id, label: i.label, type: i.type, strong: TYPES[i.type].strong,
    price: priceOf(i.type, run.hintPolicy.prices).single, used: !!uses[i.id], result: uses[i.id]?.text ?? null,
    why: i.why ?? null}));
  const open = rows.filter((r) => !r.used);
  return {version: VERSION, board, items: rows,
    suggested: [open.find((r) => !r.strong)?.id ?? null, open.find((r) => r.strong)?.id ?? null],
    ads: {allowed: run.hintPolicy.ads !== false, remaining: Math.max(0, adLimit(run) - (run.adGranted || 0)),
      credits: Object.fromEntries(Object.entries(run.hintAdCredits || {})
          .filter(([, c]) => c.board === board).map(([id, c]) => [id, c.n]))},
    assisted: run.assisted === true};
}

function paymentFingerprint(input) {
  return [input.itemId ?? null, input.paymentSource ?? null, input.expectedPriceCoins ?? null];
}

/**
 * Reveals one menu item and pays for it, inside the caller's economy transaction.
 * Every check runs before anything is spent; a throw leaves wallet and run as they were.
 */
function use(e, run, adapter, input, time, ctx = {}) {
  if (!active(run)) fail("failed-precondition", "Bu oyun eski destek kurallarını kullanıyor.");
  if (run.finished || run.expiresAt <= time) fail("failed-precondition", "Aktif oyun bulunamadı; ipucu harcanmadı.");
  const {board, uses, items} = listed(run, adapter, ctx);
  const id = input.itemId;
  if (uses[id]) fail("already-exists", "Bu ipucu bu tahtada zaten açık.");
  const item = items.find((i) => i.id === id);
  if (!item || !TYPES[item.type] || item.type === "joker") {
    fail("failed-precondition", "Bu ipucu bu tahtada yok; ipucu harcanmadı.");
  }
  const type = TYPES[item.type];
  let result;
  try {
    result = adapter.reveal(run, id, ctx);
  } catch (err) {
    if (err instanceof RewardError) throw err;
    fail("failed-precondition", "Doğrulanmış ipucu üretilemedi; ipucu harcanmadı.");
  }
  if (!result || typeof result.text !== "string" || !result.text) {
    fail("failed-precondition", "Doğrulanmış ipucu üretilemedi; ipucu harcanmadı.");
  }
  const source = input.paymentSource;
  const key = digest([run.id, run.version || run.dataVersion || run.graphVersion || null, board, id]);
  const price = priceOf(item.type, run.hintPolicy.prices).single;
  const stockKey = source === "joker" ? TYPES.joker.key : type.key;
  if (source === "stock" || source === "joker") {
    const stock = e.inventory[stockKey];
    if (!Number.isSafeInteger(stock?.quantity) || stock.quantity < 1) {
      fail("resource-exhausted", source === "joker" ? "Çantanda Joker yok." : "Bu ipucu çantanda yok.");
    }
  } else if (source === "ad") {
    const c = run.hintAdCredits?.[id];
    if (!(c?.board === board && c.n >= (type.strong ? 2 : 1))) {
      fail("resource-exhausted", "Bu ipucu için doğrulanmış reklam hakkı yok.");
    }
  } else if (source === "coins") {
    if (input.expectedPriceCoins !== price) fail("failed-precondition", "Fiyatı yenileyip tekrar seç.");
    if (e.balances.coins < price) fail("resource-exhausted", "Yeterli Coin yok; oyununa devam edebilirsin.");
  } else fail("invalid-argument", "Çantadan, Joker, Coin veya doğrulanmış reklam seç.");

  if (source === "stock" || source === "joker") {
    e.inventory[stockKey] = {...e.inventory[stockKey], quantity: e.inventory[stockKey].quantity - 1};
  } else if (source === "ad") {
    const c = run.hintAdCredits[id]; c.n -= type.strong ? 2 : 1;
    if (!c.n) delete run.hintAdCredits[id];
  } else {
    const before = e.balances.coins; e.balances.coins -= price; e.lifetimeSpent += price;
    e.purchases["hint__" + key] = {txId: "hint__" + key, offerId: type.key, itemId: type.key, itemType: "boost",
      priceCoins: price, balanceBefore: before, balanceAfter: e.balances.coins, purchasedAt: time,
      economyConfigId: "hints-v2", consumed: true};
  }
  (run.hintUses[board] ||= {})[id] = {type: item.type, label: item.label, text: result.text, source,
    requestId: input.requestId ?? null, at: time};
  e.storeUses["hint__" + key] = {runId: run.id, modeId: run.hintPolicy.modeId, board, itemId: id, type: item.type,
    source, requestId: input.requestId ?? null, resultHash: digest(result.text), assistedImpact: true,
    createdAt: time, policyVersion: VERSION};
  run.assisted = true; run.masteryEligible = false; run.leaderboardEligible = false; e.updatedAt = time;
  if (typeof result.apply === "function") result.apply(run);
  return {itemId: id, text: result.text};
}

/** Ad benefit for one menu item; a strong item needs two verified ads. */
function adBenefit(run, itemId, benefit) {
  if (!active(run)) fail("failed-precondition", "Bu oyun eski destek kurallarını kullanıyor.");
  if (run.hintPolicy.ads === false) fail("permission-denied", "Bu oyunda reklamla ipucu alınamaz.");
  if ((run.adGranted || 0) >= adLimit(run)) fail("resource-exhausted", "Bu oyunun reklam hakkı doldu.");
  const item = (adapterOf(run)?.catalog?.[run.hintPolicy.modeId] || []).find((i) => i.id === itemId);
  if (!item) fail("failed-precondition", "Bu ipucu bu oyunda yok.");
  return {...benefit, requireVerifiedAd: true, context: {...benefit.context, hintPolicyVersion: VERSION,
    itemId, type: item.type, board: boardOf(run), modeId: run.hintPolicy.modeId}};
}

function grantAd(run, receipt) {
  const c = receipt.context || {};
  if (!active(run) || c.hintPolicyVersion !== VERSION || c.modeId !== run.hintPolicy.modeId || !TYPES[c.type]) {
    fail("failed-precondition", "Reklam hakkının oyunu veya ipucu eşleşmiyor.");
  }
  const credits = run.hintAdCredits ||= {};
  const old = credits[c.itemId];
  credits[c.itemId] = {type: c.type, board: c.board, n: (old?.board === c.board ? old.n : 0) + 1};
  run.adGranted = (run.adGranted || 0) + 1;
  (run.hintAdReceipts ||= {})[receipt.id] = true;
}

/** A verified ad that can no longer be applied becomes one stock unit; at 99 it stays pending. */
function recoverAd(e, run, receipt, time, canApply = true) {
  const c = receipt.context || {};
  if (c.hintPolicyVersion !== VERSION) return false;
  if (!TYPES[c.type] || c.type === "joker") fail("failed-precondition", "Geçersiz reklam ipucu türü.");
  const key = "hint_ad_recovery__" + receipt.id;
  if (e.storeUses[key] || run?.hintAdReceipts?.[receipt.id]) return true;
  if (canApply && run && !run.finished && run.expiresAt > time) return false;
  if (!addStock(e, c.type, 1, "verified_ad", receipt.id, time)) {
    fail("resource-exhausted", "Çanta dolu; doğrulanmış reklam hakkı bekletiliyor.");
  }
  e.storeUses[key] = {itemId: TYPES[c.type].key, source: "verified_ad_recovery", usedAt: time};
  if (run) {
    run.adGranted = (run.adGranted || 0) + 1; (run.hintAdReceipts ||= {})[receipt.id] = true;
  }
  return true;
}

/** Unused ad credit returns to stock when its board is gone or the run has ended. */
function recoverUnused(e, run, time) {
  if (!active(run)) return;
  const board = boardOf(run); const over = run.finished || run.expiresAt <= time;
  for (const [id, c] of Object.entries(run.hintAdCredits || {})) {
    if (!(c?.n > 0) || !over && c.board === board) continue;
    const take = addStock(e, c.type, c.n, "verified_ad", run.id, time);
    if (!take) continue;
    c.n -= take;
    e.storeUses["hint_unused_ad__" + digest([run.id, id, c.board, time])] = {itemId: TYPES[c.type].key, units: take,
      source: "verified_unused_ad_recovery", runId: run.id, usedAt: time};
    if (!c.n) delete run.hintAdCredits[id];
  }
}

module.exports = {VERSION, MAX_STOCK, TYPES, DEFAULT_PRICES, LEGACY, priceOf, register, active, pin, pinAny, view, use,
  paymentFingerprint, adBenefit, grantAd, recoverAd, recoverUnused, convertLegacy, modeOf};
