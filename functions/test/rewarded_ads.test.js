"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {harness} = require("./support/economy_harness");
const {createService, dayKey} = require("../rewarded_ads");
const {defaults, validateConfig} = require("../economy_config");
const ssv = require("../admob_ssv");
const unit = "ca-app-pub-1234567890123456/1234567890";
const copy = (v) => JSON.parse(JSON.stringify(v));
function setup() {
  const h = harness();
  let linked = true;
  let pro = false;
  const config = copy(defaults);
  config.sources.rewarded_coin.enabled = true;
  let sequence = 0;
  const engine = createService({db: h.db, now: () => h.now,
    getConfig: async () => validateConfig(config), units: {android: unit, ios: unit},
    isLinked: async () => linked, isPro: async () => pro,
    grantCoins: (...args) => h.context.lbProgressionGrantCoins(h.db, ...args),
    randomId: () => (++sequence).toString(16).padStart(48, "0"),
  });
  let requests = 0;
  const prepare = (placement = "loto_result", uid = "alice", requestId = (++requests).toString(16).padStart(32, "0")) =>
    engine.prepare(uid, "android", placement, requestId);
  const event = (ticket, tx = crypto.randomBytes(12).toString("hex")) => ({
    user_id: "alice", custom_data: ticket.id, ad_unit: unit, transaction_id: tx, timestamp: h.now,
    reward_amount: "999999", reward_item: "untrusted", // never used as the wallet amount
  });
  return {h, engine, prepare, event, config, setLinked: (v) => linked = v, setPro: (v) => pro = v,
    coins: () => h.read("economyState/alice/balances/coins") || 0};
}

