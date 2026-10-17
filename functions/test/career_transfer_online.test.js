"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../career_transfer");
const {questions, timing, outcome} = require("../career_transfer_online");
const version = catalog.version;
let n = 5000;
const id = () => (++n).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const enter = async (h, uid, mode, action, code) => (await h.call("enterCareerTransferOnline",
    {version, mode, action, code, requestId: id()}, auth(uid))).room;
const act = async (h, uid, room, action = "poll", extra = {}) => (await h.call("actCareerTransferOnline",
    {version, mode: room.mode, roomId: room.id, action, ...(action === "poll" ? {} : {requestId: id()}), ...extra},
    auth(uid))).room;
const read = (h, r) => h.read(`careerTransferOnline/${r.mode}/rooms/${r.id}`);
async function pair(h, mode, ranked = false) {
  const a = await enter(h, "alice", mode, ranked ? "ranked" : "create");
  const b = await enter(h, "bob", mode, ranked ? "ranked" : "join", a.code);
  assert.equal(a.id, b.id); return b;
}
async function play(h, r, aliceCorrect = true, bobCorrect = false) {
  const raw = read(h, r);
  for (let i = 0; i < raw.questions.length; i++) {
    const clock = timing(raw, i);
    h.setTime(new Date(clock.start + 1000).toISOString());
    await act(h, "alice", r); await act(h, "bob", r);
    if (aliceCorrect) await act(h, "alice", r, "answer", {round: i, answer: raw.questions[i].answer});
    if (bobCorrect) await act(h, "bob", r, "answer", {round: i, answer: raw.questions[i].answer});
    h.setTime(new Date(clock.end + 1).toISOString());
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
    answer: raw.questions[0].answer, requestId: id()};
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
