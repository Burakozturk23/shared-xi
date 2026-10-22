"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const E = require("../choice_engine");
const {finalize, state, dayFor} = require("../choice");
const {harness} = require("./support/economy_harness");
let seq = 0; const id = () => (++seq).toString(16).padStart(32, "0");
const setup = () => harness({runtimeConfig: {choice: {enabled: true, rewardsEnabled: true}, energy: {
  enabled: true, percent: 100, sessionModes: E.modes}}}, {omitEmptyObjects: true});
const prepare = async (h, mode, extra = {}) => (await h.call("prepareChoice", {mode, version: E.catalog.version,
  requestId: id(), clientVersion: 1, ...extra})).session;
const act = async (h, r, extra) => (await h.call("actChoice", {mode: r.mode, sessionId: r.id,
  revision: r.revision, requestId: id(), ...extra})).session;
const start = async (h, mode, extra) => act(h, await prepare(h, mode, extra), {action: "confirm"});
function fixture() {
  const c = structuredClone(E.catalog); const rows = [];
  for (let i = 1; i <= 240; i++) {
    const player = "test" + i; c.players[player] = {id: player, name: player}; rows.push({id: player, value: i});
  }
  c.metrics.fixture = {id: "fixture", gatePassed: true, groups: {test_scope: rows}}; return c;
}
const c = fixture();
const engine = (mode, extra = {}) => E.create(c, {mode, requestId: id(), metricId: "fixture", ...extra}, 1);
function win(r) {
  while (!r.finished) {
    const b = E.bracket(r.orderedCandidateIds, r.history); E.act(c, r, {action: "choose", candidateId: b.leftId});
  }
}
test("choice catalog: eight distinct themes, exact formats, no 128-club option", () => {
  assert.equal(Object.keys(E.catalog.themes).length, 8);
  for (const theme of Object.values(E.catalog.themes)) {
    assert.equal(theme.candidateCount, theme.type === "club" ? 64 : 128);
    if (theme.type === "club") assert.equal(theme.formats[128], undefined);
    for (const [size, f] of Object.entries(theme.formats)) {
      assert.equal(f.candidateIds.length, +size); assert.equal(new Set(f.candidateIds).size, +size);
      assert.ok(f.candidateIds.every((id) => E.catalog.candidates[id].legacyId));
    }
  }
});
test("choice content gates never mark unreviewed statistics or cards as verified", () => {
  const unreviewed = Object.values(E.catalog.metrics).filter((m) => !m.id.startsWith("uefa_ec_ucl_2023_"));
  assert.equal(unreviewed.length, 8);
  for (const m of unreviewed) {
    assert.equal(m.gatePassed, false); assert.throws(() => E.create(E.catalog,
        {mode: "higher_lower", metricId: m.id, requestId: id()}, 1));
  }
  assert.ok(Object.values(E.catalog.candidates).every((p) => p.contentStatus === "needs_review"));
});
test("tournament all sizes require N-1 decisions, undo crosses a round and corrupt history fails", () => {
  for (const size of [16, 32, 64, 128]) {
    const r = engine("this_or_that", {bracketId: "prime_battles_32", size});
    for (let i = 0; i < size / 2; i++) {
      E.act(c, r, {action: "choose",
        candidateId: E.bracket(r.orderedCandidateIds, r.history).leftId});
    }
    assert.equal(E.bracket(r.orderedCandidateIds, r.history).roundSize, size / 2);
    E.act(c, r, {action: "undo"}); assert.equal(E.bracket(r.orderedCandidateIds, r.history).roundSize, size);
    win(r); assert.equal(r.history.length, size - 1); assert.equal(r.championId, r.orderedCandidateIds[0]);
    const bad = structuredClone(r.history); bad[2].winnerId = "forged";
    assert.throws(() => E.bracket(r.orderedCandidateIds, bad));
  }
});
test("tournament projection strips private seeds, unsourced seasons and old claim strings", () => {
  const r = engine("this_or_that", {bracketId: "prime_battles_32"}); const pub = E.publicRun(c, r);
  assert.equal(pub.privateSeed, undefined);
  for (const p of Object.values(pub.candidates)) {
    assert.equal(p.legacyHighlight, undefined); assert.equal(p.seasonKey, undefined);
  }
});
test("ranking pair score excludes ties and counts tie-group exact positions", () => {
  assert.deepEqual(E.score([5, 4, 3, 2, 1]), {score: 100, exactMatches: 5, comparable: 10, correct: 10});
  assert.equal(E.score([1, 2, 3, 4, 5]).score, 0);
  assert.deepEqual(E.score([5, 5, 3, 2, 1]), {score: 100, exactMatches: 5, comparable: 9, correct: 9});
  assert.throws(() => E.score([0, 0, 0, 0, 0]));
});
test("objective ranking exact 5/10 unique diverse players and no future or value leak", () => {
  for (const size of [5, 10]) {
    for (let i = 0; i < 30; i++) {
      const r = engine("blind_ranking", {size}); assert.equal(new Set(r.orderedCandidateIds).size, size);
      assert.ok(new Set(Object.values(r.values)).size >= (size === 5 ? 4 : 7));
      const correctOrder = [...r.orderedCandidateIds].sort((a, b) => r.values[b] - r.values[a]);
      for (const player of r.orderedCandidateIds) {
        const pub = E.publicRun(c, r); assert.equal(pub.values, undefined);
        assert.equal(pub.orderedCandidateIds, undefined); assert.equal(pub.privateSeed, undefined);
        assert.equal(pub.current.id, player);
        const slot = correctOrder.indexOf(player);
        E.act(c, r, {action: "place", slot, candidateId: player});
        assert.throws(() => E.act(c, r, {action: "place", slot, candidateId: player}));
      }
      const pub = E.publicRun(c, r); assert.equal(pub.score, 100); assert.equal(pub.exactMatches, size);
      assert.equal(pub.current, undefined);
    }
  }
});
test("personal ranking four themes use unique real identities and never produce objective fields", () => {
  for (const themeId of Object.keys(c.personal)) {
    for (const size of [5, 10]) {
      const r = engine("blind_ranking", {type: "personal", themeId, size});
      for (let slot = 0; slot < size; slot++) {
        assert.ok(c.players[r.orderedCandidateIds[slot]]);
        E.act(c, r, {action: "place", slot, candidateId: r.orderedCandidateIds[slot]});
      }
      const pub = E.publicRun(c, r);
      for (const key of ["score", "exactMatches", "values", "comparable"]) assert.equal(pub[key], undefined);
    }
  }
});
test("higher/lower fresh identities, exact values, difficulty bands, answer lock and hidden projection", () => {
  let higher = 0; let total = 0;
  for (let n = 0; n < 70; n++) {
    const r = engine("higher_lower"); const used = new Set();
    for (let i = 0; i < 23; i++) {
      const q = r.question; assert.ok(q); assert.notEqual(q.leftValue, q.rightValue);
      assert.equal(q.difficulty, i < 3 ? "easy" : i < 9 ? "normal" : i < 19 ? "hard" : "master");
      for (const player of [q.leftId, q.rightId]) {
        assert.equal(used.has(player), false); used.add(player);
      }
      const pub = E.publicRun(c, r); assert.equal(pub.question[q.knownSide ? "leftValue" : "rightValue"], undefined);
      const up = q.knownSide ? q.leftValue > q.rightValue : q.rightValue > q.leftValue;
      higher += Number(up); total++;
      const event = {action: "guess", questionId: q.id, direction: up ? "higher" : "lower"};
      E.act(c, r, event); assert.equal(r.streak, i + 1); assert.throws(() => E.act(c, r, event));
      assert.equal(E.publicRun(c, r).question.leftValue, q.leftValue);
      E.act(c, r, {action: "next"});
    }
  }
  assert.ok(higher / total > .43 && higher / total < .57);
});
test("higher/lower first wrong ends zero streak and exhausted identities end safely", () => {
  const r = engine("higher_lower"); const q = r.question;
  const up = q.knownSide ? q.leftValue > q.rightValue : q.rightValue > q.leftValue;
  E.act(c, r, {action: "guess", questionId: q.id, direction: up ? "lower" : "higher"});
  assert.equal(r.finished, true); assert.equal(r.streak, 0); assert.ok(E.publicRun(c, r).question.rightValue);
  r.usedIds = c.metrics.fixture.groups.test_scope.map((p) => p.id); assert.equal(E.higherPair(c, r), null);
});
test("ranking uses UTC day while tournament and streak use Istanbul day", () => {
  const t = Date.parse("2026-09-20T22:00:00Z");
  assert.equal(dayFor("blind_ranking", t), "2026-09-20"); assert.equal(dayFor("this_or_that", t), "2026-09-21");
  assert.equal(dayFor("higher_lower", t), "2026-09-21");
});
const total = (s, prefix = "") => Object.entries(s.claims).filter(([k]) => k.startsWith(prefix))
    .reduce((a, [, v]) => a + v.coins, 0);
