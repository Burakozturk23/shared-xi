"use strict";
const crypto = require("node:crypto");
const defaults = require("./config/linkball_economy.defaults.json");
const PARAMETER = "linkball_economy_v1";
const DEFERRED = ["casual_completion", "weekly_mission", "special_event"];

function freeze(value) {
  if (value && typeof value === "object") {
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}
freeze(defaults);

// A complete snapshot is accepted atomically; partial or misspelled configs
// cannot silently change the currency, item identities, or supported sources.
function validateConfig(input) {
  const value = typeof input === "string" ? JSON.parse(input) : JSON.parse(JSON.stringify(input));
  function check(v, d, key = "") {
    if (typeof v !== typeof d || v === null) throw new Error("Invalid economy field: " + key);
    if (Array.isArray(d)) {
      if (!Array.isArray(v) || v.length !== d.length) throw new Error("Invalid economy array: " + key);
      d.forEach((item, i) => check(v[i], item, key));
    } else if (typeof d === "object") {
      if (Array.isArray(v) || Object.keys(v).sort().join() !== Object.keys(d).sort().join()) {
        throw new Error("Invalid economy keys: " + key);
      }
      for (const k of Object.keys(d)) check(v[k], d[k], k);
    } else if (typeof d === "number") {
      const max = key === "priceCoins" ? 1000000 : 10000;
      if (!Number.isSafeInteger(v) || v < 1 || v > max) throw new Error("Invalid economy number: " + key);
    } else if (typeof d === "string") {
      if (!v.trim() || v.length > 160) throw new Error("Invalid economy text: " + key);
      if (!["revision", "title", "subtitle", "badge"].includes(key) && v !== d) {
        throw new Error("Immutable economy identity: " + key);
      }
    }
  }
  check(value, defaults);
  const s = value.sources;
  if (value.schemaVersion !== 1 || s.daily_reward.dailyLimit !== 1 || s.daily_mission.dailyLimit > 3 ||
      s.squad_challenge.dailyLimit !== 3 || s.squad_challenge.freeAttempts > 10 ||
      value.sinks.squad_extra_attempt.dailyLimit > 3 || s.rewarded_coin.dailyLimit > 2 ||
      s.weekly_mission.weeklyLimit !== 1 || s.casual_completion.minCoins > s.casual_completion.maxCoins) {
    throw new Error("Economy limits exceed supported policy");
  }
  if (DEFERRED.some((key) => s[key].enabled)) throw new Error("Source requires a later verified integration");
  if (Object.values(value.sinks.cosmetics.offers).some((o) => o.oneTime !== true)) {
    throw new Error("Only one-time cosmetics are supported");
  }
  function canonical(v) {
    if (Array.isArray(v)) return v.map(canonical);
    if (!v || typeof v !== "object") return v;
    return Object.fromEntries(Object.keys(v).sort().map((k) => [k, canonical(v[k])]));
  }
  const configId = "economy-" + crypto.createHash("sha256").update(JSON.stringify(canonical(value)))
      .digest("hex").slice(0, 20);
  return freeze({...value, configId});
}
const DEFAULT_CONFIG = validateConfig(defaults);

// No network at module initialization: Firebase discovery remains fast.
function createProvider({fetch, now = Date.now, warn = () => {}, ttlMs = 300000, timeoutMs = 3000}) {
  let cached = DEFAULT_CONFIG;
  let expires = 0;
  let pending;
  return async () => {
    if (now() < expires) return cached;
    if (pending) return pending;
    pending = (async () => {
      let timer;
      try {
        const raw = await Promise.race([
          Promise.resolve().then(fetch),
          new Promise((resolve, reject) => {
            timer = setTimeout(() => reject(new Error("Remote Config timeout")), timeoutMs);
          }),
        ]);
        cached = validateConfig(raw);
        expires = now() + ttlMs;
      } catch (error) {
        expires = now() + 30000;
        warn("Economy configuration unavailable; retaining validated snapshot", {
          configId: cached.configId, reason: error.message,
        });
      } finally {
        clearTimeout(timer);
        pending = null;
      }
      return cached;
    })();
    return pending;
  };
}
function publicContract(config) {
  return {
    configId: config.configId,
    displayName: "Link Coin",
    currency: "coin",
    xpSpendable: false,
    resetTimeZone: config.resetTimeZone,
    achievementRewards: config.sources.achievement.enabled ? config.sources.achievement.rewards : {},
  };
}
function squadPolicy(config = DEFAULT_CONFIG) {
  return {
    ...config.sources.squad_challenge,
    configId: config.configId,
    extraEnabled: config.sinks.squad_extra_attempt.enabled,
    extraPrice: config.sinks.squad_extra_attempt.priceCoins,
    maxPaid: config.sinks.squad_extra_attempt.dailyLimit,
  };
}
module.exports = {defaults, PARAMETER, DEFAULT_CONFIG, validateConfig, createProvider, publicContract, squadPolicy};