test("B enables rewarded source only, keeping the global 2/day cap", () => {
  const c = copy(defaults);
  c.sources.rewarded_coin.enabled = true;
  assert.equal(validateConfig(c).sources.rewarded_coin.amount, 20);
  c.sources.rewarded_coin.dailyLimit = 3;
  assert.throws(() => validateConfig(c));
});
test("SSV reward uses issued server amount and writes wallet receipt/ledger once", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  assert.equal(s.coins(), 0);
  const event = s.event(ticket);
  s.config.sources.rewarded_coin.amount = 100;
  await Promise.all([s.engine.accept(event), s.engine.accept(event), s.engine.accept(event)]);
  assert.equal(s.coins(), 20);
  const claim = s.h.read("economyState/alice/claims/reward_ad__" + ticket.id);
  assert.equal(claim.balanceBefore, 0);
  assert.equal(claim.balanceAfter, 20);
  assert.equal(claim.sourceType, "rewarded_coin");
  assert.equal(s.h.read("economyLedger/alice/" + claim.txId).idempotencyKey, claim.txId);
});
test("two result placements share the same daily allowance; replay never increments it", async () => {
  const s = setup();
  const first = await s.prepare();
  await s.engine.accept(s.event(first.ticket));
  s.h.setTime(s.h.now + 31000);
  const second = await s.prepare("cinko_result");
  await s.engine.accept(s.event(second.ticket));
  assert.equal(s.coins(), 40);
  s.h.setTime(s.h.now + 31000);
  await assert.rejects(s.prepare(), {code: "resource-exhausted"});
});
test("concurrent starts reserve one watch and client retries reuse its requestId", async () => {
  const s = setup();
  const id = "a".repeat(32);
  const values = await Promise.all([s.prepare("loto_result", "alice", id), s.prepare("loto_result", "alice", id)]);
  assert.equal(values[0].ticket.id, values[1].ticket.id);
  const attempts = await Promise.allSettled([s.prepare("cinko_result"), s.prepare("loto_result")]);
  assert.ok(attempts.every((r) => r.status === "rejected"));
  assert.equal(Object.keys(s.h.read("rewardedAdState/alice/tickets")).length, 1);
});
test("Pro gets the same bonus and limit; callable rejects unverified premium data", async () => {
  const s = setup();
  s.setPro(true);
  const {ticket} = await s.prepare();
  assert.equal(s.coins(), 20);
  assert.equal(s.h.read("economyState/alice/claims/reward_ad__" + ticket.id).sourceType, "pro_daily_bonus");
  s.h.setTime(s.h.now + 31000);
  await s.prepare();
  s.h.setTime(s.h.now + 31000);
  await assert.rejects(s.prepare(), {code: "resource-exhausted"});
  const h = harness({premiumState: {alice: {plan: "lifetime", verified: false}}});
  h.setConfig((c) => c.sources.rewarded_coin.enabled = true);
  const status = await h.call("getRewardedAdStatus", {platform: "android"});
  assert.equal(status.pro, false);
  await assert.rejects(h.call("prepareRewardedAd", {platform: "android", placement: "loto_result",
    requestId: "a".repeat(32), pro: true, amount: 99999}), {code: "failed-precondition"});
});
test("Pro and ad bonus cannot be combined to exceed two; online placements are rejected", async () => {
  const s = setup();
  await s.engine.accept(s.event((await s.prepare()).ticket));
  s.setPro(true);
  s.h.setTime(s.h.now + 31000);
  await s.prepare();
  s.h.setTime(s.h.now + 31000);
  await assert.rejects(s.prepare(), {code: "resource-exhausted"});
  await assert.rejects(s.prepare("online_result"), {code: "invalid-argument"});
});
test("anonymous verified reward waits for same-UID Google upgrade and settles once", async () => {
  const s = setup();
  s.setLinked(false);
  const {ticket} = await s.prepare();
  await s.engine.accept(s.event(ticket));
  assert.equal(s.coins(), 0);
  assert.equal((await s.engine.status("alice", "android", ticket.id)).pendingCoins, 20);
  s.setLinked(true);
  await Promise.all([s.engine.settle("alice"), s.engine.settle("alice")]);
  assert.equal(s.coins(), 20);
  assert.equal((await s.engine.status("alice", "android", ticket.id)).ticket.status, "credited");
});
test("interrupted wallet projection is recovered from durable receipt without duplicate credit", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  s.h.failNext("");
  await assert.rejects(s.engine.accept(s.event(ticket)), /Simulated/);
  assert.equal(s.coins(), 20);
  assert.ok(s.h.read("rewardedAdState/alice/pending/" + ticket.id));
  await s.engine.status("alice", "android", ticket.id);
  assert.equal(s.coins(), 20);
  assert.equal(s.h.read("rewardedAdState/alice/pending/" + ticket.id), null);
});
test("wallet failure before credit survives midnight and changed/disabled configuration", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  s.h.failNext("economyState/alice");
  await assert.rejects(s.engine.accept(s.event(ticket)), /Simulated/);
  s.h.setTime("2026-09-21T01:00:00Z");
  s.config.sources.rewarded_coin.enabled = false;
  s.config.sources.rewarded_coin.amount = 99;
  await s.engine.status("alice", "android", ticket.id);
  assert.equal(s.coins(), 20);
});
test("Istanbul midnight restores two new slots and delayed SSV uses its reserved issue day", async () => {
  const s = setup();
  s.h.setTime("2026-09-20T20:59:50Z");
  const {ticket} = await s.prepare();
  const event = s.event(ticket);
  s.h.setTime("2026-09-20T21:00:20Z");
  await s.engine.accept(event);
  const status = await s.engine.status("alice", "android");
  assert.equal(status.dayKey, "2026-09-21");
  assert.equal(status.remaining, 2);
  assert.equal(dayKey(Date.parse("2026-09-20T20:59:59Z")), "2026-09-20");
});
test("invalid unit, different user, reused transaction and expired watch cannot earn", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  const valid = s.event(ticket, "abc123");
  await assert.rejects(s.engine.accept({...valid, ad_unit: "9999999999"}), {code: "permission-denied"});
  await assert.rejects(s.engine.accept({...valid, user_id: "bob"}), {code: "not-found"});
  await assert.rejects(s.engine.accept({...valid, timestamp: s.h.now + 21 * 60000}), {code: "permission-denied"});
  await s.engine.accept(valid);
  s.h.setTime(s.h.now + 31000);
  const second = await s.prepare();
  await assert.rejects(s.engine.accept(s.event(second.ticket, "abc123")), {code: "already-exists"});
  assert.equal(s.coins(), 20);
});
test("cancelled ad uses no reward slot; a later signed completion remains authoritative", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  await s.engine.cancel("alice", ticket.id);
  assert.equal((await s.engine.status("alice", "android")).remaining, 2);
  assert.equal(s.coins(), 0);
  await s.engine.accept(s.event(ticket));
  assert.equal(s.coins(), 20);
});
test("deleted account has no ticket to resurrect; private ticket keys are validated", async () => {
  const s = setup();
  const {ticket} = await s.prepare();
  s.h.seed("rewardedAdState/alice", null);
  await assert.rejects(s.engine.accept(s.event(ticket)), {code: "not-found"});
  await assert.rejects(s.engine.status("alice", "android", "__proto__"), {code: "invalid-argument"});
  assert.equal(s.coins(), 0);
});
test("real exported callables require auth and expose official test units as preview-only", async () => {
  const h = harness();
  await assert.rejects(h.call("getRewardedAdStatus", {platform: "android"}, null), {code: "unauthenticated"});
  const status = await h.call("getRewardedAdStatus", {platform: "android"});
  assert.equal(status.testingOnly, true);
  assert.equal(status.enabled, false);
});

