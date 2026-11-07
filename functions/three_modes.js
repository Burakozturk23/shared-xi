"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const H = require("./hints");
const {RewardError, dayKey} = require("./rewarded_ads");
const energy = require("./energy");
const catalog = require("./config/three_modes_catalog.json");
const MODES = new Set(["letter11", "squad_vault"]);
const players = new Map(catalog.players.map((p) => [p.id, p]));
const clubs = new Map(catalog.clubs.map((p) => [p.id, p]));
const targets = {letter11: catalog.letters};
const idOk = (id) => typeof id === "string" && /^[a-f0-9]{32}$/.test(id);
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (v) => crypto.createHash("sha256").update(v).digest("hex");
const norm = (v) => String(v || "").toLowerCase().replaceAll("ı", "i").replaceAll("ß", "ss")
    .replaceAll("ø", "o").replaceAll("ł", "l").replaceAll("đ", "d")
    .normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
const stateOf = (raw) => {
  const s = {...raw};
  for (const key of ["sessions", "active", "collection", "daily", "claims", "pending",
    "starts"]) s[key] ||= {};
  return s;
};
// RTDB may serialize numeric-key maps as arrays with null holes.
// A hole is never a placed player or a score; normalize back to a sparse map.
const picksOf = (raw) => Object.fromEntries(Object.entries(raw || {})
    .filter(([slot, id]) => /^([0-9]|10)$/.test(slot) && Number.isSafeInteger(id) && players.has(id)));
const lineupOf = (raw) => Array.from({length: 11}, (_, i) => raw?.[i] || null);
const sessionOf = (s) => s ? {...s, picks: picksOf(s.picks), actions: s.actions || {}, hints: s.hints || [],
  guesses: s.guesses || [], revealed: s.revealed || [],
  nameHints: s.nameHints || [], adReceipts: s.adReceipts || {}} : null;
const targetOf = (s) => targets[s.mode]?.find((x) => x.id === s.target);
const puzzleOf = (s) => catalog.puzzles.find((p) => p.id === s.puzzle);
// Several V4 rows can be one club (same name and country); any of them answers.
const canonical = (id) => clubs.get(id)?.canonicalId || id;
const collectionKey = (s) => s.mode + "__" + s.target;
const indexFrom = (seed, length) => parseInt(hash(seed).slice(0, 8), 16) % length;
// Harf 11 letter rule, the same as tools/three_modes/build_catalog.py
// initials(): lower-case surname particles never count, ASCII "I" of a Turkish
// name is İ. Returns the word of the name or alias that gives the letter.
const PARTICLES = new Set(["van", "von", "de", "da", "di", "do", "dos", "das", "del", "della", "der", "den", "du",
  "la", "le", "el", "al", "bin", "ben", "ten", "ter", "y", "e", "zu", "of", "af"]);
function initialOf(token, turkish) {
  const ch = token[0];
  if (ch === "i" || ch === "İ" || ch === "I" && turkish) return "İ";
  if (ch === "I" || ch === "ı") return "I";
  const up = ch.toUpperCase();
  return "ÇĞÖŞÜ".includes(up) ? up : norm(ch).toUpperCase().slice(0, 1);
}
function letterWord(p, letter) {
  const turkish = ["turkey", "turkiye"].includes(norm(p.country));
  for (const name of [p.name, ...(p.aliases || [])]) {
    for (const token of String(name).trim().split(/[\s-]+/)) {
      if (token && !PARTICLES.has(token) && initialOf(token, turkish) === letter) return token;
    }
  }
  return null;
}
const positionLabel = {GK: "kaleci", DEF: "defans", MID: "orta saha", FWD: "forvet"};
const publicPlayer = (p) => ({id: p.id, name: p.name, country: p.country, position: p.position});
function stars(s) {
  if (s.finished && !s.won) return 0;
  return Math.max(0, 5 - s.wrong - s.penalty);
}
function score(s) {
  if (s.mode === "squad_vault") return s.won ? stars(s) : 0;
  return Object.keys(s.picks).length;
}
function mastery(s) {
  return score(s) === 11 && s.hints.length === 0 && s.wrong <= 3;
}
function eligible(s, position) {
  const target = targetOf(s);
  const used = new Set(Object.values(s.picks));
  return catalog.players.filter((p) => p.position === position && !used.has(p.id) &&
    p.letters.includes(target.letter));
}
// İpucu v2 menus (hints/squad.js).
const adapter = H.register(require("./hints/squad").three({catalog, clubs, players, puzzleOf, eligible, letterWord,
  targetOf}));
