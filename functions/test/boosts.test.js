"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const B = require("../boosts");
const {harness} = require("./support/economy_harness");
const {createService: ads} = require("../rewarded_ads");
const {defaults} = require("../economy_config");
const ct = require("../career_transfer").catalog;
const three = require("../three_modes").catalog;
const mc = require("../mystery_chain").catalog;
const fc = require("../fake_club").catalog;
const arcade = require("../arcade_engine").catalog;
let n = 0; const id = () => (++n).toString(16).padStart(32, "0");
const policy = {enabled: true, betaUids: {alice: true}, readyModes: Object.fromEntries(
    Object.keys(B.modes).map((m) => [m, true]))};
function setup() {
  return harness({runtimeConfig: {boosts: policy, arcade: {enabled: true},
    mysteryChain: {soloEnabled: true, dataEnabled: true},
    fakeClub: {dataEnabled: true, soloEnabled: true}},
  economyState: {alice: {balances: {coins: 1000}, inventory: {
    boost_basic: {quantity: 3, itemType: "boost"}, boost_first_letter: {quantity: 3, itemType: "boost"},
  }}}}, {omitEmptyObjects: true});
}
const start = async (h) => (await h.call("startCareerTransfer", {mode: "transfer", version: ct.version,
  requestId: id()})).session;
const input = (s, extra = {}) => ({mode: s.mode, version: ct.version, sessionId: s.id, revision: s.revision,
  requestId: id(), action: "hint", boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25, ...extra});
const coins = (h) => h.read("economyState/alice/balances/coins");