const pair = crypto.generateKeyPairSync("ec", {namedCurve: "prime256v1"});
const time = Date.parse("2026-09-20T10:00:00Z");
function signed(overrides = {}, signer = pair.privateKey) {
  const values = {ad_network: "5450213213286189855", ad_unit: "1234567890", custom_data: "a".repeat(48),
    reward_amount: "20", reward_item: "Link Coin + ödül", timestamp: String(time),
    transaction_id: "ab12", user_id: "alice",
    ...overrides};
  const raw = new URLSearchParams(values).toString();
  const sig = crypto.sign("sha256", Buffer.from(raw), signer).toString("base64url");
  return raw + "&signature=" + sig + "&key_id=42";
}
test("SSV accepts original encoded bytes and rejects tampering, duplicate fields and wrong keys", async () => {
  const raw = signed();
  assert.equal((await ssv.verify(raw, async () => pair.publicKey, time)).reward_item, "Link Coin + ödül");
  for (const input of [raw.replace("reward_amount=20", "reward_amount=999"),
    raw.replace("ad_unit=1234567890", "ad_unit=1234567890&ad_unit=1234567890"),
    raw + "&user_id=bob", raw.replace("user_id=alice", "user_id=bob"), decodeURIComponent(raw)]) {
    await assert.rejects(ssv.verify(input, async () => pair.publicKey, time), ssv.VerificationError);
  }
  const wrong = crypto.generateKeyPairSync("ec", {namedCurve: "prime256v1"}).publicKey;
  await assert.rejects(ssv.verify(raw, async () => wrong, time), ssv.VerificationError);
});
test("old and future signed SSV events fail before reward; wrong algorithm is never accepted", async () => {
  await assert.rejects(ssv.verify(signed(), async () => pair.publicKey, time + 86400001), ssv.VerificationError);
  await assert.rejects(ssv.verify(signed({timestamp: String(time + 300001)}), async () => pair.publicKey, time),
      ssv.VerificationError);
  const rsa = crypto.generateKeyPairSync("rsa", {modulusLength: 2048}).publicKey;
  const provider = ssv.createKeyProvider({fetchKeys: async () => ({keys: [{keyId: 42,
    pem: rsa.export({type: "spki", format: "pem"})}]}), now: () => time});
  await assert.rejects(provider("42"), ssv.KeyUnavailableError);
});
test("signing key cache is single-flight, rotates and will not use keys older than 24 hours", async () => {
  let clock = time;
  let calls = 0;
  let down = false;
  let keyId = 42;
  const provider = ssv.createKeyProvider({now: () => clock, fetchKeys: async () => {
    calls++;
    if (down) throw new Error("offline");
    return {keys: [{keyId, pem: pair.publicKey.export({type: "spki", format: "pem"})}]};
  }});
  await Promise.all([provider("42"), provider("42"), provider("42")]);
  assert.equal(calls, 1);
  await assert.rejects(provider("999"), ssv.VerificationError);
  assert.equal(calls, 1);
  clock += 60001;
  keyId = 43;
  await provider("43");
  assert.equal(calls, 2);
  down = true;
  clock += 7 * 3600000;
  await provider("43");
  clock += 18 * 3600000;
  await assert.rejects(provider("43"), ssv.KeyUnavailableError);
});
