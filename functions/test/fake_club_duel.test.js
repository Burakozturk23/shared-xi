"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../fake_club");
const {timing, questions} = require("../career_transfer_online");
const version = catalog.version; const mode = "fake_club_duel";
let seq = 8000;
const id = () => (++seq).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const enter = async (h, uid, action, code) => (await h.call("enterCareerTransferOnline",
    {mode, version, action, code, requestId: id()}, auth(uid))).room;
const act = async (h, uid, r, action = "poll", extra = {}) => (await h.call("actCareerTransferOnline",
    {mode, version, roomId: r.id, action, ...(action === "poll" ? {} : {requestId: id()}), ...extra}, auth(uid))).room;
const raw = (h, r) => h.read(`careerTransferOnline/${mode}/rooms/${r.id}`);
function setup(options) {
  return harness({runtimeConfig: {fakeClub: {dataEnabled: true, friendsEnabled: true, rankedEnabled: true}}}, options);
}
async function pair(h, ranked = false) {
  const a = await enter(h, "alice", ranked ? "ranked" : "create");
  const b = await enter(h, "bob", ranked ? "ranked" : "join", a.code); assert.equal(a.id, b.id); return b;
}
async function play(h, r, bobAnswers = true) {
  const bank = raw(h, r);
  for (let i = 0; i < 10; i++) {
    const clock = timing(bank, i); h.setTime(clock.start + 1000);
    const a = await act(h, "alice", r); const b = await act(h, "bob", r);
    await act(h, "alice", r, "answer", {round: i, roundToken: a.roundToken, answer: bank.questions[i].answer});
    if (bobAnswers) {
      await act(h, "bob", r, "answer", {round: i, roundToken: b.roundToken,
        answer: b.question.options.find((x) => x.id !== bank.questions[i].answer).id});
    }
    h.setTime(clock.end + 1); await act(h, "alice", r); r = await act(h, "bob", r);
  }
  return r;
}
test("ON01-03: same ten questions, four clubs, 10s clocks, no answers until both submitted", async () => {
  assert.equal(questions(mode, "sample").length, 10);
  const h = setup({omitEmptyObjects: true}); const r = await pair(h); const bank = raw(h, r);
  h.setTime(bank.startedAt + 1000);
  const a = await act(h, "alice", r); const b = await act(h, "bob", r);
  assert.deepEqual(a.question, b.question); assert.equal(a.questionId, b.questionId);
  assert.equal(a.question.options.length, 4); assert.equal(a.deadline - a.startsAt, 10000);
  assert.equal(a.reveal, undefined); assert.equal(a.question.answer, undefined);
  assert.equal(a.question.fakeClubId, undefined); assert.equal(a.explanation, undefined);
  await act(h, "alice", r, "answer", {round: 0, roundToken: a.roundToken, answer: bank.questions[0].answer});
  assert.equal((await act(h, "bob", r)).opponentAnswer, undefined);
  const done = await act(h, "bob", r, "answer", {round: 0, roundToken: b.roundToken, answer: bank.questions[0].answer});
  assert.equal(done.reveal, bank.questions[0].answer); assert.ok(done.explanation);
  assert.equal(new Set(bank.questions.map((q) => q.public.player.id)).size, 10);
});
test("ON04: token, deadline, one answer and request fingerprints block forged submissions", async () => {
  const h = setup(); const r = await pair(h); const bank = raw(h, r); h.setTime(bank.startedAt + 1000);
  const a = await act(h, "alice", r);
  const req = {mode, version, roomId: r.id, action: "answer", round: 0, roundToken: a.roundToken,
    answer: bank.questions[0].answer, requestId: id(), score: 999999, clientTime: 0};
  await assert.rejects(h.call("actCareerTransferOnline", {...req, roundToken: "forged"}, auth("alice")),
      {code: "failed-precondition"});
  await Promise.all([h.call("actCareerTransferOnline", req, auth("alice")),
    h.call("actCareerTransferOnline", req, auth("alice"))]);
  assert.equal(raw(h, r).answers.alice[0].score, 145);
  await assert.rejects(h.call("actCareerTransferOnline", {...req, requestId: id()}, auth("alice")),
      {code: "already-exists"});
  h.setTime(bank.startedAt + 10000);
  await assert.rejects(h.call("actCareerTransferOnline", {...req, requestId: id()}, auth("bob")),
      {code: "failed-precondition"});
});
test("ON05-07: friend matches reward nothing; five ranked wins share allowance with other modes", async () => {
  const h = setup({omitEmptyObjects: true}); await play(h, await pair(h));
  assert.equal(h.read("rankedState"), null); assert.equal(h.read("economyState/alice/energy"), null);
  const existing = Object.fromEntries(Array.from({length: 4}, (_, i) => [String(i), {serverValidated: true,
    player1Uid: "alice", player2Uid: "old", settledAt: h.now}]));
  await h.db.ref("rankedState/settlements/career_race").set(existing);
  const r = await play(h, await pair(h, true)); assert.equal(r.status, "finished");
  await act(h, "alice", r); await act(h, "bob", r);
  assert.equal(h.read("economyState/alice/balances/coins"), 3);
  await play(h, await pair(h, true)); assert.equal(h.read("economyState/alice/balances/coins"), 3);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 8);
  assert.equal(h.read("rankedState/profiles/alice/modeStats/fake_club_duel/wins"), 2);
});
test("ON05-07: no-answer and forfeits receive no reward; resume preserves clock", async () => {
  const h = setup(); let r = await play(h, await pair(h, true), false);
  assert.equal(r.rewardEligible, false); assert.equal(h.read("economyState/bob/balances/coins"), null);
  r = await pair(h, true); const before = raw(h, r); h.setTime(before.startedAt + 5000);
  const resumed = await enter(h, "alice", "resume"); assert.equal(resumed.id, r.id);
  assert.equal(resumed.startedAt, before.startedAt);
  h.setTime(before.startedAt + 65000); r = await act(h, "alice", r);
  assert.equal(r.status, "forfeit"); assert.equal(r.rewardEligible, false);
});

test("ON rollout: closed by default; friend and ranked gates are independent", async () => {
  const h = harness(); await assert.rejects(pair(h), {code: "failed-precondition"});
  h.seed("runtimeConfig/fakeClub", {dataEnabled: true, friendsEnabled: true, rankedEnabled: false});
  const r = await pair(h); assert.equal(r.status, "playing");
  await assert.rejects(enter(h, "third", "ranked"), {code: "failed-precondition"});
});
test("ON05-06: tie breakers and forfeits: Elo without payment", async () => {
  const {outcome} = require("../career_transfer_online");
  const q = questions(mode, "tie");
  const room = {host: "alice", guest: "bob", startedAt: 0, questions: q, answers: {
    alice: {0: {correct: true, score: 100, elapsed: 2000}}, bob: {0: {correct: true, score: 100, elapsed: 3000}},
  }};
  assert.equal(outcome(room), "alice"); room.answers.bob[0].elapsed = 2000; assert.equal(outcome(room), null);
  room.answers.bob[0].score = 101; assert.equal(outcome(room), "bob");
  const h = setup(); const r = await pair(h, true); await act(h, "alice", r, "leave");
  await act(h, "bob", r);
  assert.equal(h.read("rankedState/profiles/alice/modeStats/fake_club_duel/losses"), 1);
  assert.equal(h.read("rankedState/profiles/bob/modeStats/fake_club_duel/wins"), 1);
  assert.equal(h.read("economyState/bob/balances/coins"), null);
});
