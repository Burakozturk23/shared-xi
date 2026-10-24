"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const {RewardError, dayKey} = require("./rewarded_ads");
const energy = require("./energy");
const {validId, shuffled} = require("./career_transfer");
const catalog = require("./config/fake_club_catalog.json");
const MODES = ["fake_endless", "fake_speed"];
const boosts = ["boost_first_letter", "boost_last_letter", "boost_anagram"];
const defaults = Object.freeze({dataEnabled: true, soloEnabled: false, friendsEnabled: false,
  rankedEnabled: false, rewardsEnabled: false, disabledQuestions: []});
const policyOf = (p) => ({...defaults, ...p});
const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const stateOf = (s) => ({sessions: {}, active: {}, starts: {}, records: {}, medals: {}, claims: {},
  pending: {}, daily: {}, energyCredits: 0, ...s});
const runOf = (r) => r && ({usedPlayers: [], history: [], actions: {}, adReceipts: {}, eliminated: [],
  confirmed: [], ...r});
const difficulty = (streak) => streak >= 20 ? "legend" : streak >= 12 ? "hard" : streak >= 5 ? "normal" : "easy";
const multiplier = (streak) => streak >= 10 ? 3 : streak >= 5 ? 2 : streak >= 3 ? 1.5 : 1;
const explanation = (q) => `${q.player.name}; ${q.options.filter((c) => q.realClubIds.includes(c.id))
    .map((c) => c.name).join(", ")} kulüplerinde oynadı. ${q.options.find((c) => c.id === q.fakeClubId).name}` +
    " için doğrulanmış A takım kaydı yok.";
