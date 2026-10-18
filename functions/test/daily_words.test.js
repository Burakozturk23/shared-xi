"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, compiled, normalize, feedback, weekKey} = require("../daily_words");
let seq = 0; const id = () => (++seq).toString(16).padStart(32, "0");
const TODAY = "2026-10-19";
function setup(extra = {}) {
  const h = harness({runtimeConfig: {dailyWords: {enabled: true, rewardsEnabled: true},
    energy: {enabled: true, percent: 100, sessionModes: ["anagram", "lingo", "passaparola"]}}, ...extra},
  {omitEmptyObjects: true});
  h.setTime(Date.parse(TODAY + "T10:00:00+03:00")); return h;
}
const load = (h, mode) => h.call("getDailyWords", {mode});
const run = async (h, mode) => (await load(h, mode)).session;
const raw = (h, r, uid = "alice") => h.read(r.mode === "passa_weekly" ?
  `dailyWordState/${uid}/weeks/${r.period}` : `dailyWordState/${uid}/days/${r.period}/${r.mode}`);
const input = (r, action, answer, extra = {}) => ({mode: r.mode, period: r.period,
  packId: r.packId, contentVersion: r.contentVersion, revision: r.revision, questionId: r.questionId,
  action, ...(answer == null ? {} : {answer}), requestId: id(), ...extra});
const act = async (h, r, action, answer, extra) =>
  (await h.call("actDailyWords", input(r, action, answer, extra))).session;
async function weekly(h) {
  const s = await load(h, "passa_weekly");
  return (await h.call("actDailyWords", {mode: s.mode, period: s.period, packId: s.packId,
    contentVersion: s.contentVersion, action: "start", requestId: id()})).session;
}
async function lingo(h) {
  const r = await run(h, "daily_lingo"); return act(h, r, "guess", raw(h, r).puzzle.answer);
}
async function passa(h, count = 7, classic = false) {
  let r = classic ? await weekly(h) : await run(h, "passa_daily");
  for (let n = 0; n < (classic ? 29 : 7); n++) {
    const q = raw(h, r).questions[r.index];
    r = await act(h, r, "guess", n < count ? q.answer : "Yanlış cevap");
  }
  return r;
}
async function anagram(h, count = 3) {
  let r = await run(h, "daily_anagram");
  for (let n = 0; n < 3; n++) {
    const q = raw(h, r).questions[r.index];
    if (n < count) r = await act(h, r, "guess", q.answer);
    else for (const answer of ["YANLIS", "OLMADI", "BILEMEDIM"]) r = await act(h, r, "guess", answer);
    if (n < 2) r = await act(h, r, "next");
  }
  return r;
}
const coins = (h) => h.read("economyState/alice/balances/coins") || 0;
const xp = (h) => h.read("progressionState/alice/lifetimeXp") || 0;

