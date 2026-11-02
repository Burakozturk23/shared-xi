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

test("Sezon: with avatars on, Pro steps 10 and 20 draw an avatar instead of 100 coins", async () => {
  const h = harness({runtimeConfig: {seasonAvatars: {enabled: true}},
    premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const service = h.context.lbSeasonService();
  const status = await service.status("alice");
  assert.deepEqual([...status.avatarSteps], [10, 20]);
  assert.equal(status.proTotal, 840);
  const tier = status.tiers[9];
  assert.equal(tier.proAvatar, true); assert.equal(tier.proCoins, 0);
  assert.ok(status.avatarOdds.tiers.length === 2);
  assert.equal(status.tiers[4].proAvatar, false);
  // Off: unchanged coins.
  const off = await harness({premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}})
      .context.lbSeasonService().status("alice");
  assert.equal(off.proTotal, 1040); assert.equal(off.tiers[9].proCoins, 100);
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
