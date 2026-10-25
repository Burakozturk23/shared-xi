"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const S = require("./squad_challenge");
const {RewardError} = require("./rewarded_ads");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (v) => crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex");
const players = new Map(S.catalog.players.map((p) => [p.id, p]));
const themes = new Map(S.catalog.themes.map((t) => [t.id, t]));
const formations = new Map(S.catalog.formations.map((f) => [f.id, f]));
function scope(input) {
  if (input.catalogVersion !== S.catalog.version) fail("failed-precondition", "Kadro kataloğunu güncelle.");
  const theme = themes.get(input.themeId); const formation = formations.get(input.formationId);
  if (!theme || !formation) fail("invalid-argument", "Tema veya diziliş geçersiz.");
  return {theme, formation};
}
function recommendation(run, input) {
  const {theme, formation} = scope({...input, themeId: run.mission.themeId, formationId: run.mission.formationId});
  const ids = input.playerIds; const slot = input.slot;
  if (!Array.isArray(ids) || ids.length !== 11 || !Number.isInteger(slot) || slot < 0 || slot >= 11) {
    fail("invalid-argument", "Kadro taslağı veya mevki geçersiz.");
  }
  const selected = ids.map((id, i) => {
    if (id == null) return null;
    const p = players.get(id);
    if (!p || !Number.isSafeInteger(id) || !theme.players.includes(id) || !S.positionFits(p, formation.slots[i])) {
      fail("invalid-argument", "Taslak oyuncusu tema veya mevkiye uymuyor.");
    }
    return p;
  });
  const used = selected.filter(Boolean);
  if (new Set(used.map((p) => p.id)).size !== used.length) fail("invalid-argument", "Tekrarlanan oyuncu.");
  const countries = new Set();
  for (const p of used) {
    if (theme.uniqueCountries && p.countries.some((c) => countries.has(c))) fail("invalid-argument", "Ülke tekrarı.");
    for (const c of p.countries) countries.add(c);
  }
  const cost = used.reduce((sum, p) => sum + theme.costs[p.id], 0);
  if (cost > run.mission.budget) fail("invalid-argument", "Kadro kredisi aşıldı.");
  const others = selected.filter((p, i) => p && i !== slot);
  const otherCountries = new Set(others.flatMap((p) => p.countries));
  const available = run.mission.budget - others.reduce((sum, p) => sum + theme.costs[p.id], 0);
  const candidates = theme.players.map((id) => players.get(id)).filter((p) =>
    p.id !== ids[slot] && S.positionFits(p, formation.slots[slot]) && theme.costs[p.id] <= available &&
    !others.some((x) => x.id === p.id) && (!theme.uniqueCountries || !p.countries.some((c) => otherCountries.has(c))))
      .map((p) => ({id: p.id, name: p.name, cost: theme.costs[p.id],
        newCountries: p.countries.filter((c) => !otherCountries.has(c)).length,
        links: formation.adjacency[slot].filter((i) =>
          selected[i]?.clubIds.some((c) => p.clubIds.includes(c))).length}));
  candidates.sort((a, b) => b.links - a.links || b.newCountries - a.newCountries || a.cost - b.cost || a.id - b.id);
  if (!candidates.length) fail("failed-precondition", "Doğrulanmış aday yok; destek harcanmadı.");
  return {slot, slotLabel: formation.slots[slot].label, playerIds: ids.map((id) => id ?? 0), available,
    candidates: candidates.slice(0, input.boostId === "boost_basic" ? 5 : 1),
    explanation: "Mevki ve krediye uygun; komşu kulüp bağı, yeni ülke ve düşük kredi sırasıyla. " +
      "Tam kadro garantisi değildir."};
}
function recover(e, now) {
  const s = e.squadChallenge || {};
  for (const r of [...Object.values(s.runs || {}), ...Object.values(s.practiceRuns || {})]) {
    if (!B.paid(r)) continue;
    r.finished = r.status !== "active";
    B.recoverUnused(e, r, now, (sku) => !r.supportHints?.[sku]);
  }
  if (s.active && s.runs?.[s.active.id]) s.active = s.runs[s.active.id];
  for (const [id, r] of Object.entries(s.practiceRuns || {})) {
    if (r.status !== "active" && r.startedAt < now - 2 * 86400000 && !(r.adCredits > 0)) delete s.practiceRuns[id];
  }
}
function publicView(r) {
  return {legacy: !B.paid(r), session: {id: r.id, revision: r.revision || 0, finished: r.status !== "active",
    support: B.view(r), adCredits: r.adCredits || 0, adGranted: r.adGranted || 0},
  hints: r.supportHints || {}, penalty: r.supportPenalty || 0, result: r.result || null,
  practice: r.practice === true};
}
function createService({db, normalize, project, isLinked, now = Date.now}) {
  async function change(uid, fn) {
    const ref = db.ref("economyState/" + uid); const base = (await ref.get()).val(); let result;
    const tx = await ref.transaction((raw) => {
      const e = normalize(structuredClone(raw ?? base)); e.squadChallenge ||= {};
      recover(e, now()); result = fn(e, e.squadChallenge); recover(e, now());
      if (result?.session) {
        const r = e.squadChallenge.runs?.[result.session.id] ||
          e.squadChallenge.practiceRuns?.[result.session.id];
        result = publicView(r);
      }
      return e;
    });
    if (!tx.committed) fail("aborted", "Kadro değişti. Yenile.");
    await project(db, uid, normalize(tx.snapshot.val())); return result;
  }
  function find(s, input) {
    const r = s.runs?.[input.sessionId] || s.practiceRuns?.[input.sessionId];
    if (!B.paid(r)) fail("failed-precondition", "Destek panelini yenile.");
    if (input.catalogVersion !== S.catalog.version || r.version !== S.catalog.version) {
      fail("failed-precondition", "Kadro kataloğu değişti.");
    }
    return r;
  }
  async function get(uid, input) {
    if (!await isLinked(uid)) return {legacy: true};
    const {theme, formation} = scope(input); const policy = await B.policyFor(db, uid, true);
    const newId = "practice_" + crypto.randomBytes(16).toString("hex");
    return change(uid, (e, s) => {
      let r;
      if (input.runId) {
        r = s.runs?.[input.runId];
        if (!r || r.mission.themeId !== theme.id || r.mission.formationId !== formation.id) {
          fail("not-found", "Kadro oturumu bulunamadı.");
        }
      } else {
        const key = hash([theme.id, formation.id]); s.practiceRuns ||= {}; s.practiceActive ||= {};
        r = s.practiceRuns[s.practiceActive[key]];
        if (!r || r.status !== "active" || r.expiresAt <= now()) {
          if (r) {
            r.status = "expired"; recover(e, now());
          }
          if (policy?.readyModes?.squad_challenge !== true) return {legacy: true};
          r = {id: newId, practice: true, status: "active", startedAt: now(),
            mission: {themeId: theme.id, formationId: formation.id, budget: 160}};
          s.practiceRuns[r.id] = r; s.practiceActive[key] = r.id;
        }
      }
      if (!B.paid(r) && r.status === "active" && policy?.readyModes?.squad_challenge === true) {
        Object.assign(r, {mode: "squad_challenge", entry: r.practice ? "solo" : "daily", version: S.catalog.version,
          revision: 0, expiresAt: now() + 86400000, adCredits: 0, adGranted: 0, adReceipts: {}, actions: {}});
        B.pin(r, policy);
      }
      return publicView(r);
    });
  }
  async function use(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "")) fail("invalid-argument", "İstek kimliği geçersiz.");
    const fp = hash([input.sessionId, input.catalogVersion, input.revision, input.slot,
      input.playerIds, ...B.paymentFingerprint(input)]);
    return change(uid, (e, s) => {
      const r = find(s, input); r.actions ||= {};
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek değiştirilemez.");
        return publicView(r);
      }
      if (r.status !== "active" || r.revision !== input.revision) fail("failed-precondition", "Kadro durumunu yenile.");
      if (!["boost_basic", "boost_strong"].includes(input.boostId)) fail("invalid-argument", "Yanlış destek.");
      if (r.supportHints?.[input.boostId]) fail("already-exists", "Bu destek bu kadroda zaten kullanıldı.");
      const hint = recommendation(r, input);
      B.consume(e, r, input, input.boostId, input.boostId, hint, now());
      (r.supportHints ||= {})[input.boostId] = hint;
      r.supportPenalty = (r.supportPenalty || 0) + (input.boostId === "boost_basic" ? 10 : 20);
      r.actions[input.requestId] = fp; r.revision++; return publicView(r);
    });
  }
  async function finishPractice(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    return change(uid, (e, s) => {
      const r = find(s, input);
      if (!r.practice) fail("permission-denied", "Günlük kadro kendi sonuç yolunu kullanır.");
      if (r.status === "finished") {
        if (hash(r.playerIds) !== hash(input.playerIds)) fail("failed-precondition", "Kadro zaten sonuçlandı.");
        return publicView(r);
      }
      if (r.status !== "active") fail("failed-precondition", "Antrenman sona erdi.");
      const score = S.evaluate(r.mission.themeId, r.mission.formationId, input.playerIds, r.mission.budget);
      r.status = "finished"; r.playerIds = input.playerIds; r.finished = true;
      r.result = {...score, rawScore: score.score, score: Math.max(0, score.score - (r.supportPenalty || 0)),
        penalty: r.supportPenalty || 0, assisted: r.assisted === true, masteryEligible: !r.assisted,
        won: true, reward: 0, finishedAt: now()};
      const records = r.assisted ? (s.assistedPracticeBest ||= {}) : (s.practiceBest ||= {});
      records[r.mission.themeId] = Math.max(records[r.mission.themeId] || 0, r.result.score);
      return publicView(r);
    });
  }
  async function prepareHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "squad_support_hint") fail("permission-denied", "Hesap gerekli.");
    const e = normalize((await db.ref("economyState/" + uid).get()).val());
    const r = find(e.squadChallenge || {}, input);
    if (r.status !== "active" || r.expiresAt <= now() || input.boostId !== "boost_basic" ||
        r.supportHints?.boost_basic) {
      fail("failed-precondition", "Bu kadroda reklam desteği kullanılamaz.");
    }
    return B.adBenefit(r, {amount: 0, claimKey: "squad_hint_" + r.id,
      context: {sessionId: r.id, catalogVersion: S.catalog.version}}, "boost_basic");
  }
  async function settleHint(uid, receipt) {
    return change(uid, (e, s) => {
      const r = s.runs?.[receipt.context?.sessionId] || s.practiceRuns?.[receipt.context?.sessionId];
      const usable = r?.status === "active" && !r.supportHints?.boost_basic;
      if (!B.recoverAd(e, r, receipt, now(), "boost_basic", usable)) B.grantAd(r, receipt);
    });
  }
  return {get, use, finishPractice, prepareHint, settleHint};
}
module.exports = {createService, recommendation, recover, publicView};