function sessionView(raw) {
  const s = sessionOf(raw);
  if (!s) return null;
  const target = targetOf(s);
  const v = {id: s.id, mode: s.mode, entry: s.entry, formation: s.formation,
    formations: target?.formations || [s.formation], revision: s.revision, finished: s.finished,
    dailyOfficial: s.dailyOfficial, expiresAt: s.expiresAt, day: s.day,
    wrong: s.wrong, hints: s.hints, freeHint: !B.paid(s) && !H.active(s) && !s.freeUsed, support: B.view(s),
    hintMenu: H.view(s, adapter), adCredits: s.adCredits,
    adRemaining: Math.max(0, 2 - s.adGranted), feedback: s.feedback || "", energyCharged: s.energyCharged,
    result: s.result || null};
  if (s.mode !== "squad_vault") {
    v.targetId = s.target; v.title = `${target.letter} harfi`; v.score = score(s);
    v.slots = catalog.formations[s.formation].map((pos, slot) => {
      const p = players.get(s.picks[slot]);
      return {slot, position: pos, player: p ? publicPlayer(p) : null};
    });
  } else {
    const puzzle = puzzleOf(s); const club = clubs.get(puzzle.clubId);
    v.title = s.finished ? club.name : "Gizli kulüp";
    v.stars = stars(s); v.remaining = Math.max(0, 5 - s.guesses.length);
    v.difficulty = puzzle.difficulty || null; v.won = s.won === true;
    v.league = s.leagueShown || s.finished ? club.league : null;
    v.club = s.finished ? {id: club.id, name: club.name, badgeKey: club.badgeKey} : null;
    v.slots = puzzle.players.map((id, slot) => {
      const p = players.get(id);
      return {slot, position: p.position, country: s.finished || s.revealed.includes(slot) ? p.country : null,
        player: s.finished || s.nameHints.includes(slot) ? publicPlayer(p) : null};
    });
    v.historyNote = "Farklı dönemlerde bu kulüpte oynamış futbolcular; aynı sezonun ilk 11'i değildir.";
  }
  return v;
}

