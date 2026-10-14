"use strict";
const {RewardError, dayKey} = require("./rewarded_ads");
const bank = require("./config/daily_question_catalog.json");
const categories = ["career", "ucl", "turkey", "transfer", "player", "international", "derby"];
const DAY = 86400000;
const fail = (code, message) => {
  throw new RewardError(code, message);
};
function select(day) {
  const date = new Date(day + "T00:00:00Z");
  const category = categories[(date.getUTCDay() + 6) % 7];
  const pool = bank.questions.filter((q) => q.category === category);
  // One category per weekday; every category has >=13 entries (>=91 days).
  const week = Math.floor((date.getTime() - Date.UTC(2026, 0, 5)) / (7 * DAY));
  return pool[((week % pool.length) + pool.length) % pool.length];
}
const normalize = (raw) => ({answers: {}, hints: {}, pending: {}, total: 0, streak: 0, lastDay: "", ...raw});
function createService({db, grantCoins, grantXp, projectBadges, isLinked, isPro, enabled, now = Date.now}) {
  async function current() {
    if (!await enabled()) fail("failed-precondition", "Günün Sorusu henüz açılmadı.");
    const day = dayKey(now());
    const selected = select(day);
    const tx = await db.ref("dailyQuestionPrivate/" + day).transaction((raw) => raw || {...selected, day,
      version: bank.version});
    return tx.snapshot.val();
  }
  async function change(uid, fn) {
    let error;
    const tx = await db.ref("dailyQuestionState/" + uid).transaction((raw) => {
      error = null;
      const s = normalize(raw);
      try {
        fn(s); return s;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    return normalize(tx.snapshot.val());
  }
  async function settle(uid) {
    const s = normalize((await db.ref("dailyQuestionState/" + uid).get()).val());
    if (!await isLinked(uid)) return;
    for (const [id, reward] of Object.entries(s.pending)) {
      await grantCoins(uid, id, "daily_question", reward.day, reward.coins, "daily-question-v1");
      await grantXp(uid, id, reward.xp);
      await change(uid, (latest) => {
        delete latest.pending[id];
      });
    }
    await projectBadges(uid, s.total);
  }
  async function status(uid) {
    const q = await current();
    await settle(uid);
    const s = normalize((await db.ref("dailyQuestionState/" + uid).get()).val());
    const result = s.answers[q.day] || null;
    const safe = {day: q.day, id: q.id, version: q.version, category: q.category, prompt: q.prompt,
      options: q.options, difficulty: q.difficulty};
    // Answer/explanation/source URLs are only returned after this account submits.
    return {ok: true, question: safe, result: result ? {...result, answer: q.answer,
      explanation: q.explanation, sources: q.sources} : null,
    eliminated: s.hints[q.day]?.eliminated ?? null, total: s.total,
    streak: [q.day, dayKey(now() - DAY)].includes(s.lastDay) ? s.streak : 0,
    pendingRewards: Object.keys(s.pending).length, pro: await isPro(uid), serverNow: now(),
    nextQuestionAt: Date.parse(q.day + "T00:00:00+03:00") + DAY};
  }
  async function submit(uid, input) {
    const q = await current();
    if (input.day !== q.day || input.questionId !== q.id) {
      fail("failed-precondition",
          "Yeni günün sorusu geldi. Ekranı yenile.");
    }
    if (!Number.isInteger(input.option) || input.option < 0 || input.option > 2) {
      fail("invalid-argument",
          "Bir seçenek seç.");
    }
    await change(uid, (s) => {
      if (s.answers[q.day]) {
        if (s.answers[q.day].option !== input.option) fail("already-exists", "Bugünkü cevabın kaydedildi.");
        return;
      }
      if (s.hints[q.day]?.eliminated === input.option) fail("invalid-argument", "Elenen seçenek seçilemez.");
      const yesterday = dayKey(now() - DAY);
      s.streak = s.lastDay === yesterday ? s.streak + 1 : 1;
      s.total += 1; s.lastDay = q.day;
      const correct = input.option === q.answer;
      const bonus = s.streak % 7 === 0;
      const coins = (correct ? 8 : 2) + (bonus ? 20 : 0);
      const xp = (correct ? 10 : 5) + (bonus ? 30 : 0);
      s.answers[q.day] = {questionId: q.id, option: input.option, correct, coins, xp, bonus, at: now()};
      s.pending["daily_question__" + q.day] = {day: q.day, coins, xp};
    });
    return status(uid);
  }
  async function prepareHint(uid) {
    const q = await current();
    const s = normalize((await db.ref("dailyQuestionState/" + uid).get()).val());
    if (s.answers[q.day] || s.hints[q.day]) fail("failed-precondition", "Bugünkü ipucu kullanılamaz.");
    return {amount: 0, claimKey: "quiz_hint_" + q.day, context: {day: q.day, questionId: q.id}};
  }
  async function settleHint(uid, receipt) {
    const q = (await db.ref("dailyQuestionPrivate/" + receipt.context?.day).get()).val();
    if (!q || q.id !== receipt.context?.questionId) fail("failed-precondition", "Soru kaydı bulunamadı.");
    await change(uid, (s) => {
      // A delayed verified receipt never changes an already submitted answer.
      if (s.answers[q.day] || s.hints[q.day]) return;
      s.hints[q.day] = {receiptId: receipt.id, eliminated: (q.answer + 1) % 3};
    });
  }
  return {status, submit, prepareHint, settleHint, settle};
}
module.exports = {createService, select, categories, bank};