test("new run prices and product types are server-pinned; no unpaid or mismatched stock reveal", async () => {
  const h = setup(); const s = await start(h);
  assert.equal(s.freeHint, false); assert.equal(s.support.version, 1);
  for (const data of [{paymentSource: null}, {expectedPriceCoins: 1}, {boostId: "boost_first_letter"},
    {boost: "boost_first_letter"}, {paymentSource: "ad"}]) {
    await assert.rejects(h.call("actCareerTransfer", input(s, data)));
    assert.equal(coins(h), 1000);
    assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/hints`), null);
  }
  const r = await h.call("actCareerTransfer", input(s));
  assert.equal(coins(h), 975); assert.equal(r.session.hints.length, 1);
  assert.equal(r.session.support.assisted, true); assert.equal(r.session.support.masteryEligible, false);
});
test("parallel identical paid requests and projection retry debit once with stable hint", async () => {
  const h = setup(); const s = await start(h); const request = input(s);
  h.failNext(""); await assert.rejects(h.call("actCareerTransfer", request));
  assert.equal(coins(h), 975);
  const values = await Promise.all([h.call("actCareerTransfer", request), h.call("actCareerTransfer", request)]);
  assert.deepEqual(values[0].session.hints, values[1].session.hints);
  assert.equal(coins(h), 975);
  await assert.rejects(h.call("actCareerTransfer", {...request, paymentSource: "stock"}), {code: "invalid-argument"});
  assert.equal(Object.keys(h.read("economyState/alice/purchases")).length, 1);
});
test("stock and reveal survive normalization; concurrent distinct requests respect revision", async () => {
  const h = setup(); const s = await start(h);
  const results = await Promise.allSettled([h.call("actCareerTransfer", input(s, {paymentSource: "stock"})),
    h.call("actCareerTransfer", input(s, {paymentSource: "stock"}))]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 2);
  await h.call("getEnergyStatus");
  assert.equal((await h.call("getCareerTransfer", {mode: "transfer"})).session.hints.length, 1);
  assert.equal(coins(h), 1000);
});
test("other account, finished run, stale revision and insufficient coins cannot spend", async () => {
  const h = setup(); let s = await start(h);
  await assert.rejects(h.call("actCareerTransfer", input(s), {uid: "bob"}), {code: "not-found"});
  await assert.rejects(h.call("actCareerTransfer", input(s, {revision: 12})), {code: "aborted"});
  h.seed("economyState/alice/balances/coins", 24);
  await assert.rejects(h.call("actCareerTransfer", input(s)), {code: "resource-exhausted"});
  s = (await h.call("actCareerTransfer", input(s, {action: "skip"}))).session;
  await assert.rejects(h.call("actCareerTransfer", input(s)), {code: "failed-precondition"});
  assert.equal(coins(h), 24);
});
test("legacy run and opened hints survive rollout; disabled rollout cannot sell new products", async () => {
  const h = setup(); h.seed("runtimeConfig/boosts", {enabled: false});
  const old = await start(h); assert.equal(old.freeHint, true); assert.equal(old.support, null);
  await assert.rejects(h.call("purchaseEconomyOffer", {offerId: "boost_basic_3", expectedPriceCoins: 65,
    requestId: id()}), {code: "failed-precondition"});
  h.seed("runtimeConfig/boosts", policy);
  const r = await h.call("actCareerTransfer", input(old, {paymentSource: null}));
  assert.equal(r.session.hints.length, 1); assert.equal(coins(h), 1000);
  const offers = (await h.call("getStoreCatalog")).offers;
  assert.ok(offers.some((x) => x.offerId === "boost_basic_3" && x.priceCoins === 65));
  await h.call("purchaseEconomyOffer", {offerId: "boost_basic_3", expectedPriceCoins: 65, requestId: id()});
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 6);
});
test("new policy cannot be forged for any of thirteen ranked/friend wire modes", () => {
  for (const mode of require("../missions_v3").onlineModes) {
    // club_manager has no solo boost adapter; raw wire names never authorize PvP.
    const r = {id: id(), mode, expiresAt: 10000}; B.pin(r, policy);
    assert.equal(B.paid(r), false, mode);
    assert.throws(() => B.consume({}, r, {}, "boost_basic", "x", {text: "x"}, 1));
  }
});
for (const mode of ["coach_xi", "squad_vault", "letter11"]) {
  test(`${mode}: real adapter consumes typed product`, async () => {
    const h = setup(); const s = (await h.call("startThreeMode", {mode, version: three.version,
      entry: "random", requestId: id()})).session;
    const data = {mode, version: three.version, sessionId: s.id, revision: s.revision, requestId: id(),
      action: "hint", hint: mode === "squad_vault" ? "flag" : "country", slot: 0,
      boostId: "boost_basic", paymentSource: "coins", expectedPriceCoins: 25};
    await assert.rejects(h.call("actThreeMode", {...data, paymentSource: null}));
    const r = await h.call("actThreeMode", data);
    assert.equal(r.session.hints.length, 1); assert.equal(coins(h), 975);
  });
}
for (const mode of ["mystery", "mastermind"]) {
  test(`${mode}: real adapter charges a verified optional hint`, async () => {
    const h = setup(); const s = (await h.call("startMysteryChain", {mode, version: mc.version,
      requestId: id()})).session;
    const r = await h.call("actMysteryChain", {mode, version: mc.version, sessionId: s.id,
      revision: s.revision, requestId: id(), action: "hint", boostId: mode === "mystery" ? "boost_basic" :
      "boost_connection", paymentSource: "coins", expectedPriceCoins: mode === "mystery" ? 25 : 40});
    assert.equal(r.session.support.assisted, true); assert.equal(coins(h), mode === "mystery" ? 975 : 960);
  });
}
test("fake club paid elimination removes exactly one candidate and records assisted result", async () => {
  const h = setup(); const s = (await h.call("startFakeClub", {mode: "fake_endless", version: fc.version,
    requestId: id()})).session;
  const r = await h.call("actFakeClub", {mode: s.mode, version: fc.version, sessionId: s.id,
    questionId: s.question.questionId, revision: s.revision, requestId: id(), action: "fifty",
    boostId: "boost_eliminate", paymentSource: "coins", expectedPriceCoins: 35});
  assert.equal(r.session.eliminated.length, 1); assert.equal(coins(h), 965);
  assert.equal(r.session.support.assisted, true);
});
for (const mode of ["burst", "pyramid"]) {
  test(`${mode}: engine hint and wallet commit together`, async () => {
    const h = setup(); let s = (await h.call("prepareArcade", {mode, version: arcade.version,
      style: "survival", difficulty: "easy", requestId: id()})).session;
    s = (await h.call("actArcade", {mode, sessionId: s.id, revision: s.revision, requestId: id(),
      action: "confirm"})).session;
    const privateRun = h.read(`economyState/alice/arcade/sessions/${s.id}`);
    const slot = privateRun.board?.slots.find((x) => !privateRun.filled?.[x.id] &&
    x.supports.every((id) => privateRun.filled?.[id]));
    const data = {mode, sessionId: s.id, revision: s.revision, requestId: id(), action: "hint",
      questionId: s.question?.id, slotId: slot?.id, boostId: mode === "pyramid" ? "boost_strong" : "boost_basic",
      paymentSource: "coins", expectedPriceCoins: mode === "pyramid" ? 60 : 25};
    await assert.rejects(h.call("actArcade", {...data, paymentSource: null}));
    const r = await h.call("actArcade", data);
    assert.equal(r.session.hints, 1); assert.equal(r.session.support.assisted, true);
    assert.equal(coins(h), mode === "pyramid" ? 940 : 975);
  });
}
test("new Pro run requires real verified ad and cannot mint a free credit", async () => {
  const h = setup(); const s = await start(h);
  const service = h.context.lbCareerTransferService();
  const engine = ads({db: h.db, now: () => h.now, getConfig: async () => defaults, units: {},
    isLinked: async () => true, isPro: async () => true, grantCoins: async () => {},
    prepareThreeReward: (...args) => service.prepareHint(...args),
    settleThreeReward: (...args) => service.settleHint(...args)});
  await assert.rejects(engine.prepare("alice", "android", "transfer_hint", id(), {sessionId: s.id}),
      {code: "failed-precondition"});
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 0);
});
test("late verified ad is recovered to stock exactly once, including a full-stock retry", async () => {
  const h = setup(); const s = await start(h);
  const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "transfer_hint", {sessionId: s.id});
  assert.equal(benefit.requireVerifiedAd, true);
  await h.call("actCareerTransfer", input(s, {action: "skip"}));
  const receipt = {id: "a".repeat(48), context: benefit.context};
  h.seed("economyState/alice/inventory/boost_basic/quantity", 99);
  await assert.rejects(service.settleHint("alice", receipt), {code: "resource-exhausted"});
  h.seed("economyState/alice/inventory/boost_basic/quantity", 98);
  await Promise.all([service.settleHint("alice", receipt), service.settleHint("alice", receipt)]);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 99);
});

test("all hint placements share four Istanbul-day ads, with SSV replay and rollover", async () => {
  const h = harness(); let seq = 0;
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const benefit = async (_, placement) => ({amount: 0, claimKey: placement + ++seq,
    requireVerifiedAd: true, context: {sessionId: String(seq)}});
  const config = structuredClone(defaults); config.sources.rewarded_coin.enabled = true;
  const service = ads({db: h.db, now: () => h.now, getConfig: async () => config, units: {android: unit},
    isLinked: async () => true, isPro: async () => false, grantCoins: async () => {},
    prepareThreeReward: benefit, settleThreeReward: async () => {},
    prepareDailyReward: benefit, settleDailyReward: async () => {},
    prepareStoryReward: benefit, settleStoryReward: async () => {},
    prepareQuizReward: benefit, settleQuizReward: async () => {}});
  for (const placement of ["transfer_hint", "daily_hint", "story_hint", "quiz_hint"]) {
    const {ticket} = await service.prepare("alice", "android", placement, id(), {});
    const event = {user_id: "alice", custom_data: ticket.id, ad_unit: unit, timestamp: h.now,
      transaction_id: ticket.id};
    await service.accept(event); await service.accept(event); h.setTime(h.now + 31000);
  }
  await assert.rejects(service.prepare("alice", "android", "mystery_hint", id(), {}),
      {code: "resource-exhausted"});
  h.setTime(h.now + 86400000);
  assert.ok((await service.prepare("alice", "android", "mystery_hint", id(), {})).ticket);
});

test("verified ad survives a concurrent paid purchase filling the active run hint limit", async () => {
  const h = setup(); let s = await start(h);
  const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "transfer_hint", {sessionId: s.id});
  for (let i = 0; i < 3; i++) {
    s = (await h.call("actCareerTransfer", input(s, {boostId: i === 2 ? "boost_first_letter" :
      "boost_basic"}))).session;
  }
  assert.equal(s.finished, false);
  const receipt = {id: "b".repeat(48), context: benefit.context};
  await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 4);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 0);
});

test("missing mystery run recovers its original basic product, never a connection product", async () => {
  const h = setup();
  const s = (await h.call("startMysteryChain", {mode: "mystery", version: mc.version,
    requestId: id()})).session;
  const service = h.context.lbMysteryChainService();
  const benefit = await service.prepareHint("alice", "mystery_hint", {sessionId: s.id});
  h.seed(`economyState/alice/mysteryChain/sessions/${s.id}`, null);
  const receipt = {id: "c".repeat(48), context: benefit.context};
  await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 4);
  assert.equal(h.read("economyState/alice/inventory/boost_connection"), null);
});

test("typed ad credit cannot buy a different support and identical use remains idempotent", async () => {
  const h = setup(); const s = (await h.call("startThreeMode", {mode: "coach_xi", version: three.version,
    entry: "random", requestId: id()})).session;
  const service = h.context.lbThreeModesService();
  const benefit = await service.prepareHint("alice", "coach11_hint", {sessionId: s.id, boostId: "boost_basic"});
  assert.equal(benefit.context.boostId, "boost_basic"); assert.equal(benefit.context.modeId, "coach_xi");
  await service.settleHint("alice", {id: "d".repeat(48), context: benefit.context});
  const data = {mode: "coach_xi", version: three.version, sessionId: s.id, revision: s.revision,
    requestId: id(), action: "hint", hint: "club", slot: 0, boostId: "boost_connection", paymentSource: "ad"};
  await assert.rejects(h.call("actThreeMode", data), {code: "resource-exhausted"});
  assert.equal(h.read(`economyState/alice/threeModes/sessions/${s.id}/adCredits`), 1);
  const use = {...data, requestId: id(), hint: "country", boostId: "boost_basic"};
  const [a, b] = await Promise.all([h.call("actThreeMode", use), h.call("actThreeMode", use)]);
  assert.deepEqual(a.session.hints, b.session.hints); assert.equal(coins(h), 1000);
  assert.equal(a.session.support.adCreditsByProduct.boost_basic, 0);
});
test("expired typed ad recovers the selected SKU and retains its run ad counter", async () => {
  const h = setup(); const s = (await h.call("startThreeMode", {mode: "coach_xi", version: three.version,
    entry: "random", requestId: id()})).session;
  const service = h.context.lbThreeModesService();
  const benefit = await service.prepareHint("alice", "coach11_hint", {sessionId: s.id, boostId: "boost_connection"});
  h.setTime(h.now + 25 * 3600000);
  const receipt = {id: "e".repeat(48), context: benefit.context};
  await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  assert.equal(h.read("economyState/alice/inventory/boost_connection/quantity"), 1);
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 3);
  assert.equal(h.read(`economyState/alice/threeModes/sessions/${s.id}/adGranted`), 1);
});
test("strong and currently unusable support cannot obtain an ad benefit", async () => {
  const h = setup(); const s = (await h.call("startThreeMode", {mode: "squad_vault", version: three.version,
    entry: "random", requestId: id()})).session;
  await assert.rejects(h.context.lbThreeModesService().prepareHint("alice", "vault_hint",
      {sessionId: s.id, boostId: "boost_strong"}), {code: "permission-denied"});
  const t = await start(h);
  await assert.rejects(h.context.lbCareerTransferService().prepareHint("alice", "transfer_hint",
      {sessionId: t.id, boostId: "boost_first_letter"}), {code: "failed-precondition"});
});
test("ticket replay cannot switch the bound support product", async () => {
  const h = setup(); const s = await start(h); const service = h.context.lbCareerTransferService();
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const engine = ads({db: h.db, now: () => h.now, getConfig: async () => defaults, units: {android: unit},
    isLinked: async () => true, isPro: async () => false, grantCoins: async () => {},
    prepareThreeReward: (...args) => service.prepareHint(...args),
    settleThreeReward: (...args) => service.settleHint(...args)});
  const requestId = id(); const context = {sessionId: s.id, boostId: "boost_basic"};
  const {ticket} = await engine.prepare("alice", "android", "transfer_hint", requestId, context);
  await assert.rejects(engine.prepare("alice", "android", "transfer_hint", requestId,
      {...context, boostId: "boost_first_letter"}), {code: "invalid-argument"});
  await assert.rejects(engine.prepare("alice", "android", "transfer_hint", id(), context));
  const event = {user_id: "alice", custom_data: ticket.id, ad_unit: unit, timestamp: h.now,
    transaction_id: ticket.id};
  await engine.accept(event); await engine.accept(event);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adProducts/boost_basic`), 1);
});
test("fake-club elimination ad cannot be spent on a career trace", async () => {
  const h = setup(); const s = (await h.call("startFakeClub", {mode: "fake_endless", version: fc.version,
    requestId: id()})).session;
  const service = h.context.lbFakeClubService();
  const benefit = await service.prepareHint("alice", "fake_club_hint", {sessionId: s.id, boostId: "boost_eliminate"});
  await service.settleHint("alice", {id: "f".repeat(48), context: benefit.context});
  const data = {mode: s.mode, version: fc.version, sessionId: s.id, questionId: s.question.questionId,
    revision: s.revision, requestId: id(), action: "trace", boostId: "boost_connection", paymentSource: "ad"};
  await assert.rejects(h.call("actFakeClub", data), {code: "resource-exhausted"});
  const result = await h.call("actFakeClub", {...data, requestId: id(), action: "fifty", boostId: "boost_eliminate"});
  assert.equal(result.session.eliminated.length, 1); assert.equal(coins(h), 1000);
});
test("already-earned untyped ad credit is preserved through the typed receipt upgrade", async () => {
  const h = setup(); const s = await start(h);
  h.seed(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`, 1);
  const result = await h.call("actCareerTransfer", input(s, {paymentSource: "ad"}));
  assert.equal(result.session.hints.length, 1); assert.equal(coins(h), 1000);
});

test("SSV arriving after the career phase changes preserves the originally selected product in stock", async () => {
  const h = setup(); const s = (await h.call("startCareerTransfer", {mode: "career", version: ct.version,
    requestId: id()})).session;
  const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "career_hint", {sessionId: s.id, boostId: "boost_basic"});
  const raw = h.read(`economyState/alice/careerTransfer/sessions/${s.id}`);
  const puzzle = ct.careers.find((p) => p.id === raw.puzzle);
  await h.call("actCareerTransfer", {mode: "career", version: ct.version, sessionId: s.id,
    revision: s.revision, requestId: id(), action: "guess", playerId: puzzle.playerId});
  await service.settleHint("alice", {id: "a1".repeat(24), context: benefit.context});
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 4);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adGranted`), 1);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 0);
});

