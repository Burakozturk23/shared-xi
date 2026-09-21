"use strict";
const crypto = require("node:crypto");
const PRODUCTS = Object.freeze({
  linkball_coins_500: 500,
  linkball_coins_1400: 1400,
  linkball_coins_3200: 3200,
});
const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
const accountId = (uid) => hash("linkball-play:" + uid);

// No Play API calls during function discovery. Injected transport also keeps
// tests offline. The private token record survives projection/consume failures.
function createService({db, play, normalize, project, ErrorType, now = Date.now}) {
  const fail = (code, message) => {
    throw new ErrorType(code, message);
  };
  async function rateLimit(uid) {
    const minute = Math.floor(now() / 60000);
    const tx = await db.ref("coinPurchaseRate/" + uid).transaction((old) => {
      const value = old && old.minute === minute ? old : {minute, count: 0};
      if (value.count >= 20) return;
      return {...value, count: value.count + 1};
    });
    if (!tx.committed) fail("resource-exhausted", "Bir dakika sonra tekrar dene.");
  }
  async function settle(record, tokenHash, refunded = false) {
    if (!record.uid || record.deleted) return null;
    const ref = db.ref("economyState/" + record.uid);
    const grantKey = "play_coin__" + tokenHash;
    const refundKey = "play_refund__" + tokenHash;
    const tx = await ref.transaction((raw) => {
      const state = normalize(raw);
      const exists = state.claims[grantKey];
      const key = refunded ? refundKey : grantKey;
      if (state.claims[key] || (!refunded && state.claims[refundKey])) return state;
      // A refund arriving before fulfillment permanently blocks a later grant.
      const amount = refunded ? (exists ? -exists.amount : 0) : record.amount;
      const before = state.balances.coins;
      state.balances.coins += amount;
      if (!refunded) state.lifetimeEarned += amount;
      state.claims[key] = {
        txId: key, sourceType: refunded ? "google_play_refund" : "google_play_purchase",
        sourceId: tokenHash, productId: record.productId, amount,
        balanceBefore: before, balanceAfter: state.balances.coins,
        claimedAt: now(), economyConfigId: "play-coins-v1",
      };
      state.createdAt ||= now();
      state.updatedAt = now();
      return state;
    });
    const state = normalize(tx.snapshot.val());
    await project(db, record.uid, state);
    return state;
  }
  async function fulfill(record, tokenHash) {
    const latest = (await db.ref("coinPurchaseTokens/" + tokenHash).get()).val();
    if (!latest || latest.deleted || latest.refunded) {
      fail("failed-precondition", "Satın alma iptal edilmiş veya hesap silinmiş.");
    }
    const state = await settle(latest, tokenHash);
    if (state.claims["play_refund__" + tokenHash]) {
      fail("failed-precondition", "Satın alma iade edilmiş.");
    }
    // Consume only after the canonical wallet commit. On interruption, the
    // worker verifies consumption again; never blindly grants a second time.
    const current = await play.get(record.productId, record.token);
    if (current.purchaseState === 1) {
      await revoke(tokenHash);
      fail("failed-precondition", "Satın alma iade edilmiş.");
    }
    if (current.purchaseState !== 0) fail("unavailable", "Ödeme onayı bekleniyor.");
    if (current.consumptionState !== 1) await play.consume(record.productId, record.token);
    await db.ref("coinPurchaseTokens/" + tokenHash).transaction((value) => {
      if (!value) return value;
      return {...value, consumed: true, updatedAt: now()};
    });
    await db.ref("coinPurchaseWork/" + tokenHash).set(null);
    return {ok: true, productId: record.productId, amount: record.amount,
      coins: state.balances.coins, consumed: true};
  }
  async function verify(uid, productId, token) {
    if (!Object.hasOwn(PRODUCTS, productId) || typeof token !== "string" ||
        token.length < 16 || token.length > 4096) fail("invalid-argument", "Geçersiz satın alma.");
    await rateLimit(uid);
    const tokenHash = hash(token);
    const ref = db.ref("coinPurchaseTokens/" + tokenHash);
    const previous = (await ref.get()).val();
    if (previous && (previous.uid !== uid || previous.productId !== productId || previous.deleted)) {
      fail("permission-denied", "Satın alma farklı bir hesaba bağlı.");
    }
    if (previous && previous.refunded) fail("failed-precondition", "Satın alma iade edilmiş.");
    const purchase = await play.get(productId, token);
    if (purchase.purchaseState !== 0) {
      if (previous && purchase.purchaseState === 1) await revoke(tokenHash);
      fail("failed-precondition", "Ödeme tamamlanmamış veya iptal edilmiş.");
    }
    if (purchase.obfuscatedExternalAccountId !== accountId(uid) ||
        (purchase.productId && purchase.productId !== productId) ||
        (purchase.quantity ?? 1) !== 1 || ![0, 1].includes(purchase.consumptionState)) {
      fail("permission-denied", "Satın alma hesabı veya ürün eşleşmiyor.");
    }
    if (!previous && purchase.consumptionState === 1) {
      fail("failed-precondition", "Daha önce tüketilmiş satın alma doğrulanamadı.");
    }
    // Index first: a crash leaves a harmless orphan, not an unrepairable grant.
    await db.ref("coinPurchaseWork/" + tokenHash).set(true);
    await db.ref("coinPurchaseByUser/" + uid + "/" + tokenHash).set(true);
    const tx = await ref.transaction((old) => {
      if (old) return old;
      return {uid, productId, token, amount: PRODUCTS[productId], createdAt: now(),
        testPurchase: purchase.purchaseType === 0, consumed: false};
    });
    const record = tx.snapshot.val();
    if (record.uid !== uid || record.productId !== productId || record.deleted || record.refunded) {
      fail("permission-denied", "Satın alma kullanılamıyor.");
    }
    return fulfill(record, tokenHash);
  }
  async function revoke(tokenHash) {
    const tx = await db.ref("coinPurchaseTokens/" + tokenHash).transaction((old) => {
      // Tombstone prevents late client delivery after a refund notification.
      return {...(old || {}), refunded: true, updatedAt: now()};
    });
    await settle(tx.snapshot.val(), tokenHash, true);
    await db.ref("coinPurchaseWork/" + tokenHash).set(null);
  }
  async function retry(tokenHash) {
    const record = (await db.ref("coinPurchaseTokens/" + tokenHash).get()).val();
    if (!record || record.deleted) {
      await db.ref("coinPurchaseWork/" + tokenHash).set(null);
      return;
    }
    if (record.refunded) return revoke(tokenHash);
    return fulfill(record, tokenHash);
  }
  return {verify, revoke, retry};
}
module.exports = {PRODUCTS, hash, accountId, createService};
