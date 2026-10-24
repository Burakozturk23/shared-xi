"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const E = require("./arcade_engine");
const energy = require("./energy");
const {dayKey} = require("./rewarded_ads");
const {normalize: nameKey} = require("./daily_words");
const {validId} = require("./career_transfer");
const {catalog, fail, hydrate} = E;
const defaults = {enabled: false, rewardsEnabled: false};
const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
const state = (s) => ({sessions: {}, active: {}, records: {}, claims: {}, pending: {}, paid: {}, daily: {}, ...s});
const recordKey = (r) => r.mode === "burst" ? `burst__${r.style}__${r.pairType}` : r.mode + "__" + r.difficulty;
function check(input) {
  if (!["burst", "pyramid", "matching"].includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
  if (input.style && !["speed", "survival"].includes(input.style) || input.pairType && !["clubClub",
    "clubCountry"].includes(input.pairType) ||
    input.difficulty && !["easy", "normal", "hard"].includes(input.difficulty)) {
    fail("invalid-argument",
        "Geçersiz oyun seçimi.");
  }
}
function finalize(s, r, time, rewarded) {
  if (!r.finished || r.recorded || r.phase !== "active") return;
  r.recorded = true; r.finishedAt = time;
  const key = recordKey(r) + "__" + r.dataVersion + (r.assisted ? "__assisted" : "");
  const rec = s.records[key] ||= {mode: r.mode, style: r.style, pairType: r.pairType, difficulty: r.difficulty,
    dataVersion: r.dataVersion, sessions: 0, bestScore: 0, bestRounds: 0, bestStreak: 0, bestCorrect: 0};
  rec.sessions++; rec.bestScore = Math.max(rec.bestScore, r.score); rec.bestRounds = Math.max(rec.bestRounds, r.rounds);
  rec.bestStreak = Math.max(rec.bestStreak, r.bestStreak); rec.bestCorrect = Math.max(rec.bestCorrect, r.correct);
  if (!r.hints) rec.bestNoHintScore = Math.max(rec.bestNoHintScore || 0, r.score);
  if (r.mode === "burst") {
    rec.bestLives = Math.max(rec.bestLives || 0, r.lives);
    if (r.correct) rec.bestAverageAnswerMs = Math.min(rec.bestAverageAnswerMs || Infinity, r.activeMs / r.correct);
  }
  if (r.won) {
    rec.bestTimeMs = Math.min(rec.bestTimeMs ?? Infinity, r.activeMs);
    if (r.mode === "matching") {
      if (rec.bestMoves == null || r.moves < rec.bestMoves || r.moves === rec.bestMoves &&
        r.activeMs < rec.timeAtBestMoves) {
        rec.bestMoves = r.moves; rec.timeAtBestMoves = r.activeMs;
      }
    }
  }
  if (!rewarded) return;
  function award(id, coins) {
    if (s.claims[id]) return;
    s.claims[id] = {at: time, coins, sessionId: r.id}; s.pending[id] = {coins, mode: r.mode};
    r.rewardKeys.push(id); r.earnedCoins += coins;
  }
  if (r.mode === "burst") {
    const thresholds = r.style === "speed" ? [2, 3, 5, 7] : [3, 6, 9, 12];
    thresholds.forEach((n, i) => {
      const master = r.style === "speed" ? r.wrong === 0 && r.passes === 0 : r.hints === 0 && r.passes === 0 &&
        r.lives >= 3;
      if (r.rounds >= n && (i !== 3 ||
        master)) award(`burst:v1:${r.style}:${["bronze", "silver", "gold", "master"][i]}`, i === 3 ? 3 : 2);
    });
  } else if (r.won) {
    const coins = r.mode === "pyramid" ? {easy: 2, normal: 2, hard: 3} : {easy: 1, normal: 2, hard: 2};
    award(`${r.mode}:v1:${r.difficulty}`, coins[r.difficulty]);
    if (r.difficulty === "hard" && (r.mode === "pyramid" ? r.wrong === 0 &&
      r.hints === 0 : r.moves <= 24)) award(`${r.mode}:v1:master`, 3);
  }
  const qualifies = r.mode === "burst" ? r.rounds >= (r.style === "speed" ? 2 : 3) : r.won && r.difficulty !== "easy";
  if (qualifies) {
    const group = r.mode === "burst" ? "burst" : "logic"; const day = dayKey(time); const k = group + "__" + day;
    s.daily[k] ||= {day, group, at: time, status: "pending", sessionId: r.id};
  }
}
function createService({db, normalize, project, grantCoins, grantXp, dailyClaim, isLinked,
  getRollout = async () => ({}), getPolicy = async () => ({}), now = Date.now}) {
  const read = async (uid) => state((await db.ref(`economyState/${uid}/arcade`).get()).val());
  async function pinned(version) {
    if (version === catalog.version) return catalog;
    const c = (await db.ref(`arcadeCatalogs/${version}`).get()).val();
    if (!c) fail("unavailable", "Kayıtlı veri sürümü yüklenemedi. Hak harcanmadı; yeniden dene.");
    c.pyramids = E.list(c.pyramids); c.burst = E.list(c.burst); c.careers = E.list(c.careers);
    return c;
  }
  async function change(uid, fn) {
    let error; const time = now();
    const tx = await db.ref(`economyState/${uid}`).transaction((raw) => {
      error = null; const e = normalize(structuredClone(raw));
      e.arcade = state(e.arcade); e.energy = energy.refreshed(e.energy, time);
      try {
        fn(e.arcade, e, time); e.updatedAt = time; return e;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "İsteği aynı kimlikle yeniden gönder.");
    const e = normalize(tx.snapshot.val()); e.arcade = state(e.arcade); e.energy = energy.refreshed(e.energy, time);
    await project(db, uid, e); return e;
  }
  async function cost(uid, mode) {
    if (!await isLinked(uid)) return 0;
    const p = {...energy.policy.rollout, ...await getRollout()};
    return p.enabled && parseInt(hash(uid).slice(0, 8), 16) % 100 < p.percent && (p.sessionModes ||
      []).includes(mode) ? 1 : 0;
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, p] of Object.entries(s.pending)) {
      // Ledger-safe spelling, while canonical achievement keys retain the PDF contract.
      const txId = id.replaceAll(":", "__");
      await grantCoins(uid, txId, "arcade_achievement", p.mode, p.coins, "arcade-v1");
      await grantXp(uid, txId, p.coins * 2);
      await change(uid, (s) => {
        s.paid[id] = true; delete s.pending[id];
      });
    }
    for (const [key, d] of Object.entries(s.daily)) {
      if (d.status !== "pending") continue;
      const result = await dailyClaim(uid, d.day, d.group);
      await change(uid, (s) => {
        if (s.daily[key]) s.daily[key].status = result;
      });
    }
  }
  async function result(uid, mode, kitVersion) {
    const s = await read(uid); const r = hydrate(s.sessions[s.active[mode]]);
    const c = r ? await pinned(r.dataVersion) : catalog;
    return {version: catalog.version,
      ...(mode === "burst" && kitVersion != null && kitVersion !== c.version ? {burstKit: {
        version: c.version, questions: c.burst,
        players: Object.fromEntries(Object.values(c.players).map((p) => [p.id,
          {id: p.id, name: p.name, country: p.country, countryId: p.countryId, aliases: p.aliases}])),
      }} : {}), availability: {...defaults, ...await getPolicy()},
      energyCost: await cost(uid, mode), linked: await isLinked(uid),
      session: E.publicRun(c, r, now()), records: s.records, medals: s.claims, paid: s.paid,
      pendingCoins: Object.values(s.pending).reduce((n, p) => n + p.coins, 0), daily: s.daily,
      recent: Object.values(s.sessions).filter((x) => x.mode === mode && x.finished).sort((a,
          b) => b.finishedAt - a.finishedAt)
          .slice(0, 10).map((x) => ({id: x.id, score: x.score, rounds: x.rounds, moves: x.moves,
            activeMs: x.activeMs, difficulty: x.difficulty, style: x.style, pairType: x.pairType,
            finishedAt: x.finishedAt}))};
  }
  async function status(uid, input) {
    check(input);
    const s = await read(uid); const r = hydrate(s.sessions[s.active[input.mode]]);
    if (r) {
      const c = await pinned(r.dataVersion); const p = {...defaults, ...await getPolicy()};
      const linked = await isLinked(uid);
      await change(uid, (s, e, t) => {
        const live = hydrate(s.sessions[r.id]);
        const before = JSON.stringify([live.activeMs, live.finished, live.question?.id, live.open]);
        E.tick(c, live, t);
        if (input.reopen && live.mode === "matching" && !live.finished) live.open = [];
        if (live.phase === "prepared" && t >= live.preparedUntil) {
          live.finished = true; live.reason = "Hazırlık süresi doldu. Enerji harcanmadı.";
          if (e.energy.sessions[live.id]?.status === "reserved") e.energy.sessions[live.id].status = "cancelled";
        }
        if (before !== JSON.stringify([live.activeMs, live.finished, live.question?.id, live.open])) live.revision++;
        finalize(s, live, t, p.rewardsEnabled && linked && !live.practice); s.sessions[live.id] = live;
      });
    }
    await settle(uid); return result(uid, input.mode, input.kitVersion || "none");
  }
  async function prepare(uid, input) {
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    check(input);
    if (!validId(input.requestId) || input.version !== catalog.version) {
      fail("invalid-argument",
          "Oyun verisini yenile.");
    }
    const p = {...defaults, ...await getPolicy()};
    if (!p.enabled) fail("failed-precondition", "Bu güncelleme henüz açılmadı.");
    const charge = await cost(uid, input.mode); const linked = await isLinked(uid);
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    if (charge && (!Number.isSafeInteger(input.clientVersion) || input.clientVersion < rollout.minClientVersion)) {
      fail("failed-precondition", "Enerji sistemi için uygulamayı güncelle.");
    }
    // All expensive selection/solver work precedes the energy reservation.
    const draft = E.create(catalog, input, now());
    B.pin(draft, boostPolicy);
    await db.ref(`arcadeCatalogs/${catalog.version}`).transaction((raw) => raw || catalog);
    await change(uid, (s, e, time) => {
      if (s.sessions[input.requestId]) {
        const r = s.sessions[input.requestId];
        if (recordKey(r) !== recordKey(draft)) fail("invalid-argument", "İstek başka oyun seçimine ait.");
        return;
      }
      const previous = hydrate(s.sessions[s.active[input.mode]]);
      if (previous && !previous.finished && previous.expiresAt > time &&
        (previous.phase === "active" || previous.preparedUntil > time)) {
        fail("already-exists",
            "Önce kayıtlı oyuna devam et veya bitir.");
      }
      if (charge && e.energy.balance - energy.held(e.energy) < 1) fail("resource-exhausted", "1 enerji gerekli.");
      draft.preparedUntil = time + energy.policy.reservationMs; draft.practice = !linked;
      draft.energyCharged = false; draft.energyReserved = charge === 1;
      if (charge) {
        e.energy.sessions[draft.id] = {mode: draft.mode, unitId: "session", key: "",
          status: "reserved", createdAt: time, expiresAt: draft.preparedUntil};
      }
      s.sessions[draft.id] = draft; s.active[draft.mode] = draft.id;
      const old = Object.values(s.sessions).filter((x) => x.finished &&
        !Object.values(s.active).includes(x.id)).sort((a, b) => b.createdAt - a.createdAt);
      for (const x of old.slice(30)) delete s.sessions[x.id];
    });
    return result(uid, input.mode, "none");
  }
  function applyRequest(s, e, t, input, c, p, linked) {
    const canonical = Object.fromEntries(["mode", "sessionId", "requestId", "revision", "action", "questionId",
      "entityId", "query", "slotId", "cardId", "elapsedMs", "boostId", "paymentSource", "expectedPriceCoins"]
        .filter((k) => input[k] != null).map((k) => [k, input[k]]));
    const fp = hash(JSON.stringify(canonical));
    const r = hydrate(s.sessions[input.sessionId]);
    if (!r || r.mode !== input.mode || !validId(input.requestId)) fail("invalid-argument", "Geçersiz olay.");
    if (r.actions[input.requestId]) {
      if (r.actions[input.requestId] !== fp) fail("invalid-argument", "Aynı istek değiştirilemez.");
      return;
    }
    if (r.revision !== input.revision) fail("aborted", "Oyun başka cihazda değişti. Yenile.");
    if (r.finished) fail("failed-precondition", "Oyun sona erdi.");
    if (!p.enabled && input.action !== "finish" && input.action !== "cancel") {
      fail("unavailable",
          "Mod geçici olarak kapalı; kaydın korunuyor.");
    }
    if (input.action === "cancel" && r.phase === "prepared") {
      r.finished = true; r.reason = "Hazırlık iptal edildi; enerji harcanmadı.";
      if (e.energy.sessions[r.id]?.status === "reserved") e.energy.sessions[r.id].status = "cancelled";
    } else if (input.action === "confirm") {
      if (r.phase !== "prepared" || t >= r.preparedUntil) {
        fail("failed-precondition",
            "Hazırlık süresi doldu; yeniden hazırla.");
      }
      if (r.energyReserved) {
        const reservation = e.energy.sessions[r.id];
        if (!reservation || !["reserved",
          "confirmed"].includes(reservation.status)) fail("failed-precondition", "Enerji rezervasyonu doldu.");
        // Generic energy confirmation may have already debited this same receipt.
        if (reservation.status === "reserved") {
          if (e.energy.balance < 1) fail("resource-exhausted", "Enerji yetersiz.");
          if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = t;
          e.energy.balance--; reservation.status = "confirmed"; reservation.expiresAt = t + energy.policy.resumeMs;
        }
        r.energyCharged = true;
      }
      r.phase = "active"; r.paused = false; r.startedAt = t; r.lastAt = t; r.expiresAt = t + energy.policy.resumeMs;
    } else {
      if (r.phase !== "active") fail("failed-precondition", "Önce hazır tahtayı başlat.");
      let eventTime = t;
      if (r.mode === "burst" && input.elapsedMs != null) {
        if (!Number.isSafeInteger(input.elapsedMs) || input.elapsedMs < 0 ||
            r.lastAt + input.elapsedMs > t + 1000) fail("invalid-argument", "Olay süresi doğrulanamadı.");
        eventTime = r.lastAt + input.elapsedMs;
      }
      if (t >= r.expiresAt) {
        r.finished = true; r.reason = "24 saatlik devam süresi doldu.";
      }
      E.tick(c, r, eventTime);
      if (!r.finished) {
        const previousHints = r.hints;
        E.act(c, r, input, eventTime);
        if (input.action === "hint" && B.paid(r) && r.hints > previousHints) {
          B.consume(e, r, input, r.mode === "pyramid" ? "boost_strong" : "boost_basic",
              r.mode === "pyramid" ? "slot:" + input.slotId : "hint:" + previousHints, {text: r.hint}, t);
        }
      }
      finalize(s, r, t, p.rewardsEnabled && linked && !r.practice);
    }
    r.actions[input.requestId] = fp; r.revision++;
    // Older retries fail the revision fence; they can never execute twice.
    const ids = Object.keys(r.actions); for (const k of ids.slice(0, Math.max(0,
        ids.length - 1500))) delete r.actions[k];
    s.sessions[r.id] = r;
  }
  async function replay(uid, input) {
    const events = input.events;
    if (input.mode !== "burst" || !Array.isArray(events) || !events.length || events.length > 1000) {
      fail("invalid-argument", "Geçersiz çevrimdışı olay paketi.");
    }
    const saved = hydrate((await read(uid)).sessions[events[0].sessionId]);
    if (B.paid(saved) && events.some((e) => e.action === "hint")) {
      fail("failed-precondition", "Ücretli destek çevrimiçi doğrulanır; hak harcanmadı.");
    }
    if (!saved || saved.mode !== "burst") fail("not-found", "Kayıt bu hesaba ait değil.");
    const c = await pinned(saved.dataVersion); const p = {...defaults, ...await getPolicy()};
    const linked = await isLinked(uid);
    await change(uid, (s, e, t) => {
      for (const event of events) {
        if (event.mode !== "burst" || event.sessionId !== saved.id ||
          !["answer", "tick", "pass", "hint", "pause", "resume", "finish"].includes(event.action)) {
          fail("invalid-argument", "Çevrimdışı paket oturum sınırını aşamaz.");
        }
        applyRequest(s, e, t, event, c, p, linked);
      }
      s.sessions[saved.id].lastAt = t;
    });
    await settle(uid); return result(uid, "burst");
  }
  async function act(uid, input) {
    check(input);
    if (!validId(input.requestId) || !validId(input.sessionId)) fail("invalid-argument", "Geçersiz işlem kimliği.");
    const snapshot = await read(uid); const saved = hydrate(snapshot.sessions[input.sessionId]);
    if (!saved || saved.mode !== input.mode) fail("not-found", "Bu hesaba ait oturum bulunamadı.");
    const c = await pinned(saved.dataVersion); const p = {...defaults, ...await getPolicy()};
    const linked = await isLinked(uid);
    await change(uid, (s, e, t) => {
      applyRequest(s, e, t, input, c, p, linked);
      // Network/loading time is excluded after the server validates the monotonic event.
      if (input.elapsedMs != null) s.sessions[input.sessionId].lastAt = t;
    });
    await settle(uid); return result(uid, input.mode);
  }
  async function search(uid, input) {
    check(input);
    const query = nameKey(String(input.query || "").slice(0, 120)); if (query.length < 2) return {items: []};
    let c = catalog;
    if (input.sessionId) {
      const r = (await read(uid)).sessions[input.sessionId];
      if (!r || r.mode !== input.mode) fail("not-found", "Oturum bulunamadı.");
      c = await pinned(r.dataVersion);
    }
    // No question/answers/filled state is consulted, including ranking and cache keys.
    const pool = input.mode === "pyramid" ? Object.values(c.entities) : Object.values(c.players);
    const items = pool.filter((p) => [p.name, ...(p.aliases || [])].some((x) => nameKey(x).includes(query)))
        .sort((a, b) => Number(nameKey(b.name).startsWith(query)) - Number(nameKey(a.name).startsWith(query)) ||
          nameKey(a.name).localeCompare(nameKey(b.name)) || a.id.localeCompare(b.id)).slice(0, 12)
        .map((p) => ({id: p.id, name: p.name, type: p.type || "player", country: p.country || ""}));
    return {items};
  }
  async function prepareHint(uid, placement, context) {
    const r = hydrate((await read(uid)).sessions[context?.sessionId]);
    if (placement !== "burst_survival_hint" || !r || r.mode !== "burst" || r.style !== "survival" ||
      r.phase !== "active" || r.finished || r.expiresAt <= now() || r.adGranted >= 2 ||
      !r.question.answers.some((id) => !r.found.includes(id) &&
        !r.hinted.includes(id))) fail("failed-precondition", "Bu oturumda reklam ipucu kullanılamaz.");
    return B.adBenefit(r, {amount: 0, claimKey: `burst_hint_${r.id}_${r.adGranted}`,
      context: {sessionId: r.id, credit: r.adGranted}}, context?.boostId);
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e, t) => {
      const r = hydrate(s.sessions[receipt.context?.sessionId]);
      if (B.recoverAd(e, r, receipt, t)) {
        if (r) s.sessions[r.id] = r; return;
      }
      if (!r || r.mode !== "burst" || r.style !== "survival" || r.finished || r.expiresAt <= t ||
        r.adReceipts[receipt.id] || r.adGranted >= 2 || r.adGranted !== receipt.context.credit) return;
      B.grantAd(r, receipt); s.sessions[r.id] = r;
    });
  }
  return {status, prepare, act, replay, search, settle, prepareHint, settleHint};
}
module.exports = {createService, defaults, catalog, finalize, recordKey};
