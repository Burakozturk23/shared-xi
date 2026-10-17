"use strict";
const crypto = require("node:crypto");
const {RewardError, dayKey} = require("./rewarded_ads");
const energy = require("./energy");
const {norm} = require("./three_modes");
const {players, playerView, validId} = require("./career_transfer");
const {graphOf, validMove, remaining} = require("./mystery_chain_graph");
const catalog = require("./config/mystery_chain_catalog.json");
const MODES = ["mystery", "mastermind", "blitz"];
const boosts = ["boost_first_letter", "boost_last_letter", "boost_anagram"];
const hash = (v) => crypto.createHash("sha256").update(v).digest("hex");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const stateOf = (raw) => ({sessions: {}, active: {}, starts: {}, collection: {}, claims: {}, pending: {},
  payments: {}, days: {}, sprintDays: {}, energyCredits: 0,
  sprintBest: {chains: 0, score: 0, streak: 0}, streak: 0, ...raw});
const runOf = (r) => r && ({path: [], routes: [], hints: [], guesses: [], actions: {}, adReceipts: {}, ...r});
const fileKey = (mode, p) => mode === "mystery" ? `mystery__${p.playerId}` : `chain__${p.id}`;
const pool = (c, mode) => mode === "mystery" ? c.mystery : mode === "mastermind" ? c.mastery : c.sprint;
function view(raw, time) {
  const r = runOf(raw); if (!r) return null;
  const v = {id: r.id, mode: r.mode, revision: r.revision, graphVersion: r.graphVersion,
    startedAt: r.startedAt, expiresAt: r.expiresAt, serverNow: time, endAt: r.endAt || null,
    hardEndAt: r.hardEndAt || null, finished: r.finished, found: r.found, wrong: r.wrong,
    guesses: r.guesses, hints: r.hints, freeHint: !r.freeUsed, adCredits: r.adCredits,
    adRemaining: Math.max(0, 2 - r.adGranted), optionalHints: r.optionalHints,
    score: r.score, streak: r.streak, chains: r.chains, skipped: r.skipped, undoUsed: r.undoUsed,
    result: r.result || null, feedback: r.feedback || "", energyCharged: r.energyCharged,
    firstOfficial: r.first, deadEnd: !!r.deadEnd};
  if (r.mode === "mystery") {
    v.initial = [{id: "country", text: r.puzzle.country}, {id: "position", text: r.puzzle.position}];
    if (r.finished) {
      v.player = r.player; v.source = r.puzzle.source;
    }
  } else {
    v.start = r.start; v.target = r.target; v.current = r.path.length ? r.path[r.path.length - 1].club : r.start;
    v.path = r.path; v.par = r.puzzle.par; v.maxMoves = r.maxMoves;
    v.bridgeHint = r.bridgeHint || null;
    if (r.finished) v.routes = r.routes;
  }
  return v;
}
function createService({db, normalize, project, grantCoins, grantXp, isLinked, getRollout,
  getPolicy = async () => ({}), now = Date.now, random = () => crypto.randomBytes(16).toString("hex")}) {
  async function change(uid, fn) {
    let error; const time = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null; const e = normalize(raw); e.mysteryChain = stateOf(e.mysteryChain);
      e.energy = energy.refreshed(e.energy, time);
      try {
        fn(e.mysteryChain, e, time); return e;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "Aynı isteği yeniden gönder.");
    const e = normalize(tx.snapshot.val()); e.mysteryChain = stateOf(e.mysteryChain);
    await project(db, uid, e); return e;
  }
  const read = async (uid) => stateOf((await db.ref(`economyState/${uid}/mysteryChain`).get()).val());
  async function pinned(version) {
    if (version === catalog.version) return catalog;
    const old = (await db.ref(`mysteryChainCatalogs/${version}`).get()).val();
    if (!old) fail("unavailable", "Bu oyunun kayıtlı veri sürümüne erişilemiyor. Tekrar dene.");
    return old;
  }
  function check(input) {
    if (!MODES.includes(input.mode) || input.version !== catalog.version) {
      fail("failed-precondition", "Mod verisi güncellendi. Yenile.");
    }
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const config = await getPolicy();
    const cap = Number.isInteger(config.dailyCoins) && config.dailyCoins >= 0 ? Math.min(1000, config.dailyCoins) : 24;
    const e = await change(uid, (s, _, time) => {
      const day = dayKey(time); const d = s.days[day] ||= {coins: 0, xp: 0};
      for (const [key, reward] of Object.entries(s.pending).sort((a, b) =>
        a[1].at - b[1].at || a[0].localeCompare(b[0]))) {
        const coins = Math.min(reward.coins, cap - d.coins);
        if (coins <= 0) break;
        const id = key + "__" + day; if (s.payments[id]) continue;
        s.payments[id] = {coins, xp: coins * 2, target: reward.target, paid: false};
        d.coins += coins; d.xp += coins * 2; reward.coins -= coins;
        if (!reward.coins) delete s.pending[key];
      }
    });
    for (const [id, p] of Object.entries(e.mysteryChain.payments)) {
      if (p.paid) continue;
      await grantCoins(uid, id, "mystery_chain", p.target, p.coins, "mc-reward-v1");
      await grantXp(uid, id, p.xp);
      await change(uid, (s) => {
        if (s.payments[id]) s.payments[id].paid = true;
      });
    }
  }
  function award(s, r, key, coins, time) {
    if (s.claims[key]) return;
    s.claims[key] = {coins, at: time}; s.pending[key] = {coins, at: time, target: r.puzzle.id}; r.earned += coins;
  }
  function finish(s, r, time) {
    if (r.finished) return;
    r.finished = true;
    let medal = 0;
    if (r.mode === "blitz") {
      const day = dayKey(Math.min(time, r.endAt, r.hardEndAt));
      const d = s.sprintDays[day] ||= {tier: 0, chains: 0, score: 0};
      medal = r.chains >= 5 && r.skipped === 0 ? 4 : r.chains >= 3 ? 3 : r.chains >= 2 ? 2 : r.chains >= 1 ? 1 : 0;
      for (let i = d.tier + 1; i <= medal; i++) award(s, r, `mc__sprint__${day}__${i}`, [0, 2, 2, 2, 4][i], time);
      d.tier = Math.max(d.tier, medal); d.chains = Math.max(d.chains, r.chains); d.score = Math.max(d.score, r.score);
      s.sprintBest = {chains: Math.max(s.sprintBest.chains, r.chains), score: Math.max(s.sprintBest.score, r.score),
        streak: Math.max(s.sprintBest.streak, r.bestStreak)};
    } else {
      if (r.found) {
        if (r.mode === "mystery") medal = r.wrong === 0 ? r.optionalHints === 0 ? 4 : 3 : r.wrong === 1 ? 2 : 1;
        else {
          medal = r.path.length === r.puzzle.par && !r.optionalHints && !r.undoUsed ? 4 :
          r.path.length <= r.puzzle.par + 1 ? 3 : r.path.length <= r.puzzle.par + 2 ? 2 : 1;
        }
      }
      const key = fileKey(r.mode, r.puzzle); const record = s.collection[key];
      if (r.first && medal) {
        award(s, r, `mc__${key}__v1`,
            (r.mode === "mystery" ? [0, 2, 3, 4, 6] : [0, 3, 5, 8, 12])[medal], time);
      }
      const result = {medal, score: r.score, found: r.found, hints: r.hints, optionalHints: r.optionalHints,
        moves: r.path.length, wrong: r.wrong, undoUsed: r.undoUsed, at: time};
      if (r.first) record.firstResult = result;
      record.last = result; record.lastAt = time; record.bestMedal = Math.max(record.bestMedal || 0, medal);
      record.bestScore = Math.max(record.bestScore || 0, r.score);
      record.solvedCount = (record.solvedCount || 0) + (r.found ? 1 : 0);
      if (r.found && r.mode === "mastermind" && (!record.bestMoves || r.path.length < record.bestMoves)) {
        record.bestMoves = r.path.length; record.route = r.path;
      }
      if (r.mode === "mystery") s.streak = r.found ? s.streak + 1 : 0;
    }
    r.result = {medal, coins: r.earned, xp: r.earned * 2, practice: r.mode !== "blitz" && !r.first, score: r.score};
  }
  function expire(s, time) {
    for (const id of Object.values(s.active)) {
      const r = runOf(s.sessions[id]); if (!r || r.finished) continue;
      const deadline = r.mode === "blitz" ? Math.min(r.endAt, r.hardEndAt) : r.expiresAt;
      if (time >= deadline) {
        finish(s, r, deadline); s.sessions[id] = r;
      }
    }
  }
  function applyPolicy(s, e, policy, time) {
    const disabled = new Set(policy.disabledFiles || []);
    for (const id of Object.values(s.active)) {
      const r = runOf(s.sessions[id]);
      if (!r || r.finished || !disabled.has(fileKey(r.mode, r.puzzle))) continue;
      if (r.mode === "blitz") finish(s, r, time);
      else r.result = {medal: 0, coins: 0, xp: 0, practice: true, score: r.score};
      r.finished = true; r.voided = true;
      r.feedback = "Veri düzeltmesi nedeniyle dosya kapandı. Harcanan enerji telafi edildi.";
      if (r.energyCharged) s.energyCredits++;
      const key = fileKey(r.mode, r.puzzle);
      if (s.collection[key]?.firstSession === r.id && !s.collection[key].last) delete s.collection[key];
      s.sessions[id] = r;
    }
    const refund = Math.min(s.energyCredits, Math.max(0, energy.policy.capacity - e.energy.balance));
    e.energy.balance += refund; s.energyCredits -= refund;
  }
  function setupChain(r, p, c) {
    const clubs = new Map(c.clubs.map((x) => [x.id, x]));
    r.puzzle = p; r.start = clubs.get(p.start); r.target = clubs.get(p.target);
    r.path = []; r.maxMoves = Math.min(p.par + 3, 8); r.bridgeHint = null; r.deadEnd = false;
  }
  async function status(uid, input) {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
    const policy = await getPolicy();
    await change(uid, (s, e, time) => {
      applyPolicy(s, e, policy, time); expire(s, time);
    }); await settle(uid);
    const s = await read(uid); const r = runOf(s.sessions[s.active[input.mode]]);
    const e = normalize((await db.ref("economyState/" + uid).get()).val());
    return {version: catalog.version, quality: catalog.quality, session: view(r, now()), linked: await isLinked(uid),
      coins: e.balances.coins, collection: Object.values(s.collection).filter((x) => !!x.last &&
        (input.mode === "mystery" ? x.mode === "mystery" : x.mode === "mastermind") &&
        !(r && !r.finished && r.mode === "mystery" && x.id === r.puzzle.id)),
      pendingCoins: Object.values(s.pending).reduce((n, x) => n + x.coins, 0) +
        Object.values(s.payments).filter((x) => !x.paid).reduce((n, x) => n + x.coins, 0),
      sprintBest: s.sprintBest, sprintToday: s.sprintDays[dayKey(now())] || {tier: 0, chains: 0, score: 0},
      inventory: boosts.map((id) => ({id, quantity: e.inventory[id]?.quantity || 0}))};
  }
  async function start(uid, input) {
    check(input); if (!validId(input.requestId)) fail("invalid-argument", "Geçersiz istek.");
    // Immutable version archive keeps active paths, PAR and hints stable after deploy.
    await db.ref(`mysteryChainCatalogs/${catalog.version}`).transaction((raw) => raw || catalog);
    const policy = await getPolicy();
    const seed = random(); const fingerprint = hash(JSON.stringify([input.mode, input.target || null]));
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    const charge = rollout.enabled === true && parseInt(hash(uid).slice(0, 8), 16) % 100 < rollout.percent &&
      (rollout.sessionModes || []).includes(input.mode === "mystery" ? "mystery" : "chain");
    const e = await change(uid, (s, e, time) => {
      applyPolicy(s, e, policy, time);
      expire(s, time);
      if (s.starts[input.requestId]) {
        if (s.starts[input.requestId] !== fingerprint) fail("invalid-argument", "İstek başka oyuna ait.");
        if (!s.sessions[input.requestId]) fail("failed-precondition", "Eski oturum sona erdi.");
        return;
      }
      const old = runOf(s.sessions[s.active[input.mode]]);
      if (old && !old.finished) fail("already-exists", "Kayıtlı oyununa devam et.");
      let candidates = pool(catalog, input.mode)
          .filter((p) => !(policy.disabledFiles || []).includes(fileKey(input.mode, p)));
      if (input.target) {
        if (input.mode === "blitz" ||
          !s.collection[fileKey(input.mode, {id: input.target, playerId: input.target})]?.last) {
          fail("permission-denied", "Önce arşive ekle.");
        }
        candidates = candidates.filter((p) => p.id === input.target);
      } else if (input.mode !== "blitz") {
        const unseen = candidates.filter((p) => !s.collection[fileKey(input.mode, p)]);
        if (unseen.length) candidates = unseen;
      }
      if (!candidates.length) fail("failed-precondition", "Doğrulanmış dosya bulunamadı.");
      const p = candidates[parseInt(hash(seed).slice(0, 8), 16) % candidates.length];
      if (charge) {
        if (e.energy.balance - energy.held(e.energy) < 1) {
          fail("resource-exhausted", "Yeni oyun için 1 enerji gerekli.");
        }
        if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = time;
        e.energy.balance--;
      }
      applyPolicy(s, e, policy, time);
      const key = fileKey(input.mode, p); const first = !s.collection[key];
      const r = {id: input.requestId, mode: input.mode, puzzle: p, first, graphVersion: catalog.version,
        startedAt: time, expiresAt: time + energy.policy.resumeMs, endAt: time + 60000, hardEndAt: time + 180000,
        revision: 0, finished: false, found: false, wrong: 0, earned: 0, score: 0, chains: 0, streak: 0,
        bestStreak: 0, skipped: 0, undoUsed: false, energyCharged: charge, optionalHints: 0,
        freeUsed: false, adCredits: 0, adGranted: 0, hints: [], guesses: [], actions: {},
        adReceipts: {}, path: [], routes: []};
      if (input.mode === "mystery") r.player = playerView(players.get(p.playerId)); else setupChain(r, p, catalog);
      if (input.mode !== "blitz") {
        s.collection[key] ||= {id: p.id, mode: input.mode, firstAt: time,
          graphVersion: catalog.version, firstSession: r.id, player: r.player || null,
          start: r.start || null, target: r.target || null, par: p.par || null, bestMedal: 0};
      }
      s.sessions[r.id] = r; s.active[input.mode] = r.id; s.starts[r.id] = fingerprint;
      for (const [id, old] of Object.entries(s.sessions)) {
        if (old.expiresAt < time && !Object.values(s.active).includes(id)) delete s.sessions[id];
      }
    });
    await settle(uid);
    return {version: catalog.version, session: view(e.mysteryChain.sessions[input.requestId], now())};
  }
  function nextHint(r, graph, c) {
    if (r.mode === "blitz" || r.optionalHints >= 3) return null;
    if (r.mode === "mystery") return r.puzzle.hints[[0, 3, 4][r.optionalHints]];
    const path = remaining(graph, r); if (!path?.length) return null;
    const next = path[0];
    const id = `${r.path.map((x) => x.clubId).join("_")}__${next.playerId}__${next.clubId}`;
    if (r.hints.some((h) => h.id === id)) return null;
    const player = c.graph.find((p) => p.id === next.playerId).player;
    const club = c.clubs.find((x) => x.id === next.clubId);
    return {id, playerId: next.playerId, clubId: next.clubId,
      text: `Bir sonraki geçerli köprü: ${player.name} → ${club.name}`};
  }
  async function act(uid, input) {
    check(input);
    if (!validId(input.requestId) || !validId(input.sessionId)) fail("invalid-argument", "Geçersiz işlem.");
    const prior = runOf((await read(uid)).sessions[input.sessionId]);
    if (!prior || prior.mode !== input.mode) fail("not-found", "Oturum bulunamadı.");
    const policy = await getPolicy();
    const c = await pinned(prior.graphVersion); const graph = graphOf(c);
    const clubs = new Map(c.clubs.map((x) => [x.id, x]));
    const e = await change(uid, (s, e, time) => {
      applyPolicy(s, e, policy, time);
      const r = runOf(s.sessions[input.sessionId]);
      if (r.voided) return;
      const fingerprint = hash(JSON.stringify([input.action, input.playerId ?? null, input.clubId ?? null,
        input.boost ?? null]));
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fingerprint) fail("invalid-argument", "İstek başka işleme ait.");
        return;
      }
      if (r.finished) fail("failed-precondition", "Dosya tamamlandı.");
      const end = r.mode === "blitz" ? Math.min(r.endAt, r.hardEndAt) : r.expiresAt;
      if (time >= end) {
        finish(s, r, end); r.actions[input.requestId] = fingerprint; r.revision++; s.sessions[r.id] = r; return;
      }
      if (input.revision !== r.revision) fail("aborted", "Oyun başka cihazda değişti. Yenile.");
      if (input.action === "guess" && r.mode === "mystery") {
        const p = players.get(input.playerId);
        if (!p) fail("invalid-argument", "Listeden geçerli bir futbolcu seç. Hakkın azalmadı.");
        if (r.guesses.includes(p.id)) fail("already-exists", "Bu futbolcuyu zaten denedin; hakkın azalmadı.");
        r.guesses.push(p.id);
        if (p.id === r.puzzle.playerId) {
          r.found = true; r.score = Math.max(0, 100 - r.wrong * 20 - r.optionalHints * 10);
          r.streak = s.streak + 1; finish(s, r, time);
        } else {
          r.wrong++; r.feedback = "Yanlış futbolcu; yeni bilgi açıldı.";
          if (r.wrong < 3) r.hints.push({...r.puzzle.hints[r.wrong], automatic: true});
          else finish(s, r, time);
        }
      } else if (input.action === "move" && r.mode !== "mystery") {
        if (r.path.length >= r.maxMoves) fail("failed-precondition", "Hamle sınırı doldu. Geri al veya bitir.");
        if (!validMove(graph, r, input.playerId, input.clubId)) {
          fail("invalid-argument", "Geçersiz köprü veya tekrar eden futbolcu/kulüp.");
        }
        r.path.push({playerId: input.playerId, clubId: input.clubId,
          player: playerView(c.graph.find((p) => p.id === input.playerId).player), club: clubs.get(input.clubId)});
        r.bridgeHint = null;
        if (input.clubId === r.puzzle.target) {
          if (r.mode === "mastermind") {
            r.found = true;
            r.score = r.path.length === r.puzzle.par ? 100 : r.path.length === r.puzzle.par + 1 ? 70 : 40;
            finish(s, r, time);
          } else {
            r.chains++; r.streak++; r.bestStreak = Math.max(r.bestStreak, r.streak);
            r.score += 100 + Math.min(50, r.streak * 10);
            r.routes.push({pair: r.puzzle.id, par: r.puzzle.par, route: r.path});
            r.endAt = Math.min(r.endAt + 5000, time + 75000, r.hardEndAt);
            const valid = c.sprint.filter((p) => !(policy.disabledFiles || []).includes(fileKey("blitz", p)));
            const candidates = valid.filter((p) => !r.routes.some((x) => x.pair === p.id) && p.id !== r.puzzle.id);
            const choices = candidates.length ? candidates : valid;
            if (!choices.length) {
              finish(s, r, time); s.sessions[r.id] = r; return;
            }
            const next = choices[parseInt(hash(r.id + r.chains).slice(0, 8), 16) % choices.length];
            setupChain(r, next, c); r.feedback = "Zincir tamamlandı · +5 saniye";
          }
        } else {
          r.deadEnd = !remaining(graph, r);
          r.feedback = r.deadEnd ?
             "Bu rotadan kalan hamlelerle hedefe ulaşılamıyor. Geri alabilirsin." : "Geçerli köprü.";
        }
      } else if (input.action === "undo" && r.mode !== "mystery") {
        if (!r.path.length) fail("failed-precondition", "Geri alınacak hamle yok.");
        r.path.pop(); r.undoUsed = true; r.bridgeHint = null; r.deadEnd = !remaining(graph, r);
      } else if (input.action === "hint") {
        const hint = nextHint(r, graph, c);
        if (!hint) fail("failed-precondition", "Yeni geçerli ipucu yok. Geri al veya oyuna devam et.");
        if (input.boost) {
          const item = e.inventory[input.boost];
          if (!boosts.includes(input.boost) || !item || item.quantity < 1) {
            fail("resource-exhausted", "Destek stokta yok.");
          }
          item.quantity--; e.storeUses[`mc__${r.id}__${r.optionalHints}`] = {itemId: input.boost, usedAt: time};
        } else if (!r.freeUsed) r.freeUsed = true;
        else if (r.adCredits > 0) r.adCredits--;
        else fail("resource-exhausted", "Doğrulanmış reklam veya destek gerekli.");
        r.optionalHints++; r.hints.push(hint); if (r.mode === "mastermind") r.bridgeHint = hint;
      } else if (input.action === "skip") {
        if (r.mode !== "blitz") finish(s, r, time);
        else {
          if (r.skipped) fail("resource-exhausted", "Sprintte yalnızca bir pas hakkın var.");
          r.skipped = 1; r.streak = 0; r.endAt = Math.max(time, r.endAt - 10000);
          if (time >= r.endAt) finish(s, r, r.endAt);
          else {
            const next = c.sprint.find((p) => p.id !== r.puzzle.id &&
              !(policy.disabledFiles || []).includes(fileKey("blitz", p)));
            if (next) setupChain(r, next, c); else finish(s, r, time);
          }
        }
      } else if (input.action === "finish" && r.mode === "blitz") finish(s, r, time);
      else fail("invalid-argument", "Geçersiz işlem.");
      r.actions[input.requestId] = fingerprint; r.revision++; s.sessions[r.id] = r;
    });
    await settle(uid);
    const wallet = normalize((await db.ref("economyState/" + uid).get()).val());
    return {session: view(e.mysteryChain.sessions[input.sessionId], now()), coins: wallet.balances.coins,
      inventory: boosts.map((id) => ({id, quantity: wallet.inventory[id]?.quantity || 0}))};
  }
  async function search(uid, input) {
    check(input); const q = norm(input.query).slice(0, 80);
    if (q.length < 2 && !input.playerId) return {results: []};
    if (input.mode === "mystery") {
      return {results: [...players.values()].filter((p) => q.split(" ").every((t) => p.search.includes(t)))
          .sort((a, b) => Number(norm(b.name) === q) - Number(norm(a.name) === q) || a.rank - b.rank)
          .slice(0, 30).map(playerView)};
    }
    const r = runOf((await read(uid)).sessions[input.sessionId]);
    if (!r || r.mode !== input.mode || r.finished) fail("not-found", "Aktif zincir bulunamadı.");
    const c = await pinned(r.graphVersion); const graph = graphOf(c);
    if (input.playerId) return {clubs: c.clubs.filter((x) => validMove(graph, r, input.playerId, x.id))};
    const current = r.path.length ? r.path[r.path.length - 1].clubId : r.puzzle.start;
    return {results: (graph.byClub.get(current) || []).filter((id) => !r.path.some((x) => x.playerId === id))
        .map((id) => c.graph.find((p) => p.id === id).player)
        .filter((p) => q.split(" ").every((t) => p.search.includes(t)))
        .sort((a, b) => a.rank - b.rank).slice(0, 30).map(playerView)};
  }
  async function prepareHint(uid, placement, context) {
    const r = runOf((await read(uid)).sessions[context?.sessionId]);
    if (!r || (r.mode === "mystery" ? "mystery_hint" : "chain_hint") !== placement ||
        r.finished || r.mode === "blitz" || r.expiresAt <= now() || r.adGranted >= 2 ||
        r.optionalHints + r.adCredits + (r.freeUsed ? 0 : 1) >= 3) {
      fail("failed-precondition", "Reklamlı ipucu hakkı yok.");
    }
    const c = await pinned(r.graphVersion);
    if (!nextHint(r, graphOf(c), c)) fail("failed-precondition", "Bu konumda yeni köprü ipucu yok.");
    return {amount: 0, claimKey: `mc_hint_${r.id}_${r.adGranted}`,
      context: {sessionId: r.id, mode: r.mode, credit: r.adGranted}};
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, _, time) => {
      const r = runOf(s.sessions[receipt.context?.sessionId]);
      if (!r || r.mode !== receipt.context?.mode || r.mode === "blitz" || r.finished || r.expiresAt <= time ||
          r.adReceipts[receipt.id] || r.adGranted >= 2 || r.optionalHints + r.adCredits + (r.freeUsed ? 0 : 1) >= 3 ||
          r.adGranted !== receipt.context.credit) return;
      r.adGranted++; r.adCredits++; r.adReceipts[receipt.id] = true; s.sessions[r.id] = r;
    });
  }
  return {status, start, act, search, settle, prepareHint, settleHint};
}
module.exports = {createService, catalog, view};