function createService({db, normalize, project, grantCoins, grantXp, isLinked, getRollout,
  now = Date.now, random = () => crypto.randomBytes(16).toString("hex")}) {
  async function change(uid, fn) {
    let error;
    const time = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null;
      const state = normalize(structuredClone(raw)); state.threeModes = stateOf(state.threeModes);
      state.energy = energy.refreshed(state.energy, time);
      try {
        for (const r of Object.values(state.threeModes.sessions)) {
          B.recoverUnused(state, r, time,
              () => (r.hints?.length || 0) < 3);
        }
        fn(state.threeModes, state, time);
        for (const r of Object.values(state.threeModes.sessions)) {
          H.recoverUnused(state, sessionOf(r), time);
          B.recoverUnused(state, r, time,
              () => (r.hints?.length || 0) < 3);
        }
        return state;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "İşlem tamamlanmadı; aynı isteği yeniden gönder.");
    const state = normalize(tx.snapshot.val()); state.threeModes = stateOf(state.threeModes);
    await project(db, uid, state);
    return state;
  }
  function check(input) {
    if (input.version !== catalog.version || !MODES.has(input.mode)) {
      fail("failed-precondition", "Oyun verisi güncellendi. Modu yeniden aç.");
    }
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const state = stateOf((await db.ref("economyState/" + uid + "/threeModes").get()).val());
    for (const [key, value] of Object.entries(state.pending)) {
      if (value.coins) await grantCoins(uid, key, "three_modes", value.target, value.coins, catalog.version);
      if (value.xp) await grantXp(uid, key, value.xp);
      await change(uid, (s) => {
        delete s.pending[key];
      });
    }
  }
  async function read(uid) {
    return stateOf((await db.ref("economyState/" + uid + "/threeModes").get()).val());
  }
  async function daily(mode) {
    const day = dayKey(now()); const key = mode + "__" + day;
    let fixed;
    if (mode === "squad_vault") {
      // Today's vault: the same puzzle for everyone.
      const puzzle = catalog.puzzles[indexFrom(key + catalog.version, catalog.puzzles.length)];
      fixed = {day, target: puzzle.id, formation: puzzle.formation, version: catalog.version};
    } else {
      // Hard letters (Ş, İ, Ç…) are too narrow for a shared daily target.
      const pool = targets[mode]?.filter((x) => x.difficulty !== "hard");
      if (!pool) fail("invalid-argument", "Bu modda günlük oyun yok.");
      const target = pool[indexFrom(key + catalog.version, pool.length)];
      const form = target.formations[indexFrom(key, target.formations.length)];
      fixed = {day, target: target.id, formation: form, version: catalog.version};
    }
    const tx = await db.ref("threeModeDaily/" + key).transaction((raw) => raw || fixed);
    const value = tx.snapshot.val();
    if (value.version !== catalog.version) fail("failed-precondition", "Günlük veri güncellemesi yarın açılacak.");
    return value;
  }
  async function status(uid, input = {}) {
    if (!MODES.has(input.mode)) fail("invalid-argument", "Geçersiz mod.");
    await settle(uid);
    const s = await read(uid); const linked = await isLinked(uid);
    const active = sessionOf(s.sessions[s.active[input.mode]]);
    let dailyGame = null; let dailyUnavailable = false;
    try {
      dailyGame = await daily(input.mode);
    } catch (error) {
      if (error.code !== "failed-precondition") throw error;
      // A frozen previous-version daily must not block roulette or archives.
      dailyUnavailable = true;
    }
    // Today's vault names no club before it is opened.
    if (dailyGame && input.mode === "squad_vault") dailyGame = {day: dailyGame.day, formation: dailyGame.formation};
    const current = active && active.version === catalog.version && !active.finished && active.expiresAt > now() &&
      (active.entry !== "daily" || active.day === dayKey(now())) ? sessionView(active) : null;
    const exposeRecord = (r) => r ? {...r,
      bestLineup: lineupOf(r.bestLineup).map((id) => players.has(id) ? publicPlayer(players.get(id)) : null),
      lastLineup: lineupOf(r.lastLineup).map((id) => players.has(id) ? publicPlayer(players.get(id)) : null)} : null;
    const list = input.mode === "squad_vault" ? catalog.vaultClubs.map((id) => {
      const c = clubs.get(id); const record = s.collection[`squad_vault__${id}`];
      return {id: String(id), name: record?.solved ? c.name : "Kilitli kasa", league: c.league,
        badgeKey: record?.solved ? c.badgeKey : null, record: exposeRecord(record)};
    }) : targets[input.mode].map((t) => ({id: t.id, name: t.letter, letter: t.letter,
      formations: t.formations, difficulty: t.difficulty, count: t.count,
      record: exposeRecord(s.collection[`${input.mode}__${t.id}`])}));
    return {ok: true, version: catalog.version, mode: input.mode, entries: list, session: current,
      daily: dailyGame, dailyUnavailable, dailyUsed: !!s.daily[`${input.mode}__${dayKey(now())}`], linked,
      pendingRewards: Object.keys(s.pending).length, leagueSnapshot: catalog.leagueSnapshot,
      ...(input.mode === "letter11" ? {passport: (catalog.policy.passport || []).map((m) =>
        ({...m, at: m.at === "all" ? catalog.letters.length : m.at,
          claimed: !!s.claims[`three__passport__${m.at}`]}))} : {})};
  }
  async function start(uid, input) {
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    check(input);
    if (!idOk(input.requestId) || !["random", "archive", "daily", "league"].includes(input.entry)) {
      fail("invalid-argument", "Geçersiz oyun isteği.");
    }
    if (input.entry === "league" && input.mode !== "squad_vault") fail("invalid-argument", "Geçersiz lig oyunu.");
    const fixed = input.entry === "daily" ? await daily(input.mode) : null;
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    const charged = energy.inRollout(rollout, uid) &&
      (rollout.sessionModes || []).includes(input.mode);
    const seed = random();
    const state = await change(uid, (s, e, time) => {
      const prior = sessionOf(s.sessions[input.requestId]);
      if (prior) {
        if (prior.startFingerprint !== hash(JSON.stringify([input.mode, input.entry, input.target || null,
          input.formation || null, input.difficulty || null, input.league || null]))) {
          fail("invalid-argument", "İstek başka oyuna ait.");
        }
        return;
      }
      if (s.starts[input.requestId]) fail("failed-precondition", "Bu eski oyun isteğinin devam süresi doldu.");
      const active = sessionOf(s.sessions[s.active[input.mode]]);
      if (active && active.version === catalog.version && !active.finished && active.expiresAt > time &&
          (active.entry !== "daily" || active.day === dayKey(time))) {
        fail("already-exists", "Devam eden oyunu tamamla veya erken bitir.");
      }
      let target; let puzzle; let formation = input.formation || "433";
      if (input.mode === "squad_vault") {
        let pool = catalog.puzzles.filter((p) =>
          input.entry !== "league" || clubs.get(p.clubId).league === input.league);
        if (fixed) pool = pool.filter((p) => p.id === fixed.target);
        if (input.entry === "archive") {
          if (!s.collection[`squad_vault__${input.target}`]?.solved) fail("failed-precondition", "Önce bu kasayı çöz.");
          pool = pool.filter((p) => String(p.clubId) === input.target);
        }
        if (!fixed && input.entry !== "archive") {
          if (input.difficulty) {
            const level = pool.filter((p) => p.difficulty === input.difficulty);
            if (level.length) pool = level;
          }
          // Unsolved clubs first: a solved club pays nothing again, so it
          // should not keep costing energy while new ones remain.
          const open = pool.filter((p) => !s.collection[`squad_vault__${p.clubId}`]?.solved);
          if (open.length) pool = open;
          const recent = Object.values(s.sessions).filter((x) => x.mode === "squad_vault")
              .sort((a, b) => b.startedAt - a.startedAt).slice(0, 5).map((x) => x.target);
          const fresh = pool.filter((p) => !recent.includes(String(p.clubId)));
          if (fresh.length) pool = fresh;
        }
        if (!pool.length) fail("failed-precondition", "Bu ligde oynanabilir kasa yok.");
        puzzle = pool[indexFrom(seed, pool.length)]; target = String(puzzle.clubId); formation = puzzle.formation;
      } else {
        let pool = targets[input.mode];
        if (input.entry === "random" && input.difficulty) pool = pool.filter((x) => x.difficulty === input.difficulty);
        if (input.entry === "random" && input.formation) {
          pool = pool.filter((x) => x.formations.includes(input.formation));
        }
        if (input.entry === "random") {
          const open = pool.filter((x) => !s.collection[`${input.mode}__${x.id}`]?.mastery);
          if (open.length) pool = open;
          // Without a chosen difficulty a hard letter is a quarter as likely.
          if (!input.difficulty) pool = pool.flatMap((x) => x.difficulty === "hard" ? [x] : [x, x, x, x]);
        }
        const selected = fixed ? pool.find((x) => x.id === fixed.target) : input.entry === "archive" ?
          pool.find((x) => x.id === input.target) : pool[indexFrom(seed, pool.length)];
        if (!selected) fail("failed-precondition", "Oynanabilir içerik bulunamadı.");
        target = selected.id;
        formation = fixed?.formation || (selected.formations.includes(formation) ? formation : selected.formations[0]);
      }
      if (!catalog.formations[formation]) fail("invalid-argument", "Formasyon bulunamadı.");
      const day = dayKey(time); const key = input.mode + "__" + day;
      const official = input.entry === "daily" && !s.daily[key];
      if (charged && !official) {
        if (e.energy.balance - energy.held(e.energy) < 1) {
          fail("resource-exhausted", "Enerjin bitti. Günlük ilk oyun ücretsiz.");
        }
        if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = time;
        e.energy.balance--;
      }
      // Daily ownership, content and energy charge commit together across devices.
      if (official) s.daily[key] = {sessionId: input.requestId, day, target, formation};
      const session = {startFingerprint: hash(JSON.stringify([input.mode, input.entry, input.target || null,
        input.formation || null, input.difficulty || null, input.league || null])),
      id: input.requestId, mode: input.mode, entry: input.entry, target, formation,
      difficulty: input.difficulty || "easy", day, dailyOfficial: official, startedAt: time,
      expiresAt: Math.min(time + energy.policy.resumeMs, input.entry === "daily" ?
          Date.parse(day + "T00:00:00+03:00") + 86400000 : Number.MAX_SAFE_INTEGER),
      version: catalog.version, energyCharged: charged && !official, revision: 0,
      picks: {}, actions: {}, guesses: [], hints: [], wrong: 0, freeUsed: false, adGranted: 0,
      adCredits: 0, adReceipts: {}, finished: false,
      penalty: input.entry === "league" ? catalog.policy.leagueKnowledgePenalty : 0};
      if (puzzle) {
        Object.assign(session, {puzzle: puzzle.id, revealed: puzzle.initial, nameHints: [],
          leagueShown: input.entry === "league"});
      }
      H.pinAny(session, boostPolicy, e, time);
      s.sessions[session.id] = session; s.active[input.mode] = session.id;
      s.starts[session.id] = true;
      // Collections/receipts are permanent; expired session bodies are bounded.
      const obsolete = Object.values(s.sessions).filter((x) => x.expiresAt < time)
          .sort((a, b) => b.startedAt - a.startedAt).slice(20);
      for (const x of obsolete) if (!(x.adCredits > 0) && !H.pending(x)) delete s.sessions[x.id];
    });
    return {ok: true, version: catalog.version, session: sessionView(state.threeModes.sessions[input.requestId])};
  }
  function reward(s, key, value) {
    if (s.claims[key]) return false;
    s.claims[key] = {coins: value.coins, xp: value.xp};
    if (value.coins || value.xp) s.pending[key] = value;
    return true;
  }
  function finish(s, run, time) {
    run.finished = true; run.finishedAt = time;
    const value = score(run); const master = run.mode !== "squad_vault" && mastery(run);
    const key = collectionKey(run); const previous = s.collection[key] || {};
    const achieved = run.mode === "squad_vault" ? catalog.policy.vault : catalog.policy.medals;
    let coins = 0; let xp = 0; const medals = [];
    for (let i = 0; i < achieved.length; i++) {
      const tier = achieved[i];
      if (value < tier.at || tier.mastery && !master) continue;
      if (reward(s, `three__${key}__${i}`, {coins: tier.coins, xp: tier.xp, target: key})) {
        coins += tier.coins; xp += tier.xp; medals.push(i + 1);
      }
    }
    const lineup = run.mode === "squad_vault" ? puzzleOf(run).players :
      catalog.formations[run.formation].map((_, i) => run.picks[i] || null);
    const record = {...previous, best: run.assisted ? previous.best || 0 : Math.max(previous.best || 0, value),
      bestAssisted: run.assisted ? Math.max(previous.bestAssisted || 0, value) : previous.bestAssisted || 0,
      mastery: !!previous.mastery || master,
      bestFormation: !run.assisted && value > (previous.best || 0) || master && !previous.mastery ? run.formation :
        previous.bestFormation || (run.assisted ? "" : run.formation),
      lastLineup: lineup, lastFormation: run.formation, lastAt: time,
      solved: !!previous.solved || (run.mode === "squad_vault" ? !!run.won : value > 0),
      bestLineup: !run.assisted && value > (previous.best || 0) || master && !previous.mastery ?
        lineup : previous.bestLineup || (run.assisted ? [] : lineup)};
    s.collection[key] = record;
    if (run.mode === "squad_vault" && Object.entries(s.collection)
        .filter(([k, r]) => k.startsWith("squad_vault__") && r.best >= 1).length >= 5) {
      const b = catalog.policy.archiveBonus;
      if (reward(s, "three__vault_archive_5", {...b, target: "squad_vault"})) {
        coins += b.coins; xp += b.xp;
      }
    }
    // Harf Pasaportu: letters completed with all eleven pay at fixed milestones.
    if (run.mode === "letter11" && value === 11) {
      const done = Object.entries(s.collection).filter(([k, r]) => k.startsWith("letter11__") && r.best >= 11).length;
      for (const m of catalog.policy.passport || []) {
        const at = m.at === "all" ? catalog.letters.length : m.at;
        if (done >= at && reward(s, `three__passport__${m.at}`, {coins: m.coins, xp: m.xp, target: "letter11"})) {
          coins += m.coins; xp += m.xp; run.passport = m.at;
        }
      }
    }
    // Daily bonus: a won vault (1+ star) or a letter XI of 8+ players (7 on a medium letter).
    const dailyAt = catalog.policy.letterDailyAt?.[targetOf(run)?.difficulty] ?? 8;
    if (run.dailyOfficial && (run.mode === "squad_vault" ? run.won && value >= 1 : value >= dailyAt)) {
      const b = catalog.policy.daily[run.mode];
      if (b && reward(s, `three__daily__${run.mode}__${run.day}`, {...b, target: run.mode})) {
        coins += b.coins; xp += b.xp;
      }
    }
    if (run.dailyOfficial) {
      s.daily[`${run.mode}__${run.day}`].result = {score: value, assisted: run.assisted === true,
        mastery: master, wrong: run.wrong};
    }
    run.result = {score: value, assisted: run.assisted === true, mastery: master, newMedals: medals, coins, xp,
      ...(run.passport ? {passport: run.passport} : {})};
  }
  async function act(uid, input) {
    check(input);
    if (!idOk(input.sessionId) || !idOk(input.requestId)) fail("invalid-argument", "Geçersiz işlem kimliği.");
    const state = await change(uid, (s, e, time) => {
      const run = sessionOf(s.sessions[input.sessionId]);
      if (!run || run.mode !== input.mode || run.version !== catalog.version) fail("not-found", "Oturum bulunamadı.");
      const fingerprint = hash(JSON.stringify([input.action, input.playerId ?? null, input.clubId ?? null,
        input.slot ?? null, input.formation ?? null, input.hint ?? null, input.confirmReset ?? null,
        ...B.paymentFingerprint(input), input.itemId ?? null]));
      if (run.actions[input.requestId]) {
        if (run.actions[input.requestId] !== fingerprint) fail("invalid-argument", "İşlem kimliği başka cevaba ait.");
        return;
      }
      if (run.finished || run.expiresAt <= time) fail("failed-precondition", "Oyun sona erdi.");
      if (input.revision !== run.revision) fail("aborted", "Oyun diğer cihazda değişti. Yenile.");
      if (Object.keys(run.actions).length >= 300 && input.action !== "finish") {
        fail("resource-exhausted", "Oturum işlem sınırına ulaştı.");
      }
      run.feedback = "";
      const slotOk = Number.isInteger(input.slot) && input.slot >= 0 && input.slot < 11;
      if (input.action === "finish") {
        finish(s, run, time);
      } else if (input.action === "formation" && run.mode !== "squad_vault") {
        if (run.entry === "daily" || !targetOf(run).formations.includes(input.formation)) {
          fail("failed-precondition", "Bu formasyon bu oyunda kullanılamaz.");
        }
        if (Object.keys(run.picks).length && input.confirmReset !== true) {
          fail("failed-precondition", "Dolu kadroyu sıfırlamayı onayla.");
        }
        run.formation = input.formation; run.picks = {};
      } else if (input.action === "clear" && run.mode !== "squad_vault" && slotOk) {
        delete run.picks[input.slot];
      } else if (input.action === "place" && run.mode !== "squad_vault" && slotOk) {
        const p = players.get(input.playerId);
        if (!p || !p.position) fail("invalid-argument", "Oyuncu kimliği/mevkisi çözülemedi. Yanlış hakkın değişmedi.");
        if (Object.values(run.picks).includes(p.id)) fail("already-exists", "Bu futbolcu zaten kadroda.");
        const target = targetOf(run);
        const slot = catalog.formations[run.formation][input.slot];
        if (!p.letters.includes(target.letter)) {
          run.wrong++;
          run.feedback = `${p.name}: adı veya bilinen lakabı ${target.letter} ile başlamıyor.`;
        } else if (p.position !== slot) {
          run.wrong++;
          run.feedback = `${p.name} bir ${positionLabel[p.position] || "farklı mevki"} oyuncusu; ` +
            `bu yer ${positionLabel[slot]} için.`;
        } else {
          run.picks[input.slot] = p.id;
          const word = letterWord(p, target.letter);
          run.feedback = `Doğru: ${p.name}` + (word ? ` · "${word}" ${target.letter} ile başlıyor.` : "");
        }
      } else if (input.action === "guess" && run.mode === "squad_vault") {
        if (!clubs.has(input.clubId)) fail("invalid-argument", "Kulübü arama listesinden seç. Hakkın değişmedi.");
        if (run.guesses.some((g) => canonical(g) === canonical(input.clubId))) {
          fail("already-exists", "Bu kulübü zaten denedin.");
        }
        run.guesses.push(input.clubId);
        if (canonical(input.clubId) === canonical(puzzleOf(run).clubId)) {
          run.won = true; finish(s, run, time);
        } else {
          run.wrong++; run.feedback = "Bu kasa başka bir kulübe ait.";
          if (run.guesses.length >= 5) finish(s, run, time);
        }
      } else if (input.action === "hint" && H.active(run)) {
        H.use(e, run, adapter, input, time, {slot: input.slot});
      } else if (input.action === "hint") {
        if (!B.paid(run) && run.freeUsed && run.adCredits <= 0) {
          fail("resource-exhausted", "İpucu için doğrulanmış reklam hakkı gerekli.");
        }
        let text;
        if (run.mode === "squad_vault") {
          const puzzle = puzzleOf(run);
          if (input.hint === "flag") {
            const slot = puzzle.players.findIndex((_, i) => !run.revealed.includes(i));
            if (slot < 0) fail("failed-precondition", "Tüm bayraklar açık.");
            run.revealed.push(slot); text = "Bir bayrak daha açıldı.";
          } else if (input.hint === "league" && !run.leagueShown) {
            run.leagueShown = true; text = clubs.get(puzzle.clubId).league;
          } else if (input.hint === "player") {
            const slot = run.revealed.find((i) => !run.nameHints.includes(i));
            if (slot == null) fail("failed-precondition", "İsmi gizli açık bayrak yok.");
            run.nameHints.push(slot); text = players.get(puzzle.players[slot]).name;
          } else fail("failed-precondition", "Bu ipucu zaten açık veya uygun değil.");
          run.penalty += catalog.policy.hintCosts[input.hint];
        } else {
          if (!slotOk || run.picks[input.slot]) fail("invalid-argument", "Önce boş bir mevki seç.");
          const options = eligible(run, catalog.formations[run.formation][input.slot]);
          if (!options.length) fail("failed-precondition", "Bu mevki için ipucu bulunamadı.");
          // One target player per slot, so successive hints narrow the same
          // footballer instead of describing a different one each time.
          const known = (p) => (p.clubs || []).some((id) => clubs.get(id)?.league);
          const ranked = options.sort((a, b) => Number(known(b)) - Number(known(a)) || a.rank - b.rank);
          const p = ranked[0];
          if (["club", "league"].includes(input.hint) && !known(p)) {
            fail("failed-precondition", "Bu mevki için doğrulanmış kulüp ipucu yok.");
          }
          if (input.hint === "shape") {
            const word = letterWord(p, targetOf(run).letter) || "";
            text = word.length > 2 ? `"${word.slice(0, 2)}${"_".repeat(word.length - 2)}" (${word.length} harf)` : "";
          } else if (["club", "league"].includes(input.hint)) {
            const c = p.clubs.map((id) => clubs.get(id)).find((c) => c && (input.hint !== "league" || c.league));
            text = input.hint === "club" ? c.name : `${c.league} (kulübün veri sürümündeki ligi)`;
          } else if (input.hint === "country") {
            text = p.country;
          } else fail("invalid-argument", "Bu ipucu desteklenmiyor.");
          if (!text) fail("failed-precondition", "Doğrulanmış ipucu yok.");
          text = `Seçili mevkiye uygun, henüz bulunmamış bir futbolcu: ${text}`;
        }
        if (B.paid(run)) {
          if (run.hints.length >= 3) fail("resource-exhausted", "Bu oyunun üç ipucu kullanıldı.");
          const sku = run.mode === "squad_vault" && input.hint === "player" ? "boost_strong" :
            input.hint === "club" ? "boost_connection" : "boost_basic";
          B.consume(e, run, input, sku, `hint:${run.hints.length}`, {text}, time);
        } else if (!run.freeUsed) run.freeUsed = true; else run.adCredits--;
        run.hints.push({kind: input.hint, text}); run.feedback = text;
      } else fail("invalid-argument", "Geçersiz oyun işlemi.");
      run.revision++; run.actions[input.requestId] = fingerprint; s.sessions[run.id] = run;
    });
    await settle(uid);
    return {ok: true, version: catalog.version, linked: await isLinked(uid),
      session: sessionView(state.threeModes.sessions[input.sessionId])};
  }
  async function search(uid, input) {
    check(input);
    const q = norm(input.query).slice(0, 80);
    if (q.length < 2) return {ok: true, results: []};
    // Never filter by the answer, letter, selected position or club.
    const vault = input.mode === "squad_vault";
    // Clubs: only playable senior clubs with a league, the best known first.
    const list = vault ? catalog.clubs.filter((c) => c.searchable) : catalog.players;
    const tokens = q.split(" ");
    // Whole-word starts beat matches inside a word ("real" -> Real Madrid, not Villarreal).
    const starts = (p) => Number(tokens.every((t) => (" " + p.search).includes(" " + t)));
    const hits = list.filter((p) => tokens.every((t) => p.search.includes(t))).sort((a, b) =>
      Number(norm(b.name) === q) - Number(norm(a.name) === q) || starts(b) - starts(a) ||
      (vault ? (b.popularity || 0) - (a.popularity || 0) : (a.rank || 0) - (b.rank || 0)) || a.id - b.id);
    return {ok: true, results: hits.slice(0, 30).map((p) => input.mode === "squad_vault" ?
      {id: p.id, name: p.name, country: p.country, league: p.league} : publicPlayer(p))};
  }
  async function prepareHint(uid, placement, context) {
    const expected = {letter11_hint: "letter11", vault_hint: "squad_vault"}[placement];
    const s = await read(uid); const run = sessionOf(s.sessions[context?.sessionId]);
    if (H.active(run)) {
      if (!expected || run.mode !== expected || run.finished || run.expiresAt <= now()) {
        fail("failed-precondition", "Bu oyun için reklamlı ipucu hakkı yok.");
      }
      return H.adBenefit(run, context.itemId, {amount: 0, claimKey: `three_hint_${run.id}_${run.adGranted}`,
        context: {sessionId: run.id, mode: run.mode, credit: run.adGranted}});
    }
    if (!expected || !run || run.mode !== expected || run.finished || run.expiresAt <= now() || run.adGranted >= 2 ||
        B.paid(run) && run.hints.length + run.adCredits >= 3) {
      fail("failed-precondition", "Bu oyun için reklamlı ipucu hakkı yok.");
    }
    return B.adBenefit(run, {amount: 0, claimKey: `three_hint_${run.id}_${run.adGranted}`,
      context: {sessionId: run.id, mode: run.mode, credit: run.adGranted}}, context?.boostId);
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e, time) => {
      const run = sessionOf(s.sessions[receipt.context?.sessionId]);
      if (receipt.context?.hintPolicyVersion === H.VERSION) {
        const ok = run && H.active(run) && run.mode === receipt.context.mode &&
          run.adGranted === receipt.context.credit;
        if (H.recoverAd(e, run, receipt, time, ok)) {
          if (run) s.sessions[run.id] = run; return;
        }
        H.grantAd(run, receipt); s.sessions[run.id] = run; return;
      }
      // A late receipt cannot modify another run or convert into coins.
      const canApply = run && run.hints.length + run.adCredits < 3 &&
        run.adGranted < (run.boostPolicy?.daily ? 1 : 2) && run.adGranted === receipt.context.credit;
      if (B.recoverAd(e, run, receipt, time, "boost_basic", canApply)) {
        if (run) s.sessions[run.id] = run; return;
      }
      if (!run || run.mode !== receipt.context?.mode || run.finished || run.expiresAt <= now()) return;
      if (run.adReceipts[receipt.id]) return;
      if (run.adGranted >= 2 || run.adGranted !== receipt.context.credit) return;
      B.grantAd(run, receipt);
      // Watching only grants credit; mastery changes when a hint is consumed.
      s.sessions[run.id] = run;
    });
  }
  async function resume(uid, input) {
    check(input);
    const s = await read(uid); const run = sessionOf(s.sessions[input.sessionId]);
    if (!run || run.mode !== input.mode) fail("not-found", "Oturum bulunamadı.");
    if (run.version !== catalog.version || !run.finished && run.expiresAt <= now()) {
      fail("failed-precondition", "Devam süresi doldu.");
    }
    await settle(uid);
    return {ok: true, version: catalog.version, linked: await isLinked(uid), session: sessionView(run)};
  }
  return {status, start, act, search, resume, prepareHint, settleHint, settle};
}
module.exports = {createService, catalog, norm, sessionView, score, stars, mastery, letterWord};
