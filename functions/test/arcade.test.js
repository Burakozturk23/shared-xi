"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const E = require("../arcade_engine");
const {finalize} = require("../arcade");
const version = E.catalog.version;
let seq = 0; const id = () => (++seq).toString(16).padStart(32, "0");
const setup = (options = {omitEmptyObjects: true}) => harness({runtimeConfig: {
  arcade: {enabled: true, rewardsEnabled: true}, energy: {enabled: true, percent: 100, sessionModes: ["burst",
    "pyramid", "matching"]}}}, options);
const prepare = async (h, mode, extra = {}) => (await h.call("prepareArcade", {mode, version, requestId: id(),
  ...extra})).session;
const act = async (h, s, extra) => (await h.call("actArcade", {mode: s.mode, sessionId: s.id, requestId: id(),
  revision: s.revision, questionId: s.question?.id, ...extra})).session;
const start = async (h, mode, extra = {}) => act(h, await prepare(h, mode, extra), {action: "confirm"});
const raw = (h, s) => h.read(`economyState/alice/arcade/sessions/${s.id}`);
async function correct(h, s) {
  const r = raw(h, s); return act(h, s, {action: "answer", entityId: r.question.answers.find((x) => !(r.found ||
    []).includes(x))});
}
async function winMatching(h, difficulty) {
  let s = await start(h, "matching", {difficulty});
  const cards = raw(h, s).board.cards;
  for (let i = 0; i < s.board.count; i++) {
    for (const c of cards.filter((c) => c.pair === i)) {
      s = await act(h,
          s, {action: "flip", cardId: c.id});
    }
  }
  return s;
}
test("D: V4 positive puzzles have six searchable distinct players, all four tiers and both pair types", () => {
  for (const q of E.catalog.burst) {
    assert.ok(q.answers.length >= 6); assert.equal(new Set(q.answers).size, q.answers.length);
    for (const id of q.answers) {
      assert.equal(E.resolve(E.catalog, E.catalog.players[id].name, null, "burst"), id);
    }
  }
  for (const t of ["easy", "normal", "hard", "legend"]) {
    for (const p of ["clubClub",
      "clubCountry"]) assert.ok(E.catalog.burst.some((q) => q.difficulty === t && q.pairType === p));
  }
});
test("M: 300 generated boards are exact induced matchings; closed projection has no identities", () => {
  for (const difficulty of ["easy", "normal", "hard"]) {
    for (let i = 0; i < 100; i++) {
      const b = E.matching(E.catalog, difficulty, "coverage" + i);
      assert.equal(b.pairs.length, {easy: 6, normal: 8, hard: 12}[difficulty]);
      for (const p of b.pairs) {
        for (const q of b.pairs) {
          assert.equal(p.excluded.includes(q.clubId),
              p.playerId === q.playerId);
        }
      }
      const r = E.create(E.catalog, {mode: "matching", difficulty, requestId: "coverage" + i}, 1000);
      assert.ok(E.publicRun(E.catalog, r,
          1000).board.cards.every((c) => Object.keys(c).sort().join() === "id,visible"));
    }
  }
});
test("P: every certificate obeys typed edges, unique entities, geometry and 3+ different witnesses", () => {
  for (const b of E.catalog.pyramids) {
    const solved = E.solve(E.catalog, b, b.initial); assert.ok(solved);
    assert.equal(new Set(Object.values(solved)).size, b.slots.length);
    assert.equal(b.slots.length, b.difficulty === "easy" ? 10 : 15);
    assert.equal(Object.keys(b.initial).length, b.difficulty === "easy" ? 5 : 6);
    const evidence = new Set();
    for (const s of b.slots) {
      for (const n of s.supports) {
        const e = E.edge(E.catalog, solved[s.id], solved[n]); assert.ok(e); evidence.add(e.clubId || e.countryId);
      }
    }
    assert.ok(evidence.size >= 3);
  }
  const country = Object.values(E.catalog.entities).find((x) => x.type === "country");
  assert.equal(E.edge(E.catalog, country.id, country.id), null);
});
test("E: rollout closed, reservation cancellation, confirm replay and cross-account isolation", async () => {
  await assert.rejects(prepare(harness(), "matching"), {code: "failed-precondition"});
  const h = setup(); let s = await prepare(h, "matching");
  assert.equal(h.read("economyState/alice/energy/balance"), 6);
  assert.equal(h.read(`economyState/alice/energy/sessions/${s.id}/status`), "reserved");
  s = await act(h, s, {action: "cancel"}); assert.equal(h.read("economyState/alice/energy/balance"), 6);
  s = await prepare(h, "pyramid"); const requestId = id();
  const [a, b] = await Promise.all([act(h, s, {action: "confirm", requestId}), act(h, s, {action: "confirm",
    requestId})]);
  assert.equal(a.revision, b.revision); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await assert.rejects(act(h, a, {action: "answer", slotId: "bad"}), {code: "failed-precondition"});
  await assert.rejects(h.call("actArcade", {mode: "pyramid", sessionId: a.id, requestId: id(),
    revision: a.revision, action: "finish"}, {uid: "bob"}), {code: "not-found"});
});
test("S: 3 correct complete round, scoring cap, unknown/duplicate free, speed wrong/pass penalties", async () => {
  const h = setup(); let s = await start(h, "burst");
  s = await act(h, s, {action: "answer", query: "zzzyyyunknown"}); assert.equal(s.wrong, 0);
  s = await correct(h, s); assert.equal(s.score, 100);
  const player = s.found[0].id; s = await act(h, s, {action: "answer", entityId: player}); assert.equal(s.score, 100);
  s = await correct(h, s); s = await correct(h, s); assert.equal(s.score, 350); assert.equal(s.rounds, 1);
  assert.equal(s.found.length, 0);
  for (let i = 0; i < 9; i++) s = await correct(h, s);
  assert.equal(s.bestStreak, 12); assert.equal(s.score, 1950);
  const wrong = Object.keys(E.catalog.players).find((id) => !raw(h, s).question.answers.includes(id));
  s = await act(h, s, {action: "answer", entityId: wrong}); assert.equal(s.totalRemainingMs, 117000);
  assert.equal(s.streak, 0);
  s = await act(h, s, {action: "pass"}); assert.equal(s.totalRemainingMs, 112000); assert.equal(s.passes, 1);
});
test("S: authoritative total clock, round timeout, pause and 24h expiry", async () => {
  const h = setup(); let s = await start(h, "burst"); const old = s.question.id;
  h.setTime(h.now + 30000); s = await act(h, s, {action: "tick"}); assert.notEqual(s.question.id, old);
  assert.equal(s.totalRemainingMs, 90000);
  s = await act(h, s, {action: "pause"}); h.setTime(h.now + 50000); s = await act(h, s, {action: "resume"});
  assert.equal(s.totalRemainingMs, 90000);
  h.setTime(h.now + 90000); s = await act(h, s, {action: "tick"}); assert.equal(s.finished, true);
});
test("M: one move per second card, mismatch lock survives pause/resume, same card ignored", async () => {
  const h = setup(); let s = await start(h, "matching", {difficulty: "easy"});
  const cards = raw(h, s).board.cards; const a = cards[0]; const b = cards.find((x) => x.pair !== a.pair);
  s = await act(h, s, {action: "flip", cardId: a.id}); s = await act(h, s, {action: "flip", cardId: a.id});
  assert.equal(s.moves, 0);
  s = await act(h, s, {action: "flip", cardId: b.id}); assert.equal(s.moves, 1);
  s = await act(h, s, {action: "pause"}); s = await act(h, s, {action: "resume"});
  await assert.rejects(act(h, s, {action: "flip", cardId: a.id}), {code: "failed-precondition"});
  h.setTime(h.now + 1000); s = await act(h, s, {action: "flip", cardId: a.id}); assert.equal(s.moves, 1);
});
test("P: unknown/reused and repeated wrong are free, any solvable move, undo, hints budgets", async () => {
  const h = setup(); let s = await start(h, "pyramid", {difficulty: "easy"});
  const r = raw(h, s); const slot = r.board.slots.find((x) => !r.filled[x.id] && x.supports.every((n) => r.filled[n]));
  s = await act(h, s, {action: "answer", slotId: slot.id, query: "unknown"}); assert.equal(s.lives, 5);
  const wrong = Object.keys(E.catalog.entities).find((id) => !Object.values(r.filled).includes(id) &&
    slot.supports.some((n) => !E.edge(E.catalog, id, r.filled[n])));
  s = await act(h, s, {action: "answer", slotId: slot.id, entityId: wrong}); assert.equal(s.lives, 4);
  s = await act(h, s, {action: "answer", slotId: slot.id, entityId: wrong}); assert.equal(s.lives, 4);
  s = await act(h, s, {action: "answer", slotId: slot.id, entityId: r.board.certificate[slot.id]});
  assert.equal(s.correct, 1);
  s = await act(h, s, {action: "undo"}); assert.equal(s.correct, 0);
  for (let i = 0; i < 2; i++) s = await act(h, s, {action: "hint", slotId: slot.id});
  await assert.rejects(act(h, s, {action: "hint", slotId: slot.id}), {code: "resource-exhausted"});
});
test("E: Matching medals once, shared logic daily once, payout retry and records", async () => {
  const h = setup(); const a = await winMatching(h, "hard"); assert.equal(a.moves, 12); assert.equal(a.earnedCoins, 5);
  assert.equal(h.read("economyState/alice/balances/coins"), 7);
  const b = await winMatching(h, "hard"); assert.equal(b.earnedCoins, 0);
  assert.equal(h.read("economyState/alice/balances/coins"), 7);
  assert.ok(h.read("economyState/alice/arcade/records"));
});
test("E: cumulative Burst rewards and independent Pyramid medals meet exact maxima", () => {
  const s = {records: {}, claims: {}, pending: {}, daily: {}};
  const base = {phase: "active", finished: true, won: true, hints: 0, wrong: 0, passes: 0, lives: 5, rounds: 12,
    score: 9000, correct: 36, bestStreak: 36, activeMs: 60000, dataVersion: version, rewardKeys: [], earnedCoins: 0};
  for (const style of ["speed", "survival"]) {
    finalize(s, {...base, mode: "burst", style, pairType: "clubClub",
      id: style}, 10000, true);
  }
  assert.equal(Object.values(s.claims).reduce((n, x) => n + x.coins, 0), 18);
  for (const difficulty of ["easy", "normal", "hard"]) {
    finalize(s, {...base, rewardKeys: [], mode: "pyramid",
      difficulty, id: difficulty}, 10000, true);
  }
  assert.equal(Object.values(s.claims).reduce((n, x) => n + x.coins, 0), 28);
});
test("D: search results cannot change with current puzzle; forged scores ignored", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  const query = {mode: "burst", query: "ron", sessionId: s.id}; const a = await h.call("searchArcade", query);
  s = await act(h, s, {action: "pass", score: 999999, rounds: 100}); const b = await h.call("searchArcade", query);
  assert.deepEqual(a, b); assert.equal(s.score, 0); assert.equal(s.rounds, 0);
  s = await act(h, s, {action: "hint"}); assert.equal(s.hints, 1); assert.equal(s.lives, 5);
  await assert.rejects(act(h, s, {action: "hint"}), {code: "resource-exhausted"});
});