const complete = (mode, extra) => ({id: id(), mode, dataVersion: "test", phase: "active", finished: true,
  completed: mode !== "higher_lower", practice: false, ...extra});
test("streak thresholds pay only difference, shared six coin cap, eight lifetime achievement coins", () => {
  const s = state();
  for (const [metricId, streak] of [["a", 5], ["a", 10], ["a", 20], ["a", 20], ["b", 20], ["c", 20]]) {
    const r = complete("higher_lower", {metricId, streak}); finalize(s, r, 1, true); finalize(s, r, 1, true);
  }
  assert.equal(total(s, "streak__"), 6); assert.equal(total(s, "hl__"), 8); assert.equal(total(s), 14);
});
test("tournament quotas include theme-size uniqueness, lifetime caps and central daily mission", () => {
  const s = state(); const candidate = Object.keys(c.candidates)[0];
  for (const [i, type] of ["player", "player", "club", "club", "player"].entries()) {
    const r = complete("this_or_that", {bracketId: "theme" + (i === 1 ? 0 : i), size: 128, type,
      contentVerified: true, orderedCandidateIds: [candidate], history: []}); finalize(s, r, 1, true, c);
  }
  assert.equal(total(s, "complete__"), 10); assert.equal(total(s, "tot__"), 8);
  assert.equal(s.daily["mission__1970-01-01"].status, "pending");
});
test("ranking shared first-two quota and all eleven lifetime achievement coins", () => {
  const s = state();
  for (const [i, type] of ["objective", "objective", "objective", "personal"].entries()) {
    const r = complete("blind_ranking", {type, size: 10, metricId: "metric" + i,
      score: 100, exactMatches: 10, comparable: 45, values: {}, placements: []}); finalize(s, r, 1, true, c);
  }
  assert.equal(total(s, "rank__"), 6); assert.equal(total(s, "br__"), 11);
});
test("real callables validate gates before energy and unreviewed tournament is free practice", async () => {
  await assert.rejects(prepare(harness(), "blind_ranking", {type: "personal", themeId: "favorites"}),
      {code: "failed-precondition"});
  const h = setup();
  await assert.rejects(prepare(h, "higher_lower", {metricId: Object.keys(c.metrics)[0]}));
  assert.equal(h.read("economyState/alice/energy"), null);
  const r = await start(h, "this_or_that", {bracketId: "prime_battles_32"});
  assert.equal(r.practice, true); assert.equal(h.read("economyState/alice/energy/balance"), 6);
});
test("energy reserve cancel and concurrent confirm retry debit once; account and revision isolation", async () => {
  const h = setup(); const extra = {type: "personal", themeId: "favorites", size: 5};
  let r = await prepare(h, "blind_ranking", extra); await act(h, r, {action: "cancel"});
  assert.equal(h.read("economyState/alice/energy/balance"), 6);
  r = await prepare(h, "blind_ranking", extra); const event = {action: "confirm", requestId: id()};
  const [a, b] = await Promise.all([act(h, r, event), act(h, r, event)]);
  assert.equal(a.revision, b.revision); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await h.call("getChoice", {mode: r.mode}); assert.equal(h.read("economyState/alice/energy/balance"), 5);
  await assert.rejects(h.call("actChoice", {mode: r.mode, sessionId: r.id, revision: a.revision,
    requestId: id(), action: "finish"}, {uid: "bob"}), {code: "not-found"});
  await assert.rejects(act(h, r, {action: "place", slot: 0, candidateId: a.current.id}), {code: "aborted"});
});
test("personal completion is archived/awarded once and guest practice cannot earn after linking", async () => {
  for (const guest of [false, true]) {
    const h = setup(); h.setLinked("alice", !guest);
    let r = await start(h, "blind_ranking", {type: "personal", themeId: "favorites", size: 5});
    h.setLinked("alice", true);
    for (let slot = 0; slot < 4; slot++) r = await act(h, r, {action: "place", slot, candidateId: r.current.id});
    const event = {action: "place", slot: 4, candidateId: r.current.id, requestId: id()};
    const [a, b] = await Promise.all([act(h, r, event), act(h, r, event)]);
    assert.equal(a.earnedCoins, guest ? 0 : 4); assert.equal(a.earnedCoins, b.earnedCoins);
    const s = h.read("economyState/alice/choice"); assert.equal(Object.keys(s.archive).length, 1);
    assert.equal(Object.keys(s.records || {}).length, 0); assert.equal(Object.keys(s.pending || {}).length, 0);
    assert.equal(total(state(s)), guest ? 0 : 4);
  }
});
test("offline tournament replay is atomic, tolerates accepted prefix and rejects post-final undo", async () => {
  const h = setup(); const s = await start(h, "this_or_that", {bracketId: "prime_battles_32"});
  const r = E.hydrate(h.read(`economyState/alice/choice/sessions/${s.id}`)); const events = [];
  while (!r.finished) {
    const event = {mode: r.mode, sessionId: r.id, revision: r.revision++, requestId: id(), action: "choose",
      candidateId: E.bracket(r.orderedCandidateIds, r.history).leftId};
    E.act(c, r, event); events.push(event);
  }
  const bad = structuredClone(events); bad[7].candidateId = "invalid";
  await assert.rejects(h.call("replayChoice", {mode: r.mode, events: bad}));
  assert.equal(h.read(`economyState/alice/choice/sessions/${r.id}/revision`), s.revision);
  await h.call("actChoice", events[0]);
  const final = await h.call("replayChoice", {mode: r.mode, events});
  const again = await h.call("replayChoice", {mode: r.mode, events});
  assert.equal(final.session.completed, true); assert.equal(again.session.revision, 16);
  assert.equal(final.archive.length, 1); assert.equal(final.session.history.length, 15);
  await assert.rejects(act(h, final.session, {action: "undo"}), {code: "failed-precondition"});
});
test("interrupted XP projection repairs outbox, duplicate payload binding rejects altered event", async () => {
  const h = setup(); let r = await start(h, "blind_ranking", {type: "personal", themeId: "favorites", size: 5});
  for (let slot = 0; slot < 4; slot++) r = await act(h, r, {action: "place", slot, candidateId: r.current.id});
  const event = {mode: r.mode, sessionId: r.id, revision: r.revision, requestId: id(), action: "place", slot: 4,
    candidateId: r.current.id};
  h.failNext("progressionProfiles/alice");
  await assert.rejects(h.call("actChoice", event), /Simulated interrupted write/);
  await h.call("actChoice", event); await h.call("getChoice", {mode: r.mode});
  assert.equal(h.read("economyState/alice/balances/coins"), 4);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 8);
  assert.equal(h.read("economyState/alice/choice/pending"), null);
  await assert.rejects(h.call("actChoice", {...event, slot: 3}), {code: "invalid-argument"});
});