test("LG01/03/06 PA02/04/12/21 AN02/05/10/11: entire reviewed calendar, dictionary and letter bank", () => {
  assert.equal(catalog.alphabet.length, 29); assert.ok(catalog.alphabet.includes("Ğ"));
  assert.equal(catalog.players.length, 270); assert.ok(catalog.questions.length >= 174);
  assert.equal(Object.keys(catalog.daily).length, 90);
  const seen = new Set(); const seenLingo = new Set();
  const counts = (a) => a.reduce((m, v) => {
    m[v] = (m[v] || 0) + 1; return m;
  }, {});
  for (const letter of catalog.alphabet) {
    assert.ok(catalog.questions.filter((q) => q.letter === letter).length >= 6);
  }
  for (const q of catalog.questions) {
    assert.ok(q.proof); assert.ok(q.revision);
    for (const a of q.acceptedAnswers) {
      assert.equal(a, normalize(a));
      assert.ok(q.rule === "contains" ? a.includes(normalize(q.letter)) : a.startsWith(normalize(q.letter)));
    }
    if (q.letter === "Ğ") assert.match(q.answer, /[ğĞ]/);
  }
  for (const day of Object.keys(catalog.daily)) {
    const p = compiled(day, false);
    assert.ok(!seenLingo.has(p.lingo.id)); seenLingo.add(p.lingo.id);
    assert.match(p.lingo.answer, /^[A-Z]{4,9}$/);
    assert.ok(p.dictionary.includes(p.lingo.answer));
    const weekday = new Date(day + "T12:00:00Z").getUTCDay();
    assert.equal(p.lingo.category, ["player", "player", "club", "country", "player", "club", "country"][weekday]);
    assert.equal(new Set(p.questions.map((q) => q.letter)).size, 7);
    assert.deepEqual(counts(p.questions.map((q) => q.difficulty)), {1: 3, 2: 3, 3: 1});
    assert.deepEqual(p.anagram.map((q) => q.difficulty), [1, 2, 3]);
    for (const a of p.anagram) {
      assert.ok(!seen.has(a.id)); seen.add(a.id); assert.notEqual(a.answer, a.scrambled);
      assert.deepEqual([...a.answer].sort(), [...a.scrambled].sort());
    }
  }
  for (const week of Object.keys(catalog.weekly)) {
    const p = compiled(week, true);
    assert.equal(new Set(p.questions.map((q) => q.letter)).size, 29);
    assert.deepEqual(counts(p.questions.map((q) => q.difficulty)), {1: 10, 2: 13, 3: 6});
  }
});
test("LG05/06 AN04: normalization and exact-first duplicate-letter frequency", () => {
  assert.equal(normalize("I ı İ i Ç Ş Ğ Ü Ö é ø ł ß"), "IIIICSGUO EOLSS".replace(/ /g, ""));
  assert.equal(normalize("De Bruyne"), "DEBRUYNE");
  assert.deepEqual(feedback("BABEL", "AAAAA"), ["absent", "exact", "absent", "absent", "absent"]);
  assert.deepEqual(feedback("BABEL", "BBALL"), ["exact", "present", "present", "absent", "exact"]);
});
test("LG01/02 PA01/11 AN01/13: same package across accounts, repeat opens, zero energy", async () => {
  const h = setup();
  for (const mode of ["daily_lingo", "passa_daily", "daily_anagram"]) {
    const a = await run(h, mode); const b = (await h.call("getDailyWords", {mode}, {uid: "bob"})).session;
    assert.equal(a.packId, b.packId); assert.equal(a.questionId, b.questionId);
    assert.equal(a.packId, (await run(h, mode)).packId);
    assert.equal(a.contentVersion, b.contentVersion);
    if (mode === "daily_anagram") assert.equal(a.rounds[0].scrambledLetters, b.rounds[0].scrambledLetters);
  }
  assert.equal(h.read("economyState/alice/energy"), null);
});
test("closed rollout / missing future content cannot silently create a random replacement", async () => {
  const h = setup({runtimeConfig: {}});
  assert.equal((await load(h, "daily_lingo")).availability, false);
  assert.equal((await load(h, "daily_lingo")).session, null);
  const active = setup(); active.setTime(Date.parse("2027-02-01T10:00:00Z"));
  assert.equal((await load(active, "daily_anagram")).availability, false);
});
test("LG03/04/07/08/09/13: invalid guesses and premature hints never consume a turn or leak answer", async () => {
  const h = setup(); let r = await run(h, "daily_lingo");
  assert.equal(r.answer, undefined); assert.equal(r.display, undefined); assert.equal(r.hint, undefined);
  for (const answer of ["", "X", "Z".repeat(r.length)]) {
    await assert.rejects(act(h, r, "guess", answer), {code: "invalid-argument"});
  }
  await assert.rejects(act(h, r, "hint"), {code: "failed-precondition"});
  await assert.rejects(act(h, r, "buy_letter"), {code: "invalid-argument"});
  assert.equal((await run(h, "daily_lingo")).attempts, 0);
  const q = raw(h, r).puzzle;
  const wrong = compiled(TODAY, false).dictionary.filter((x) => x.length === r.length && x !== q.answer);
  for (let i = 0; i < 3; i++) r = await act(h, r, "guess", wrong[i]);
  r = await act(h, r, "hint"); assert.ok(r.hint); assert.equal(r.attempts, 3);
  assert.equal(r.answer, undefined);
  r = await act(h, r, "guess", q.answer);
  assert.equal(r.result.medal, "Altın"); assert.equal(r.result.coins, 3); assert.equal(r.result.xp, 6);
  await assert.rejects(act(h, r, "guess", wrong[3]), {code: "failed-precondition"});
});
test("LG14: six valid wrong guesses earn only participation XP, reveal/giveup earn nothing", async () => {
  const h = setup(); let r = await run(h, "daily_lingo");
  const answer = raw(h, r).puzzle.answer;
  const wrong = compiled(TODAY, false).dictionary.filter((x) => x.length === r.length && x !== answer);
  for (const word of wrong.slice(0, 6)) r = await act(h, r, "guess", word);
  assert.ok(r.finished); assert.equal(r.answer, answer); assert.equal(coins(h), 0); assert.equal(xp(h), 2);
  const b = setup(); const ended = await act(b, await run(b, "daily_lingo"), "giveup");
  assert.equal(ended.result.eligibleForDailyBonus, false); assert.equal(xp(b), 0);
});
test("PA03/05/06/07/18: letter aliases, Ğ, one pass and no early solutions", async () => {
  const h = setup(); let r = await weekly(h); const state = raw(h, r);
  assert.equal(r.question.answer, undefined); assert.equal(r.rounds[0].answer, undefined);
  const first = r.questionId;
  r = await act(h, r, "pass");
  for (let n = 0; n < 28; n++) {
    const q = raw(h, r).questions[r.index];
    if (q.letter === "Ğ") assert.equal(r.question.rule, "contains");
    r = await act(h, r, "guess", normalize(q.answer).toLowerCase());
    if (!r.finished) assert.equal(r.rounds.find((x) => x.status === "correct")?.answer, undefined);
  }
  assert.equal(r.questionId, first); assert.equal(r.question.passAvailable, false);
  await assert.rejects(act(h, r, "pass"), {code: "failed-precondition"});
  r = await act(h, r, "guess", state.questions[0].answer);
  assert.ok(r.finished); assert.equal(r.result.solved, 29); assert.equal(r.rounds.length, 29);
  const fullNameH = catalog.questions.find((q) => q.letter === "H" && q.answer === "Harry Kane");
  const fullNameL = catalog.questions.find((q) => q.letter === "L" && q.answer === "Luka Modrić");
  assert.ok(fullNameH); assert.ok(fullNameL);
  assert.ok(!fullNameH.acceptedAnswers.includes("KANE")); assert.ok(!fullNameL.acceptedAnswers.includes("MODRIC"));
});
test("PA08/16: 240-second deadline survives restart, delayed response and Monday rollover", async () => {
  const h = setup(); let r = await weekly(h); const deadline = r.deadline;
  assert.equal(deadline - h.now, 240000);
  const q = raw(h, r).questions[r.index]; r = await act(h, r, "guess", q.answer);
  h.setTime(h.now + 239999); assert.equal((await run(h, "passa_weekly")).deadline, deadline);
  h.setTime(deadline); r = await act(h, r, "guess", "forged");
  assert.ok(r.finished); assert.equal(r.result.solved, 1); assert.equal(xp(h), 3);
  assert.equal(weekKey(Date.parse("2026-10-18T20:59:59Z")), "2026-10-12");
  assert.equal(weekKey(Date.parse("2026-10-18T21:00:00Z")), "2026-10-19");
  const empty = setup(); let w = await weekly(empty); empty.setTime(w.deadline);
  w = await run(empty, "passa_weekly"); assert.equal(w.result.xp, 0); assert.equal(w.result.coins, 0);
});
test("PA13: all daily / weekly reward and medal thresholds are independent and capped", async () => {
  for (const [correct, coin, points] of [[0, 0, 1], [2, 0, 1], [3, 1, 2], [5, 2, 4], [7, 3, 6]]) {
    const h = setup(); const r = await passa(h, correct);
    assert.equal(r.result.coins, coin); assert.equal(r.result.xp, points);
    assert.equal((await run(h, "passa_daily")).result.solved, correct);
  }
  for (const [correct, coin, points] of [[0, 0, 0], [1, 0, 3], [15, 0, 3], [16, 2, 6], [29, 2, 6]]) {
    const h = setup(); const r = await passa(h, correct, true);
    assert.equal(r.result.coins, coin); assert.equal(r.result.xp, points);
  }
});
test("AN03/04/07/08: duplicate/empty guesses, two one-time hints and normalized full-name alias", async () => {
  const h = setup(); let r = await run(h, "daily_anagram");
  const q = raw(h, r).questions[0];
  assert.equal(r.rounds[0].answer, undefined); assert.equal(r.rounds[0].name, undefined);
  assert.equal(r.rounds[0].playerId, undefined); assert.equal(r.rounds[1].scrambledLetters, undefined);
  await assert.rejects(act(h, r, "guess", " "), {code: "invalid-argument"});
  r = await act(h, r, "guess", "Yanlış");
  await assert.rejects(act(h, r, "guess", "YANLIS"), {code: "already-exists"});
  r = await act(h, r, "bio"); r = await act(h, r, "bio");
  r = await act(h, r, "first"); r = await act(h, r, "first");
  assert.equal(r.rounds[0].guesses.length, 1); assert.equal(r.rounds[0].firstLetter, q.answer[0]);
  r = await act(h, r, "guess", q.name);
  assert.equal(r.rounds[0].score, 50); assert.equal(r.score, 50);
  assert.equal(r.rounds[0].name, q.name);
  await assert.rejects(act(h, r, "guess", q.answer), {code: "failed-precondition"});
});
test("AN09/14: daily scores, mastery and all solve/reveal reward bands", async () => {
  for (const correct of [0, 1, 2, 3]) {
    const h = setup(); const r = await anagram(h, correct);
    assert.equal(r.score, correct * 100); assert.equal(r.result.coins, correct);
    assert.equal(r.result.xp, correct ? correct * 2 : 1);
    assert.equal(r.result.medal === "Ustalık", correct === 3);
  }
  const h = setup(); let r = await run(h, "daily_anagram");
  for (let i = 0; i < 3; i++) {
    r = await act(h, r, "reveal"); if (i < 2) r = await act(h, r, "next");
  }
  assert.equal(r.result.xp, 0); assert.equal(r.result.eligibleForDailyBonus, false);
});
test("LG16 PA15 AN16: atomic trio pays exactly 11/22; practice and weekly never count", async () => {
  const h = setup(); await lingo(h); await passa(h); assert.equal(coins(h), 6);
  await anagram(h); assert.equal(coins(h), 11); assert.equal(xp(h), 22);
  for (const m of ["daily_lingo", "passa_daily", "daily_anagram"]) await load(h, m);
  assert.equal(coins(h), 11); assert.equal(xp(h), 22);
  const s = await load(h, "daily_anagram"); assert.equal(s.bonus.coins, 2); assert.equal(s.archive.streak, 1);
  await passa(h, 29, true); assert.equal(coins(h), 13); assert.equal(xp(h), 28);
  const skip = setup(); await lingo(skip); await passa(skip); let a = await run(skip, "daily_anagram");
  a = await act(skip, a, "giveup"); assert.equal(a.result.eligibleForDailyBonus, false);
  assert.equal((await load(skip, "daily_lingo")).bonus, null);
});
test("LG15/19 PA14/19 AN15/21: concurrent retries, forged revision, changed payload and wallet/XP crash", async () => {
  const h = setup(); const r = await run(h, "daily_lingo");
  const request = input(r, "guess", raw(h, r).puzzle.answer);
  await Promise.all([h.call("actDailyWords", request), h.call("actDailyWords", request)]);
  assert.equal(coins(h), 3); assert.equal(xp(h), 6);
  await assert.rejects(h.call("actDailyWords", {...request, answer: "WRONG"}), {code: "invalid-argument"});
  const b = setup(); const a = await run(b, "daily_anagram");
  const q = input(a, "guess", raw(b, a).questions[0].answer);
  await b.call("actDailyWords", q);
  await assert.rejects(b.call("actDailyWords", {...q, requestId: id()}), {code: "aborted"});
  const crash = setup(); const l = await run(crash, "daily_lingo");
  crash.failNext("progressionState/alice");
  await assert.rejects(act(crash, l, "guess", raw(crash, l).puzzle.answer));
  assert.equal(coins(crash), 3); await load(crash, "daily_lingo");
  assert.equal(coins(crash), 3); assert.equal(xp(crash), 6);
});
test("LG17/20 PA17 AN17/20: midnight expires old plays and published content remains pinned", async () => {
  const h = setup(); const r = await run(h, "daily_lingo");
  const request = input(r, "guess", raw(h, r).puzzle.answer);
  await h.call("actDailyWords", request);
  h.setTime(Date.parse("2026-10-19T21:00:00Z"));
  const newer = await run(h, "daily_lingo"); assert.equal(newer.period, "2026-10-20");
  assert.notEqual(newer.packId, r.packId); assert.equal(coins(h), 3);
  await h.call("actDailyWords", request); assert.equal(coins(h), 3);
  await assert.rejects(h.call("actDailyWords", {...request, requestId: id()}), {code: "failed-precondition"});
  const p = h.read("dailyWordPrivate/daily/2026-10-20");
  p.contentVersion = "dw-previous-deploy"; h.seed("dailyWordPrivate/daily/2026-10-20", p);
  const bob = (await h.call("getDailyWords", {mode: "daily_lingo"}, {uid: "bob"})).session;
  assert.equal(bob.contentVersion, "dw-previous-deploy"); assert.equal(bob.packId, p.packId);
  const old = await h.call("getDailyWordsHistory", {mode: "daily_lingo", period: TODAY});
  assert.ok(old.readOnly); assert.equal(old.session.result.solved, 1);
});
test("LG18 PA20 AN19: account isolation and guest upgrade retain only the same UID's reward", async () => {
  const h = setup(); h.setLinked("alice", false); await lingo(h);
  assert.equal(coins(h), 0); assert.equal(xp(h), 0);
  const bob = (await h.call("getDailyWords", {mode: "daily_lingo"}, {uid: "bob"})).session;
  assert.equal(bob.attempts, 0); assert.equal(bob.finished, false);
  h.setLinked("alice", true); await load(h, "daily_lingo");
  assert.equal(coins(h), 3); assert.equal(xp(h), 6);
});
test("withdrawal voids an unfinished pack without granting an extra attempt", async () => {
  const h = setup(); const r = await run(h, "daily_lingo");
  h.seed("runtimeConfig/dailyWords/disabledQuestions", [r.questionId]);
  const v = await run(h, "daily_lingo"); assert.equal(v.result.reason, "void");
  assert.equal(v.result.eligibleForDailyBonus, false); assert.equal(coins(h), 0);
  h.seed("runtimeConfig/dailyWords/disabledQuestions", []);
  assert.ok((await run(h, "daily_lingo")).finished);
});

test("AN06: server reshuffles preserve letters, never return the solution and cost no score/attempt", async () => {
  const h = setup(); let r = await run(h, "daily_anagram");
  const q = raw(h, r).questions[0];
  for (let n = 0; n < 20; n++) {
    r = await act(h, r, "shuffle");
    assert.notEqual(r.rounds[0].scrambledLetters, q.answer);
    assert.deepEqual([...r.rounds[0].scrambledLetters].sort(), [...q.answer].sort());
    assert.equal(r.attempts, 0); assert.equal(r.score, 0);
  }
});
