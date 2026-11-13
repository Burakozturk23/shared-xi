"use strict";
// Faz 4: shared avatar draw, monthly Pro Kasası, Sezon avatar steps, Pro energy depot.
const test = require("node:test");
const assert = require("node:assert/strict");
const C = require("../pro_crate");
const {harness} = require("./support/economy_harness");

const empty = () => ({inventory: {}, storeUses: {}, claims: {}, balances: {coins: 0}, lifetimeEarned: 0});
const pro = (startedAt) => ({plan: "monthly", verified: true, entitled: true, startedAt,
  expiresAt: startedAt + 40 * 86400000});
const owned = (ids, type = "avatar") => Object.fromEntries(ids.map((itemId) => [itemId,
  {itemId, itemType: type, quantity: 1}]));

test("draw pool: buyable avatars only, owned ones excluded; odds add up and follow the 3:2 weights", () => {
  assert.equal(C.AVATARS.length, 164);
  assert.equal(C.AVATARS.filter((a) => a.price === 450).length, 48);
  const season = C.odds(empty(), "season");
  assert.equal(season.count, 164);
  const t450 = season.tiers.find((t) => t.price === 450); const t300 = season.tiers.find((t) => t.price === 300);
  assert.ok(Math.abs(t450.chance + t300.chance - 1) < 0.001);
  assert.ok(Math.abs(t450.chance - 96 / 444) < 0.001); // ~21.6%
  assert.ok(Math.abs(t300.each / t450.each - 1.5) < 0.01);
  const crate = C.odds(empty(), "crate");
  assert.deepEqual(crate.tiers.map((t) => t.price), [450]);
  assert.equal(crate.count, 48);
  assert.ok(Math.abs(C.expectedValue("season") - 332.43) < 0.01);
});

test("a draw is stable per player and receipt, never gives an owned avatar, and falls back to kit then coins", () => {
  const a = empty(); const b = empty();
  const r1 = C.drawAvatar(a, "k1", "alice", "season", "season_pass", 1);
  const r2 = C.drawAvatar(b, "k1", "alice", "season", "season_pass", 1);
  assert.equal(r1.itemId, r2.itemId);
  assert.equal(C.drawAvatar(a, "k1", "alice", "season", "season_pass", 2), r1); // retry: same receipt
  assert.equal(a.inventory[r1.itemId].quantity, 1);
  // Every 450 owned: the Kasa falls back to the 300 tier.
  const rich = empty(); rich.inventory = owned(C.AVATARS.filter((x) => x.price === 450).map((x) => x.itemId));
  assert.equal(C.AVATARS.find((x) => x.itemId === C.drawAvatar(rich, "k", "alice", "crate", "pro_crate", 1).itemId)
      .price, 300);
  // Everything owned: a kit, then coins.
  const all = empty(); all.inventory = owned(C.AVATARS.map((x) => x.itemId));
  assert.equal(C.drawAvatar(all, "k", "alice", "season", "season_pass", 1).kind, "kit");
  all.inventory = {...owned(C.AVATARS.map((x) => x.itemId)), ...owned(C.KITS.map((x) => x.itemId), "kit")};
  const coins = C.drawAvatar(all, "k2", "alice", "season", "season_pass", 1);
  assert.equal(coins.kind, "coins"); assert.equal(all.balances.coins, 300);
  assert.equal(all.claims["pro_reward_fallback__k2"].sourceType, "pro_reward_fallback");
});