function view(raw, time) {
  const r = runOf(raw); if (!r) return null;
  const q = r.question;
  return {id: r.id, mode: r.mode, revision: r.revision, dataVersion: r.dataVersion,
    startedAt: r.startedAt, expiresAt: r.expiresAt, serverNow: time, deadline: r.deadline || null,
    questionStartedAt: r.questionStartedAt, finished: r.finished, answered: r.answered,
    lives: r.lives, streak: r.streak, bestStreak: r.bestStreak, cleanStreak: r.cleanStreak,
    score: r.score, correct: r.correct, answers: r.answers, hintsUsed: r.hintsUsed,
    questionNumber: r.answers + (r.answered ? 0 : 1), free5050: !r.freeUsed, support: B.view(r),
    traceRemaining: Math.max(0, 2 - r.traceUsed), adCredits: r.adCredits,
    traceAvailable: !r.traceOnQuestion && q.realClubIds.some((id) => !r.eliminated.includes(id)),
    eliminated: r.eliminated, confirmed: r.confirmed, energyCharged: r.energyCharged,
    earnedCoins: r.earnedCoins, earnedXp: r.earnedCoins * 2, reason: r.reason || "",
    question: {questionId: q.questionId, dataVersion: q.dataVersion, player: q.player,
      difficulty: q.difficulty, options: q.options.map(({popularity, ...club}) => club)},
    ...(r.answered || r.finished ? {selectedId: r.selectedId ?? null, wasCorrect: r.wasCorrect, points: r.points,
      quick: r.quick, fakeClubId: q.fakeClubId, explanation: explanation(q), evidence: q.evidence} : {}),
    ...(r.finished ? {history: r.history} : {})};
}
function pick(c, r, policy) {
  const tier = r.mode === "fake_endless" ? difficulty(r.streak) :
    ["easy", "normal", "hard", "easy", "normal", "hard", "easy", "normal", "hard", "normal"][r.answers];
  const candidates = c.questions.filter((q) => q.difficulty === tier &&
    !r.usedPlayers.includes(q.playerId) && !(policy.disabledQuestions || []).includes(q.questionId));
  return shuffled(candidates, r.id + "|" + r.answers)[0] || null;
}
function setup(r, q, time) {
  r.question = q; r.usedPlayers.push(q.playerId); r.questionStartedAt = time;
  r.deadline = r.mode === "fake_speed" ? time + 10000 : null;
  r.answered = false; r.selectedId = null; r.wasCorrect = false; r.points = 0; r.quick = false;
  r.eliminated = []; r.confirmed = []; r.traceOnQuestion = false; r.questionHints = 0;
}
function createService({db, normalize, project, grantCoins, grantXp, dailyClaim, isLinked, getRollout,
  getPolicy = async () => ({}), now = Date.now}) {
  async function change(uid, fn) {
    let error; const time = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null; const e = normalize(structuredClone(raw)); e.fakeClub = stateOf(e.fakeClub);
      e.energy = energy.refreshed(e.energy, time);
      try {
        fn(e.fakeClub, e, time); return e;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "Aynı isteği yeniden gönder.");
    const e = normalize(tx.snapshot.val()); e.fakeClub = stateOf(e.fakeClub);
    await project(db, uid, e); return e;
  }
  const read = async (uid) => stateOf((await db.ref(`economyState/${uid}/fakeClub`).get()).val());
  async function pinned(version) {
    if (version === catalog.version) return catalog;
    const c = (await db.ref(`fakeClubCatalogs/${version}`).get()).val();
    if (!c) fail("unavailable", "Kayıtlı veri sürümü geçici olarak erişilemiyor. Tekrar dene.");
    return c;
  }
  function check(input) {
    if (!MODES.includes(input.mode) || input.version !== catalog.version) {
      fail("failed-precondition", "Mod verisi güncellendi. Yenile.");
    }
  }
  function record(s, r) {
    return s.records[r.mode + (r.assisted ? "__assisted" : "")] ||= {bestScore: 0, bestStreak: 0,
      bestCorrect: 0, answers: 0, hintsUsed: 0, sessions: 0};
  }
  function award(s, r, tier, time, policy) {
    if (!policy.rewardsEnabled) return;
    for (let i = 1; i <= tier; i++) {
      const key = `fc__${r.mode}__medal_${i}`;
      if (s.claims[key]) continue;
      const coins = (r.mode === "fake_endless" ? [0, 2, 3, 3, 4] : [0, 1, 2, 2, 3])[i];
      s.claims[key] = {coins, at: time}; s.pending[key] = {coins, target: r.mode}; r.earnedCoins += coins;
    }
    s.medals[r.mode] = Math.max(s.medals[r.mode] || 0, tier);
  }
  function daily(s, r, time, policy) {
    if (!policy.rewardsEnabled) return;
    if (r.mode === "fake_endless" ? r.streak >= 5 : r.correct >= 7) {
      const day = dayKey(time);
      s.daily[day] ||= {at: time, mode: r.mode, status: "pending"};
    }
  }
  function finish(s, r, reason, time, policy) {
    if (r.finished) return;
    r.finished = true; r.reason = reason; r.finishedAt = time;
    const rec = record(s, r); rec.sessions++;
    if (r.mode === "fake_speed" && r.answers === 10) {
      const tier = r.correct === 10 ? 4 : r.correct >= 9 ? 3 : r.correct >= 8 ? 2 : r.correct >= 5 ? 1 : 0;
      award(s, r, tier, time, policy);
    }
  }
  function answer(s, r, selectedId, time, policy) {
    r.answered = true; r.selectedId = selectedId; r.wasCorrect = selectedId === r.question.fakeClubId;
    r.answers++;
    if (r.wasCorrect) {
      r.correct++; r.streak++;
      r.cleanStreak = r.questionHints ? 0 : r.cleanStreak + 1;
      r.bestStreak = Math.max(r.bestStreak, r.streak);
      r.quick = r.mode === "fake_speed" && time - r.questionStartedAt < 3000;
      r.points = 50 * multiplier(r.streak) * (r.quick ? 2 : 1); r.score += r.points;
    } else {
      r.lives--; r.streak = 0; r.cleanStreak = 0; r.points = 0;
    }
    r.history.push({questionId: r.question.questionId, player: r.question.player,
      selectedId, correct: r.wasCorrect, points: r.points, explanation: explanation(r.question),
      evidence: r.question.evidence, hints: r.questionHints});
    const rec = record(s, r); rec.answers++; rec.bestScore = Math.max(rec.bestScore, r.score);
    rec.bestStreak = Math.max(rec.bestStreak, r.bestStreak); rec.bestCorrect = Math.max(rec.bestCorrect, r.correct);
    if (r.mode === "fake_endless") {
      award(s, r,
        !r.assisted && r.cleanStreak >= 30 ? 4 : r.streak >= 20 ? 3 : r.streak >= 10 ? 2 : r.streak >= 5 ?
          1 : 0, time, policy);
    }
    daily(s, r, time, policy);
    if (r.lives <= 0 || r.mode === "fake_speed" && r.answers === 10) {
      finish(s, r,
        r.lives <= 0 ? "Üç canın bitti." : "10 soruluk Hız Serisi tamamlandı.", time, policy);
    }
  }
  function refresh(s, e, policy, time) {
    for (const id of Object.values(s.active)) {
      const r = runOf(s.sessions[id]); if (!r || r.finished) continue;
      if (!policy.dataEnabled || (policy.disabledQuestions || []).includes(r.question.questionId)) {
        finish(s, r, "Veri düzeltmesi nedeniyle oyun kapandı; harcanan enerji telafi edildi.", time, policy);
        r.voided = true;
        if (r.energyCharged) s.energyCredits++;
      } else {
        if (!r.answered && r.deadline && time >= r.deadline) {
          answer(s, r, null, r.deadline, policy); r.revision++;
        }
        if (time >= r.expiresAt) finish(s, r, "24 saatlik devam süresi doldu.", r.expiresAt, policy);
      }
      s.sessions[id] = r;
    }
    const refund = Math.min(s.energyCredits, Math.max(0, energy.policy.capacity - e.energy.balance));
    e.energy.balance += refund; s.energyCredits -= refund;
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, p] of Object.entries(s.pending)) {
      await grantCoins(uid, id, "fake_club_achievement", p.target, p.coins, "fc-v1");
      await grantXp(uid, id, p.coins * 2);
      await change(uid, (state) => {
        delete state.pending[id];
      });
    }
    for (const [day, d] of Object.entries(s.daily)) {
      if (d.status !== "pending") continue;
      const result = await dailyClaim(uid, day);
      if (result !== "pending") {
        await change(uid, (state) => {
          state.daily[day].status = result;
        });
      }
    }
  }
  async function energyCost(uid) {
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    return rollout.enabled === true && parseInt(hash(uid).slice(0, 8), 16) % 100 < rollout.percent &&
      (rollout.sessionModes || []).includes("fake_club") ? 1 : 0;
  }
  async function status(uid, input) {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
    const policy = policyOf(await getPolicy());
    await change(uid, (s, e, t) => refresh(s, e, policy, t)); await settle(uid);
    const s = await read(uid); const e = normalize((await db.ref("economyState/" + uid).get()).val());
    return {version: catalog.version, quality: catalog.quality, linked: await isLinked(uid),
      session: view(s.sessions[s.active[input.mode]], now()), records: s.records,
      medals: s.medals, daily: s.daily[dayKey(now())] || null, coins: e.balances.coins,
      energyCost: await energyCost(uid),
      pendingCoins: Object.values(s.pending).reduce((n, p) => n + p.coins, 0),
      availability: {solo: policy.dataEnabled && policy.soloEnabled, rewards: policy.rewardsEnabled,
        friends: policy.dataEnabled && policy.friendsEnabled,
        ranked: policy.dataEnabled && policy.friendsEnabled && policy.rankedEnabled},
      inventory: boosts.map((id) => ({id, quantity: e.inventory[id]?.quantity || 0}))};
  }
  async function start(uid, input) {
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    check(input); if (!validId(input.requestId)) fail("invalid-argument", "Geçersiz istek.");
    const policy = policyOf(await getPolicy());
    if (!policy.dataEnabled || !policy.soloEnabled) {
      fail("failed-precondition", "Sahte Kulüp test aşamasında; henüz açılmadı.");
    }
    await db.ref(`fakeClubCatalogs/${catalog.version}`).transaction((raw) => raw || catalog);
    const charge = await energyCost(uid) === 1;
    const e = await change(uid, (s, e, time) => {
      refresh(s, e, policy, time);
      if (s.starts[input.requestId]) {
        if (s.starts[input.requestId] !== input.mode) fail("invalid-argument", "İstek başka moda ait.");
        if (!s.sessions[input.requestId]) fail("failed-precondition", "Eski oturum sona erdi.");
        return;
      }
      const old = s.sessions[s.active[input.mode]];
      if (old && !old.finished) fail("already-exists", "Kayıtlı oyuna devam et.");
      const r = {id: input.requestId, mode: input.mode, dataVersion: catalog.version, revision: 0,
        startedAt: time, expiresAt: time + energy.policy.resumeMs, finished: false, answered: false,
        lives: 3, streak: 0, cleanStreak: 0, bestStreak: 0, correct: 0, score: 0, answers: 0,
        hintsUsed: 0, questionHints: 0, freeUsed: false, traceUsed: 0, adCredits: 0, adGranted: 0,
        energyCharged: charge, earnedCoins: 0, actions: {}, adReceipts: {}, history: [], usedPlayers: []};
      const q = pick(catalog, r, policy);
      if (!q) fail("failed-precondition", "Doğrulanmış soru bulunamadı. Enerji harcanmadı.");
      // Question, session and debit commit together; failures leave no reservation to leak.
      if (charge) {
        if (e.energy.balance - energy.held(e.energy) < 1) {
          fail("resource-exhausted", "Yeni oyun için 1 enerji gerekli.");
        }
        if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = time;
        e.energy.balance--;
      }
      B.pin(r, boostPolicy);
      setup(r, q, time); s.sessions[r.id] = r; s.active[r.mode] = r.id; s.starts[r.id] = r.mode;
      for (const [id, prior] of Object.entries(s.sessions)) {
        if (prior.expiresAt < time && !Object.values(s.active).includes(id)) delete s.sessions[id];
      }
    });
    return {session: view(e.fakeClub.sessions[input.requestId], now())};
  }
  async function act(uid, input) {
    check(input);
    if (!validId(input.requestId) || !validId(input.sessionId)) fail("invalid-argument", "Geçersiz işlem.");
    const before = (await read(uid)).sessions[input.sessionId];
    if (!before || before.mode !== input.mode) fail("not-found", "Oturum bulunamadı.");
    const c = await pinned(before.dataVersion); const policy = policyOf(await getPolicy());
    const e = await change(uid, (s, e, time) => {
      const fp = hash(JSON.stringify([input.action, input.questionId ?? null,
        input.clubId ?? null, input.boost ?? null, ...B.paymentFingerprint(input)]));
      let r = runOf(s.sessions[input.sessionId]);
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek başka işleme ait.");
        return;
      }
      const revision = r.revision;
      refresh(s, e, policy, time); r = runOf(s.sessions[input.sessionId]);
      // Late answer records the server timeout, never rolls it back on an exception.
      if (r.finished || r.revision !== revision) {
        r.actions[input.requestId] = fp; s.sessions[r.id] = r; return;
      }
      if (input.revision !== r.revision) fail("aborted", "Oyun başka cihazda değişti. Yenile.");
      if (input.questionId !== r.question.questionId) fail("failed-precondition", "Soru değişti. Yenile.");
      if (input.action === "answer") {
        if (r.answered) fail("already-exists", "Cevabın kilitlendi.");
        if (!Number.isSafeInteger(input.clubId) || !r.question.options.some((x) => x.id === input.clubId) ||
          r.eliminated.includes(input.clubId) || r.confirmed.includes(input.clubId)) {
          fail("invalid-argument", "Geçerli kulübü seç.");
        }
        answer(s, r, input.clubId, time, policy);
      } else if (input.action === "next") {
        if (!r.answered) fail("failed-precondition", "Önce soruyu cevapla.");
        const q = pick(c, r, policy);
        if (q) setup(r, q, time);
        else finish(s, r, "Doğrulanmış soru havuzu tamamlandı. Rekorun kaydedildi.", time, policy);
      } else if (input.action === "finish") finish(s, r, "Oturum kapatıldı; rekorların korundu.", time, policy);
      else if (input.action === "fifty" || input.action === "trace") {
        if (r.mode !== "fake_endless" || r.answered) fail("failed-precondition", "Bu oyunda yardım kapalı.");
        if (input.action === "fifty") {
          if (r.freeUsed) fail("resource-exhausted", "Oturumun ücretsiz 50/50 hakkı kullanıldı.");
          r.eliminated = r.question.realClubIds.filter((id) => !r.confirmed.includes(id)).slice(0, B.paid(r) ? 1 : 2);
          if (r.eliminated.length !== (B.paid(r) ? 1 : 2)) fail("failed-precondition", "Elenebilecek iki seçenek yok.");
          if (B.paid(r)) {
            B.consume(e, r, input, "boost_eliminate", "eliminate:" + r.question.questionId,
                {eliminated: r.eliminated}, time);
          }
          r.freeUsed = true;
        } else {
          if (r.traceUsed >= 2 || r.traceOnQuestion) {
            fail("resource-exhausted", "Bu soru veya oturum için Kariyer İzi kullanıldı.");
          }
          const id = r.question.realClubIds.find((id) => !r.eliminated.includes(id) && !r.confirmed.includes(id));
          if (!id) fail("failed-precondition", "Yeni geçerli iz yok.");
          if (B.paid(r)) {
            B.consume(e, r, input, "boost_connection", "trace:" + r.question.questionId,
                {clubId: id}, time);
          } else if (input.boost) {
            if (!boosts.includes(input.boost) || !(e.inventory[input.boost]?.quantity > 0)) {
              fail("resource-exhausted", "Destek stokta yok.");
            }
            e.inventory[input.boost].quantity--;
            e.storeUses[`fc__${r.id}__${r.traceUsed}`] = {itemId: input.boost, usedAt: time};
          } else if (r.adCredits > 0) r.adCredits--;
          else fail("resource-exhausted", "Doğrulanmış reklam veya kayıtlı destek gerekli.");
          r.traceUsed++; r.traceOnQuestion = true; r.confirmed.push(id);
        }
        r.hintsUsed++; r.questionHints++; r.cleanStreak = 0; record(s, r).hintsUsed++;
      } else fail("invalid-argument", "Geçersiz işlem.");
      r.actions[input.requestId] = fp; r.revision++; s.sessions[r.id] = r;
    });
    await settle(uid);
    return {session: view(e.fakeClub.sessions[input.sessionId], now())};
  }
  async function prepareHint(uid, placement, context) {
    const r = runOf((await read(uid)).sessions[context?.sessionId]);
    if (placement !== "fake_club_hint" || !r || r.mode !== "fake_endless" || r.finished ||
      r.answered || r.expiresAt <= now() || r.adGranted >= 2 || r.traceUsed + r.adCredits >= 2 || r.traceOnQuestion) {
      fail("failed-precondition", "Bu oyunda yeni Kariyer İzi hakkı yok.");
    }
    return B.adBenefit(r, {amount: 0, claimKey: `fc_hint_${r.id}_${r.adGranted}`,
      context: {sessionId: r.id, credit: r.adGranted}});
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e, time) => {
      const r = runOf(s.sessions[receipt.context?.sessionId]);
      const canApply = r && r.traceUsed + r.adCredits < 2 && r.adGranted < 2 &&
        r.adGranted === receipt.context.credit;
      if (B.recoverAd(e, r, receipt, time, "boost_connection", canApply)) return;
      if (!r || r.mode !== "fake_endless" || r.finished || r.expiresAt <= time || r.adReceipts[receipt.id] ||
        r.adGranted >= 2 || r.traceUsed + r.adCredits >= 2 || r.adGranted !== receipt.context.credit) return;
      r.adGranted++; r.adCredits++; r.adReceipts[receipt.id] = true; s.sessions[r.id] = r;
    });
  }
  return {status, start, act, settle, prepareHint, settleHint};
}
module.exports = {createService, catalog, view, pick, difficulty, multiplier, policyOf, explanation};