test("already granted career credit recovers when guess phase ends, without marking assistance", async () => {
  const h = setup(); const s = (await h.call("startCareerTransfer", {mode: "career", version: ct.version,
    requestId: id()})).session;
  const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "career_hint", {sessionId: s.id, boostId: "boost_basic"});
  await service.settleHint("alice", {id: "b1".repeat(24), context: benefit.context});
  const path = `economyState/alice/careerTransfer/sessions/${s.id}`;
  assert.equal(h.read(path + "/adCredits"), 1);
  const puzzle = ct.careers.find((p) => p.id === h.read(path).puzzle);
  await h.call("actCareerTransfer", {mode: "career", version: ct.version, sessionId: s.id,
    revision: s.revision, requestId: id(), action: "guess", playerId: puzzle.playerId});
  await h.call("getCareerTransfer", {mode: "career"});
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 4);
  assert.equal(h.read(path + "/adCredits"), 0); assert.equal(h.read(path + "/assisted"), false);
});
test("full stock retains unused typed credit after finish, then recovers once space is available", async () => {
  const h = setup(); let s = await start(h); const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "transfer_hint", {sessionId: s.id, boostId: "boost_basic"});
  await service.settleHint("alice", {id: "b2".repeat(24), context: benefit.context});
  const stock = "economyState/alice/inventory/boost_basic/quantity";
  h.seed(stock, 99); s = (await h.call("actCareerTransfer", input(s, {action: "skip"}))).session;
  assert.equal(s.finished, true); assert.equal(s.support.recoveryPending, true);
  assert.equal(s.support.adCreditsByProduct.boost_basic, 0);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 1);
  h.seed(stock, 98); await h.call("getCareerTransfer", {mode: "transfer"});
  await h.call("getCareerTransfer", {mode: "transfer"}); assert.equal(h.read(stock), 99);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 0);
});
test("consumed typed credit cannot recover a second stock unit at finish", async () => {
  const h = setup(); let s = await start(h); const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "transfer_hint", {sessionId: s.id, boostId: "boost_basic"});
  await service.settleHint("alice", {id: "b3".repeat(24), context: benefit.context});
  s = (await h.call("actCareerTransfer", input(s, {paymentSource: "ad"}))).session;
  await h.call("actCareerTransfer", input(s, {action: "skip"}));
  assert.equal(h.read("economyState/alice/inventory/boost_basic/quantity"), 3);
  assert.equal(h.read(`economyState/alice/careerTransfer/sessions/${s.id}/adCredits`), 0);
});
