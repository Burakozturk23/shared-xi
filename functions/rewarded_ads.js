"use strict";
const crypto = require("node:crypto");
const PLACEMENTS = new Set(["loto_result", "cinko_result"]);
const TICKET_MS = 20 * 60000;
const RETENTION_MS = 48 * 3600000;
class RewardError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (v) => crypto.createHash("sha256").update(v).digest("hex");
function dayKey(now) {
  return new Intl.DateTimeFormat("en-CA", {timeZone: "Europe/Istanbul", year: "numeric", month: "2-digit",
    day: "2-digit"}).format(new Date(now));
}
function stateOf(raw) {
  return {version: 1, days: {}, tickets: {}, pending: {}, lastIssuedAt: 0, ...raw};
}
function normalizeUnit(value) {
  return typeof value === "string" && /^ca-app-pub-\d{16}\/\d{10}$/.test(value) &&
    !value.startsWith("ca-app-pub-3940256099942544/") ? value : "";
}
function day(state, key) {
  return state.days[key] ||= {earned: 0, issued: 0};
}
function reserved(state, key, now) {
  return Object.values(state.tickets).filter((t) => t.dayKey === key && t.status === "pending" &&
    t.expiresAt > now).length;
}
function prune(state, now) {
  for (const [id, ticket] of Object.entries(state.tickets)) {
    if (ticket.createdAt < now - RETENTION_MS && !state.pending[id]) delete state.tickets[id];
  }
  for (const key of Object.keys(state.days)) {
    if (key < dayKey(now - RETENTION_MS)) delete state.days[key];
  }
}
function policyOf(config, units, platform) {
  const source = config.sources.rewarded_coin;
  return {enabled: source.enabled, amount: source.amount, limit: Math.min(2, source.dailyLimit),
    configId: config.configId, unitId: normalizeUnit(units[platform])};
}

