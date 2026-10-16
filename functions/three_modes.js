"use strict";
const crypto = require("node:crypto");
const {RewardError, dayKey} = require("./rewarded_ads");
const energy = require("./energy");
const catalog = require("./config/three_modes_catalog.json");
const MODES = new Set(["coach_xi", "letter11", "squad_vault"]);
const players = new Map(catalog.players.map((p) => [p.id, p]));
const clubs = new Map(catalog.clubs.map((p) => [p.id, p]));
const targets = {coach_xi: catalog.coaches, letter11: catalog.letters};
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
    "avatarChoices", "starts"]) s[key] ||= {};
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
const collectionKey = (s) => s.mode + "__" + s.target;
const indexFrom = (seed, length) => parseInt(hash(seed).slice(0, 8), 16) % length;
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
    (s.mode === "letter11" ? p.letters.includes(target.letter) : Object.hasOwn(target.links, p.id)));
}
function sessionView(raw) {
  const s = sessionOf(raw);
  if (!s) return null;
  const target = targetOf(s);
  const v = {id: s.id, mode: s.mode, entry: s.entry, formation: s.formation,
    formations: target?.formations || [s.formation], revision: s.revision, finished: s.finished,
    dailyOfficial: s.dailyOfficial, expiresAt: s.expiresAt, day: s.day,
    wrong: s.wrong, hints: s.hints, freeHint: !s.freeUsed, adCredits: s.adCredits,
    adRemaining: Math.max(0, 2 - s.adGranted), feedback: s.feedback || "", energyCharged: s.energyCharged,
    result: s.result || null};
  if (s.mode !== "squad_vault") {
    v.targetId = s.target; v.title = target.name || `${target.letter} harfi`;
    v.portraitId = target.portraitId || null; v.score = score(s);
    v.slots = catalog.formations[s.formation].map((pos, slot) => {
      const p = players.get(s.picks[slot]);
      return {slot, position: pos, player: p ? publicPlayer(p) : null,
        evidence: p && s.mode === "coach_xi" ? target.links[p.id].map((e) =>
          ({club: clubs.get(e.clubId).name, date: e.date, sources: e.sources})) : []};
    });
    v.coverage = s.mode === "coach_xi" ?
      "Yalnızca kaynakla doğrulanmış bağlantılar kabul edilir. Doğrulanamayan bağlantı yanlış sayılmaz." : "";
    v.context = s.mode === "coach_xi" && s.difficulty === "easy" ?
      [...new Set(Object.values(target.links).flat().map((e) => clubs.get(e.clubId).name))].join(" · ") : "";
  } else {
    const puzzle = puzzleOf(s); const club = clubs.get(puzzle.clubId);
    v.title = s.finished ? club.name : "Gizli kulüp";
    v.stars = stars(s); v.remaining = Math.max(0, 5 - s.guesses.length);
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
      const state = normalize(raw); state.threeModes = stateOf(state.threeModes);
      state.energy = energy.refreshed(state.energy, time);
      try {
        fn(state.threeModes, state, time); return state;
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
    const pool = targets[mode];
    if (!pool) fail("invalid-argument", "Bu modda günlük oyun yok.");
    const target = pool[indexFrom(key + catalog.version, pool.length)];
    const form = target.formations[indexFrom(key, target.formations.length)];
    const tx = await db.ref("threeModeDaily/" + key).transaction((raw) => raw ||
      {day, target: target.id, formation: form, version: catalog.version});
    const value = tx.snapshot.val();
    if (value.version !== catalog.version) fail("failed-precondition", "Günlük veri güncellemesi yarın açılacak.");
    return value;
  }
  async function status(uid, input = {}) {
    if (!MODES.has(input.mode)) fail("invalid-argument", "Geçersiz mod.");
    await settle(uid);
    const s = await read(uid); const linked = await isLinked(uid);
    const inventory = (await db.ref("economyState/" + uid + "/inventory").get()).val() || {};
    const active = sessionOf(s.sessions[s.active[input.mode]]);
    const dailyGame = input.mode !== "squad_vault" ? await daily(input.mode) : null;
    const current = active && active.version === catalog.version && !active.finished && active.expiresAt > now() &&
      (active.entry !== "daily" || active.day === dayKey(now())) ? sessionView(active) : null;
    const exposeRecord = (r) => r ? {...r,
      bestLineup: lineupOf(r.bestLineup).map((id) => players.has(id) ? publicPlayer(players.get(id)) : null),
      lastLineup: lineupOf(r.lastLineup).map((id) => players.has(id) ? publicPlayer(players.get(id)) : null)} : null;
    const list = input.mode === "squad_vault" ? catalog.vaultClubs.map((id) => {
      const c = clubs.get(id); const record = s.collection[`squad_vault__${id}`];
      return {id: String(id), name: record?.solved ? c.name : "Kilitli kasa", league: c.league,
        badgeKey: record?.solved ? c.badgeKey : null, record: exposeRecord(record)};
    }) : targets[input.mode].map((t) => ({id: t.id, name: t.name || t.letter, letter: t.letter || null,
      formations: t.formations, difficulty: t.difficulty, portraitId: t.portraitId || null,
      count: t.count || Object.keys(t.links).length, record: exposeRecord(s.collection[`${input.mode}__${t.id}`]),
      avatarId: t.avatarId || null, avatarCoins: t.avatarCoins || 0,
      bestEvidence: t.links ? lineupOf(s.collection[`${input.mode}__${t.id}`]?.bestLineup)
          .filter((id) => t.links[id]).map((id) => ({name: players.get(id).name,
            links: t.links[id].map((e) => ({club: clubs.get(e.clubId).name, date: e.date, sources: e.sources}))})) : [],
      avatarOwned: !!inventory[t.avatarId], avatarChoice: s.avatarChoices[t.id] || null}));
    return {ok: true, version: catalog.version, mode: input.mode, entries: list, session: current,
      daily: dailyGame, dailyUsed: !!s.daily[`${input.mode}__${dayKey(now())}`], linked,
      pendingRewards: Object.keys(s.pending).length, leagueSnapshot: catalog.leagueSnapshot};
  }
  async function start(uid, input) {
    check(input);
    if (!idOk(input.requestId) || !["random", "archive", "daily", "league"].includes(input.entry)) {
      fail("invalid-argument", "Geçersiz oyun isteği.");
    }
    if (input.entry === "league" && input.mode !== "squad_vault") fail("invalid-argument", "Geçersiz lig oyunu.");
    const fixed = input.entry === "daily" ? await daily(input.mode) : null;
    const rollout = {...energy.policy.rollout, ...await getRollout()};
    const bucket = indexFrom(uid, 100);
    const charged = rollout.enabled === true && bucket < Math.min(100, Math.max(0, rollout.percent)) &&
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
        if (input.entry === "archive") {
          if (!s.collection[`squad_vault__${input.target}`]?.solved) fail("failed-precondition", "Önce bu kasayı çöz.");
          pool = pool.filter((p) => String(p.clubId) === input.target);
        }
        const recent = Object.values(s.sessions).filter((x) => x.mode === "squad_vault")
            .sort((a, b) => b.startedAt - a.startedAt).slice(0, 5).map((x) => x.target);
        const fresh = pool.filter((p) => !recent.includes(String(p.clubId)));
        if (fresh.length) pool = fresh;
        if (!pool.length) fail("failed-precondition", "Bu ligde oynanabilir kasa yok.");
        puzzle = pool[indexFrom(seed, pool.length)]; target = String(puzzle.clubId); formation = puzzle.formation;
      } else {
        let pool = targets[input.mode];
        if (input.difficulty === "hard" && input.mode === "coach_xi") {
          fail("failed-precondition", "Dönem kısıtlı zor hoca havuzu henüz doğrulanmadı.");
        }
        if (input.entry === "random" && input.difficulty) pool = pool.filter((x) => x.difficulty === input.difficulty);
        if (input.entry === "random" && input.formation) {
          pool = pool.filter((x) => x.formations.includes(input.formation));
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
      s.sessions[session.id] = session; s.active[input.mode] = session.id;
      s.starts[session.id] = true;
      // Collections/receipts are permanent; expired session bodies are bounded.
      const obsolete = Object.values(s.sessions).filter((x) => x.expiresAt < time)
          .sort((a, b) => b.startedAt - a.startedAt).slice(20);
      for (const x of obsolete) delete s.sessions[x.id];
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
    const record = {...previous, best: Math.max(previous.best || 0, value), mastery: !!previous.mastery || master,
      bestFormation: value > (previous.best || 0) || master && !previous.mastery ? run.formation :
        previous.bestFormation || run.formation,
      lastLineup: lineup, lastFormation: run.formation, lastAt: time,
      solved: !!previous.solved || (run.mode === "squad_vault" ? !!run.won : value > 0),
      bestLineup: value > (previous.best || 0) || master && !previous.mastery ? lineup : previous.bestLineup || lineup};
    s.collection[key] = record;
    if (run.mode === "squad_vault" && Object.entries(s.collection)
        .filter(([k, r]) => k.startsWith("squad_vault__") && r.best >= 1).length >= 5) {
      const b = catalog.policy.archiveBonus;
      if (reward(s, "three__vault_archive_5", {...b, target: "squad_vault"})) {
        coins += b.coins; xp += b.xp;
      }
    }
    if (run.dailyOfficial && value >= 8) {
      const b = catalog.policy.daily[run.mode];
      if (b && reward(s, `three__daily__${run.mode}__${run.day}`, {...b, target: run.mode})) {
        coins += b.coins; xp += b.xp;
      }
    }
    if (run.dailyOfficial) {
      s.daily[`${run.mode}__${run.day}`].result = {score: value, mastery: master, wrong: run.wrong};
    }
    run.result = {score: value, mastery: master, newMedals: medals, coins, xp,
      avatarAvailable: master && !!targetOf(run)?.avatarId && !s.avatarChoices[run.target]};
  }
  async function act(uid, input) {
    check(input);
    if (!idOk(input.sessionId) || !idOk(input.requestId)) fail("invalid-argument", "Geçersiz işlem kimliği.");
    const state = await change(uid, (s, e, time) => {
      const run = sessionOf(s.sessions[input.sessionId]);
      if (!run || run.mode !== input.mode || run.version !== catalog.version) fail("not-found", "Oturum bulunamadı.");
      const fingerprint = hash(JSON.stringify([input.action, input.playerId ?? null, input.clubId ?? null,
        input.slot ?? null, input.formation ?? null, input.hint ?? null, input.confirmReset ?? null]));
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
        if (run.mode === "coach_xi" && !Object.hasOwn(target.links, p.id)) {
          run.feedback = "Bu hoca-futbolcu bağı henüz doğrulanmadı. Yanlış hakkın değişmedi.";
        } else if (p.position !== catalog.formations[run.formation][input.slot] ||
            run.mode === "letter11" && !p.letters.includes(target.letter)) {
          run.wrong++; run.feedback = "Futbolcunun harfi veya mevkisi bu slota uymuyor.";
        } else {
          run.picks[input.slot] = p.id; run.feedback = "Doğru bağlantı: " + p.name;
          if (run.mode === "coach_xi") {
            const proof = target.links[p.id][0];
            run.feedback += ` · ${clubs.get(proof.clubId).name} · ${proof.date}`;
          }
        }
      } else if (input.action === "guess" && run.mode === "squad_vault") {
        if (!clubs.has(input.clubId)) fail("invalid-argument", "Kulübü arama listesinden seç. Hakkın değişmedi.");
        if (run.guesses.includes(input.clubId)) fail("already-exists", "Bu kulübü zaten denedin.");
        run.guesses.push(input.clubId);
        if (input.clubId === puzzleOf(run).clubId) {
          run.won = true; finish(s, run, time);
        } else {
          run.wrong++; run.feedback = "Bu kasa başka bir kulübe ait.";
          if (run.guesses.length >= 5) finish(s, run, time);
        }
      } else if (input.action === "hint") {
        if (run.freeUsed && run.adCredits <= 0) {
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
          const filtered = run.mode === "letter11" && ["club", "league"].includes(input.hint) ?
            options.filter((p) => (p.clubs || []).some((id) => clubs.has(id) &&
              (input.hint !== "league" || clubs.get(id).league))) : options;
          if (!filtered.length) fail("failed-precondition", "Bu mevki için doğrulanmış ipucu yok.");
          const p = filtered.sort((a, b) => a.rank - b.rank)[run.hints.length % filtered.length];
          if (run.mode === "coach_xi" && ["club", "years"].includes(input.hint)) {
            const proof = targetOf(run).links[p.id][0];
            text = input.hint === "club" ? clubs.get(proof.clubId).name : proof.date.slice(0, 4);
          } else if (run.mode === "letter11" && ["club", "league"].includes(input.hint)) {
            const c = p.clubs.map((id) => clubs.get(id)).find((c) => c && (input.hint !== "league" || c.league));
            text = input.hint === "club" ? c.name : `${c.league} (kulübün veri sürümündeki ligi)`;
          } else if (input.hint === "country") {
            text = p.country;
          } else fail("invalid-argument", "Bu ipucu desteklenmiyor.");
          if (!text) fail("failed-precondition", "Doğrulanmış ipucu yok.");
          text = `Seçili mevkiye uygun, henüz bulunmamış bir futbolcu: ${text}`;
        }
        if (!run.freeUsed) run.freeUsed = true; else run.adCredits--;
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
    // Never filter by the answer, letter, coach link, selected position or club.
    const list = input.mode === "squad_vault" ? catalog.clubs : catalog.players;
    const tokens = q.split(" ");
    const hits = list.filter((p) => tokens.every((t) => p.search.includes(t))).sort((a, b) =>
      Number(norm(b.name) === q) - Number(norm(a.name) === q) || (a.rank || 0) - (b.rank || 0) || a.id - b.id);
    return {ok: true, results: hits.slice(0, 30).map((p) => input.mode === "squad_vault" ?
      {id: p.id, name: p.name, country: p.country, league: p.league} : publicPlayer(p))};
  }
  async function prepareHint(uid, placement, context) {
    const expected = {coach11_hint: "coach_xi", letter11_hint: "letter11", vault_hint: "squad_vault"}[placement];
    const s = await read(uid); const run = sessionOf(s.sessions[context?.sessionId]);
    if (!expected || !run || run.mode !== expected || run.finished || run.expiresAt <= now() || run.adGranted >= 2) {
      fail("failed-precondition", "Bu oyun için reklamlı ipucu hakkı yok.");
    }
    return {amount: 0, claimKey: `three_hint_${run.id}_${run.adGranted}`,
      context: {sessionId: run.id, mode: run.mode, credit: run.adGranted}};
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s) => {
      const run = sessionOf(s.sessions[receipt.context?.sessionId]);
      // A late receipt cannot modify another run or convert into coins.
      if (!run || run.mode !== receipt.context?.mode || run.finished || run.expiresAt <= now()) return;
      if (run.adReceipts[receipt.id]) return;
      if (run.adGranted >= 2 || run.adGranted !== receipt.context.credit) return;
      run.adGranted++; run.adCredits++; run.adReceipts[receipt.id] = true;
      // Watching only grants credit; mastery changes when a hint is consumed.
      s.sessions[run.id] = run;
    });
  }
  async function chooseAvatar(uid, input) {
    check(input);
    if (!await isLinked(uid)) fail("permission-denied", "Ödülünü almak için hesabını bağla.");
    const coach = catalog.coaches.find((c) => c.id === input.target);
    if (input.mode !== "coach_xi" || !coach?.avatarId || !["avatar", "coins"].includes(input.choice)) {
      fail("invalid-argument", "Geçersiz hoca ödülü.");
    }
    await change(uid, (s, e, time) => {
      if (!s.collection[`coach_xi__${coach.id}`]?.mastery) fail("permission-denied", "Önce ipucusuz ustalık kazan.");
      if (s.avatarChoices[coach.id]) return;
      const choice = e.inventory[coach.avatarId] ? "coins" : input.choice;
      s.avatarChoices[coach.id] = {choice, at: time, value: coach.avatarCoins, avatarId: coach.avatarId};
      if (choice === "avatar") {
        e.inventory[coach.avatarId] = {itemId: coach.avatarId, itemType: "avatar", quantity: 1,
          sourceType: "coach_mastery", sourceId: coach.id, acquiredAt: time};
      } else reward(s, `three__avatar__${coach.id}`, {target: coach.id, coins: coach.avatarCoins, xp: 0});
    });
    return status(uid, input);
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
  return {status, start, act, search, resume, chooseAvatar, prepareHint, settleHint, settle};
}
module.exports = {createService, catalog, norm, sessionView, score, stars, mastery};
