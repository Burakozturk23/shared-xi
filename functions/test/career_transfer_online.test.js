"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, players} = require("../career_transfer");
const {questions, timing, outcome, roundToken} = require("../career_transfer_online");
const version = catalog.version;
let n = 5000;
const id = () => (++n).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const enter = async (h, uid, mode, action, code) => (await h.call("enterCareerTransferOnline",
    {version, mode, action, code, requestId: id()}, auth(uid))).room;
const read = (h, r) => h.read(`careerTransferOnline/${r.mode}/rooms/${r.id}`);
// Career Race and Transfer Duel answers carry the round token like the other duels.
const token = (h, room, kind, extra) => kind === "answer" && ["career_race", "transfer_duel"].includes(room.mode) &&
  !("roundToken" in extra) ? {roundToken: roundToken(read(h, room), extra.round)} : {};
const act = async (h, uid, room, kind = "poll", extra = {}) => (await h.call("actCareerTransferOnline",
    {version, mode: room.mode, roomId: room.id, action: kind, ...(kind === "poll" ? {} : {requestId: id()}),
      ...token(h, room, kind, extra), ...extra}, auth(uid))).room;
async function pair(h, mode, ranked = false) {
  const a = await enter(h, "alice", mode, ranked ? "ranked" : "create");
  const b = await enter(h, "bob", mode, ranked ? "ranked" : "join", a.code);
  assert.equal(a.id, b.id); return b;
}
// A wrong but valid answer: another option, the reversed order, or another player.
function wrong(q) {
  if (q.kind === "order") return [...q.answer].reverse();
  if (q.kind === "transfer") return [...players.keys()].find((id) => id !== q.answer);
  return q.public.options.find((o) => o.id !== q.answer).id;
}
// bobAnswers: "right", "wrong" (a valid wrong answer) or "none".
async function play(h, r, aliceCorrect = true, bobAnswers = "wrong") {
  const raw = read(h, r);
  for (let i = 0; i < raw.questions.length; i++) {
    const clock = timing(read(h, r), i);
    h.setTime(new Date(clock.start + 1000).toISOString());
    await act(h, "alice", r); await act(h, "bob", r);
    if (aliceCorrect) await act(h, "alice", r, "answer", {round: i, answer: raw.questions[i].answer});
    if (bobAnswers !== "none") {
      await act(h, "bob", r, "answer", {round: i, answer: bobAnswers === "right" ? raw.questions[i].answer :
        wrong(raw.questions[i])});
    }
    h.setTime(new Date(Math.max(timing(read(h, r), i).end, clock.start + 1000) + 1).toISOString());
    await act(h, "alice", r); r = await act(h, "bob", r);
  }
  return r;
}
test("online banks have exact round mix, durations and unique server-only keys", () => {
  const q = questions("career_race", "test");
  assert.deepEqual(q.map((x) => x.kind), ["missing", "missing", "missing", "order", "order", "mystery"]);
  assert.equal(q.reduce((s, x) => s + x.duration, 0), 130000);
  assert.equal(new Set(q.map((x) => x.id.split("_")[0])).size, 6);
  assert.equal(questions("transfer_duel", "test").length, 5);
  for (const x of q) assert.equal(x.public.answer, undefined);
});
test("Career Race: hidden club never shows in the route, real distractors, 2 careers per difficulty", () => {
  const played = new Set(catalog.careers.flatMap((p) => p.stops.map((s) => s.clubId)));
  const byId = new Map(catalog.careers.map((p) => [p.id, p]));
  for (let i = 0; i < 60; i++) {
    const q = questions("career_race", "quality" + i);
    assert.deepEqual(q.map((x) => x.public.difficulty).sort(),
        ["beginner", "beginner", "legend", "legend", "normal", "normal"]);
    for (const x of q) {
      const p = byId.get(x.id.split("_")[0]);
      if (x.kind === "missing") {
        const hidden = x.public.route.indexOf("?");
        assert.equal(p.stops.filter((s) => s.clubId === x.answer).length, 1);
        assert.equal(p.stops[hidden].clubId, x.answer);
        assert.equal(new Set(x.public.options.map((o) => o.name)).size, 4);
        for (const o of x.public.options) {
          assert.ok(played.has(o.id));
          if (o.id !== x.answer) assert.ok(!p.stops.some((s) => s.clubId === o.id));
        }
      }
      if (x.kind === "order") {
        // Three consecutive stops of the career, in order.
        const at = p.stops.findIndex((s) => s.id === x.answer[0]);
        assert.deepEqual(x.answer, p.stops.slice(at, at + 3).map((s) => s.id));
      }
    }
  }
});
test("Transfer Duel: 2 easy, 2 medium, 1 hard, known players, no player or club pair twice", () => {
  const byId = new Map(catalog.transfers.map((p) => [p.id, p]));
  let multi = 0;
  for (let i = 0; i < 80; i++) {
    const q = questions("transfer_duel", "duel" + i); const moves = q.map((x) => byId.get(x.id));
    assert.deepEqual(q.map((x) => x.difficulty), ["easy", "easy", "medium", "medium", "hard"]);
    assert.equal(new Set(moves.map((p) => p.playerId)).size, 5);
    assert.equal(new Set(moves.map((p) => [p.fromClubId, p.toClubId].sort().join())).size, 5);
    assert.ok(moves.some((p) => p.year < 2015));
    for (const [j, p] of moves.entries()) {
      assert.ok(players.get(p.playerId).rank <= 3000);
      assert.equal(q[j].timedHints.length, 2);
      if (p.alsoPlayerIds) {
        multi++; assert.deepEqual(q[j].accepted, [p.playerId, ...p.alsoPlayerIds]);
      }
      assert.equal(q[j].public.answer, undefined); assert.equal(q[j].public.hints, undefined);
    }
  }
  assert.ok(multi > 0);
});
test("Transfer Duel opens hints at 10 s and 20 s, each lowers the base; shared moves accept all", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let r = await pair(h, "transfer_duel"); const raw = read(h, r);
  const at = async (i, ms) => {
    h.setTime(new Date(timing(raw, i).start + ms).toISOString());
    await act(h, "alice", r); return act(h, "bob", r);
  };
  r = await at(0, 1000); assert.deepEqual(r.question.hints, []);
  r = await at(0, 11000); assert.equal(r.question.hints.length, 1); assert.match(r.question.hints[0], /^Milliyet/);
  await act(h, "alice", r, "answer", {round: 0, answer: raw.questions[0].answer});
  r = await at(0, 21000); assert.equal(r.question.hints.length, 2); assert.match(r.question.hints[1], /^Mevki/);
  await act(h, "bob", r, "answer", {round: 0, answer: raw.questions[0].answer});
  const room = read(h, r);
  assert.equal(room.answers.alice[0].score, 100 - 15 + Math.floor(50 * 19000 / 30000));
  assert.equal(room.answers.bob[0].score, 100 - 30 + Math.floor(50 * 9000 / 30000));
  r = await at(0, 21500); assert.match(r.explanation, /\d{4}-\d{2}-\d{2}/);
  // A move several players made the same day accepts every one of them.
  const shared = catalog.transfers.find((p) => p.alsoPlayerIds);
  const key = `careerTransferOnline/transfer_duel/rooms/${r.id}`; const stored = read(h, r);
  stored.questions[1] = {...stored.questions[1], answer: shared.playerId,
    accepted: [shared.playerId, ...shared.alsoPlayerIds]};
  h.seed(key, stored);
  h.setTime(new Date(timing(read(h, r), 1).start + 1000).toISOString());
  await act(h, "alice", r); r = await act(h, "bob", r);
  await act(h, "alice", r, "answer", {round: 1, answer: shared.alsoPlayerIds[0]});
  assert.equal(read(h, r).answers.alice[1].correct, true);
});
test("Transfer Duel closes a round once both answered; the next starts 2 s later", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let r = await pair(h, "transfer_duel"); const raw = read(h, r);
  const start = timing(raw, 0).start; const at = async (ms) => {
    h.setTime(new Date(start + ms).toISOString()); await act(h, "alice", r); return act(h, "bob", r);
  };
  r = await at(1000); assert.equal(r.question.month, raw.questions[0].public.month);
  assert.match(String(r.question.month), /^(0[1-9]|1[0-2])$/);
  await act(h, "alice", r, "answer", {round: 0, answer: raw.questions[0].answer});
  r = await at(4000); assert.equal(r.reveal, undefined); assert.equal(r.deadline, start + 30000);
  await act(h, "bob", r, "answer", {round: 0, answer: wrong(raw.questions[0])});
  r = await at(5500); assert.equal(r.round, 0); assert.equal(r.reveal, raw.questions[0].answer);
  r = await at(7100); assert.equal(r.round, 1); assert.equal(r.startsAt, start + 6000);
  assert.equal(r.deadline, start + 36000); assert.ok(r.question.from);
  // Career Race moves on the same way.
  const g = harness({}, {omitEmptyObjects: true}); let c = await pair(g, "career_race"); const cr = read(g, c);
  g.setTime(new Date(timing(cr, 0).start + 1000).toISOString());
  await act(g, "alice", c); c = await act(g, "bob", c);
  await act(g, "alice", c, "answer", {round: 0, answer: cr.questions[0].answer});
  await act(g, "bob", c, "answer", {round: 0, answer: wrong(cr.questions[0])});
  g.setTime(new Date(timing(cr, 0).start + 1500).toISOString());
  c = await act(g, "bob", c); assert.equal(c.reveal, cr.questions[0].answer);
  g.setTime(new Date(timing(cr, 0).start + 3100).toISOString());
  c = await act(g, "bob", c); assert.equal(c.round, 1);
});
test("friend match: same questions, no early keys/opponent answers and no rewards or energy", async () => {
  const h = harness({}, {omitEmptyObjects: true}); let r = await pair(h, "career_race");
  const raw = read(h, r); h.setTime(new Date(raw.startedAt + 1000).toISOString());
  const a = await act(h, "alice", r); const b = await act(h, "bob", r);
  assert.deepEqual(a.question, b.question); assert.equal(a.question.answer, undefined);
  assert.equal(a.reveal, undefined);
  await act(h, "alice", r, "answer", {round: 0, answer: raw.questions[0].answer});
  assert.equal((await act(h, "bob", r)).opponentAnswer, undefined);
  for (let i = 0; i < raw.questions.length; i++) {
    const clock = timing(raw, i); h.setTime(new Date(clock.start + 1000).toISOString());
    await act(h, "alice", r); await act(h, "bob", r);
    if (i) await act(h, "alice", r, "answer", {round: i, answer: raw.questions[i].answer});
    h.setTime(new Date(clock.end + 1).toISOString());
    await act(h, "alice", r); r = await act(h, "bob", r);
  }
  assert.equal(r.status, "finished"); assert.equal(r.rewardEligible, false);
  assert.equal(h.read("rankedState"), null); assert.equal(h.read("economyState/alice/energy"), null);
});
test("one final answer, retry fingerprint, late submissions and unauthorized players", async () => {
  const h = harness(); const r = await pair(h, "transfer_duel"); const raw = read(h, r);
  await assert.rejects(act(h, "mallory", r), {code: "permission-denied"});
  await assert.rejects(act(h, "alice", r, "answer", {round: 0, answer: raw.questions[0].answer}),
      {code: "failed-precondition"});
  h.setTime(new Date(raw.startedAt + 1000).toISOString());
  const req = {version, mode: r.mode, roomId: r.id, action: "answer", round: 0,
    answer: raw.questions[0].answer, requestId: id(), roundToken: roundToken(raw, 0)};
  await Promise.all([h.call("actCareerTransferOnline", req, auth("alice")),
    h.call("actCareerTransferOnline", req, auth("alice"))]);
  await assert.rejects(act(h, "alice", r, "answer", {round: 0, answer: req.answer}), {code: "already-exists"});
  await assert.rejects(h.call("actCareerTransferOnline", {...req, answer: 1}, auth("alice")),
      {code: "invalid-argument"});
  h.setTime(new Date(raw.startedAt + 30000).toISOString());
  await assert.rejects(act(h, "bob", r, "answer", {round: 0, answer: req.answer}), {code: "failed-precondition"});
});
test("ranked completion settles ELO and once-only Coin/XP, both modes share first five", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  for (let i = 0; i < 6; i++) {
    let r = await pair(h, i % 2 ? "career_race" : "transfer_duel", true);
    r = await play(h, r);
    assert.equal(r.status, "finished");
    await Promise.all([act(h, "alice", r), act(h, "bob", r)]);
  }
  assert.equal(h.read("economyState/alice/balances/coins"), 15);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 40);
  assert.equal(h.read("economyState/bob/balances/coins"), 5);
  assert.equal(h.read("progressionState/bob/lifetimeXp"), 20);
  assert.equal(h.read("rankedState/profiles/alice/wins"), 6);
  assert.equal(h.read("rankedState/profiles/alice/modeStats/career_race/wins"), 3);
});
test("legacy ranked settlements consume the same first-five allowance", async () => {
  const rows = Object.fromEntries(Array.from({length: 5}, (_, i) => [String(i), {serverValidated: true,
    player1Uid: "alice", player2Uid: "old", settledAt: Date.parse("2026-09-20T09:00:00Z")}]));
  const h = harness({rankedState: {settlements: {grid: rows}}});
  const r = await play(h, await pair(h, "transfer_duel", true));
  assert.equal(r.status, "finished");
  assert.equal(h.read("economyState/alice/balances/coins"), null);
  assert.equal(h.read("economyState/bob/balances/coins"), 1);
});
test("a ranked player who answered nothing gets no reward, whatever the mode", async () => {
  const h = harness({}, {omitEmptyObjects: true});
  for (const mode of ["career_race", "transfer_duel"]) {
    let r = await pair(h, mode, true);
    r = await play(h, r, true, "none");
    assert.equal(r.status, "finished"); assert.equal(r.rewardEligible, false);
  }
  assert.equal(h.read("economyState/bob/balances/coins"), null);
  assert.ok(h.read("economyState/alice/balances/coins") > 0);
});
test("short disconnect resumes same clock; 60s absence forfeits without economic reward", async () => {
  const h = harness(); const r = await pair(h, "transfer_duel", true); const raw = read(h, r);
  h.setTime(new Date(raw.startedAt + 10000).toISOString());
  assert.equal((await act(h, "alice", r)).startedAt, raw.startedAt);
  h.setTime(new Date(raw.startedAt + 61000).toISOString());
  const end = await act(h, "alice", r);
  assert.equal(end.status, "forfeit"); assert.equal(end.rewardEligible, false);
  assert.equal(h.read("rankedState"), null);
});
test("all score/time ties draw; explicit leave and blocked pairing never reward", async () => {
  const raw = {host: "a", guest: "b", answers: {}, questions: questions("transfer_duel", "tie"), startedAt: 1};
  assert.equal(outcome(raw), null);
  const h = harness({blocks: {alice: {bob: true}, bob: {alice: true}}});
  const a = await enter(h, "alice", "career_race", "create");
  await assert.rejects(enter(h, "bob", "career_race", "join", a.code), {code: "permission-denied"});
  assert.equal((await act(h, "alice", a, "leave")).status, "cancelled");
});
test("scheduled reconcile closes silent matches and does not repeat settled projections", async () => {
  const h = harness(); let r = await pair(h, "transfer_duel", true);
  r = await play(h, r);
  assert.equal(read(h, r).settled, true);
  const profile = h.read("users/alice"); const coins = h.read("economyState/alice/balances/coins");
  h.setTime(h.now + 60000);
  await h.call("reconcileCareerTransferOnline");
  assert.deepEqual(h.read("users/alice"), profile);
  assert.equal(h.read("economyState/alice/balances/coins"), coins);
  r = await pair(h, "career_race", true);
  h.setTime(h.now + 65000);
  await h.call("reconcileCareerTransferOnline");
  assert.equal(read(h, r).status, "forfeit");
});

