"use strict";
const crypto = require("node:crypto");
const {RewardError, dayKey} = require("./rewarded_ads");
const policy = require("./config/energy_v1.json");
const catalog = require("./energy_catalog");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const safeId = (id) => typeof id === "string" && /^[a-zA-Z0-9_-]{1,100}$/.test(id);
const requestId = (id) => typeof id === "string" && /^[a-f0-9]{32}$/.test(id);
function refreshed(raw, time) {
  const e = {balance: policy.capacity, refillAt: time, sessions: {}, unlocked: {}, receipts: {}, ...raw};
  e.sessions ||= {}; e.unlocked ||= {}; e.receipts ||= {};
  if (e.balance < policy.capacity) {
    const n = Math.max(0, Math.floor((time - e.refillAt) / policy.refillMs));
    e.balance = Math.min(policy.capacity, e.balance + n);
    e.refillAt += n * policy.refillMs;
  }
  if (e.balance >= policy.capacity) e.refillAt = time;
  for (const s of Object.values(e.sessions)) {
    if (s.status === "reserved" && s.expiresAt <= time) s.status = "expired";
  }
  for (const [id, s] of Object.entries(e.sessions)) {
    if (s.createdAt < time - 2 * policy.resumeMs) delete e.sessions[id];
  }
  // Daily counters reset independently of the hourly balance.
  const today = dayKey(time);
  if (e.daily?.day !== today) e.daily = {day: today, ads: 0, purchases: 0, pro: false};
  return e;
}
const held = (e) => Object.values(e.sessions).filter((s) => s.status === "reserved").length;
function createService({db, normalize, project = async () => {}, isPro, getRollout, now = Date.now}) {
  async function enabled(uid) {
    const r = {...policy.rollout, ...await getRollout()};
    const bucket = parseInt(crypto.createHash("sha256").update(uid).digest("hex").slice(0, 8), 16) % 100;
    return {active: r.enabled === true && bucket < Math.min(100, Math.max(0, r.percent)),
      minClientVersion: r.minClientVersion,
      sessionModes: Array.isArray(r.sessionModes) ? r.sessionModes.filter((m) => policy.sessionModes.includes(m)) : []};
  }
  async function change(uid, fn) {
    let error;
    const time = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null;
      const state = normalize(raw);
      state.energy = refreshed(state.energy, time);
      state.updatedAt = time;
      try {
        fn(state.energy, state, time); return state;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    const state = normalize(tx.snapshot.val());
    // RTDB omits empty maps from committed snapshots. Restore them for every
    // caller, including status, migrated stories and missing-session checks.
    state.energy = refreshed(state.energy, time);
    await project(db, uid, state);
    return state.energy;
  }
  function view(e, active, pro) {
    const reserved = held(e);
    return {ok: true, enabled: active, serverNow: now(), capacity: policy.capacity,
      balance: e.balance, available: e.balance - reserved, reserved,
      nextRefillAt: e.balance < policy.capacity ? e.refillAt + policy.refillMs : null,
      daily: e.daily, pro, packages: policy.packages, version: policy.version};
  }
  async function status(uid) {
    const e = await change(uid, () => {});
    return view(e, (await enabled(uid)).active, await isPro(uid));
  }
  async function start(uid, input) {
    const rollout = await enabled(uid);
    if (!rollout.active) return {ok: true, enabled: false};
    if (policy.sessionModes.includes(input.mode) && !rollout.sessionModes.includes(input.mode)) {
      return {ok: true, enabled: false};
    }
    if (!Number.isSafeInteger(input.clientVersion) || input.clientVersion < rollout.minClientVersion) {
      fail("failed-precondition", "Enerji sistemi için uygulamayı güncelle.");
    }
    if (!requestId(input.requestId) || !safeId(input.mode) || !safeId(input.unitId || "session")) {
      fail("invalid-argument", "Geçersiz oyun isteği.");
    }
    const unit = catalog.resolve(input.mode, input.unitId);
    if (!unit && !policy.sessionModes.includes(input.mode)) fail("invalid-argument", "Bu oyun birimi bulunamadı.");
    const key = unit ? input.mode + "__" + unit.id : "";
    const old = unit && await catalog.migrated(db, uid, unit);
    const e = await change(uid, (e, s, time) => {
      if (old) e.unlocked[key] ||= {at: time, migrated: true};
      if (key && e.unlocked[key]) return;
      const existing = e.sessions[input.requestId];
      if (existing) {
        if (existing.mode !== input.mode || existing.unitId !== (unit?.id || input.unitId || "session")) {
          fail("invalid-argument", "İstek başka oyuna ait.");
        }
        if (["expired", "cancelled"].includes(existing.status) || existing.expiresAt <= time) {
          fail("failed-precondition", "Oyun isteği sona erdi. Yeniden başlat.");
        }
        return;
      }
      // Two devices opening the same story share one hold.
      if (key && Object.values(e.sessions).some((s) => s.key === key && s.status === "reserved")) return;
      if (e.balance - held(e) < 1) {
        fail("resource-exhausted",
            "Enerjin bitti. Günlük oyunlar ücretsiz; enerji saatte bir yenilenir.");
      }
      e.sessions[input.requestId] = {id: input.requestId, mode: input.mode,
        unitId: unit?.id || input.unitId || "session", key, status: "reserved", createdAt: time,
        expiresAt: time + policy.reservationMs};
    });
    if (key && e.unlocked[key]) return {ok: true, enabled: true, unlocked: true, unitId: unit.id};
    const session = e.sessions[input.requestId] || Object.values(e.sessions).find((s) => s.key === key &&
        s.status === "reserved");
    return {ok: true, enabled: true, serverNow: now(), session};
  }
  async function confirm(uid, input) {
    const rollout = await enabled(uid);
    if (!rollout.active) {
      await cancel(uid, input); return {ok: true, enabled: false};
    }
    if (!requestId(input.sessionId)) fail("invalid-argument", "Geçersiz oturum.");
    const e = await change(uid, (e, state, time) => {
      const s = e.sessions[input.sessionId];
      if (s && !s.key && !rollout.sessionModes.includes(s.mode)) {
        if (s.status === "reserved") s.status = "cancelled";
        return;
      }
      if (!s || !["reserved", "confirmed"].includes(s.status)) {
        fail("failed-precondition",
            "Oyun rezervasyonu sona erdi.");
      }
      if (s.status === "confirmed") {
        if (s.expiresAt <= time) fail("failed-precondition", "Oturum sona erdi.");
        return;
      }
      if (!s.key || !e.unlocked[s.key]) {
        if (e.balance < 1) fail("resource-exhausted", "Enerji yetersiz.");
        if (e.balance === policy.capacity) e.refillAt = time;
        e.balance -= 1;
      }
      s.status = "confirmed"; s.confirmedAt = time; s.expiresAt = time + policy.resumeMs;
      if (s.key) e.unlocked[s.key] ||= {at: time};
    });
    const session = e.sessions[input.sessionId];
    if (session && !session.key && !rollout.sessionModes.includes(session.mode)) {
      return {ok: true, enabled: false};
    }
    return {ok: true, serverNow: now(), session};
  }
  async function resume(uid, input) {
    if (!requestId(input.sessionId) || !safeId(input.mode)) fail("invalid-argument", "Geçersiz oturum.");
    const rollout = await enabled(uid);
    if (!rollout.active || (policy.sessionModes.includes(input.mode) &&
        !rollout.sessionModes.includes(input.mode))) return {ok: true, enabled: false};
    const e = await change(uid, () => {}); const s = e.sessions[input.sessionId];
    if (!s || s.status !== "confirmed" || s.expiresAt <= now() || s.mode !== input.mode) {
      fail("not-found",
          "Devam edilebilir oturum yok.");
    }
    return {ok: true, enabled: true, serverNow: now(), session: s};
  }
  async function cancel(uid, input) {
    await change(uid, (e) => {
      if (e.sessions[input.sessionId]?.status === "reserved") e.sessions[input.sessionId].status = "cancelled";
    });
    return {ok: true};
  }
  async function purchase(uid, input) {
    if (!requestId(input.requestId) || !Object.hasOwn(policy.packages, input.packageId || "")) {
      fail("invalid-argument", "Geçersiz enerji paketi.");
    }
    if (!(await enabled(uid)).active) fail("failed-precondition", "Enerji sistemi henüz açık değil.");
    const offer = policy.packages[input.packageId]; const key = "energy__" + input.requestId;
    await change(uid, (e, s, time) => {
      if (s.purchases[key]) {
        if (s.purchases[key].offerId !== input.packageId) fail("invalid-argument", "Paket isteği eşleşmiyor.");
        return;
      }
      if (e.daily.purchases >= policy.purchaseLimit) fail("resource-exhausted", "Günlük 2 dolum hakkını kullandın.");
      if (e.balance + offer.energy > policy.capacity) {
        fail("failed-precondition",
            "Paketin tamamı için enerji alanı yok.");
      }
      if (s.balances.coins < offer.coins) fail("failed-precondition", "Link Coin yetersiz.");
      const before = s.balances.coins;
      s.balances.coins -= offer.coins; s.lifetimeSpent += offer.coins;
      s.purchases[key] = {txId: key, offerId: input.packageId, itemId: "energy", itemType: "energy",
        priceCoins: offer.coins, balanceBefore: before, balanceAfter: s.balances.coins, purchasedAt: time,
        economyConfigId: "energy-v1"};
      e.balance += offer.energy; e.daily.purchases += 1;
      if (e.balance === policy.capacity) e.refillAt = time;
    });
    return status(uid);
  }
  async function proBonus(uid) {
    if (!(await enabled(uid)).active || !await isPro(uid)) fail("permission-denied", "Etkin Pro üyeliği gerekli.");
    await change(uid, (e, s, time) => {
      if (e.daily.pro) return;
      if (e.balance + policy.proAmount > policy.capacity) {
        fail("failed-precondition",
            "Bonus için en az 2 enerji alanı gerekli.");
      }
      e.balance += policy.proAmount; e.daily.pro = true;
      if (e.balance === policy.capacity) e.refillAt = time;
    });
    return status(uid);
  }
  async function prepareReward(uid) {
    const v = await status(uid);
    if (!v.enabled || v.daily.ads >= policy.adLimit || v.balance > 4) {
      fail("failed-precondition",
          "Enerji bonusu şu an alınamaz.");
    }
    return {amount: 0, claimKey: "energy_" + v.daily.day + "_" + v.daily.ads, context: {day: v.daily.day,
      slot: v.daily.ads}};
  }
  async function settleReward(uid, receipt) {
    await change(uid, (e, s, time) => {
      if (e.receipts[receipt.id]) return;
      // Verified receipts are durable: if capacity is full, the outbox retries later.
      if (e.balance + 2 > policy.capacity) {
        fail("failed-precondition",
            "Doğrulanmış bonus bekliyor. Enerji kullandıktan sonra yeniden dene.");
      }
      const day = receipt.context?.day;
      const used = Object.values(e.receipts).filter((r) => r.day === day).length;
      if (used >= 2) fail("resource-exhausted", "Bu günün enerji bonusları alındı.");
      e.balance += 2; e.receipts[receipt.id] = {day, at: time};
      if (day === e.daily.day) e.daily.ads += 1;
      if (e.balance === policy.capacity) e.refillAt = time;
    });
  }
  async function requireStory(uid, mode, id, clientVersion) {
    const r = await enabled(uid);
    if (!r.active) return;
    if (!Number.isSafeInteger(clientVersion) || clientVersion < r.minClientVersion) {
      fail("failed-precondition",
          "Devam etmek için uygulamayı güncelle.");
    }
    const unit = catalog.resolve(mode, id);
    if (!unit) fail("invalid-argument", "Hikâye bulunamadı.");
    const legacy = await catalog.migrated(db, uid, unit);
    const e = await change(uid, (e, s, time) => {
      if (legacy) e.unlocked[mode + "__" + unit.id] ||= {at: time, migrated: true};
    });
    if (!e.unlocked[mode + "__" + unit.id]) fail("permission-denied", "Önce bu hikâyeyi enerjiyle aç.");
  }
  return {status, start, confirm, resume, cancel, purchase, proBonus, prepareReward, settleReward, requireStory,
    enabled};
}
module.exports = {createService, refreshed, held, policy};
