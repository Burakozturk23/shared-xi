"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const {RewardError} = require("./rewarded_ads");
const definitions = require("./mission_story_events").definitions;
const fail = (code, text) => {
  throw new RewardError(code, text);
};
const hash = (v) => crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex");
const cache = new Map();
function content(mode) {
  if (!definitions.some((d) => d[1] === mode)) fail("invalid-argument", "Geçersiz hikâye modu.");
  if (cache.has(mode)) return cache.get(mode);
  const catalog = require("./" + mode).catalog; const targets = {};
  function add(task, section, done, open = () => true) {
    targets[task.id] = {task, section, done, open};
  }
  if (mode === "player_journey") {
    for (const chapter of catalog.chapters) {
      for (const j of chapter.journeys) {
        j.tasks.forEach((t, i) =>
          add(t, j.id, (s) => (s.journeys?.[j.id]?.solved || 0) > i,
              (s) => (s.journeys?.[j.id]?.solved || 0) >= i));
      }
    }
  } else if (mode === "what_if") {
    for (const s of catalog.scenarios) {
      for (const r of s.routes) {
        add(r.task, s.id + "__" + r.id, (state) => !!state.progress?.[s.id]?.ends?.[r.id]);
      }
    }
  } else if (mode === "nostalgia") {
    for (const c of catalog.chapters) {
      c.tasks.forEach((t, i) => add(t, c.id,
          (s) => !!s.completed?.[t.id], (s) => i === 0 || c.tasks.slice(0, i).every((x) => s.completed?.[x.id])));
    }
  } else {
    for (const t of catalog.matches || catalog.tasks) {
      add(t, t.dynastyId || t.episodeId || t.id,
          (s) => !!s.completed?.[t.id],
          (s) => !["dynasties", "football_docu"].includes(mode) || t.stage === 1 ||
          !!s.completed?.[(t.dynastyId || t.episodeId) + "-01"]);
    }
  }
  const result = {version: String(catalog.version) + ":" + hash(catalog).slice(0, 16), targets,
    collection: definitions.find((d) => d[1] === mode)[0]};
  cache.set(mode, result); return result;
}
function help(t, sku) {
  if (sku === "boost_basic" && typeof t.hint === "string" && t.hint.trim()) return t.hint;
  if (sku === "boost_strong") {
    if (typeof t.strongHint === "string" && t.strongHint.trim()) return t.strongHint;
    const options = t.options || []; const keys = t.answerKeys || [];
    const label = (key) => options.find((o) => (o.id || o.key) === key)?.label;
    if (keys.length > 1 && label(keys[0])) {
      return "İlk bağlantı: " + (t.slots?.[0] ? t.slots[0] + " → " : "") + label(keys[0]);
    }
    if (options.length > 2) {
      const excluded = options.find((o) => !keys.includes(o.id || o.key));
      if (excluded) return "Bu seçenek elenir: " + excluded.label;
    }
  }
  fail("failed-precondition", "Bu görev için doğrulanmış ek bilgi yok; destek harcanmadı.");
}
function create({db, documentRef, isLinked, premium, now = Date.now}) {
  const receiptPrefixes = {player_journey: "journey_hint__", what_if: "what_if_hint__",
    nostalgia: "nostalgia_v2_hint__", international_glory: "international_v2_hint__",
    dynasties: "dynasties_v2_hint__", football_docu: "football_docu_v2_hint__", derby_day: "derby_day_v2_hint__"};
  async function oldReceipt(uid, mode, targetId) {
    const prefix = receiptPrefixes[mode];
    return prefix && (await db.ref("economyState/" + uid + "/purchases/" + prefix + targetId).get()).val();
  }
  async function enabled(uid, mode) {
    const c = content(mode); const state = (await documentRef(c.collection)(uid).get()).val() || {};
    if (Object.values(state.supportRuns || {}).some(B.paid)) return true;
    const policy = await B.policyFor(db, uid, await isLinked(uid));
    if (policy?.readyModes?.[mode] !== true) return false;
    const pro = await premium(uid);
    // A missing cutover or historical subscription timestamp preserves the
    // previous Pro offer. Administrators must explicitly date a new offer.
    return !(pro.active && (!Number.isSafeInteger(policy.proOfferCutoverAt) || !pro.startedAt ||
      pro.startedAt < policy.proOfferCutoverAt));
  }
  function target(input, allowLatest = false) {
    const c = content(input.mode); const t = c.targets[input.targetId];
    if (!t || !(allowLatest && input.contentVersion == null) && input.contentVersion !== c.version) {
      fail("failed-precondition", "Hikâye içeriğini yenile.");
    }
    return {c, t, key: hash([input.mode, c.version, t.section]).slice(0, 32)};
  }
  function syncRun(s, r, c, t) {
    if (Object.values(c.targets).filter((x) => x.section === t.section).every((x) => x.done(s))) r.finished = true;
    r.actions ||= {}; r.reveals ||= {}; r.adReceipts ||= {};
    const owned = s.hints?.[t.task.id];
    if (owned === true || owned?.coin || owned?.ad) {
      for (const sku of Object.keys(r.boostPolicy.products)) {
        try {
          r.reveals[t.task.id + ":" + sku] ||= help(t.task, sku);
        } catch (_) {/* no valid clue */}
      }
    }
  }
  function view(s, r, c, t) {
    const support = B.view(r);
    support.products = support.products.filter((p) => {
      try {
        help(t.task, p.id); return true;
      } catch (_) {
        return false;
      }
    });
    return {legacy: false, contentVersion: c.version, completed: t.done(s), session: {id: r.id, revision: r.revision,
      support, adCredits: r.adCredits, adGranted: r.adGranted, finished: r.finished},
    hints: Object.fromEntries(support.products.filter((p) => r.reveals?.[t.task.id + ":" + p.id])
        .map((p) => [p.id, r.reveals[t.task.id + ":" + p.id]]))};
  }
  async function ensure(uid, input) {
    const {c, t, key} = target(input, true);
    if (!await enabled(uid, input.mode)) return {legacy: true};
    const policy = await B.policyFor(db, uid, await isLinked(uid));
    const receipt = await oldReceipt(uid, input.mode, input.targetId);
    let error;
    const tx = await documentRef(c.collection)(uid).transaction((raw) => {
      error = null; const s = raw || {}; s.supportRuns ||= {};
      try {
        if (!t.open(s)) fail("failed-precondition", "Önceki hikâye aşamasını tamamla.");
        if (!s.supportRuns[key]) {
          const r = {id: key, mode: input.mode, version: c.version, revision: 0, createdAt: now(),
            expiresAt: Number.MAX_SAFE_INTEGER, finished: false, adCredits: 0, adGranted: 0,
            adReceipts: {}, actions: {}, reveals: {}};
          B.pin(r, policy);
          if (!B.paid(r)) fail("failed-precondition", "Yeni hikâye desteği şu anda kapalı.");
          s.supportRuns[key] = r;
        }
        if (receipt) (s.hints ||= {})[input.targetId] ||= {coin: true};
        syncRun(s, s.supportRuns[key], c, t);
        return s;
      } catch (e) {
        error = e; return undefined;
      }
    });
    if (error) throw error;
    const s = tx.snapshot.val(); return view(s, s.supportRuns[key], c, t);
  }
  async function use(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Destek için hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "")) fail("invalid-argument", "Geçersiz istek kimliği.");
    const {c, t, key} = target(input); let error;
    const fingerprint = hash([input.targetId, input.revision, ...B.paymentFingerprint(input)]);
    const tx = await documentRef(c.collection)(uid).transaction((raw, e, time) => {
      error = null; const s = raw || {}; const r = s.supportRuns?.[key];
      try {
        if (!B.paid(r) || !e) fail("failed-precondition", "Destek panelini yenile.");
        syncRun(s, r, c, t);
        if (r.actions[input.requestId]) {
          if (r.actions[input.requestId] !== fingerprint) fail("invalid-argument", "İstek değiştirilemez.");
          return s;
        }
        if (r.revision !== input.revision) fail("aborted", "Başka cihazda değişiklik var. Yenile.");
        if (!t.open(s) || t.done(s)) fail("failed-precondition", "Bu aşama kapalı veya tamamlanmış.");
        const text = help(t.task, input.boostId); const revealKey = input.targetId + ":" + input.boostId;
        if (r.reveals[revealKey]) fail("already-exists", "Bu ipucu zaten açık.");
        B.consume(e, r, input, input.boostId, revealKey, {text}, time);
        r.reveals[revealKey] = text; r.actions[input.requestId] = fingerprint; r.revision++;
        (s.supportAssisted ||= {})[t.section] = true;
        return s;
      } catch (err) {
        error = err; return undefined;
      }
    });
    if (error) throw error;
    const s = tx.snapshot.val(); return view(s, s.supportRuns[key], c, t);
  }
  async function guardLegacy(uid, mode, targetId) {
    const c = content(mode); const s = (await documentRef(c.collection)(uid).get()).val() || {};
    const old = s.hints?.[targetId];
    if (!(old === true || old?.coin || old?.ad) && !await oldReceipt(uid, mode, targetId) && await enabled(uid, mode)) {
      fail("failed-precondition", "Bu oturumda Destek Çantası'nı kullan; uygulamayı güncelle.");
    }
  }
  async function prepareHint(uid, placement, input) {
    if (placement !== "story_support_hint" || !await isLinked(uid)) fail("permission-denied", "Hesap gerekli.");
    const {c, t, key} = target(input);
    const s = (await documentRef(c.collection)(uid).get()).val() || {}; const r = s.supportRuns?.[key];
    if (!B.paid(r) || input.sessionId !== r.id || !t.open(s) || t.done(s)) {
      fail("failed-precondition", "Aktif hikâye desteği yok.");
    }
    syncRun(s, r, c, t);
    help(t.task, input.boostId);
    if (r.reveals[input.targetId + ":" + input.boostId]) fail("already-exists", "İpucu açık.");
    return B.adBenefit(r, {amount: 0, claimKey: "story_support_" + key + "_" + r.adGranted,
      context: {mode: input.mode, targetId: input.targetId, contentVersion: c.version, sessionId: key}}, input.boostId);
  }
  async function settleHint(uid, receipt) {
    const {c, t, key} = target(receipt.context); let error;
    await documentRef(c.collection)(uid).transaction((raw, e, time) => {
      error = null; const s = raw || {}; const r = s.supportRuns?.[key];
      try {
        if (!e) fail("failed-precondition", "Hikâye cüzdan kaydı hazır değil.");
        if (r) syncRun(s, r, c, t);
        const canApply = !!r && t.open(s) && !t.done(s) && !r.reveals[t.task.id + ":" + receipt.context.boostId];
        if (B.recoverAd(e, r, receipt, time, "boost_basic", canApply)) return s;
        if (!r.adReceipts[receipt.id]) B.grantAd(r, receipt);
        return s;
      } catch (err) {
        error = err; return undefined;
      }
    });
    if (error) throw error;
  }
  return {enabled, ensure, use, guardLegacy, prepareHint, settleHint};
}
function recoverUnused(e, s, time) {
  for (const r of Object.values(s.supportRuns || {})) {
    const c = content(r.mode);
    B.recoverUnused(e, r, time, (sku, scope) => {
      const t = c.targets[scope.targetId];
      return c.version === r.version && !!t && t.open(s) && !t.done(s) &&
        !r.reveals?.[scope.targetId + ":" + sku];
    });
  }
}
module.exports = {create, content, help, recoverUnused};
