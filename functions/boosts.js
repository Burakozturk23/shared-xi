"use strict";
const crypto = require("node:crypto");
const {RewardError} = require("./rewarded_ads");
// Only adapters which atomically mutate the canonical run and wallet may opt in.
// Neither a client mode string nor an arbitrary round ID creates an entitlement.
const VERSION = 1;
const specs = [
  ["first_letter", "İlk harf", 25, 65, true, "Temel"],
  ["last_letter", "Son harf", 25, 65, true, "Temel"],
  ["anagram", "Harf karışımı", 60, 150, false, "Güçlü"],
  ["basic", "Temel bilgi", 25, 65, true, "Temel"],
  ["eliminate", "Tek seçenek ele", 35, 90, true, "Taktiksel"],
  ["connection", "Bağlantı yardımı", 40, 105, true, "Taktiksel"],
  ["strong", "Güçlü bilgi", 60, 150, false, "Güçlü"],
];
const products = Object.fromEntries(specs.map(([id, title, priceCoins, bundlePrice, ads, category]) =>
  ["boost_" + id, {id: "boost_" + id, title, priceCoins, bundlePrice, ads, category}]));
const modes = {
  coach_xi: ["basic", "connection"], squad_vault: ["basic", "strong"], letter11: ["basic", "connection"],
  career: ["basic", "connection"], transfer: ["basic", "first_letter"],
  mystery: ["basic"], mastermind: ["connection"], fake_endless: ["eliminate", "connection"],
  burst_survival: ["basic"], pyramid: ["strong"], matching: ["strong"],
  daily_lingo: ["basic"], daily_anagram: ["basic", "first_letter"],
  passa_daily: ["basic"], passa_weekly: ["basic"],
  higher_lower_training: ["basic"], blind_ranking_training: ["basic"],
  player_journey: ["basic", "strong"], what_if: ["basic", "strong"], ucl_moments: ["basic", "strong"],
  nostalgia: ["basic", "strong"], international_glory: ["basic", "strong"],
  dynasties: ["basic", "strong"], football_docu: ["basic", "strong"], derby_day: ["basic", "strong"],
};
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const digest = (x) => crypto.createHash("sha256").update(JSON.stringify(x)).digest("hex");
const modeOf = (run) => run.training === true && ["higher_lower", "blind_ranking"].includes(run.mode) ?
  run.mode + "_training" : run.mode === "burst" ? "burst_" + run.style : run.mode;