test("Kasa: off by default; Pro only; 48 hours after start; once a month with the full contents", async () => {
  const h = harness({runtimeConfig: {proCrate: {enabled: true, public: true}}});
  h.setTime("2026-11-10T09:00:00Z");
  await assert.rejects(h.call("claimProCrate"), {code: "permission-denied"});
  h.seed("premiumState/alice", pro(h.now - 3600000));
  const early = await h.call("getProCrate");
  assert.equal(early.canOpen, false); assert.equal(early.odds.count, 48);
  await assert.rejects(h.call("claimProCrate"), /48 saat/);
  h.setTime(h.now + 48 * 3600000);
  const [a, b] = await Promise.all([h.call("claimProCrate"), h.call("claimProCrate")]);
  assert.equal([a, b].filter((r) => r.granted).length, 1);
  const inv = h.read("economyState/alice/inventory");
  assert.equal(inv.boost_basic.quantity, 12); assert.equal(inv.boost_strong.quantity, 4);
  assert.equal(inv.boost_connection.quantity, 2); assert.equal(inv.boost_eliminate.quantity, 2);
  const avatar = a.receipt.avatar.itemId;
  assert.equal(inv[avatar].itemType, "avatar");
  assert.equal(C.AVATARS.find((x) => x.itemId === avatar).price, 450);
  assert.equal((await h.call("getProCrate")).opened, true);
  // Next month: a new Kasa, never the same avatar again.
  h.setTime("2026-12-02T09:00:00Z");
  const dec = await h.call("claimProCrate");
  assert.equal(dec.month, "2026-12"); assert.notEqual(dec.receipt.avatar.itemId, avatar);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 24);
  // A subscription that ends between the check and the commit does not open.
  const late = harness({runtimeConfig: {proCrate: {enabled: true, public: true}}});
  late.setTime("2026-11-10T09:00:00Z");
  late.seed("premiumState/alice", {...pro(late.now - 5 * 86400000), expiresAt: late.now + 1});
  const realDraw = late.context.lbProDraw;
  late.context.lbProDraw = async (db, uid, run) => {
    late.setTime(late.now + 10); return realDraw(db, uid, run);
  };
  await assert.rejects(late.call("claimProCrate"), {code: "permission-denied"});
  assert.equal(late.read("economyState/alice/inventory/boost_basic"), null);
  // Off: nothing opens.
  const off = harness({premiumState: {alice: pro(0)}});
  await assert.rejects(off.call("claimProCrate"), /henüz açık değil/);
});

test("Kasa supports over the 99 cap turn into half-price coins; the last three days remind", async () => {
  const h = harness({runtimeConfig: {proCrate: {enabled: true, public: true}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}},
    economyState: {alice: {balances: {coins: 0}, inventory: {boost_basic: {itemId: "boost_basic",
      itemType: "boost", quantity: 95}}}}});
  h.setTime("2026-11-28T09:00:00Z");
  assert.equal((await h.call("getProCrate")).remind, true);
  const r = await h.call("claimProCrate");
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 99);
  assert.equal(r.receipt.supports.boost_basic, 4);
  assert.equal(r.receipt.overflowCoins, 8 * 12);
  assert.equal(h.read("economyState/alice/balances/coins"), 96);
});