test("UEFA historical metrics have verified identities, explicit scope, and playable production pools", () => {
  const source = require("../../tools/choice/uefa_2023_snapshot.json");
  const accepted = new Map(source.rows.map((r) => [r.playerId, r]));
  assert.equal(accepted.size, 145);
  assert.ok(source.excluded.some((r) =>
    r.sourceName === "Deco" && r.reason === "nationality_mismatch"));
  for (const field of ["appearances", "goals"]) {
    const metricId = `uefa_ec_ucl_2023_${field}`; const m = E.catalog.metrics[metricId];
    assert.equal(m.gatePassed, true); assert.ok(m.scopeLabel.includes("elemeler"));
    assert.equal(m.sourceSha256, source.sourceSha256);
    for (const row of m.groups[source.scopeId]) {
      assert.equal(row.value, accepted.get(row.id)[field]); assert.ok(E.catalog.players[row.id]);
    }
    for (let i = 0; i < 20; i++) {
      const r = E.create(E.catalog, {mode: "higher_lower", metricId, requestId: id()}, 1);
      r.phase = "active";
      for (let turn = 0; turn < 20; turn++) {
        assert.equal(r.finished, false, "pool must support the twenty-streak tier");
        const pub = E.publicRun(E.catalog, r);
        assert.equal(pub.question[pub.question.knownSide === 0 ? "rightValue" : "leftValue"], undefined);
        assert.equal(pub.metric.groups, undefined); assert.equal(pub.metric.sourceColumn, undefined);
        assert.equal(pub.metric.edition, "2022/23 UEFA arşivi");
        E.act(E.catalog, r, {action: "guess", questionId: r.question.id,
          direction: r.question.knownSide === 0 ? (r.question.rightValue > r.question.leftValue ? "higher" : "lower") :
            (r.question.leftValue > r.question.rightValue ? "higher" : "lower")});
        assert.equal(r.correct, true);
        if (turn < 19) E.act(E.catalog, r, {action: "next"});
      }
      assert.equal(new Set(r.usedIds).size, r.usedIds.length);
      for (const size of [5, 10]) {
        const ranked = E.create(E.catalog,
            {mode: "blind_ranking", type: "objective", size, metricId, requestId: id()}, 1);
        ranked.phase = "active";
        const pub = E.publicRun(E.catalog, ranked);
        assert.equal(pub.values, undefined); assert.equal(pub.orderedCandidateIds, undefined);
        assert.ok(pub.metric.scopeLabel.includes("1955–2023"));
        for (let slot = 0; slot < size; slot++) {
          E.act(E.catalog, ranked,
              {action: "place", slot, candidateId: ranked.orderedCandidateIds[slot]});
        }
        assert.equal(ranked.finished, true); assert.ok(ranked.score >= 0 && ranked.score <= 100);
      }
    }
  }
});