// All limits + receipts commit in one server-private transaction. Currency is
// settled via the existing idempotent wallet, with a durable retryable outbox.
function createService({db, getConfig, units, grantCoins, isLinked, isPro, now = Date.now,
  randomId = () => crypto.randomBytes(24).toString("hex")}) {
  const ref = (uid) => db.ref("rewardedAdState/" + uid);
  async function transact(uid, change) {
    let error;
    const tx = await ref(uid).transaction((raw) => {
      error = null;
      const state = stateOf(raw);
      try {
        change(state);
        return state;
      } catch (e) {
        error = e;
        return raw; // allow RTDB to retry a cold null cache against real data
      }
    });
    if (error) throw error;
    return stateOf(tx.snapshot.val());
  }
  async function settle(uid) {
    const state = stateOf((await ref(uid).get()).val());
    if (!Object.keys(state.pending).length || !await isLinked(uid)) return;
    for (const [id, receipt] of Object.entries(state.pending)) {
      await grantCoins(uid, "reward_ad__" + id, receipt.sourceType, receipt.placement,
          receipt.amount, receipt.configId);
      await transact(uid, (latest) => {
        if (latest.tickets[id]) latest.tickets[id].status = "credited";
        delete latest.pending[id];
      });
    }
  }
  function publicTicket(ticket) {
    if (!ticket) return null;
    const status = ticket.status === "pending" && ticket.expiresAt <= now() ? "expired" : ticket.status;
    return {id: ticket.id, amount: ticket.amount, status,
      unitId: ticket.unitId, placement: ticket.placement, expiresAt: ticket.expiresAt};
  }
  async function status(uid, platform, ticketId) {
    if (ticketId != null && !/^[a-f0-9]{48}$/.test(ticketId)) fail("invalid-argument", "Geçersiz reklam kaydı.");
    await settle(uid);
    const time = now();
    const state = stateOf((await ref(uid).get()).val());
    const policy = policyOf(await getConfig(), units, platform);
    const key = dayKey(time);
    const pro = await isPro(uid);
    const ticket = ticketId ? state.tickets[ticketId] : Object.values(state.tickets)
        .filter((t) => t.status === "verified" || t.status === "pending" && t.expiresAt > time)
        .sort((a, b) => b.createdAt - a.createdAt)[0];
    return {ok: true, dayKey: key, resetTimeZone: "Europe/Istanbul", pro,
      enabled: policy.enabled, testingOnly: !policy.unitId,
      amount: policy.amount, dailyLimit: policy.limit,
      remaining: Math.max(0, policy.limit - day(state, key).earned - reserved(state, key, time)),
      pendingCoins: Object.values(state.pending).reduce((sum, p) => sum + p.amount, 0),
      ticket: publicTicket(ticket)};
  }
  async function prepare(uid, platform, placement, requestId) {
    if (!PLACEMENTS.has(placement) || !["android", "ios"].includes(platform) ||
        typeof requestId !== "string" || !/^[a-f0-9]{32}$/.test(requestId)) {
      fail("invalid-argument", "Geçersiz reklam teklifi.");
    }
    const time = now();
    const policy = policyOf(await getConfig(), units, platform);
    const pro = await isPro(uid);
    if (!policy.enabled) fail("failed-precondition", "Bonuslar şu anda kapalı.");
    if (!pro && !policy.unitId) fail("failed-precondition", "Reklam bağlantısı henüz hazır değil.");
    const key = dayKey(time);
    const id = randomId();
    const state = await transact(uid, (s) => {
      prune(s, time);
      if (Object.values(s.tickets).some((t) => t.requestId === requestId)) return;
      const d = day(s, key);
      if (d.earned + reserved(s, key, time) >= policy.limit) {
        fail("resource-exhausted", "Günlük bonus sınırına ulaştın.");
      }
      if (d.issued >= 12 || s.lastIssuedAt > time - 30000) {
        fail("resource-exhausted", "Kısa bir süre sonra tekrar dene.");
      }
      // One outstanding watch at a time across both placements/devices.
      if (reserved(s, key, time) > 0) fail("failed-precondition", "Önceki reklamın doğrulaması bekleniyor.");
      s.lastIssuedAt = time;
      d.issued += 1;
      const ticket = {id, requestId, placement, dayKey: key, amount: policy.amount,
        configId: policy.configId, dailyLimit: policy.limit, unitId: policy.unitId,
        createdAt: time, expiresAt: time + TICKET_MS, status: pro ? "verified" : "pending",
        sourceType: pro ? "pro_daily_bonus" : "rewarded_coin"};
      s.tickets[id] = ticket;
      if (pro) {
        d.earned += 1;
        s.pending[id] = {...ticket};
      }
    });
    const ticket = Object.values(state.tickets).find((t) => t.requestId === requestId);
    await settle(uid);
    return {ok: true, pro, userId: uid, ticket: publicTicket(ticket)};
  }
  async function cancel(uid, id) {
    if (!/^[a-f0-9]{48}$/.test(id || "")) fail("invalid-argument", "Geçersiz reklam kaydı.");
    await transact(uid, (s) => {
      if (s.tickets[id]?.status === "pending") s.tickets[id].status = "cancelled";
    });
    return {ok: true};
  }
  async function accept(event) {
    const uid = event.user_id;
    const id = event.custom_data;
    const time = now();
    await transact(uid, (s) => {
      const t = s.tickets[id];
      if (!t) fail("not-found", "Reward ticket not found");
      // Unit, time and identity came from cryptographically verified Google data.
      if (event.ad_unit !== t.unitId && event.ad_unit !== t.unitId.split("/")[1]) {
        fail("permission-denied", "Ad unit mismatch");
      }
      if (event.timestamp < t.createdAt - 60000 || event.timestamp > t.expiresAt ||
          time - event.timestamp > 24 * 3600000 || t.sourceType !== "rewarded_coin") {
        fail("permission-denied", "Reward ticket expired");
      }
      const transactionHash = hash(event.transaction_id);
      if (["verified", "credited"].includes(t.status)) {
        if (t.transactionHash !== transactionHash) fail("already-exists", "Ticket already used");
        return;
      }
      if (Object.values(s.tickets).some((other) => other.transactionHash === transactionHash)) {
        fail("already-exists", "Transaction already used");
      }
      const d = day(s, t.dayKey);
      if (d.earned >= t.dailyLimit) fail("resource-exhausted", "Daily limit reached");
      d.earned += 1;
      t.status = "verified";
      t.verifiedAt = time;
      t.transactionHash = transactionHash;
      s.pending[id] = {...t};
    });
    await settle(uid);
    return {ok: true};
  }
  return {status, prepare, cancel, accept, settle};
}
module.exports = {createService, RewardError, dayKey, policyOf, normalizeUnit};
