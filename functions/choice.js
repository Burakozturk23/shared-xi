"use strict";
const E = require("./choice_engine");
const B = require("./boosts");
const H = require("./hints");
const energy = require("./energy");
const {dayKey} = require("./rewarded_ads");
const {validId} = require("./career_transfer");
const {catalog, fail, hash, hydrate, list} = E;
const defaults = {enabled: false, rewardsEnabled: false};
const state = (s) => ({sessions: {}, active: {}, records: {}, claims: {}, pending: {}, paid: {}, daily: {},
  archive: {}, progress: {themes: {}, metrics: {}, statMetrics: {}}, ...s});
const dayFor = (mode, t) => mode === "blind_ranking" ? new Date(t).toISOString().slice(0, 10) : dayKey(t);
function finalize(s, r, time, rewarded, c = catalog) {
  if (!r.finished || r.recorded || r.phase !== "active") return;
  r.recorded = true; r.completedAt = time; r.rewardKeys ||= []; r.earnedCoins ||= 0;
  if (r.mode !== "higher_lower" && !r.completed) return;
  const recordKey = `${r.mode}__${r.metricId || r.bracketId || r.themeId}__${r.size || 0}__${r.dataVersion}`;
  // Training runs keep their own record, so supported play is still tracked.
  if ((!r.practice || r.training) &&
    (r.mode === "higher_lower" || r.mode === "blind_ranking" && r.type === "objective")) {
    const key = recordKey + (r.training ? "__training" : "");
    const rec = s.records[key] ||= {mode: r.mode, metricId: r.metricId, size: r.size || 0,
      dataVersion: r.dataVersion, best: 0, sessions: 0, ...(r.training ? {training: true} : {})};
    rec.best = Math.max(rec.best, r.mode === "higher_lower" ? r.streak : r.score); rec.sessions++;
    rec.lastAt = time; rec.lastSessionId = r.id;
  }
  if (r.completed) {
    s.archive[r.id] = E.publicRun(c, r);
    // The collection keeps the newest 200 results.
    const old = Object.values(s.archive).sort((a, b) => (b.completedAt || 0) - (a.completedAt || 0)).slice(200);
    for (const x of old) delete s.archive[x.id];
  }
  // A bracket is a matter of taste, so only its pace can be checked: a run
  // faster than 0.6 s per decision earns no reward.
  const rushed = r.mode === "this_or_that" && r.startedAt != null && time - r.startedAt < (r.size - 1) * 600;
  if (rushed && rewarded && !r.practice && r.contentVerified) {
    r.rewardReason = "Seçimler çok hızlı yapıldı; bu turnuva ödül vermedi. Koleksiyonun kaydedildi.";
    s.archive[r.id] = E.publicRun(c, r); return;
  }
  if (!rewarded || r.practice || r.mode === "this_or_that" && !r.contentVerified) {
    r.rewardReason = r.training ? "Antrenman: normal rekor, ödül ve ustalığa eklenmez." :
      r.practice ? "Misafir/deneme oyunu; ödül yok." : "Ödüller veya içerik onayı henüz açılmadı.";
    if (r.completed) s.archive[r.id] = E.publicRun(c, r); return;
  }
  function award(id, coins) {
    if (coins <= 0 || s.claims[id]) return;
    s.claims[id] = {at: time, coins, sessionId: r.id}; s.pending[id] = {coins, mode: r.mode};
    r.rewardKeys.push(id); r.earnedCoins += coins;
  }
  const day = dayFor(r.mode, time); const key = r.mode + "__" + day;
  const daily = s.daily[key] ||= {day, count: 0, coins: 0, keys: {}}; daily.keys ||= {};
  const progress = s.progress; progress.themes ||= {}; progress.metrics ||= {}; progress.statMetrics ||= {};
  if (r.mode === "this_or_that") {
    const k = r.bracketId + "__" + r.size; const coins = c.policy.this_or_that[r.size];
    if (daily.count < 2 && !daily.keys[k]) {
      daily.count++; daily.coins += coins; daily.keys[k] = true; award("complete__" + r.id, coins);
    } else r.rewardReason = "Günlük hak veya tema/boyut ödülü kullanıldı. Koleksiyonun kaydedildi.";
    progress.themes[r.bracketId] = true;
    award("tot__first_champion", 2); award("tot__" + r.type + "_champion", 2);
    if (Object.keys(progress.themes).length >= 4) award("tot__four_themes", 2);
    s.daily["mission__" + day] ||= {day, status: "pending", kind: "mission"};
  } else if (r.mode === "higher_lower") {
    const tier = r.streak >= 20 ? 3 : r.streak >= 10 ? 2 : r.streak >= 5 ? 1 : 0;
    const old = daily.keys[r.metricId] || 0; const coins = Math.min(Math.max(0, tier - old), 6 - daily.coins);
    daily.keys[r.metricId] = Math.max(old, tier); daily.coins += coins; award("streak__" + r.id, coins);
    if (r.streak >= 5) {
      award("hl__first", 1); progress.metrics[r.metricId] = true;
    }
    if (r.streak >= 10) award("hl__master", 2);
    if (r.streak >= 20) award("hl__consistent", 2);
    // Three metrics, or every open one while fewer than three pass review.
    const open = Object.values(c.metrics || {}).filter((m) => m.gatePassed).length;
    if (Object.keys(progress.metrics).length >= Math.max(1, Math.min(3, open))) award("hl__explorer", 3);
  } else {
    // A personal list has no right answer, so only one a day is rewarded.
    const personalLeft = r.type !== "personal" || !daily.personal;
    if (daily.count < 2 && personalLeft) {
      const coins = c.policy.blind_ranking[r.size]; daily.count++; daily.coins += coins; award("rank__" + r.id, coins);
      if (r.type === "personal") daily.personal = true;
    } else {
      r.rewardReason = personalLeft ? "UTC günündeki iki ödüllü oyun tamamlandı. Listen kaydedildi." :
        "Bugünün ödüllü kişisel listesi kullanıldı; nesnel listeler ödül vermeye devam eder.";
    }
    award("br__first_rank", 1);
    if (r.size === 10) award("br__classic_rank", 2);
    if (r.type === "personal") award("br__my_first_list", 1);
    else {
      progress.statMetrics[r.metricId] = true;
      // A ten-list is far harder than a five-list: 80+ there, or a perfect five.
      if (r.size === 10 ? r.score >= 80 : r.score === 100) award("br__stat_80", 2);
      if (r.size === 10 && r.score === 100) award("br__stat_perfect", 3);
      const open = Object.values(c.metrics || {}).filter((m) => m.gatePassed).length;
      if (Object.keys(progress.statMetrics).length >= Math.max(1, Math.min(3, open))) award("br__three_metrics", 2);
    }
  }
  if (r.completed) s.archive[r.id] = E.publicRun(c, r);
}
function createService({db, normalize, project, grantCoins, grantXp, dailyClaim, isLinked,
  getRollout = async () => ({}), getPolicy = async () => ({}), now = Date.now}) {
  function check(input) {
    if (!E.modes.includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
  }
  const read = async (uid) => state((await db.ref(`economyState/${uid}/choice`).get()).val());
  async function pinned(version) {
    if (version === catalog.version) return catalog;
    const c = (await db.ref(`choiceCatalogs/${version}`).get()).val();
    if (!c) fail("unavailable", "Kayıtlı veri sürümü yüklenemedi. Kaydın korunuyor."); return c;
  }
  async function change(uid, fn) {
    let error; const time = now();
    const tx = await db.ref(`economyState/${uid}`).transaction((raw) => {
      error = null; const e = normalize(structuredClone(raw)); e.choice = state(e.choice);
      e.energy = energy.refreshed(e.energy, time);
      try {
        fn(e.choice, e, time);
        for (const r of Object.values(e.choice.sessions)) {
          H.recoverUnused(e, E.hydrate(r), time);
          B.recoverUnused(e, r, time, (_, scope) => {
            try {
              return clue(r).target === scope.targetId;
            } catch (_) {
              return false;
            }
          });
        }
        e.updatedAt = time; return e;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "İsteği aynı kimlikle yeniden dene.");
    await project(db, uid, normalize(tx.snapshot.val()));
  }
  async function cost(uid, mode) {
    if (!await isLinked(uid)) return 0;
    const p = {...energy.policy.rollout, ...await getRollout()};
    return energy.inRollout(p, uid) &&
      list(p.sessionModes).includes(mode) ? 1 : 0;
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, p] of Object.entries(s.pending)) {
      await grantCoins(uid, "choice__" + id, "choice_completion", p.mode, p.coins, "choice-v1");
      await grantXp(uid, "choice__" + id, p.coins * 2);
      await change(uid, (s) => {
        s.paid[id] = true; delete s.pending[id];
      });
    }
    for (const [id, d] of Object.entries(s.daily)) {
      if (d.kind !== "mission" || d.status !== "pending") continue;
      const result = await dailyClaim(uid, d.day, "choice");
      await change(uid, (s) => {
        s.daily[id].status = result;
      });
    }
  }
  // Champion picks across all players, one per completed bracket.
  const statsPath = (r) => `choiceStats/${r.dataVersion}/${r.bracketId}__${r.size}`;
  async function countChampion(uid, sessionId) {
    const r = hydrate((await read(uid)).sessions[sessionId]);
    if (!r || r.mode !== "this_or_that" || !r.completed || !r.championId || r.statsCounted) return;
    await db.ref(statsPath(r)).transaction((raw) => {
      const v = raw || {total: 0, champions: {}};
      v.total = (v.total || 0) + 1; v.champions ||= {};
      v.champions[r.championId] = (v.champions[r.championId] || 0) + 1; return v;
    });
    await change(uid, (s) => {
      if (s.sessions[sessionId]) s.sessions[sessionId].statsCounted = true;
    });
  }
  async function community(c, r) {
    if (!r || r.mode !== "this_or_that" || !r.completed) return null;
    const v = (await db.ref(statsPath(r)).get()).val();
    if (!v?.total) return null;
    const share = (id) => Math.round(100 * (v.champions?.[id] || 0) / v.total);
    const top = Object.entries(v.champions || {}).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, 3)
        .filter(([id]) => c.candidates[id]).map(([id]) => ({id, name: c.candidates[id].name, share: share(id)}));
    return {total: v.total, championShare: share(r.championId), top};
  }
  async function result(uid, input) {
    const s = await read(uid); const r = hydrate(s.sessions[s.active[input.mode]]);
    const c = r ? await pinned(r.dataVersion) : catalog;
    const decorate = (v) => v && {...v, rewardPending: list(v.rewardKeys).some((k) => !s.paid[k])};
    const archive = Object.values(s.archive).filter((x) => x.mode === input.mode)
        .sort((a, b) => b.completedAt - a.completedAt || a.id.localeCompare(b.id));
    const offset = Number.isSafeInteger(input.offset) && input.offset >= 0 ? input.offset : 0;
    return {version: catalog.version, availability: {...defaults, ...await getPolicy()},
      catalog: {metrics: Object.values(catalog.metrics).map(({groups, ...m}) => m),
        themes: Object.values(catalog.themes).map(({formats, ...t}) => ({...t,
          formats: Object.entries(formats).map(([size, f]) => ({size: Number(size), approved: f.approved}))})),
        personal: Object.values(catalog.personal).map(({ids, ...t}) => ({...t, count: list(ids).length}))},
      trainingAvailable: ["higher_lower", "blind_ranking"].includes(input.mode) &&
        (await B.policyFor(db, uid, await isLinked(uid)))?.readyModes?.[input.mode + "_training"] === true,
      energyCost: await cost(uid, input.mode), linked: await isLinked(uid),
      session: decorate(E.publicRun(c, r)), community: await community(c, r), records: s.records,
      achievements: s.claims, paid: s.paid,
      daily: s.daily[input.mode + "__" + dayFor(input.mode, now())] || {count: 0, coins: 0},
      dayZone: input.mode === "blind_ranking" ? "UTC" : "Europe/Istanbul",
      archive: archive.slice(offset, offset + 20).map(decorate),
      nextOffset: offset + 20 < archive.length ? offset + 20 : null};
  }
  async function status(uid, input) {
    check(input);
    await change(uid, (s, _, t) => {
      for (const r of Object.values(s.sessions)) {
        if (r.training && !r.finished && r.expiresAt <= t) {
          r.finished = true; r.reason = "Antrenman oturumu sona erdi.";
          finalize(s, hydrate(r), t, false);
        }
      }
    });
    await settle(uid); return result(uid, input);
  }
  async function prepare(uid, input) {
    check(input); const p = {...defaults, ...await getPolicy()};
    if (!p.enabled) fail("failed-precondition", "Bu güncelleme henüz açılmadı.");
    if (!validId(input.requestId) || input.version !== catalog.version) fail("invalid-argument", "Veriyi yenile.");
    const draft = E.create(catalog, input, now()); draft.ownerUid = uid;
    const linked = await isLinked(uid);
    if (input.training != null && typeof input.training !== "boolean") fail("invalid-argument", "Geçersiz antrenman.");
    if (input.training === true) {
      if (!linked || !["higher_lower", "blind_ranking"].includes(draft.mode) || draft.type === "personal") {
        fail("permission-denied", "Bu oyun antrenman desteği kullanamaz.");
      }
      draft.training = true; draft.expiresAt = now() + energy.policy.resumeMs;
      draft.adCredits = 0; draft.adGranted = 0; draft.adReceipts = {}; draft.trainingHints = {};
      H.pinAny(draft, await B.policyFor(db, uid, linked), null, now());
      if (!B.paid(draft) && !H.active(draft)) fail("failed-precondition", "Antrenman desteği henüz açılmadı.");
    }
    const charge = draft.training || draft.contentVerified === false ? 0 : await cost(uid, input.mode);
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    if (charge && (!Number.isSafeInteger(input.clientVersion) || input.clientVersion < rollout.minClientVersion)) {
      fail("failed-precondition", "Uygulamayı güncelle.");
    }
    await db.ref(`choiceCatalogs/${catalog.version}`).transaction((raw) => raw || catalog);
    await change(uid, (s, e, t) => {
      const existing = s.sessions[draft.id];
      if (existing) {
        for (const k of ["mode", "size", "bracketId", "metricId", "themeId", "type", "training", "daily"]) {
          if ((existing[k] || null) !== (draft[k] || null)) fail("invalid-argument", "İstek seçimi değişti.");
        }
        return;
      }
      const old = hydrate(s.sessions[s.active[input.mode]]);
      if (old && !old.finished) {
        if (old.phase !== "prepared" || old.preparedUntil > t) fail("already-exists", "Önce kayıtlı oyunu bitir.");
        old.finished = true;
        if (e.energy.sessions[old.id]?.status === "reserved") e.energy.sessions[old.id].status = "cancelled";
      }
      if (charge && e.energy.balance - energy.held(e.energy) < 1) fail("resource-exhausted", "1 enerji gerekli.");
      draft.practice = !!draft.training || !linked || draft.contentVerified === false;
      draft.preparedUntil = t + energy.policy.reservationMs; draft.energyReserved = charge === 1;
      if (charge) {
        e.energy.sessions[draft.id] = {mode: draft.mode, unitId: "session", key: "",
          status: "reserved", createdAt: t, expiresAt: draft.preparedUntil};
      }
      s.sessions[draft.id] = draft; s.active[draft.mode] = draft.id;
      // Finished runs are archived; keep only the newest 30 full sessions.
      const done = Object.values(s.sessions).filter((x) => x.finished && !Object.values(s.active).includes(x.id))
          .sort((a, b) => (b.completedAt || b.createdAt) - (a.completedAt || a.createdAt));
      for (const x of done.slice(30)) if (!(x.adCredits > 0) && !H.pending(x)) delete s.sessions[x.id];
    });
    return result(uid, input);
  }
  function apply(s, e, t, input, c, policy, linked) {
    const r = hydrate(s.sessions[input.sessionId]);
    if (!r || r.mode !== input.mode) fail("not-found", "Oturum bulunamadı.");
    if (!validId(input.requestId)) fail("invalid-argument", "Olay kimliği gerekli.");
    const canonical = Object.fromEntries(["mode", "sessionId", "requestId", "revision", "action", "candidateId",
      "questionId", "direction", "slot",
      ...(B.paid(r) ? ["paymentSource", "boostId", "expectedPriceCoins"] : []),
      ...(H.active(r) ? ["paymentSource", "itemId", "expectedPriceCoins"] : [])]
        .filter((k) => input[k] != null).map((k) => [k, input[k]]));
    const fp = hash(JSON.stringify(canonical));
    if (r.actions[input.requestId]) {
      if (r.actions[input.requestId] !== fp) fail("invalid-argument", "Aynı olay değiştirilemez."); return;
    }
    if (r.revision !== input.revision) fail("aborted", "Oyun başka cihazda değişti. Yenile.");
    if (r.finished) fail("failed-precondition", "Oyun bitti.");
    if (!policy.enabled && !["finish", "cancel"].includes(input.action)) fail("unavailable", "Mod geçici kapalı.");
    if (input.action === "cancel" && r.phase === "prepared") {
      r.finished = true;
      if (e.energy.sessions[r.id]?.status === "reserved") e.energy.sessions[r.id].status = "cancelled";
    } else if (input.action === "confirm") {
      if (r.phase !== "prepared" || t >= r.preparedUntil) fail("failed-precondition", "Hazırlık süresi doldu.");
      if (r.energyReserved) {
        const hold = e.energy.sessions[r.id];
        if (!hold || !["reserved", "confirmed"].includes(hold.status)) fail("failed-precondition", "Rezervasyon yok.");
        if (hold.status === "reserved") {
          if (e.energy.balance < 1) fail("resource-exhausted", "Enerji yetersiz.");
          if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = t;
          e.energy.balance--; hold.status = "confirmed"; hold.expiresAt = t + energy.policy.resumeMs;
        }
      }
      r.phase = "active"; r.startedAt = t;
    } else {
      if (r.phase !== "active") fail("failed-precondition", "Önce başlat.");
      if (input.action === "hint" && H.active(r)) {
        if (!linked || !r.training) fail("permission-denied", "Yalnız antrenmanda destek alınabilir.");
        H.use(e, r, adapter, input, t, {c});
      } else if (input.action === "hint") {
        if (!linked || !r.training || !B.paid(r)) fail("permission-denied", "Yalnız antrenmanda destek alınabilir.");
        const info = clue(r, c);
        if (input.questionId !== info.target) fail("aborted", "Gösterilen soru değişti. Yenile.");
        B.consume(e, r, input, "boost_basic", info.target, {text: info.text}, t);
        (r.trainingHints ||= {})[info.target] = info.text;
      } else {
        if (r.training && r.expiresAt <= t && input.action !== "finish") {
          fail("failed-precondition", "Antrenman oturumu sona erdi. Yenile.");
        }
        E.act(c, r, input); finalize(s, r, t, policy.rewardsEnabled && linked, c);
      }
    }
    r.actions[input.requestId] = fp; r.revision++; s.sessions[r.id] = r;
  }
  async function replay(uid, input) {
    check(input); const events = input.events;
    if (!Array.isArray(events) || events.length < 1 || events.length > 500) {
      fail("invalid-argument", "Geçersiz günlük.");
    }
    const s = await read(uid); const r = hydrate(s.sessions[events[0].sessionId]);
    if (!r) fail("not-found", "Oturum bulunamadı.");
    const c = await pinned(r.dataVersion); const p = {...defaults, ...await getPolicy()};
    const linked = await isLinked(uid);
    await change(uid, (s, e, t) => {
      for (const ev of events) {
        if (ev.mode !== input.mode || ev.sessionId !== r.id || ["confirm", "cancel", "hint"].includes(ev.action)) {
          fail("invalid-argument", "Günlük oturumu uyuşmuyor.");
        }
        apply(s, e, t, ev, c, p, linked);
      }
    });
    await countChampion(uid, r.id); await settle(uid); return result(uid, input);
  }
  async function act(uid, input) {
    check(input); const s = await read(uid); const r = hydrate(s.sessions[input.sessionId]);
    if (!r) fail("not-found", "Oturum bulunamadı.");
    const c = await pinned(r.dataVersion); const p = {...defaults, ...await getPolicy()};
    const linked = await isLinked(uid);
    await change(uid, (s, e, t) => apply(s, e, t, input, c, p, linked));
    await countChampion(uid, input.sessionId); await settle(uid); return result(uid, input);
  }
  async function prepareHint(uid, placement, input) {
    const r = hydrate((await read(uid)).sessions[input.sessionId]);
    if (H.active(r)) {
      if (placement !== "choice_training_hint" || !await isLinked(uid) || r.expiresAt <= now()) {
        fail("permission-denied", "Aktif antrenman gerekli.");
      }
      return H.adBenefit(r, input.itemId, {amount: 0, claimKey: "choice_hint_" + r.id + "_" + r.adGranted,
        context: {sessionId: r.id, mode: r.mode}});
    }
    if (placement !== "choice_training_hint" || !await isLinked(uid) || !B.paid(r)) {
      fail("permission-denied", "Aktif antrenman gerekli.");
    }
    const info = clue(r, await pinned(r.dataVersion));
    if (r.expiresAt <= now() || input.boostId !== "boost_basic") fail("failed-precondition", "Destek kullanılamaz.");
    return B.adBenefit(r, {amount: 0, claimKey: "choice_hint_" + r.id + "_" + r.adGranted,
      context: {sessionId: r.id, mode: r.mode, targetId: info.target}}, "boost_basic");
  }
  async function settleHint(uid, receipt) {
    const r = hydrate((await read(uid)).sessions[receipt.context?.sessionId]);
    const c = r ? await pinned(r.dataVersion) : catalog;
    await change(uid, (s, e, t) => {
      const r = hydrate(s.sessions[receipt.context?.sessionId]); let canApply = false;
      if (receipt.context?.hintPolicyVersion === H.VERSION) {
        if (!H.recoverAd(e, r, receipt, t, !!r && H.active(r) && !r.finished)) H.grantAd(r, receipt);
        return;
      }
      try {
        canApply = clue(r, c).target === receipt.context?.targetId;
      } catch (_) {/* recover stock */}
      if (B.recoverAd(e, r, receipt, t, "boost_basic", canApply)) return;
      if (!r.adReceipts?.[receipt.id]) B.grantAd(r, receipt);
    });
  }
  return {status, prepare, act, replay, prepareHint, settleHint};
}
function clue(r, c = catalog) {
  r = hydrate(r);
  if (!r?.training || r.finished || r.phase !== "active" || !B.paid(r) && !H.active(r)) {
    fail("failed-precondition", "Aktif antrenman gerekli.");
  }
  const target = r.mode === "higher_lower" ? r.question?.id : r.orderedCandidateIds[r.placements.length];
  // v2 keeps its own once-per-question rule; v1 allows one clue per question.
  if (!target || r.answered || !H.active(r) && r.trainingHints?.[target]) {
    fail("failed-precondition", "Bu soru için destek yok.");
  }
  if (r.mode === "higher_lower") {
    const value = r.question.knownSide === 0 ? r.question.rightValue : r.question.leftValue;
    const rows = E.list(c.metrics[r.metricId]?.groups?.[r.scope]);
    const values = rows.map((x) => x.value);
    if (!values.length || !Number.isFinite(value)) fail("failed-precondition", "Doğrulanmış aralık bulunamadı.");
    const spread = Math.max(...values) - Math.min(...values);
    // Ratios (goals per match) get a two-decimal band; counts a whole-number one.
    const ratio = E.isRatio(c.metrics[r.metricId]);
    const step = ratio ? Math.max(0.01, Math.ceil(spread / 5 * 100) / 100) : Math.max(1, Math.ceil(spread / 5));
    const low = Math.floor(value / step) * step; const high = low + step;
    const fmt = (v) => ratio ? v.toFixed(2).replace(".", ",") : String(v);
    return {target, low, high, text: `Gizli değer ${fmt(low)}–${fmt(high)} aralığında.`};
  }
  if (r.mode !== "blind_ranking" || r.type !== "objective") fail("permission-denied", "Bu listede destek yok.");
  const value = r.values?.[target]; const values = Object.values(r.values || {});
  if (!Number.isFinite(value) || values.length !== r.size) fail("failed-precondition", "Doğrulanmış sıra yok.");
  // Only the half of the list, so the hint guides without solving the blind order.
  const rank = values.filter((v) => v > value).length + 1;
  const upper = rank <= Math.ceil(r.size / 2);
  return {target, low: upper ? 1 : Math.ceil(r.size / 2) + 1, high: upper ? Math.ceil(r.size / 2) : r.size,
    text: `İstatistikte listenin ${upper ? "üst" : "alt"} yarısında.`};
}
// İpucu v2 menus (hints/story_choice.js).
const adapter = H.register(require("./hints/story_choice").choice({clue, catalog: E.catalog}));
module.exports = {createService, finalize, state, dayFor, defaults, clue};