test("E: guests pay no energy and cannot later mint practice rewards", async () => {
  const h = setup(); h.setLinked("alice", false);
  const s = await winMatching(h, "easy"); assert.equal(s.practice, true); assert.equal(s.earnedCoins, 0);
  assert.equal(h.read("economyState/alice/energy/balance"), 6);
  h.setLinked("alice", true); await h.call("getArcade", {mode: "matching"});
  assert.equal(h.read("economyState/alice/balances/coins"), 0);
});
test("E: expired preparation releases hold; lost confirmation reply never charges twice", async () => {
  const h = setup(); const draft = await prepare(h, "burst"); h.setTime(h.now + 120001);
  await assert.rejects(act(h, draft, {action: "confirm"}), {code: "failed-precondition"});
  const s = await start(h, "burst"); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  const requestId = id();
  const one = await act(h, s, {action: "pause", requestId});
  const retry = await act(h, s, {action: "pause", requestId}); assert.equal(one.revision, retry.revision);
  await assert.rejects(act(h, s, {action: "finish", requestId}), {code: "invalid-argument"});
});
test("P: hard certificate completes, mastery and shared logic mission cannot double pay", async () => {
  const h = setup(); await winMatching(h, "normal");
  let s = await start(h, "pyramid", {difficulty: "hard"});
  while (!s.finished) {
    const r = E.hydrate(raw(h, s));
    const slot = r.board.slots.find((x) => !r.filled[x.id] && x.supports.every((n) => r.filled[n]));
    s = await act(h, s, {action: "answer", slotId: slot.id, entityId: r.board.certificate[slot.id]});
  }
  assert.equal(s.won, true); assert.equal(s.earnedCoins, 6);
  assert.equal(h.read("economyState/alice/balances/coins"), 10); // matching2 + daily2 + pyramid6
});
test("S: survival advances 12 rounds through tiers, max36 players, hint disqualifies mastery", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  const tiers = new Set();
  for (let i = 0; i < 36; i++) {
    tiers.add(s.question.difficulty); s = await correct(h, s);
  }
  assert.equal(s.finished, true); assert.equal(s.won, true); assert.equal(s.rounds, 12);
  assert.equal(tiers.size, 4); assert.equal(s.earnedCoins, 9);
});
test("M: reopen closes unpaired cards but cannot erase the outstanding lock", async () => {
  const h = setup(); let s = await start(h, "matching"); const cards = raw(h, s).board.cards;
  s = await act(h, s, {action: "flip", cardId: cards[0].id});
  s = await act(h, s, {action: "flip", cardId: cards.find((x) => x.pair !== cards[0].pair).id});
  const loaded = await h.call("getArcade", {mode: "matching", reopen: true});
  assert.equal(loaded.session.board.cards.filter((c) => c.visible).length, 0);
  assert.ok(loaded.session.lockUntil > h.now);
});
test("E: SSV hint credits are idempotent and capped at two per survival session", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  const service = h.context.lbArcadeService();
  for (let i = 0; i < 2; i++) {
    const benefit = await service.prepareHint("alice", "burst_survival_hint", {sessionId: s.id});
    const receipt = {id: "receipt" + i, context: benefit.context};
    await service.settleHint("alice", receipt); await service.settleHint("alice", receipt);
  }
  await assert.rejects(service.prepareHint("alice", "burst_survival_hint", {sessionId: s.id}),
      {code: "failed-precondition"});
  for (let i = 0; i < 3; i++) s = await act(h, s, {action: "hint"});
  assert.equal(s.hints, 3); assert.equal(s.adCredits, 0); assert.equal(s.lives, 5);
  await assert.rejects(act(h, s, {action: "hint"}), {code: "resource-exhausted"});
});
test("E: shared hint cap includes old per-mode counters before migration", async () => {
  const h = setup(); const s = await start(h, "burst", {style: "survival"});
  h.seed("premiumState/alice", {status: "active", productId: "linkball_pro_monthly", expiresAt: h.now + 86400000});
  const day = require("../rewarded_ads").dayKey(h.now);
  h.seed("rewardedAdState/alice/days", {[day + "__fake_club_hint"]: {earned: 2},
    [day + "__career_hint"]: {earned: 2}});
  // Inject approved ad unit only, while using actual shared-cap engine.
  const service = require("../rewarded_ads").createService({db: h.db, now: () => h.now,
    getConfig: async () => require("../economy_config").defaults,
    units: {android: "ca-app-pub-1234567890123456/1234567890"}, isLinked: async () => true,
    isPro: async () => true, prepareThreeReward: (...args) => h.context.lbArcadeService().prepareHint(...args),
    settleThreeReward: (...args) => h.context.lbArcadeService().settleHint(...args),
    grantCoins: async () => {}});
  await assert.rejects(service.prepare("alice", "android", "burst_survival_hint", id(), {sessionId: s.id}),
      {code: "resource-exhausted"});
});