for (const mode of ["career_race", "transfer_duel", "mystery_duel", "fake_club_duel"]) {
  test(`${mode}: ranked polling cannot prolong the queue; expiry permits a fresh search`, async () => {
    const h = harness({runtimeConfig: {fakeClub: {dataEnabled: true, friendsEnabled: true, rankedEnabled: true}}});
    const v = mode === "fake_club_duel" ? require("../fake_club").catalog.version :
      mode === "mystery_duel" ? require("../config/mystery_chain_catalog.json").version : version;
    const search = async () => (await h.call("enterCareerTransferOnline",
        {mode, version: v, action: "ranked", requestId: id()}, auth("alice"))).room;
    const first = await search(); const began = h.now;
    for (const offset of [10000, 20000, 29999, 30000]) {
      h.setTime(began + offset);
      const r = (await h.call("actCareerTransferOnline",
          {mode, version: v, roomId: first.id, action: "poll"}, auth("alice"))).room;
      assert.equal(r.status, offset < 30000 ? "waiting" : "cancelled");
      assert.equal(r.expiresAt, began + 30000);
    }
    assert.equal(h.read(`careerTransferOnline/${mode}/queue/alice`), null);
    const next = await search(); assert.notEqual(next.id, first.id); assert.equal(next.status, "waiting");
  });
  test(`${mode}: fresh host block and play-kind boundary are enforced`, async () => {
    const h = harness({runtimeConfig: {fakeClub: {dataEnabled: true, friendsEnabled: true, rankedEnabled: true}}});
    const v = mode === "fake_club_duel" ? require("../fake_club").catalog.version :
      mode === "mystery_duel" ? require("../config/mystery_chain_catalog.json").version : version;
    const call = (uid, action, code) => h.call("enterCareerTransferOnline",
        {mode, version: v, action, code, requestId: id()}, auth(uid));
    const {room} = await call("alice", "create");
    h.seed("blocks/alice/bob", true);
    await assert.rejects(call("bob", "join", room.code), {code: "permission-denied"});
    await assert.rejects(call("alice", "ranked"), {code: "already-exists"});
    assert.equal((await call("alice", "resume")).room.id, room.id);
    h.setTime(h.now + 300000);
    await h.context.exports.reconcileCareerTransferOnline();
    assert.equal(h.read(`careerTransferOnline/${mode}/rooms/${room.id}/status`), "cancelled");
  });
}
