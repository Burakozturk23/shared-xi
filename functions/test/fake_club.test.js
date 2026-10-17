"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, createService, multiplier} = require("../fake_club");
const version = catalog.version;
let seq = 0;
const id = () => (++seq).toString(16).padStart(32, "0");
const enabled = {dataEnabled: true, soloEnabled: true, rewardsEnabled: true, friendsEnabled: true, rankedEnabled: true};
const setup = (extra = {}, options = {omitEmptyObjects: true}) => harness({runtimeConfig: {fakeClub: enabled,
  energy: {enabled: true, percent: 100, sessionModes: ["fake_club"]}}, ...extra}, options);
const start = async (h, mode = "fake_endless", extra = {}) => (await h.call("startFakeClub",
    {mode, version, requestId: id(), ...extra})).session;
const act = async (h, s, extra) => (await h.call("actFakeClub", {mode: s.mode, version, requestId: id(),
  sessionId: s.id, questionId: s.question.questionId, revision: s.revision, ...extra})).session;
const raw = (h, s) => h.read(`economyState/alice/fakeClub/sessions/${s.id}`);
const answer = (h, s, correct = true) => act(h, s, {action: "answer",
  clubId: correct ? raw(h, s).question.fakeClubId : raw(h, s).question.realClubIds[0]});
const next = (h, s) => act(h, s, {action: "next"});
async function run(h, mode, count, correct = true) {
  let s = await start(h, mode);
  for (let i = 0; i < count; i++) {
    s = await answer(h, s, typeof correct === "function" ? correct(i) : correct);
    if (i < count - 1 && !s.finished) s = await next(h, s);
  }
  return s;
}

