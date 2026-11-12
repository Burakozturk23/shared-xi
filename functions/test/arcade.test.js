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
const prepare = async (h, mode, extra = {}) => (await h.call("prepareArcade", {mode, version,
  clientVersion: 1, requestId: id(),
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
      assert.equal(b.pairs.length, 8); assert.equal(b.cards.length, 16);
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
// A right answer is judged by the player's own clubs (and country), not only by the
// list stored with the question: a real answer left off that list never costs time.
test("Burst: any player whose clubs fit the pair is right, listed or not", () => {
  const c = E.catalog;
  const q = c.burst.find((x) => x.pairType === "clubClub" && x.answers.length >= 7);
  const [, a, b] = q.id.split(":");
  const r = E.create(c, {mode: "burst", requestId: "fit", style: "speed", pairType: "clubClub"}, 0);
  Object.assign(r, {question: {...q, answers: q.answers.slice(1)}, paused: false, phase: "active"});
  const left = q.answers[0]; assert.ok(c.players[left].clubs.includes(a) && c.players[left].clubs.includes(b));
  E.act(c, r, {action: "answer", questionId: q.id, entityId: left}, 1000);
  assert.equal(r.wrong, 0); assert.ok(r.found.includes(left));
  const stranger = Object.keys(c.players).find((id) => !c.players[id].clubs.includes(a));
  E.act(c, r, {action: "answer", questionId: q.id, entityId: stranger}, 2000);
  assert.equal(r.wrong, 1);
});
// Burst asks about known clubs only, never a youth side, and levels follow how known
// the answers are.
test("Burst: known clubs only, no youth sides, levels by how known the answers are", () => {
  const pv = require("../pvp_engine").catalog;
  const known = new Set([...pv.gridClubs, ...pv.clubOptions].map((k) => k.slice(5)));
  const third = (q) => q.answers.map((id) => pv.players[id]?.rating || 0).sort((x, y) => y - x)[2];
  const mean = (t) => {
    const qs = E.catalog.burst.filter((q) => q.difficulty === t);
    return qs.reduce((n, q) => n + third(q), 0) / qs.length;
  };
  for (const q of E.catalog.burst) {
    const [type, a, b] = q.id.split(":");
    assert.ok(known.has(a) && (type === "clubCountry" || known.has(b)), q.left + " × " + q.right);
    assert.doesNotMatch(q.left + " " + q.right, /\b(U1[5-9]|U2[0-3]|You|Youth|II|B)\b$/);
  }
  assert.ok(mean("easy") > mean("normal") && mean("normal") > mean("hard") && mean("hard") > mean("legend"));
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
  const h = setup(); const a = await winMatching(h, "hard"); assert.equal(a.moves, 8); assert.equal(a.earnedCoins, 5);
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

test("Offline: replay validates every answer/clock, pays once and rejects forged future time atomically", async () => {
  const h = setup(); const s = await start(h, "burst", {style: "survival"});
  const simulation = E.hydrate(raw(h, s)); const events = [];
  for (let i = 0; i < 36; i++) {
    const event = {mode: "burst", sessionId: s.id, requestId: id(), revision: simulation.revision,
      action: "answer", questionId: simulation.question.id, elapsedMs: 1000,
      entityId: simulation.question.answers.find((id) => !simulation.found.includes(id))};
    E.tick(E.catalog, simulation, simulation.lastAt + 1000); E.act(E.catalog, simulation, event, simulation.lastAt);
    simulation.revision++; events.push(event);
  }
  await assert.rejects(h.call("replayArcade", {mode: "burst", events}), {code: "invalid-argument"});
  assert.equal(raw(h, s).correct, 0); assert.equal(h.read("economyState/alice/balances/coins"), 0);
  h.setTime(h.now + 36000);
  const done = await h.call("replayArcade", {mode: "burst", events});
  assert.equal(done.session.correct, 36); assert.equal(done.session.score, simulation.score);
  assert.equal(done.session.activeMs, 36000); assert.equal(done.session.earnedCoins, 9);
  const coins = h.read("economyState/alice/balances/coins");
  await h.call("replayArcade", {mode: "burst", events});
  assert.equal(h.read("economyState/alice/balances/coins"), coins);
});
test("Offline: an acknowledged-but-lost prefix is skipped; cross-device branches cannot overwrite", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  const first = {mode: "burst", sessionId: s.id, revision: s.revision, requestId: id(), action: "answer",
    entityId: raw(h, s).question.answers[0], questionId: s.question.id, elapsedMs: 1000};
  h.setTime(h.now + 1000); s = (await h.call("actArcade", {...first, platform: "android", clientVersion: 1})).session;
  const second = {...first, revision: s.revision, requestId: id(), entityId: raw(h, s).question.answers[1]};
  h.setTime(h.now + 1000);
  const result = await h.call("replayArcade", {mode: "burst", events: [first, second]});
  assert.equal(result.session.correct, 2); assert.equal(result.session.activeMs, 2000);
  const stale = {...second, revision: s.revision, requestId: id()};
  await assert.rejects(h.call("replayArcade", {mode: "burst", events: [stale]}), {code: "aborted"});
  assert.equal(raw(h, s).correct, 2);
});
test("Offline: clock events never reset total budget and paused time is excluded", async () => {
  const h = setup(); const s = await start(h, "burst");
  const steps = [["tick", 30000], ["pause", 1000], ["resume", 0], ["tick", 89000]];
  const events = steps.map(([action, elapsedMs], i) => ({mode: "burst", sessionId: s.id,
    revision: s.revision + i, requestId: id(), action, elapsedMs}));
  h.setTime(h.now + 180000);
  const result = await h.call("replayArcade", {mode: "burst", events});
  assert.equal(result.session.activeMs, 120000); assert.equal(result.session.finished, true);
  assert.equal(result.session.totalRemainingMs, 0); assert.equal(result.session.score, 0);
});
test("Burst clock: elapsedMs 0 cannot stop Speed Attack; the server clock is the floor", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "speed"});
  for (let i = 0; i < 20 && !s.finished; i++) {
    h.setTime(h.now + 10000);
    s = await act(h, s, {action: "answer", entityId: raw(h, s).question.answers.find((x) =>
      !(raw(h, s).found || []).includes(x)), elapsedMs: 0});
  }
  assert.equal(s.finished, true); assert.ok(raw(h, s).activeMs >= 100000);
  assert.ok(s.rounds < 20);
});
test("Burst Speed climbs tiers; Survival rounds time out at 75 s for a life", async () => {
  const r = E.create(E.catalog, {mode: "burst", style: "speed", pairType: "clubClub", requestId: id()}, 1);
  assert.equal(r.question.difficulty, "easy");
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  assert.equal(s.roundMs, 75000);
  h.setTime(h.now + 76000);
  s = await act(h, s, {action: "tick", elapsedMs: 76000});
  assert.equal(s.lives, 4); assert.match(s.message, /−1 can/);
});
test("Burst: pausing hides the pair; hints go nationality then initials and clear once found", async () => {
  const h = setup(); let s = await start(h, "burst", {style: "survival"});
  const left = s.question.left;
  s = await act(h, s, {action: "pause"});
  assert.equal(s.question.hidden, true); assert.equal(s.question.left, undefined);
  s = await act(h, s, {action: "resume"}); assert.equal(s.question.left, left);
  h.seed(`economyState/alice/arcade/sessions/${s.id}/adCredits`, 2);
  s = await act(h, s, {action: "hint", elapsedMs: 1000}); assert.match(s.hint, /^Bir cevabın milliyeti: /);
  s = await act(h, s, {action: "hint", elapsedMs: 1000}); assert.doesNotMatch(s.hint, /milliyeti/);
  const hinted = raw(h, s).hinted[0];
  s = await act(h, s, {action: "answer", entityId: hinted, elapsedMs: 1000}); assert.equal(s.hint, "");
});
test("Burst: medals are kept with rewards off; Speed records hold no lives", async () => {
  const h = harness({runtimeConfig: {arcade: {enabled: true, rewardsEnabled: false},
    energy: {enabled: false}}}, {omitEmptyObjects: true});
  let s = await start(h, "burst", {style: "speed"});
  for (let i = 0; i < 6; i++) {
    h.setTime(h.now + 2000); s = await correct(h, s);
  }
  s = await act(h, s, {action: "finish"});
  const st = h.read("economyState/alice/arcade");
  assert.ok(st.medals["burst:v1:speed:bronze"]); assert.equal(st.claims, undefined);
  const rec = Object.values(st.records)[0];
  assert.equal(rec.bestLives, undefined); assert.ok(rec.bestAverageAnswerMs > 0);
});
test("Burst offline: an answer for a round the clock already closed is dropped, not the batch", async () => {
  const h = setup(); const s = await start(h, "burst", {style: "speed"});
  const q = raw(h, s).question;
  const events = [
    {mode: "burst", sessionId: s.id, revision: s.revision, requestId: id(), action: "tick",
      questionId: q.id, elapsedMs: 29000},
    {mode: "burst", sessionId: s.id, revision: s.revision + 1, requestId: id(), action: "answer",
      questionId: q.id, entityId: q.answers[0], elapsedMs: 2000},
  ];
  h.setTime(h.now + 40000);
  const result = await h.call("replayArcade", {mode: "burst", events});
  assert.match(result.session.message, /geç gelen cevap/); assert.equal(result.session.correct, 0);
});
test("Burst search ranks better-known players first among equal matches", async () => {
  const h = setup();
  const {items} = await h.call("searchArcade", {mode: "burst", query: "silva"});
  const ranks = items.map((x) => E.catalog.players[x.id].rank);
  const starts = items.map((x) => x.name.toLowerCase().startsWith("silva"));
  for (let i = 1; i < items.length; i++) {
    if (starts[i] === starts[i - 1]) assert.ok(ranks[i - 1] <= ranks[i]);
  }
});
const fillable = (b, filled) => b.slots.find((x) => !filled[x.id] && x.supports.length === 2 &&
  x.supports.every((n) => filled[n]));
async function solvePyramid(h, s, {undoOnce = false} = {}) {
  let undone = !undoOnce;
  while (!s.finished) {
    const r = E.hydrate(raw(h, s)); const slot = fillable(r.board, r.filled);
    s = await act(h, s, {action: "answer", slotId: slot.id, entityId: r.board.certificate[slot.id]});
    if (!undone) {
      s = await act(h, s, {action: "undo"}); undone = true;
    }
  }
  return s;
}
test("Pyramid catalog: 150 boards, hard boards are tighter than normal", () => {
  const boards = E.catalog.pyramids;
  assert.equal(boards.length, 150);
  const mean = (d) => boards.filter((b) => b.difficulty === d).reduce((n, b) => n + b.looseness, 0) /
    boards.filter((b) => b.difficulty === d).length;
  assert.ok(mean("hard") < mean("normal") - 3);
  for (const b of boards.slice(0, 20)) assert.ok(E.solve(E.catalog, b, b.initial));
});
test("Pyramid: win bonus rewards lives and no hints; undo costs bonus and hard mastery", async () => {
  const h = setup(); let s = await start(h, "pyramid", {difficulty: "hard"});
  assert.equal(s.board.cells, 9);
  s = await solvePyramid(h, s);
  assert.equal(s.won, true); assert.equal(raw(h, s).bonus, 700); assert.equal(s.score, 900 + 700);
  assert.ok(h.read("economyState/alice/arcade/claims")["pyramid:v1:master"]);
  const h2 = setup(); let s2 = await start(h2, "pyramid", {difficulty: "hard"});
  s2 = await solvePyramid(h2, s2, {undoOnce: true});
  assert.equal(raw(h2, s2).bonus, 650);
  assert.equal(h2.read("economyState/alice/arcade/claims")["pyramid:v1:master"], undefined);
});
test("Pyramid: an unlinked answer costs a life; hints come in two steps", async () => {
  const h = setup(); let s = await start(h, "pyramid", {difficulty: "normal"});
  const r = E.hydrate(raw(h, s)); const slot = fillable(r.board, r.filled);
  const used = new Set(Object.values(r.filled));
  const need = slot.supports.map((n) => r.filled[n]).concat(slot.row === 1 ? [r.filled["0"]] : []);
  const linked = Object.keys(E.catalog.entities).filter((id) => !used.has(id) &&
    need.every((n) => E.edge(E.catalog, id, n)));
  const unlinked = Object.keys(E.catalog.entities).find((id) => !used.has(id) && !linked.includes(id));
  s = await act(h, s, {action: "answer", slotId: slot.id, entityId: unlinked});
  assert.equal(s.lives, 4); assert.match(s.message, /uymuyor/);
  // \p{L}, not \w: \w misses "ü" in "Kulüp".
  s = await act(h, s, {action: "hint", slotId: slot.id}); assert.match(s.hint, /^Aday türü: \p{L}+\.$/u);
  s = await act(h, s, {action: "hint", slotId: slot.id}); assert.ok(s.hint.length > "Aday türü: Oyuncu.".length);
});
// A real link that leaves the pyramid unsolvable (Argentina under De Paul and
// Maradona when nothing Argentine reaches the top) is a right answer for that
// cell: it costs nothing and says why it cannot stay.
test("Pyramid: a linked answer that cannot reach the top is free and says so", () => {
  let found;
  for (const b of E.catalog.pyramids) {
    const slot = fillable(b, b.initial); const used = new Set(Object.values(b.initial));
    const need = slot.supports.map((n) => b.initial[n]).concat(slot.row === 1 ? [b.initial["0"]] : []);
    const dead = Object.keys(E.catalog.entities).find((id) => !used.has(id) &&
      need.every((n) => E.edge(E.catalog, id, n)) && !E.solve(E.catalog, b, {...b.initial, [slot.id]: id}));
    if (dead) {
      found = {b, slot, dead}; break;
    }
  }
  assert.ok(found, "some board has a linked dead end");
  const r = E.create(E.catalog, {mode: "pyramid", requestId: "dead-end", difficulty: found.b.difficulty}, 0);
  Object.assign(r, {board: structuredClone(found.b), filled: {...found.b.initial}, paused: false, phase: "active"});
  E.act(E.catalog, r, {action: "answer", slotId: found.slot.id, entityId: found.dead}, 1000);
  assert.equal(r.lives, 5); assert.equal(r.wrong, 0); assert.equal(r.filled[found.slot.id], undefined);
  assert.match(r.message, /^Bağlantı doğru/);
});
test("Pyramid links come from the entities: shared club, a club he played for, his country", () => {
  const c = E.catalog; const ents = Object.values(c.entities);
  const players = ents.filter((x) => x.type === "player");
  const country = ents.find((x) => x.type === "country");
  const native = players.find((p) => p.countryId === country.countryId);
  assert.deepEqual(E.edge(c, native.id, country.id), {type: "nationality", countryId: country.countryId});
  assert.deepEqual(E.edge(c, country.id, native.id), {type: "nationality", countryId: country.countryId});
  const club = c.entities["c" + native.clubs[0]];
  assert.deepEqual(E.edge(c, native.id, club.id), {type: "seniorClub", clubId: native.clubs[0]});
  const mate = players.find((p) => p.id !== native.id && p.clubs.includes(native.clubs[0]));
  assert.equal(E.edge(c, native.id, mate.id).type, "sharedClub");
  assert.equal(E.edge(c, club.id, country.id), null);
  assert.equal(E.edge(c, native.id, native.id), null);
});
test("Pyramid: new boards come first; today's board is the same for everyone", async () => {
  const h = setup(); const seen = new Set();
  for (let i = 0; i < 4; i++) {
    let s = await start(h, "pyramid", {difficulty: "easy"}); assert.ok(!seen.has(s.board.id)); seen.add(s.board.id);
    s = await act(h, s, {action: "finish"});
  }
  const a = setup(); const b = setup();
  const d1 = await start(a, "pyramid", {daily: true}); const d2 = await start(b, "pyramid", {daily: true});
  assert.equal(d1.board.id, d2.board.id); assert.ok(d1.daily); assert.equal(d1.difficulty, "normal");
  await assert.rejects(prepare(a, "burst", {daily: true}), {code: "invalid-argument"});
});
// Sixteen cards at every level; the level is how known the names are. Normal no
// longer deals Allegri with Pavia Calcio 1911.
test("Matching: 16 cards at every level, known names by level, no card matches a second one", () => {
  const pv = require("../pvp_engine").catalog;
  const rating = (id) => pv.players[id]?.rating || 0;
  const grid = new Set(pv.gridClubs.map((k) => k.slice(5)));
  const known = new Set([...grid, ...pv.clubOptions.map((k) => k.slice(5))]);
  const least = {easy: 80, normal: 76, hard: 72};
  for (const difficulty of ["easy", "normal", "hard"]) {
    for (let i = 0; i < 60; i++) {
      const b = E.matching(E.catalog, difficulty, "known" + i);
      for (const p of b.pairs) {
        const name = E.catalog.players[p.playerId].name + " / " + E.catalog.clubs[p.clubId].name;
        assert.ok(rating(p.playerId) >= least[difficulty], name);
        assert.ok((difficulty === "easy" ? grid : known).has(p.clubId), name);
        // Every club he ever played for is checked, not only the card's.
        assert.deepEqual(p.excluded, E.catalog.matchingClubs[p.playerId]);
        assert.ok(p.excluded.includes(p.clubId));
      }
    }
  }
  assert.ok(!E.catalog.matching.some((p) => E.catalog.players[p.playerId].name === "Massimiliano Allegri"));
});
test("Matching: card ids carry no pair; flipping ids in order is not a perfect game", async () => {
  for (let i = 0; i < 20; i++) {
    const b = E.matching(E.catalog, "hard", "ids" + i);
    assert.deepEqual(b.cards.map((x) => x.id), b.cards.map((_, k) => "k" + k));
  }
  const h = setup(); let s = await start(h, "matching", {difficulty: "hard"});
  for (let i = 0; i < 16 && !s.finished; i++) {
    h.setTime(h.now + 1100);
    s = await act(h, s, {action: "flip", cardId: s.board.cards[i].id});
  }
  assert.ok(!(s.finished && s.moves === 8), "sequential ids must not solve the board");
});
test("Matching: easy boards vary by seed; stars and hard mastery are tighter", async () => {
  const boards = new Set();
  for (let i = 0; i < 30; i++) {
    boards.add(E.matching(E.catalog, "easy", "easy" + i).pairs.map((p) => p.playerId).sort().join());
  }
  assert.ok(boards.size >= 10);
  assert.deepEqual(E.catalog.policy.stars.threePerPair, 1.75);
  const s = {records: {}, claims: {}, pending: {}, daily: {}};
  const base = {mode: "matching", phase: "active", finished: true, won: true, difficulty: "hard", hints: 0,
    wrong: 0, dataVersion: version, rewardKeys: [], earnedCoins: 0, activeMs: 50000, stars: 3};
  finalize(s, {...base, id: "a", moves: 13}, 1, true);
  assert.equal(s.claims["matching:v1:master"], undefined);
  finalize(s, {...base, id: "b", moves: 12}, 1, true);
  assert.ok(s.claims["matching:v1:master"]);
  assert.equal(Object.values(s.records)[0].bestStars, 3);
});
test("Matching: a paused win sets moves but no time record; today's board is shared", async () => {
  const s = {records: {}, claims: {}, pending: {}, daily: {}};
  const run = {mode: "matching", phase: "active", finished: true, won: true, difficulty: "normal", hints: 0,
    wrong: 0, dataVersion: version, rewardKeys: [], earnedCoins: 0, activeMs: 1000, moves: 14, stars: 2, pauses: 1};
  finalize(s, {...run, id: "p"}, 1, false);
  const rec = Object.values(s.records)[0];
  assert.equal(rec.bestMoves, 14); assert.equal(rec.bestTimeMs, undefined); assert.equal(rec.timeAtBestMoves, null);
  const h = setup(); let live = await start(h, "matching");
  live = await act(h, live, {action: "pause"}); assert.equal(raw(h, live).pauses, 1);
  const a = setup(); const b = setup();
  const d1 = await start(a, "matching", {daily: true}); const d2 = await start(b, "matching", {daily: true});
  assert.deepEqual(raw(a, d1).board.pairs.map((p) => p.playerId), raw(b, d2).board.pairs.map((p) => p.playerId));
  assert.ok(d1.daily); assert.equal(d1.difficulty, "normal");
});

test("starting a game never loads the whole stored catalog again", async () => {
  const h = setup(); let transactions = 0;
  const ref = h.db.ref;
  h.db.ref = (key = "") => {
    const node = ref(key);
    if (!key.startsWith("arcadeCatalogs/")) return node;
    const transaction = node.transaction;
    return {...node, transaction: (update) => {
      transactions++; return transaction(update);
    }};
  };
  await prepare(h, "pyramid", {difficulty: "normal"});
  assert.equal(transactions, 1); // first game pins the catalog
  assert.equal(h.read(`arcadeCatalogs/${version}/version`), version);
  await prepare(h, "matching", {difficulty: "normal"});
  assert.equal(transactions, 1);
});

test("no service re-reads a whole catalog to pin it", () => {
  const fs = require("node:fs"); const path = require("node:path");
  for (const file of ["arcade", "choice", "fake_club", "mystery_chain", "pvp"]) {
    const source = fs.readFileSync(path.join(__dirname, "..", file + ".js"), "utf8");
    assert.ok(!/Catalogs\/\$\{[^}]*\}`\)\.transaction/.test(source), file);
  }
});
