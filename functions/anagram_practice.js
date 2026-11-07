"use strict";
const crypto = require("node:crypto");
const W = require("./daily_words");
const B = require("./boosts");
const energy = require("./energy");
const {RewardError, dayKey} = require("./rewarded_ads");
const catalog = require("./config/anagram_practice_catalog.json");
const hash = (v) => crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex");
const version = hash(catalog);
const fail = (code, message) => {
  throw new RewardError(code, message);
};
function restored(raw) {
  const s = {sessions: {}, active: null, records: {}, assistedRecords: {}, ...raw};
  for (const r of Object.values(s.sessions)) W.publicRun(r, r.startedAt);
  return s;
}
function finalize(s, r, time, reason) {
  if (reason && !r.finished) W.finish(s, r, reason, time, {rewardsEnabled: false});
  if (!r.finished || r.recorded) return;
  r.recorded = true; r.eligible = false;
  r.result = {...r.result, coins: 0, xp: 0, medal: "Antrenman", eligibleForDailyBonus: false,
    rewardEnabled: false, assisted: r.assisted === true, masteryEligible: false, leaderboardEligible: false};
  if (r.result.reason !== "completed") return;
  const records = r.assisted ? s.assistedRecords : s.records;
  records.best = Math.max(records.best || 0, r.score); records.completed = (records.completed || 0) + 1;
}
function reconcile(s, e, time) {
  for (const [id, r] of Object.entries(s.sessions)) {
    if (!r.finished && r.expiresAt <= time) finalize(s, r, time, "expired");
    finalize(s, r, time);
    B.recoverUnused(e, r, time, (sku, scope) => {
      try {
        return W.help(r, sku === "boost_first_letter" ? "first" : "bio").questionId === scope.questionId;
      } catch (_) {
        return false;
      }
    });
    if (id !== s.active && r.finished && r.startedAt < time - 2 * 86400000 && !(r.adCredits > 0)) delete s.sessions[id];
  }
}
function makePack(requestId, time) {
  const seed = crypto.randomBytes(32).toString("hex");
  const deck = [...catalog].sort((a, b) => hash([seed, a.id]).localeCompare(hash([seed, b.id]))).slice(0, 8);
  return {period: dayKey(time), contentVersion: version, packId: "ap_" + requestId,
    anagram: deck.map((p, i) => {
      let scrambled = [...p.answer].map((c, n) => ({c, key: hash([seed, i, n])}))
          .sort((a, b) => a.key.localeCompare(b.key)).map((x) => x.c).join("");
      for (let n = 1; scrambled === p.answer && n < p.answer.length; n++) {
        scrambled = p.answer.slice(n) + p.answer.slice(0, n);
      }
      return {...p, countryLabel: p.country, questionId: hash([requestId, i, p.id]), scrambled,
        aliases: [...new Set([p.answer, p.name, ...p.aliases].map(W.normalize))]};
    })};
}
function createService({db, normalize, project, isLinked, getRollout = async () => ({}), now = Date.now}) {
  const read = async (uid) => restored((await db.ref("economyState/" + uid + "/anagramPractice").get()).val());
  async function change(uid, fn) {
    const ref = db.ref("economyState/" + uid); const base = (await ref.get()).val();
    const tx = await ref.transaction((raw) => {
      const e = normalize(structuredClone(raw ?? base)); const s = restored(e.anagramPractice);
      e.energy = energy.refreshed(e.energy, now()); reconcile(s, e, now()); fn(s, e, now()); reconcile(s, e, now());
      e.anagramPractice = s; return e;
    });
    if (!tx.committed) fail("aborted", "Aynı isteği yeniden dene.");
    await project(db, uid, normalize(tx.snapshot.val())); return restored(tx.snapshot.val().anagramPractice);
  }
  async function cost(uid) {
    const p = {...energy.policy.rollout, ...await getRollout()};
    const bucket = parseInt(crypto.createHash("sha256").update(uid).digest("hex").slice(0, 8), 16) % 100;
    return p.enabled === true && bucket < Math.max(0, Math.min(100, p.percent)) &&
      Array.isArray(p.sessionModes) && p.sessionModes.includes("anagram") ? 1 : 0;
  }
  function response(s, active, charge) {
    const r = s.sessions[s.active];
    return {legacy: !active && !r, mode: "anagram_practice", period: dayKey(now()), availability: active || !!r,
      rewardsEnabled: false, energyCost: charge, serverNow: now(), contentVersion: version,
      session: W.publicRun(r, now()), records: s.records, assistedRecords: s.assistedRecords};
  }
  async function status(uid) {
    const p = await B.policyFor(db, uid, await isLinked(uid)); const active = p?.readyModes?.anagram_practice === true;
    const before = await read(uid);
    const s = Object.keys(before.sessions).length ? await change(uid, () => {}) : before;
    return response(s, active, await cost(uid));
  }
  async function act(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "")) fail("invalid-argument", "İşlem kimliği geçersiz.");
    const policy = await B.policyFor(db, uid, true); const charge = await cost(uid);
    const pack = input.action === "start" ? makePack(input.requestId, now()) : null;
    const fingerprint = hash([input.action, input.packId, input.contentVersion, input.revision, input.questionId,
      input.answer ?? null, ...B.paymentFingerprint(input)]);
    const s = await change(uid, (s, e, time) => {
      if (input.action === "start") {
        const id = "ap_" + input.requestId;
        if (s.sessions[id]) {
          if (s.sessions[id].startFingerprint !== fingerprint) fail("invalid-argument", "İstek değiştirilemez.");
          return;
        }
        if (policy?.readyModes?.anagram_practice !== true) fail("failed-precondition", "Yeni seri şu anda kapalı.");
        if (s.sessions[s.active] && !s.sessions[s.active].finished) {
          fail("failed-precondition", "Önce açık serini bitir.");
        }
        if (input.contentVersion !== version) fail("failed-precondition", "Kataloğu yenile.");
        if (input.expectedEnergyCost !== charge) fail("failed-precondition", "Enerji bedeli değişti. Yenile.");
        if (e.energy.sessions[input.requestId]) fail("invalid-argument", "İstek başka enerji oturumuna ait.");
        if (charge && e.energy.balance - energy.held(e.energy) < charge) {
          fail("resource-exhausted", "1 enerji gerekli.");
        }
        const r = W.newRun("anagram_practice", pack, time, policy);
        r.id = id; r.startFingerprint = fingerprint; r.energyCost = charge;
        if (charge) {
          if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = time;
          e.energy.balance--;
          e.energy.sessions[input.requestId] = {id: input.requestId, mode: "anagram", unitId: "session", key: "",
            status: "confirmed", createdAt: time, confirmedAt: time, expiresAt: r.expiresAt};
        }
        s.sessions[id] = r; s.active = id; return;
      }
      const r = s.sessions[input.packId];
      if (!r || r.contentVersion !== input.contentVersion) fail("failed-precondition", "Seriyi yenile.");
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fingerprint) fail("invalid-argument", "İstek değiştirilemez.");
        return;
      }
      if (s.active !== r.id || r.finished) fail("failed-precondition", "Bu seri sona erdi.");
      if (input.revision !== r.revision) fail("aborted", "Başka cihazda ilerleme var. Yenile.");
      if (input.questionId !== r.questions[r.index].questionId) fail("failed-precondition", "Futbolcu değişti.");
      if (input.answer != null && (typeof input.answer !== "string" || input.answer.length > 100)) {
        fail("invalid-argument", "Cevap geçersiz.");
      }
      if (["bio", "first"].includes(input.action)) {
        const info = W.help(r, input.action);
        B.consume(e, r, input, info.sku, info.questionId + ":" + input.action, {text: info.text}, time);
      }
      if (input.action === "giveup") finalize(s, r, time, "giveup");
      else W.anagramAction(s, r, input, W.normalize(input.answer), time, {rewardsEnabled: false});
      r.actions[input.requestId] = fingerprint; r.revision++;
    });
    return response(s, true, charge);
  }
  async function prepareHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "anagram_practice_hint") fail("permission-denied", "Hesap gerekli.");
    const s = await read(uid); const r = s.sessions[input.sessionId];
    if (!B.paid(r) || r.finished || r.expiresAt <= now()) fail("failed-precondition", "Aktif seri bulunamadı.");
    const action = input.boostId === "boost_first_letter" ? "first" : "bio";
    const info = W.help(r, action);
    if (info.sku !== input.boostId) fail("invalid-argument", "Yanlış destek türü.");
    return B.adBenefit(r, {amount: 0, claimKey: "ap_hint_" + r.id + "_" + info.questionId + "_" + action,
      context: {sessionId: r.id, questionId: info.questionId, action}}, info.sku);
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e, time) => {
      const r = s.sessions[receipt.context?.sessionId]; let usable = false;
      try {
        usable = W.help(r, receipt.context.action).questionId === receipt.context.questionId;
      } catch (_) {/* retired */}
      if (!B.recoverAd(e, r, receipt, time, "boost_basic", usable)) B.grantAd(r, receipt);
    });
  }
  return {status, act, prepareHint, settleHint};
}
module.exports = {createService, catalog, version};
