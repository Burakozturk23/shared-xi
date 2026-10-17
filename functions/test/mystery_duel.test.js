"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../mystery_chain");
const {timing, questions} = require("../career_transfer_online");
const version = catalog.version; const mode = "mystery_duel";
let seq = 8000;
const id = () => (++seq).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const enter = async (h, uid, action, code) => (await h.call("enterCareerTransferOnline",
    {mode, version, action, code, requestId: id()}, auth(uid))).room;
const act = async (h, uid, r, action = "poll", extra = {}) => (await h.call("actCareerTransferOnline",
    {mode, version, roomId: r.id, action, ...(action === "poll" ? {} : {requestId: id()}), ...extra}, auth(uid))).room;
const raw = (h, r) => h.read(`careerTransferOnline/${mode}/rooms/${r.id}`);
async function pair(h, ranked = false) {
  const a = await enter(h, "alice", ranked ? "ranked" : "create");
  const b = await enter(h, "bob", ranked ? "ranked" : "join", a.code); assert.equal(a.id, b.id); return b;
}
async function play(h, r, bobAnswers = true) {
  const bank = raw(h, r);
  for (let i = 0; i < 5; i++) {
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
test("M10-M11: same five questions, four plausible options and server-only 10s/20s clue schedule", async () => {
  assert.equal(questions(mode, "sample").length, 5);
  const h = harness({}, {omitEmptyObjects: true}); const r = await pair(h); const bank = raw(h, r);
  h.setTime(bank.startedAt + 9999);
  let a = await act(h, "alice", r); let b = await act(h, "bob", r);
  assert.deepEqual(a.question, b.question); assert.equal(a.questionId, b.questionId);
  assert.equal(a.question.options.length, 4); assert.equal(a.question.hints.length, 0);
  assert.equal(a.reveal, undefined); assert.equal(a.question.answer, undefined);
  h.setTime(bank.startedAt + 10000); a = await act(h, "alice", r); assert.equal(a.question.hints.length, 1);
  h.setTime(bank.startedAt + 20000); a = await act(h, "alice", r); b = await act(h, "bob", r);
  assert.equal(a.question.hints.length, 2); assert.deepEqual(a.question, b.question);
  await act(h, "alice", r, "answer", {round: 0, roundToken: a.roundToken, answer: bank.questions[0].answer});
  assert.equal((await act(h, "bob", r)).opponentAnswer, undefined);
});
test("M11: token, deadline, one answer and request fingerprints block forged submissions", async () => {
  const h = harness(); const r = await pair(h); const bank = raw(h, r); h.setTime(bank.startedAt + 1000);
  const a = await act(h, "alice", r);
  const req = {mode, version, roomId: r.id, action: "answer", round: 0, roundToken: a.roundToken,
    answer: bank.questions[0].answer, requestId: id(), score: 999999, clientTime: 0};
  await assert.rejects(h.call("actCareerTransferOnline", {...req, roundToken: "forged"}, auth("alice")),
      {code: "failed-precondition"});
  await Promise.all([h.call("actCareerTransferOnline", req, auth("alice")),
    h.call("actCareerTransferOnline", req, auth("alice"))]);
  assert.equal(raw(h, r).answers.alice[0].score, 148);
  await assert.rejects(h.call("actCareerTransferOnline", {...req, requestId: id()}, auth("alice")),
      {code: "already-exists"});
  h.setTime(bank.startedAt + 30000);
  await assert.rejects(h.call("actCareerTransferOnline", {...req, requestId: id()}, auth("bob")),
      {code: "failed-precondition"});
});
test("M12: friend matches reward nothing; five ranked wins share allowance with other modes", async () => {
  const h = harness({}, {omitEmptyObjects: true}); await play(h, await pair(h));
  assert.equal(h.read("rankedState"), null); assert.equal(h.read("economyState/alice/energy"), null);
  const existing = Object.fromEntries(Array.from({length: 4}, (_, i) => [String(i), {serverValidated: true,
    player1Uid: "alice", player2Uid: "old", settledAt: h.now}]));
  await h.db.ref("rankedState/settlements/career_race").set(existing);
  const r = await play(h, await pair(h, true)); assert.equal(r.status, "finished");
  await act(h, "alice", r); await act(h, "bob", r);
  assert.equal(h.read("economyState/alice/balances/coins"), 3);
  await play(h, await pair(h, true)); assert.equal(h.read("economyState/alice/balances/coins"), 3);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 8);
  assert.equal(h.read("rankedState/profiles/alice/modeStats/mystery_duel/wins"), 2);
});
test("M12: no-answer participant and forfeits receive no match reward; resume keeps room clock", async () => {
  const h = harness(); let r = await play(h, await pair(h, true), false);
  assert.equal(r.rewardEligible, false); assert.equal(h.read("economyState/bob/balances/coins"), null);
  r = await pair(h, true); const before = raw(h, r); h.setTime(before.startedAt + 5000);
  const resumed = await enter(h, "alice", "resume"); assert.equal(resumed.id, r.id);
  assert.equal(resumed.startedAt, before.startedAt);
  h.setTime(before.startedAt + 65000); r = await act(h, "alice", r);
  assert.equal(r.status, "forfeit"); assert.equal(r.rewardEligible, false);
});