function enabled(policy, uid) {
  return policy?.enabled === true && (policy.betaUids?.[uid] === true ||
    policy.public === true && Number.isInteger(policy.percent) &&
    parseInt(digest(uid).slice(0, 8), 16) % 100 < Math.max(0, Math.min(100, policy.percent)));
}
async function policyFor(db, uid, linked) {
  if (!linked) return null;
  const p = (await db.ref("runtimeConfig/boosts").get()).val();
  return enabled(p, uid) ? p : null;
}
function pin(run, policy) {
  const mode = modeOf(run);
  if (!policy || !modes[mode] || policy.readyModes?.[mode] !== true) return;
  run.boostPolicy = {version: VERSION, modeId: mode, daily: run.entry === "daily",
    products: Object.fromEntries(modes[mode].map((id) => {
      const p = products["boost_" + id]; return [p.id, {...p}];
    }))};
  run.boostUses = {}; run.assisted = false;
}
const paid = (run) => run?.boostPolicy?.version === VERSION;
function adCredits(run, sku) {
  const typed = Object.values(run.adProducts || {}).reduce((sum, n) => sum + n, 0);
  return (run.adRecoveryPending?.[sku] ? 0 : run.adProducts?.[sku] || 0) + Math.max(0, (run.adCredits || 0) - typed);
}
function view(run) {
  return paid(run) ? {version: VERSION, products: Object.values(run.boostPolicy.products),
    adCreditsByProduct: Object.fromEntries(Object.keys(run.boostPolicy.products).map((sku) =>
      [sku, products[sku].ads ? adCredits(run, sku) : 0])),
    recoveryPending: Object.keys(run.adRecoveryPending || {}).filter((sku) => run.adProducts?.[sku] > 0).length > 0,
    adLimit: run.boostPolicy.daily ? 1 : 2,
    adRemaining: Math.max(0, (run.boostPolicy.daily ? 1 : 2) - (run.adGranted || 0)), assisted: run.assisted === true,
    resultLabel: run.assisted ? "Yardımlı" : "Yardımsız", masteryEligible: !run.assisted} : null;
}
function paymentFingerprint(input) {
  return [input.paymentSource ?? null, input.boostId ?? null, input.expectedPriceCoins ?? null];
}
// Called inside the SAME economyState transaction as hint generation. Throwing
// afterwards aborts the entire debit, receipt, reveal and assisted transition.
function consume(e, run, input, sku, target, result, time) {
  if (!paid(run)) fail("failed-precondition", "Bu oyun eski destek kurallarını kullanıyor.");
  if (run.finished || run.expiresAt <= time || run.boostPolicy.modeId !== modeOf(run)) {
    fail("failed-precondition", "Aktif oyun bulunamadı; destek harcanmadı.");
  }
  const product = run.boostPolicy.products[sku];
  if (!product || !modes[modeOf(run)]?.includes(sku.replace("boost_", ""))) {
    fail("permission-denied", "Bu modda bu destek kullanılamaz.");
  }
  if (input.boostId !== sku || input.boost) fail("invalid-argument", "Seçtiğin destek bu ipucuyla eşleşmiyor.");
  if (!result || typeof result !== "object" || typeof target !== "string" || !target) {
    fail("failed-precondition", "Doğrulanmış ipucu üretilemedi; destek harcanmadı.");
  }
  const key = digest([run.id, run.version || run.dataVersion || run.graphVersion, target]);
  const previous = (run.boostUses ||= {})[key];
  if (previous) fail("already-exists", "Bu ipucu zaten açık. Oyunu yenile.");
  const source = input.paymentSource;
  const receipt = {runId: run.id, modeId: modeOf(run),
    puzzleVersion: run.version || run.dataVersion || run.graphVersion,
    boostId: sku, targetId: target, source, requestId: input.requestId, resultHash: digest(result),
    assistedImpact: true, createdAt: time, policyVersion: VERSION};
  if (source === "stock") {
    const item = e.inventory[sku];
    if (item?.itemType !== "boost" || !Number.isSafeInteger(item.quantity) || item.quantity < 1) {
      fail("resource-exhausted", "Bu destek çantanda yok.");
    }
    item.quantity--;
  } else if (source === "coins") {
    if (input.expectedPriceCoins !== product.priceCoins) fail("failed-precondition", "Fiyatı yenileyip tekrar seç.");
    if (e.balances.coins < product.priceCoins) {
      fail("resource-exhausted", "Yeterli Coin yok; oyununa devam edebilirsin.");
    }
    const before = e.balances.coins; e.balances.coins -= product.priceCoins;
    e.lifetimeSpent += product.priceCoins;
    e.purchases["boost__" + key] = {txId: "boost__" + key, offerId: sku, itemId: sku, itemType: "boost",
      priceCoins: product.priceCoins, balanceBefore: before, balanceAfter: e.balances.coins,
      purchasedAt: time, economyConfigId: "boosts-v1", consumed: true};
  } else if (source === "ad") {
    if (!product.ads || !(adCredits(run, sku) > 0)) {
      fail("resource-exhausted", "Bu destek türü için doğrulanmış reklam hakkı yok.");
    }
    if (run.adProducts?.[sku] > 0) run.adProducts[sku]--;
    run.adCredits--;
  } else fail("invalid-argument", "Çantadan, Coin veya doğrulanmış reklam seç.");
  run.assisted = true; run.masteryEligible = false; run.leaderboardEligible = false;
  run.boostUses[key] = receipt; e.storeUses["boost__" + key] = receipt; e.updatedAt = time;
}
function adBenefit(run, benefit, sku) {
  if (!paid(run)) return benefit;
  sku ||= Object.keys(run.boostPolicy.products).find((id) => products[id].ads);
  if (!run.boostPolicy.products[sku]?.ads) fail("permission-denied", "Bu destek reklamla alınamaz.");
  if (run.adGranted >= (run.boostPolicy.daily ? 1 : 2)) fail("resource-exhausted", "Bu oyunun reklam hakkı doldu.");
  return {...benefit, requireVerifiedAd: true, context: {...benefit.context, boostPolicyVersion: VERSION,
    boostId: sku, modeId: modeOf(run), puzzleVersion: run.version || run.dataVersion || run.graphVersion}};
}
function grantAd(run, receipt) {
  const sku = receipt.context?.boostId;
  if (paid(run) && sku) {
    if (!run.boostPolicy.products[sku]?.ads || receipt.context.modeId !== modeOf(run)) {
      fail("failed-precondition", "Reklam hakkının oyun veya destek türü eşleşmiyor.");
    }
    run.adProducts ||= {}; run.adProducts[sku] = (run.adProducts[sku] || 0) + 1;
    (run.adScopes ||= {})[sku] = {...receipt.context};
  }
  run.adGranted++; run.adCredits++; (run.adReceipts ||= {})[receipt.id] = true;
}
// A verified ad arriving after expiry remains owned; it becomes a basic stock
// unit instead of disappearing. If stock is full, keep the SSV outbox pending.
function recoverAd(e, run, receipt, time, sku = "boost_basic", canApply = true) {
  if (receipt.context?.boostPolicyVersion !== VERSION) return false;
  if (receipt.context.boostId) {
    if (!products[receipt.context.boostId]?.ads) fail("failed-precondition", "Geçersiz reklam destek türü.");
    sku = receipt.context.boostId;
  }
  const key = "boost_ad_recovery__" + receipt.id;
  if (e.storeUses[key] || run?.adReceipts?.[receipt.id]) return true;
  if (canApply && run && !run.finished && run.expiresAt > time) return false;
  const item = e.inventory[sku]; const quantity = item?.quantity || 0;
  if (quantity >= 99) fail("resource-exhausted", "Çanta dolu; doğrulanmış reklam hakkı bekletiliyor.");
  e.inventory[sku] = {...item, itemId: sku, itemType: "boost", quantity: quantity + 1,
    sourceType: "verified_ad", sourceId: receipt.id, acquiredAt: item?.acquiredAt || time};
  e.storeUses[key] = {itemId: sku, source: "verified_ad_recovery", usedAt: time};
  if (run) {
    run.adGranted = (run.adGranted || 0) + 1;
    run.adReceipts ||= {}; run.adReceipts[receipt.id] = true;
  }
  return true;
}
// Transfer already-verified but unused typed credit when its question/phase
// becomes unusable. Full stock keeps the credit in the run, never blocking play
// or allowing it to be spent on a later question. Retried transitions are safe.
function recoverUnused(e, run, time, usable = () => true) {
  if (!paid(run)) return;
  for (const [sku, quantity] of Object.entries(run.adProducts || {})) {
    if (!Number.isSafeInteger(quantity) || quantity <= 0 || !products[sku]?.ads) continue;
    if (!run.adRecoveryPending?.[sku] && !run.finished && run.expiresAt > time &&
      usable(sku, run.adScopes?.[sku] || {})) continue;
    (run.adRecoveryPending ||= {})[sku] = true;
    const item = e.inventory[sku]; const count = Math.min(quantity, Math.max(0, 99 - (item?.quantity || 0)));
    if (!count) continue;
    e.inventory[sku] = {...item, itemId: sku, itemType: "boost", quantity: (item?.quantity || 0) + count,
      sourceType: "verified_ad", sourceId: run.id, acquiredAt: item?.acquiredAt || time};
    run.adProducts[sku] -= count; run.adCredits = Math.max(0, run.adCredits - count);
    (run.adRecovered ||= {})[sku] = (run.adRecovered?.[sku] || 0) + count;
    const key = "boost_unused_ad__" + digest([run.id, sku, run.adRecovered[sku]]);
    e.storeUses[key] = {itemId: sku, units: count, source: "verified_unused_ad_recovery", runId: run.id, usedAt: time};
    if (!run.adProducts[sku]) delete run.adRecoveryPending[sku];
  }
}
const offers = specs.filter(([id]) => !["first_letter", "last_letter", "anagram"].includes(id)).flatMap(
    ([id, title, price, bundle, , category], i) => [1, 3].map((units) => ({
      offerId: `boost_${id}_${units}`, itemId: "boost_" + id, itemType: "boost",
      title: units === 3 ? title + " · 3 kullanım" : title,
      subtitle: "Yalnız desteklenen solo oyunlarda; sonuç Yardımlı olarak kaydedilir.",
      badge: units === 3 ? "3’LÜ PAKET" : "TEK KULLANIM",
      units, priceCoins: units === 1 ? price : bundle, enabled: true, oneTime: false,
      category, sortOrder: 200 + i * 2 + (units === 3 ? 1 : 0),
      modes: Object.keys(modes).filter((mode) => modes[mode].includes(id)),
    })));
module.exports = {VERSION, products, modes, offers, enabled, policyFor, pin, paid, view,
  paymentFingerprint, consume, adBenefit, grantAd, recoverAd, recoverUnused};
