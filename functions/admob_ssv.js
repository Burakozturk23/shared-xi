"use strict";
const crypto = require("node:crypto");
const KEY_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const MAX_AGE_MS = 24 * 60 * 60 * 1000;

class VerificationError extends Error {}
class KeyUnavailableError extends Error {}

// Verify the original encoded bytes, never Express's decoded/reordered query.
function parse(rawQuery) {
  if (typeof rawQuery !== "string" || rawQuery.length > 8192 || /[\r\n#]/.test(rawQuery)) {
    throw new VerificationError("Invalid query");
  }
  const match = rawQuery.match(/^(.+)&signature=([^&]+)&key_id=([0-9]{1,20})$/);
  if (!match) throw new VerificationError("Missing signature");
  const params = new URLSearchParams(rawQuery);
  const keys = [...params.keys()];
  const allowed = new Set(["ad_network", "ad_unit", "custom_data", "reward_amount", "reward_item",
    "timestamp", "transaction_id", "user_id", "signature", "key_id"]);
  if (keys.length !== new Set(keys).size || keys.some((key) => !allowed.has(key))) {
    throw new VerificationError("Unexpected parameters");
  }
  const signature = params.get("signature");
  if (!/^[A-Za-z0-9_-]{80,110}={0,2}$/.test(signature)) throw new VerificationError("Invalid signature");
  const event = Object.fromEntries(params);
  if (!/^[a-f0-9]{48}$/.test(event.custom_data || "") ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(event.user_id || "") ||
      !/^[A-Za-z0-9_-]{1,200}$/.test(event.transaction_id || "") ||
      !/^(?:ca-app-pub-\d{16}\/)?\d{10}$/.test(event.ad_unit || "") ||
      !/^\d{13}$/.test(event.timestamp || "")) {
    throw new VerificationError("Invalid reward identity");
  }
  return {event, signedBytes: Buffer.from(match[1], "utf8"), signature: Buffer.from(signature, "base64url")};
}

// One bounded fetch per refresh, including unknown-key attacks. No startup IO.
function createKeyProvider({fetchKeys = async () => {
  const response = await fetch(KEY_URL, {signal: AbortSignal.timeout(4000), redirect: "error"});
  if (!response.ok) throw new Error("Key service unavailable");
  const body = await response.text();
  if (body.length > 65536) throw new Error("Key document too large");
  return JSON.parse(body);
}, now = Date.now} = {}) {
  let keys = new Map();
  let fetchedAt = 0;
  let attemptedAt = -Infinity;
  let pending;
  return async (id) => {
    if (keys.has(id) && now() - fetchedAt < 6 * 3600000) return keys.get(id);
    if (!pending && now() - attemptedAt >= 60000) {
      attemptedAt = now();
      pending = (async () => {
        const document = await fetchKeys();
        if (!Array.isArray(document.keys) || document.keys.length < 1 || document.keys.length > 20) {
          throw new Error("Invalid keys");
        }
        const next = new Map();
        for (const row of document.keys) {
          const key = crypto.createPublicKey(row.pem);
          if (key.asymmetricKeyType !== "ec" || key.asymmetricKeyDetails.namedCurve !== "prime256v1") {
            throw new Error("Unexpected signing algorithm");
          }
          next.set(String(row.keyId), key);
        }
        keys = next;
        fetchedAt = now();
      })().finally(() => pending = null);
    }
    try {
      if (pending) await pending;
    } catch (_) {
      // A previously verified key can be retained for at most 24 hours.
      if (!keys.has(id) || now() - fetchedAt >= MAX_AGE_MS) throw new KeyUnavailableError("Keys unavailable");
    }
    if (!keys.size) throw new KeyUnavailableError("Keys unavailable");
    if (!keys.has(id)) throw new VerificationError("Unknown signing key");
    if (now() - fetchedAt >= MAX_AGE_MS) throw new KeyUnavailableError("Keys expired");
    return keys.get(id);
  };
}

async function verify(rawQuery, getKey, now = Date.now()) {
  const {event, signedBytes, signature} = parse(rawQuery);
  const key = await getKey(event.key_id);
  if (!crypto.verify("sha256", signedBytes, key, signature)) throw new VerificationError("Invalid signature");
  const timestamp = Number(event.timestamp);
  if (timestamp > now + 300000 || now - timestamp > MAX_AGE_MS) throw new VerificationError("Expired event");
  return {...event, timestamp};
}
module.exports = {verify, parse, createKeyProvider, VerificationError, KeyUnavailableError};
