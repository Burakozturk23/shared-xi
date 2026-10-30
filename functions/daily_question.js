"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const {RewardError, dayKey} = require("./rewarded_ads");
const bank = require("./config/daily_question_catalog.json");
const categories = ["career", "ucl", "turkey", "transfer", "player", "international", "derby"];
const DAY = 86400000;
const fail = (code, message) => {
  throw new RewardError(code, message);
};
function select(day, previousIds = []) {
  const date = new Date(day + "T00:00:00Z");
  const category = categories[(date.getUTCDay() + 6) % 7];
  const pool = bank.questions.filter((q) => q.category === category);
  // One category per weekday; every category has >=13 entries (>=91 days).
  const week = Math.floor((date.getTime() - Date.UTC(2026, 0, 5)) / (7 * DAY));
  const offset = ((week % pool.length) + pool.length) % pool.length;
  const excluded = new Set(previousIds);
  for (let i = 0; i < pool.length; i++) {
    const q = pool[(offset + i) % pool.length];
    if (!excluded.has(q.id)) return q;
  }
  fail("failed-precondition", "Bu kategori için yeni soru hazırlanıyor.");
}
const normalize = (raw) => ({answers: {}, hints: {}, pending: {}, total: 0, streak: 0, lastDay: "", ...raw});
function createService({db, documentRef, grantCoins, grantXp, projectBadges, isLinked, isPro, enabled,
  onPlayed = async () => {}, ownStreakBonus = async () => true, now = Date.now}) {
  const ref = documentRef || ((uid) => db.ref("dailyQuestionState/" + uid));
  async function current() {
    if (!await enabled()) fail("failed-precondition", "Günün Sorusu henüz açılmadı.");
    const day = dayKey(now());
    const existing = (await db.ref("dailyQuestionPrivate/" + day).get()).val();
    if (existing) return existing;
    // Persisted publication history also prevents repeats after a catalog update.
    const today = Date.parse(day + "T00:00:00Z");
    const history = await Promise.all(Array.from({length: 90}, async (_, i) => {
      const date = new Date(today - (i + 1) * DAY).toISOString().slice(0, 10);
      return (await db.ref("dailyQuestionPrivate/" + date).get()).val()?.id;
    }));
    const selected = select(day, history.filter(Boolean));
    const tx = await db.ref("dailyQuestionPrivate/" + day).transaction((raw) => raw || {...selected, day,
      version: bank.version});
    return tx.snapshot.val();
  }
  async function change(uid, fn) {
    let error;
    const tx = await ref(uid).transaction((raw, e) => {
      error = null;
      const s = normalize(structuredClone(raw));
      try {
        fn(s, e);
        if (e) {
          for (const r of Object.values(s.boostRuns || {})) {
            if (s.answers[r.day]) r.finished = true;
            B.recoverUnused(e, r, now(), () => !s.hints[r.day]);
          }
        }
        return s;
      } catch (err) {
        error = err; return e ? undefined : raw;
      }
    });
    if (error) throw error;
    return normalize(tx.snapshot.val());
  }
  async function settle(uid) {
    const s = normalize((await ref(uid).get()).val());
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
    const policy = await B.policyFor(db, uid, await isLinked(uid));
    const stored = (await ref(uid).get()).val();
    if (policy?.readyModes?.daily_question === true || stored?.boostRuns) {
      await change(uid, (s, e) => {
        s.boostRuns ||= {};
        if (!e || policy?.readyModes?.daily_question !== true ||
          s.boostRuns[q.day] || s.answers[q.day] || s.hints[q.day]) return;
        const r = {id: "quiz_" + q.day + "_" + q.id, mode: "daily_question", entry: "daily",
          day: q.day, questionId: q.id, version: q.version, revision: 0, createdAt: now(),
          expiresAt: Date.parse(q.day + "T00:00:00+03:00") + DAY, finished: false,
          adCredits: 0, adGranted: 0, adReceipts: {}, actions: {}};
        B.pin(r, policy); s.boostRuns[q.day] = r;
      });
    }
    const s = normalize((await ref(uid).get()).val());
    const result = s.answers[q.day] || null;
    if (result) await onPlayed(uid, q.day, "daily_question");
    const safe = {day: q.day, id: q.id, version: q.version, category: q.category, prompt: q.prompt,
      options: q.options, difficulty: q.difficulty};
    // Answer/explanation/source URLs are only returned after this account submits.
    return {ok: true, question: safe, result: result ? {...result, answer: q.answer,
      explanation: q.explanation, sources: q.sources} : null,
    ...(B.paid(s.boostRuns?.[q.day]) ? {session: {id: s.boostRuns[q.day].id, revision: s.boostRuns[q.day].revision,
      support: B.view(s.boostRuns[q.day]), adCredits: s.boostRuns[q.day].adCredits,
      adGranted: s.boostRuns[q.day].adGranted}} : {}),
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
    // The shared play streak pays the weekly bonus once it is switched on.
    const ownBonus = await ownStreakBonus();
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
      const bonus = ownBonus && s.streak % 7 === 0;
      const coins = (correct ? 8 : 2) + (bonus ? 20 : 0);
      const xp = (correct ? 10 : 5) + (bonus ? 30 : 0);
      s.answers[q.day] = {...(B.paid(s.boostRuns?.[q.day]) ?
        {assisted: s.boostRuns[q.day].assisted === true, masteryEligible: !s.boostRuns[q.day].assisted} : {}),
      questionId: q.id, option: input.option, correct, coins, xp, bonus, at: now()};
      s.pending["daily_question__" + q.day] = {day: q.day, coins, xp};
    });
    return status(uid);
  }
  async function prepareHint(uid) {
    const q = await current();
    const s = normalize((await ref(uid).get()).val());
    if (B.paid(s.boostRuns?.[q.day])) fail("failed-precondition", "Destek Çantası'nı kullan; uygulamayı güncelle.");
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
  async function useHint(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    const q = await current();
    if (input.day !== q.day || input.questionId !== q.id || !/^[a-f0-9]{32}$/.test(input.requestId || "")) {
      fail("failed-precondition", "Soruyu yenile.");
    }
    const fp = crypto.createHash("sha256").update(JSON.stringify([input.day, input.questionId, input.sessionId,
      input.revision, ...B.paymentFingerprint(input)])).digest("hex");
    await change(uid, (s, e) => {
      const r = s.boostRuns?.[q.day];
      if (!e || !B.paid(r) || input.sessionId !== r.id) fail("failed-precondition", "Destek panelini yenile.");
      r.actions ||= {};
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek değiştirilemez.");
        return;
      }
      if (r.revision !== input.revision) fail("aborted", "Kayıt değişti. Yenile.");
      if (s.answers[q.day] || s.hints[q.day]) fail("failed-precondition", "Bugünkü yardım kullanılamaz.");
      const eliminated = (q.answer + 1) % 3;
      B.consume(e, r, input, "boost_eliminate", q.id, {eliminated}, now());
      s.hints[q.day] = {eliminated, requestId: input.requestId}; r.actions[input.requestId] = fp; r.revision++;
    });
    return status(uid);
  }
  async function prepareBoostHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "daily_question_hint") fail("permission-denied", "Hesap gerekli.");
    const q = await current(); const s = normalize((await ref(uid).get()).val()); const r = s.boostRuns?.[q.day];
    if (!B.paid(r) || input.sessionId !== r.id || input.boostId !== "boost_eliminate" ||
      s.hints[q.day] || s.answers[q.day]) fail("failed-precondition", "Bugünkü destek kullanılamaz.");
    return B.adBenefit(r, {amount: 0, claimKey: "quiz_boost_" + r.id,
      context: {day: q.day, questionId: q.id, sessionId: r.id}}, "boost_eliminate");
  }
  async function settleBoostHint(uid, receipt) {
    await change(uid, (s, e) => {
      const r = s.boostRuns?.[receipt.context?.day];
      if (!e) fail("failed-precondition", "Cüzdan hazır değil.");
      const canApply = r?.id === receipt.context?.sessionId && !s.hints[r.day] && !s.answers[r.day];
      if (B.recoverAd(e, r, receipt, now(), "boost_eliminate", canApply)) return;
      if (!r.adReceipts?.[receipt.id]) B.grantAd(r, receipt);
    });
  }
  return {status, submit, prepareHint, settleHint, settle, useHint, prepareBoostHint, settleBoostHint};
}
module.exports = {createService, select, categories, bank};