test("SC01-04: every question excludes the entire reviewed V4 career and has exactly 3 real + 1 fake", () => {
  const seen = new Set();
  for (const q of catalog.questions) {
    const c = catalog.careers.find((c) => c.playerId === q.playerId);
    assert.equal(c.coverage, "REVIEWED_COMPLETE_RETIRED"); assert.ok(c.sources.length);
    assert.equal(q.dataVersion, version); assert.ok(q.questionId.startsWith(version));
    assert.ok(!seen.has(q.questionId)); seen.add(q.questionId);
    assert.ok(!c.excludedClubIds.includes(q.fakeClubId));
    assert.equal(new Set(q.options.map((o) => o.id)).size, 4);
    assert.equal(q.options.filter((o) => c.seniorClubIds.includes(o.id)).length, 3);
    for (const o of q.options) assert.ok(o.name && o.country && o.league);
  }
  assert.ok(catalog.careers.length >= 30);
  for (const tier of ["easy", "normal", "hard", "legend"]) {
    assert.ok(new Set(catalog.questions.filter((q) => q.difficulty === tier).map((q) => q.playerId)).size >= 30);
  }
  const beckham = catalog.careers.find((c) => c.playerId === 4000000023);
  assert.ok(beckham.excludedClubIds.includes(466)); // Preston loan, even when not on the visible triple.
});
test("SC05/12: rollout gate and empty valid pool never spend energy; one atomic start survives retries", async () => {
  const closed = harness(); await assert.rejects(start(closed), {code: "failed-precondition"});
  const h = setup(); const requestId = id();
  const [a, b] = await Promise.all([start(h, "fake_endless", {requestId}), start(h, "fake_endless", {requestId})]);
  assert.equal(a.id, b.id); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("getFakeClub", {mode: "fake_endless"});
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await assert.rejects(start(h, "fake_speed", {requestId}), {code: "invalid-argument"});
  const blocked = setup({runtimeConfig: {fakeClub: {...enabled,
    disabledQuestions: catalog.questions.map((q) => q.questionId)},
  energy: {enabled: true, percent: 100, sessionModes: ["fake_club"]}}});
  await assert.rejects(start(blocked), {code: "failed-precondition"});
  assert.equal(blocked.read("economyState/alice"), null);
});
test("SC06/10: endless scoring, all difficulties, unique players, safe exhaustion", async () => {
  const h = setup(); let s = await start(h); const seen = new Set(); const tiers = new Set(); let expected = 0;
  for (let i = 1; i <= catalog.careers.length; i++) {
    const pid = s.question.player.id; assert.ok(!seen.has(pid)); seen.add(pid); tiers.add(s.question.difficulty);
    assert.equal(s.deadline, null); assert.equal(s.fakeClubId, undefined); assert.equal(s.explanation, undefined);
    s = await answer(h, s); expected += 50 * multiplier(i);
    assert.equal(s.quick, false); assert.equal(s.score, expected);
    s = await next(h, s); if (s.finished) break;
  }
  assert.ok(s.finished); assert.equal(seen.size, catalog.careers.length);
  assert.equal(tiers.size, 4); assert.match(s.reason, /havuzu tamamlandı/);
  assert.equal(h.read("economyState/alice/fakeClub/records/fake_endless/bestStreak"),
      catalog.careers.length);
});
test("SC06: wrong resets streak; invalid/repeated answers preserve lives", async () => {
  const h = setup(); let s = await run(h, "fake_endless", 3);
  s = await next(h, s);
  await assert.rejects(act(h, s, {action: "answer", clubId: -999}), {code: "invalid-argument"});
  assert.equal(raw(h, s).lives, 3);
  for (let i = 0; i < 3; i++) {
    s = await answer(h, s, false); assert.equal(s.lives, 2 - i); assert.equal(s.streak, 0);
    if (!s.finished) {
      await assert.rejects(answer(h, s), {code: "already-exists"}); s = await next(h, s);
    }
  }
  assert.equal(s.finished, true); assert.equal(s.bestStreak, 3);
});
test("SC07: speed stops at ten questions, 3s bonus boundary and ten-second server timeout", async () => {
  const h = setup(); let s = await start(h, "fake_speed");
  h.setTime(h.now + 2999); s = await answer(h, s); assert.equal(s.points, 100); assert.ok(s.quick);
  s = await next(h, s); h.setTime(h.now + 3000); s = await answer(h, s);
  assert.equal(s.points, 50); assert.equal(s.quick, false);
  s = await next(h, s); h.setTime(h.now + 10000); s = await answer(h, s);
  assert.equal(s.wasCorrect, false); assert.equal(s.lives, 2); assert.equal(s.selectedId, null);
  for (let i = 3; i < 10; i++) {
    s = await next(h, s); s = await answer(h, s);
  }
  assert.ok(s.finished); assert.equal(s.answers, 10); assert.equal(s.correct, 9);
  assert.equal(h.read("economyState/alice/energy/balance"), 5);
  const early = setup(); const ended = await run(early, "fake_speed", 3, false);
  assert.ok(ended.finished); assert.equal(ended.answers, 3);
});
test("SC08/09: 50/50 removes two real clubs; trace never wastes rights", async () => {
  const h = setup({economyState: {alice: {inventory: {boost_first_letter: {quantity: 2}}}}});
  let s = await start(h); s = await act(h, s, {action: "fifty"});
  assert.equal(s.eliminated.length, 2); assert.ok(!s.eliminated.includes(raw(h, s).question.fakeClubId));
  s = await act(h, s, {action: "trace", boost: "boost_first_letter"});
  assert.equal(s.confirmed.length, 1); assert.ok(!s.eliminated.includes(s.confirmed[0]));
  await assert.rejects(act(h, s, {action: "trace", boost: "boost_first_letter"}), {code: "resource-exhausted"});
  assert.equal(h.read("economyState/alice/inventory/boost_first_letter/quantity"), 1);
  s = await answer(h, s); assert.equal(s.cleanStreak, 0);
  s = await next(h, s); await assert.rejects(act(h, s, {action: "fifty"}), {code: "resource-exhausted"});
  s = await act(h, s, {action: "trace", boost: "boost_first_letter"});
  assert.equal(s.traceRemaining, 0); assert.equal(s.hintsUsed, 3);
  const speed = await start(h, "fake_speed");
  await assert.rejects(act(h, speed, {action: "fifty"}), {code: "failed-precondition"});
  await assert.rejects(act(h, speed, {action: "trace", boost: "boost_first_letter"}), {code: "failed-precondition"});
});
test("SC11/13: lifetime medals pay 12+8 coins only once; common daily adds 2 and records stay isolated", async () => {
  const h = setup(); let s = await run(h, "fake_endless", 30);
  assert.equal(s.earnedCoins, 12); assert.equal(h.read("economyState/alice/balances/coins"), 14);
  await act(h, s, {action: "finish"});
  s = await run(h, "fake_speed", 10); assert.equal(s.earnedCoins, 8);
  assert.equal(h.read("economyState/alice/balances/coins"), 22);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 44);
  const records = h.read("economyState/alice/fakeClub/records");
  assert.equal(records.fake_endless.bestStreak, 30); assert.equal(records.fake_speed.bestStreak, 10);
  s = await run(h, "fake_speed", 10); assert.equal(s.earnedCoins, 0);
  assert.equal(h.read("economyState/alice/balances/coins"), 22);
});
test("SC13: hinted streak cannot win mastery; later clean 30 streak can", async () => {
  const h = setup(); let s = await start(h); s = await act(h, s, {action: "fifty"});
  for (let i = 0; i < 30; i++) {
    s = await answer(h, s); if (i < 29) s = await next(h, s);
  }
  assert.equal(s.earnedCoins, 8); assert.equal(s.cleanStreak, 29);
  s = await next(h, s); s = await answer(h, s); assert.equal(s.earnedCoins, 12);
});
test("SC13: common daily cap, midnight and crash recovery", async () => {
  const h = setup(); h.setTime("2026-10-17T20:50:00Z");
  h.seed("missionState/alice", {version: 2, daily: {dateKey: "2026-10-17", claims: {
    daily_ranked_play_3: {rewardCoins: 5}, daily_ranked_win_1: {rewardCoins: 5}, daily_challenge_1: {rewardCoins: 5},
  }}});
  let s = await run(h, "fake_endless", 5);
  assert.equal(h.read("economyState/alice/balances/coins"), 2);
  await act(h, s, {action: "finish"}); h.setTime("2026-10-17T21:00:01Z");
  s = await run(h, "fake_endless", 4); s = await next(h, s);
  h.failNext("progressionProfiles/alice");
  await assert.rejects(answer(h, s), /Simulated interrupted write/);
  assert.equal(h.read("economyState/alice/balances/coins"), 4);
  h.setTime("2026-10-18T21:00:01Z");
  await h.call("getFakeClub", {mode: "fake_endless"});
  assert.equal(h.read("economyState/alice/balances/coins"), 4);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 8);
  assert.equal(h.read("economyState/alice/fakeClub/daily/2026-10-18/status"), "paid");
});
test("SC12/14: pinned version, resume expiry, request fingerprint and account isolation", async () => {
  const h = setup(); let s = await start(h); const stored = raw(h, s);
  h.seed("fakeClubCatalogs/fc-old", {...catalog, version: "fc-old"});
  h.seed(`economyState/alice/fakeClub/sessions/${s.id}/dataVersion`, "fc-old");
  const req = {mode: s.mode, version, sessionId: s.id, requestId: id(), revision: s.revision,
    questionId: s.question.questionId, action: "answer", clubId: stored.question.fakeClubId};
  await Promise.all([h.call("actFakeClub", req), h.call("actFakeClub", req)]);
  assert.equal(raw(h, s).answers, 1);
  await assert.rejects(h.call("actFakeClub", {...req, clubId: stored.question.realClubIds[0]}),
      {code: "invalid-argument"});
  await assert.rejects(h.call("actFakeClub", {...req, requestId: id()}, {uid: "bob", token: {}}), {code: "not-found"});
  s = (await h.call("getFakeClub", {mode: s.mode})).session; s = await next(h, s);
  assert.equal(s.dataVersion, "fc-old");
  h.setTime(s.expiresAt + 1); s = (await h.call("getFakeClub", {mode: s.mode})).session;
  assert.ok(s.finished); assert.match(s.reason, /24 saat/);
});
test("SC05: invalidated active question refunds one energy once; new games exclude it", async () => {
  const h = setup(); const s = await start(h);
  h.seed("runtimeConfig/fakeClub/disabledQuestions", [s.question.questionId]);
  await h.call("getFakeClub", {mode: s.mode}); await h.call("getFakeClub", {mode: s.mode});
  assert.equal(raw(h, s).voided, true); assert.equal(h.read("economyState/alice/energy/balance"), 6);
  assert.notEqual((await start(h)).question.questionId, s.question.questionId);
});
test("SC09: SSV cancellation and replay cannot mint trace rights", async () => {
  const h = setup(); const service = h.context.lbFakeClubService(); let s = await start(h);
  const unit = "ca-app-pub-1234567890123456/1234567890";
  const ads = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults, units: {android: unit},
    isLinked: async () => false, isPro: async () => false,
    prepareThreeReward: service.prepareHint, settleThreeReward: service.settleHint,
    grantCoins: async () => assert.fail("Hint cannot mint coins"),
  });
  const prepare = () => ads.prepare("alice", "android", "fake_club_hint", id(), {sessionId: s.id});
  const event = (t) => ({user_id: "alice", custom_data: t.id, ad_unit: unit, timestamp: h.now,
    transaction_id: id(), reward_amount: "999999"});
  let {ticket} = await prepare(); await ads.cancel("alice", ticket.id);
  await assert.rejects(ads.accept(event(ticket)), {code: "permission-denied"});
  assert.equal(raw(h, s).adCredits, 0);
  for (let i = 0; i < 2; i++) {
    h.setTime(h.now + 31000); ({ticket} = await prepare()); const e = event(ticket);
    await ads.accept(e); await ads.accept(e);
    s = await act(h, s, {action: "trace"}); s = await answer(h, s); s = await next(h, s);
  }
  assert.equal(raw(h, s).adGranted, 2); assert.equal(s.traceRemaining, 0);
  await assert.rejects(prepare(), {code: "failed-precondition"});
  const speed = await start(h, "fake_speed");
  await assert.rejects(service.prepareHint("alice", "fake_club_hint", {sessionId: speed.id}),
      {code: "failed-precondition"});
});
test("SC14: background timeout does not rewind", async () => {
  const h = setup(); let s = await start(h, "fake_speed");
  h.setTime(h.now + 3600000); s = (await h.call("getFakeClub", {mode: s.mode})).session;
  assert.equal(s.answers, 1); assert.equal(s.lives, 2); assert.equal(s.answered, true);
  const again = (await h.call("getFakeClub", {mode: s.mode})).session;
  assert.equal(again.answers, 1); assert.equal(again.deadline, s.deadline);
  s = await next(h, s); assert.equal(s.deadline, h.now + 10000);
});
test("SC13: guest badge rights remain private and settle on linking the same uid", async () => {
  const h = setup(); let linked = false;
  const service = createService({db: h.db, normalize: h.context.lbEconomyState,
    project: async () => {}, getRollout: async () => ({}), getPolicy: async () => enabled,
    isLinked: async () => linked, now: () => h.now,
    grantCoins: (...args) => h.context.lbProgressionGrantCoins(h.db, ...args),
    grantXp: h.context.lbCareerTransferGrantXp, dailyClaim: h.context.lbFakeClubDailyClaim});
  let s = (await service.start("guest", {mode: "fake_endless", version, requestId: id()})).session;
  for (let i = 0; i < 5; i++) {
    const q = h.read(`economyState/guest/fakeClub/sessions/${s.id}/question`);
    const call = (action, extra = {}) => service.act("guest", {mode: s.mode, version, sessionId: s.id,
      requestId: id(), questionId: s.question.questionId, revision: s.revision, action, ...extra});
    s = (await call("answer", {clubId: q.fakeClubId})).session;
    if (i < 4) s = (await call("next")).session;
  }
  assert.equal(h.read("economyState/guest/balances/coins"), 0);
  await service.settle("bob"); assert.equal(h.read("economyState/bob"), null);
  linked = true; await service.settle("guest"); await service.settle("guest");
  assert.equal(h.read("economyState/guest/balances/coins"), 4);
  assert.equal(h.read("progressionState/guest/lifetimeXp"), 8);
});