test("Sezon son hali: 640 coin, supports on 5 and 15, avatars from the 300 (10) and 450 (20) pools", async () => {
  const h = harness({runtimeConfig: {seasonAvatars: {enabled: true}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const service = h.context.lbSeasonService();
  const status = await service.status("alice");
  assert.deepEqual([...status.avatarSteps], [10, 20]);
  assert.deepEqual([...status.supportSteps], [5, 15]);
  assert.equal(status.proTotal, 640);
  assert.equal(status.tiers[9].proAvatar, true); assert.equal(status.tiers[9].proAvatarTier, 300);
  assert.equal(status.tiers[19].proAvatarTier, 450); assert.equal(status.tiers[19].proCoins, 0);
  assert.deepEqual({...status.tiers[4].proSupports}, {boost_strong: 2});
  assert.equal(status.tiers[4].proCoins, 0); assert.equal(status.tiers[3].proCoins, 40);
  assert.deepEqual(status.avatarPools.map((p) => [p.step, p.tier, p.count]), [[10, 300, 116], [20, 450, 48]]);
  // Claims: reach step 20 by seeding SP-bearing claims is heavy; drive the grant hooks directly.
  const season = status.id;
  const avatar20 = await h.context.lbProDraw(h.db, "alice", (e, now) =>
    C.drawAvatar(e, `season_v1__${season}__20__pro`, "alice", 450, "season_pass", now));
  assert.equal(C.AVATARS.find((a) => a.itemId === avatar20.itemId).price, 450);
  const avatar10 = C.drawAvatar({...empty(), inventory: {}}, "k10", "alice", 300, "season_pass", 1);
  assert.equal(C.AVATARS.find((a) => a.itemId === avatar10.itemId).price, 300);
  const after = await service.status("alice");
  assert.equal(after.tiers[19].proClaimed, true);
  assert.equal(after.avatarPools[1].count, 47);
  // Off: unchanged coins.
  const off = await harness({premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}})
      .context.lbSeasonService().status("alice");
  assert.equal(off.proTotal, 1040); assert.equal(off.tiers[9].proCoins, 100);
  assert.equal(off.tiers[4].proSupports, null);
});

test("Sezon claims: step 5 gives 2 Güçlü (past 99 half price), step 10 a 300 avatar, once each", async () => {
  const h = harness({runtimeConfig: {seasonAvatars: {enabled: true}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}},
    economyState: {alice: {balances: {coins: 0}, inventory: {boost_strong: {itemId: "boost_strong",
      itemType: "boost", quantity: 98}}}}});
  h.setTime("2026-11-20T09:00:00Z");
  // 7 days × 150 SP from career receipts: level 10.
  const claims = {};
  for (let d = 10; d <= 16; d++) {
    for (const [i, id] of ["general_ranked_play_5", "general_ranked_wins_3", "general_daily_days_3"].entries()) {
      claims[`c${d}_${i}`] = {sourceType: "mission_reward", sourceId: "general__" + id, amount: 1,
        claimedAt: Date.parse(`2026-11-${d}T09:00:00Z`)};
    }
  }
  h.seed("economyState/alice/claims", claims);
  const service = h.context.lbSeasonService();
  const season = (await service.status("alice")).id;
  assert.equal((await service.status("alice")).level, 10);
  const first = await service.claim("alice", {seasonId: season, step: 5, lane: "pro"});
  await service.claim("alice", {seasonId: season, step: 5, lane: "pro"});
  assert.equal(first.supports.overflowCoins, 30);
  assert.equal(h.read("economyState/alice/inventory/boost_strong/quantity"), 99);
  assert.equal(h.read("economyState/alice/balances/coins"), 30);
  const ten = await service.claim("alice", {seasonId: season, step: 10, lane: "pro"});
  assert.equal(C.AVATARS.find((a) => a.itemId === ten.avatar.itemId).price, 300);
  const again = await service.claim("alice", {seasonId: season, step: 10, lane: "pro"});
  assert.equal(again.avatar.itemId, ten.avatar.itemId);
  const status = await service.status("alice");
  assert.equal(status.tiers[4].proClaimed, true); assert.equal(status.tiers[9].proClaimed, true);
  assert.equal(status.tiers[9].proReward.itemId, ten.avatar.itemId);
  assert.equal(h.read("economyState/alice/balances/coins"), 30); // no coins for the reward steps
});

test("Pro depot: daily +2 outside the capacity, at most 20; play spends normal energy first", async () => {
  const h = harness({});
  const service = require("../energy").createService({db: h.db, normalize: h.context.lbEconomyState,
    now: () => h.now, isPro: async () => true,
    getRollout: async () => ({enabled: true, percent: 100, minClientVersion: 1, depot: true,
      sessionModes: ["bot_loto"]})});
  const req = (n) => n.toString(16).padStart(32, "0");
  await service.proBonus("alice"); // full capacity, still stored
  let s = await service.status("alice");
  assert.equal(s.balance, 6); assert.equal(s.depot, 2); assert.equal(s.available, 8); assert.equal(s.depotCap, 20);
  for (let n = 1; n <= 7; n++) {
    const r = await service.start("alice", {requestId: req(n), mode: "bot_loto", unitId: "session", clientVersion: 1});
    await service.confirm("alice", {sessionId: r.session.id});
  }
  s = await service.status("alice");
  assert.equal(s.balance, 0); assert.equal(s.depot, 1);
  // Cap: ten days of bonuses stop at 20.
  const e = h.read("economyState/alice/energy");
  h.seed("economyState/alice/energy", {...e, depot: 20});
  h.setTime(h.now + 86400000);
  await assert.rejects(service.proBonus("alice"), /dolu \(20\)/);
});

test("wallet-writing Kasa and conversion callables require App Check", () => {
  const h = harness();
  for (const name of ["getProCrate", "claimProCrate", "convertLegacyBoosts"]) {
    assert.equal(h.context.exports[name].options.enforceAppCheck, true, name);
  }
});

test("48 h wait: a new purchase waits, a subscriber who opened last month's Kasa does not", async () => {
  const h = harness({runtimeConfig: {proCrate: {enabled: true, public: true}}});
  h.setTime("2026-12-01T09:00:00Z");
  // Play reported the renewal as a fresh start an hour ago.
  h.seed("premiumState/alice", pro(h.now - 3600000));
  assert.equal((await h.call("getProCrate")).canOpen, false);
  h.seed("economyState/alice/storeUses/pro_crate__2026-11", {month: "2026-11", openedAt: h.now - 20 * 86400000});
  const s = await h.call("getProCrate");
  assert.equal(s.canOpen, true); assert.equal(s.openableAt, 0);
  assert.equal(C.previousMonth("2027-01"), "2026-12");
});

