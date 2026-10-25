"use strict";
const crypto = require("node:crypto");
const THREE_HINTS = ["burst_survival_hint", "fake_club_hint", "mystery_hint", "chain_hint", "career_hint",
  "transfer_hint", "daily_words_hint",
  "coach11_hint", "letter11_hint", "vault_hint"];
const PLACEMENTS = new Set(["loto_result", "cinko_result", "daily_hint", "daily_double", "daily_streak",
  "story_hint", "story_double", "what_if_hint", "what_if_double", "energy_refill", "quiz_hint", ...THREE_HINTS]);
const HINT_PLACEMENTS = new Set([...THREE_HINTS, "daily_hint", "quiz_hint", "story_hint", "what_if_hint"]);
// Retained legacy tickets count toward the same Istanbul-day assistance budget.
function hintCount(state, key, time, includePending) {
  const tickets = Object.values(state.tickets).filter((t) => t.dayKey === key && HINT_PLACEMENTS.has(t.placement));
  const earned = tickets.filter((t) => ["verified", "credited"].includes(t.status));
  const legacySolo = (state.days[key + "__solo_hints"]?.earned || 0) + THREE_HINTS.reduce((n, p) =>
    n + (state.days[key + "__" + p]?.earned || 0), 0);
  return Math.max(legacySolo, earned.filter((t) => THREE_HINTS.includes(t.placement)).length) +
    earned.filter((t) => !THREE_HINTS.includes(t.placement)).length +
    (includePending ? tickets.filter((t) => t.status === "pending" && t.expiresAt > time).length : 0);
}
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
  return Object.values(state.tickets).filter((t) => (t.counterKey || t.dayKey) === key && t.status === "pending" &&
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
  randomId = () => crypto.randomBytes(24).toString("hex"), prepareDailyReward, settleDailyReward,
  prepareStoryReward, settleStoryReward, prepareWhatIfReward, settleWhatIfReward,
  prepareEnergyReward, settleEnergyReward, prepareQuizReward, settleQuizReward,
  prepareThreeReward, settleThreeReward}) {
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
    if (!Object.keys(state.pending).length) return;
    const linked = await isLinked(uid);
    for (const [id, receipt] of Object.entries(state.pending)) {
      if (receipt.placement === "energy_refill") {
        try {
          await settleEnergyReward(uid, receipt);
        } catch (error) {
          if (error.code === "failed-precondition") continue; // capacity: durable pending bonus
          throw error;
        }
      } else if (THREE_HINTS.includes(receipt.placement)) {
        await settleThreeReward(uid, receipt);
      } else if (receipt.placement === "quiz_hint") {
        await settleQuizReward(uid, receipt);
      } else if (receipt.placement.startsWith("what_if_")) {
        if (!settleWhatIfReward) continue;
        await settleWhatIfReward(uid, receipt);
      } else if (receipt.placement.startsWith("story_")) {
        if (!settleStoryReward) continue;
        await settleStoryReward(uid, receipt);
      } else if (receipt.placement.startsWith("daily_")) {
        if (!settleDailyReward) continue;
        await settleDailyReward(uid, receipt);
      } else {
        if (!linked) continue;
        await grantCoins(uid, "reward_ad__" + id, receipt.sourceType, receipt.placement,
            receipt.amount, receipt.configId);
      }
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
        .filter((t) => !t.placement.startsWith("daily_") && !t.placement.startsWith("story_") &&
          !t.placement.startsWith("what_if_") &&
          !["energy_refill", "quiz_hint", ...THREE_HINTS].includes(t.placement) &&
          (t.status === "verified" || t.status === "pending" && t.expiresAt > time))
        .sort((a, b) => b.createdAt - a.createdAt)[0];
    return {ok: true, dayKey: key, resetTimeZone: "Europe/Istanbul", pro,
      enabled: policy.enabled, testingOnly: !policy.unitId,
      amount: policy.amount, dailyLimit: policy.limit,
      remaining: Math.max(0, policy.limit - day(state, key).earned - reserved(state, key, time)),
      pendingCoins: Object.values(state.pending).reduce((sum, p) => sum + p.amount, 0),
      ticket: publicTicket(ticket)};
  }
  async function prepare(uid, platform, placement, requestId, context) {
    if (!PLACEMENTS.has(placement) || !["android", "ios"].includes(platform) ||
        typeof requestId !== "string" || !/^[a-f0-9]{32}$/.test(requestId)) {
      fail("invalid-argument", "Geçersiz reklam teklifi.");
    }
    const checkExisting = (existing) => {
      if (existing.placement !== placement) fail("invalid-argument", "Reklam isteği eşleşmiyor.");
      if ((placement.startsWith("story_") || placement.startsWith("what_if_")) && Object.entries(existing.context || {})
          .some(([key, value]) => context?.[key] !== value)) {
        fail("invalid-argument", "Reklam görevi eşleşmiyor.");
      }
      if (THREE_HINTS.includes(placement) && existing.context?.sessionId !== context?.sessionId) {
        fail("invalid-argument", "Reklam oturumu eşleşmiyor.");
      }
      if (THREE_HINTS.includes(placement) && context?.boostId &&
          existing.context?.boostId !== context.boostId) {
        fail("invalid-argument", "Reklam destek türü eşleşmiyor.");
      }
    };
    const existing = Object.values(stateOf((await ref(uid).get()).val()).tickets)
        .find((t) => t.requestId === requestId);
    if (existing) {
      checkExisting(existing);
      await settle(uid);
      return {ok: true, pro: existing.sourceType === "pro_daily_bonus", userId: uid, ticket: publicTicket(existing)};
    }
    const whatIf = placement.startsWith("what_if_");
    const story = placement.startsWith("story_") || whatIf;
    if (story && !await isLinked(uid)) fail("permission-denied", "Google hesabına bağlan.");
    const special = ["energy_refill", "quiz_hint", ...THREE_HINTS].includes(placement);
    const benefit = THREE_HINTS.includes(placement) ? await prepareThreeReward?.(uid, placement, context) :
      placement === "energy_refill" ? await prepareEnergyReward?.(uid) :
      placement === "quiz_hint" ? await prepareQuizReward?.(uid) : whatIf ? await prepareWhatIfReward?.(uid,
          placement, context) :
      story ? await prepareStoryReward?.(uid, placement, context) : placement.startsWith("daily_") ?
      await prepareDailyReward?.(uid, placement, context) : null;
    if ((special || story || placement.startsWith("daily_")) && !benefit) {
      fail("failed-precondition",
          "Bonus hazır değil.");
    }
    const time = now();
    const policy = policyOf(await getConfig(), units, platform);
    // Story uses its own opt-in placements, not the disabled generic coin source.
    if (story) {
      policy.enabled = true; policy.limit = 4; policy.configId = whatIf ? "what-if-v1" : "journey-v1";
    }
    if (special) {
      policy.enabled = true;
      policy.limit = THREE_HINTS.includes(placement) ?
        Math.min(4, require("./config/three_modes_catalog.json").policy.hintDailyLimit) :
        placement === "energy_refill" ? 2 : 1;
      policy.configId = THREE_HINTS.includes(placement) ? "three-modes-hints-v1" : "energy-quiz-v1";
    }
    const pro = !benefit?.requireVerifiedAd && await isPro(uid);
    if (!policy.enabled) fail("failed-precondition", "Bonuslar şu anda kapalı.");
    if (!pro && !policy.unitId) fail("failed-precondition", "Reklam bağlantısı henüz hazır değil.");
    const key = dayKey(time);
    const counterKey = THREE_HINTS.includes(placement) ? key + "__solo_hints" : special ? key + "__" + placement : key;
    const id = randomId();
    const state = await transact(uid, (s) => {
      prune(s, time);
      const prior = Object.values(s.tickets).find((t) => t.requestId === requestId);
      if (prior) {
        checkExisting(prior); return;
      }
      if (benefit && Object.values(s.tickets).some((t) => t.claimKey === benefit.claimKey &&
        (["verified", "credited"].includes(t.status) || t.status === "pending" && t.expiresAt > time))) {
        fail("already-exists", "Bu bonus zaten alındı veya doğrulanıyor.");
      }
      const d = day(s, counterKey);
      if (HINT_PLACEMENTS.has(placement) && hintCount(s, key, time, true) >= 4) {
        fail("resource-exhausted", "Günlük dört reklamlı destek hakkın doldu.");
      }
      // Include old per-placement counters during the shared-cap migration.
      const legacyHints = THREE_HINTS.includes(placement) ? THREE_HINTS.reduce((n, p) =>
        n + (s.days[key + "__" + p]?.earned || 0), 0) : 0;
      const oldReserved = THREE_HINTS.includes(placement) ? Object.values(s.tickets).filter((t) =>
        t.dayKey === key && THREE_HINTS.includes(t.placement) && t.counterKey !== counterKey &&
        t.status === "pending" && t.expiresAt > time).length : 0;
      if (d.earned + legacyHints + oldReserved + reserved(s, counterKey, time) >= policy.limit) {
        fail("resource-exhausted", "Günlük bonus sınırına ulaştın.");
      }
      if (d.issued >= 12 || s.lastIssuedAt > time - 30000) {
        fail("resource-exhausted", "Kısa bir süre sonra tekrar dene.");
      }
      // One outstanding watch at a time across both placements/devices.
      if (Object.values(s.tickets).some((t) => t.status === "pending" && t.expiresAt > time)) {
        fail("failed-precondition", "Önceki reklamın doğrulaması bekleniyor.");
      }
      s.lastIssuedAt = time;
      d.issued += 1;
      const ticket = {id, requestId, placement, dayKey: key, counterKey,
        amount: benefit ? benefit.amount : policy.amount,
        ...(benefit ? {context: benefit.context, claimKey: benefit.claimKey,
          requireVerifiedAd: benefit.requireVerifiedAd === true} : {}),
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
      if (t.status === "cancelled" && ["energy_refill", "quiz_hint", ...THREE_HINTS].includes(t.placement)) {
        fail("permission-denied", "Reward ticket cancelled");
      }
      const transactionHash = hash(event.transaction_id);
      if (["verified", "credited"].includes(t.status)) {
        if (t.transactionHash !== transactionHash) fail("already-exists", "Ticket already used");
        return;
      }
      if (Object.values(s.tickets).some((other) => other.transactionHash === transactionHash)) {
        fail("already-exists", "Transaction already used");
      }
      const d = day(s, t.counterKey || t.dayKey);
      if (t.requireVerifiedAd && hintCount(s, t.dayKey, time, false) >= 4) {
        fail("resource-exhausted", "Günlük reklamlı destek limiti doldu.");
      }
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
