"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const H = require("./hints");
const {RewardError, dayKey} = require("./rewarded_ads");
const energy = require("./energy");
const {norm} = require("./three_modes");
const catalog = require("./config/career_transfer_catalog.json");
const people = require("./config/three_modes_catalog.json").players;
const players = new Map(people.map((p) => [p.id, p]));
const clubs = new Map(catalog.clubs.map((c) => [c.id, c]));
const MODES = ["career", "transfer"];
const boosts = ["boost_first_letter", "boost_last_letter", "boost_anagram"];
const hash = (v) => crypto.createHash("sha256").update(v).digest("hex");
const validId = (v) => typeof v === "string" && /^[a-f0-9]{32}$/.test(v);
const fail = (c, m) => {
  throw new RewardError(c, m);
};
const stateOf = (raw) => ({sessions: {}, active: {}, starts: {}, collection: {}, claims: {},
  pending: {}, payments: {}, days: {}, streak: 0, longestStreak: 0, ...raw});
const runOf = (r) => r && ({hints: [], guesses: [], actions: {}, adReceipts: {}, order: [], correctness: [], ...r});
const pool = (mode) => mode === "career" ? catalog.careers : catalog.transfers;
const puzzleOf = (s) => pool(s.mode).find((p) => p.id === s.puzzle);
const playerView = (p) => ({id: p.id, name: p.name, country: p.country, position: p.position});
// Everyone who made the shown move in that year answers it; the screen only has clubs and year.
const answersOf = (p) => [p.playerId, ...(p.alsoPlayerIds || [])];
const TRANSFER_LEVELS = ["easy", "medium", "hard"];
// Streak badges pay once, the first time the best streak reaches them.
const STREAK_REWARDS = [{id: "streak_5", at: 5, coins: 10}, {id: "streak_10", at: 10, coins: 20}];
const detailedPositions = {"Goalkeeper": "Kaleci", "Centre-Back": "Stoper", "Left-Back": "Sol bek",
  "Right-Back": "Sağ bek", "Defensive Midfield": "Ön libero", "Central Midfield": "Merkez orta saha",
  "Attacking Midfield": "On numara", "Left Midfield": "Sol orta saha", "Right Midfield": "Sağ orta saha",
  "Left Winger": "Sol kanat", "Right Winger": "Sağ kanat", "Second Striker": "İkinci forvet",
  "Centre-Forward": "Santrfor"};
function shuffled(list, seed) {
  return [...list].sort((a, b) => hash(seed + JSON.stringify(a)).localeCompare(hash(seed + JSON.stringify(b))));
}
// Career cards: back-to-back periods at one club are one card, so two cards
// can never be told apart only by a hidden "1st / 2nd spell" label.
function cardsOf(p) {
  const cards = [];
  for (const stop of p.stops) {
    const last = cards.at(-1);
    if (last && last.clubId === stop.clubId) {
      last.end = stop.end; last.stopIds.push(stop.id);
    } else cards.push({id: stop.id, clubId: stop.clubId, start: stop.start, end: stop.end, stopIds: [stop.id]});
  }
  return cards;
}
// Longer careers get more checks: up to 5 cards 2, 6–8 cards 3, 9+ cards 4.
const maxChecks = (n) => n <= 5 ? 2 : n <= 8 ? 3 : 4;
const clubOfCard = (cards, id) => cards.find((c) => c.id === id)?.clubId;
// A card position is right when it holds the right club; two cards of the
// same club are interchangeable.
const correctnessOf = (cards, order) => order.map((id, i) => clubOfCard(cards, id) === cards[i].clubId);
// Shuffle that never starts as the solution (when another order exists).
function startOrder(cards, seed) {
  let order = cards.map((c) => c.id);
  for (let i = 0; i < 24; i++) {
    order = shuffled(cards.map((c) => c.id), seed + ":" + i);
    if (correctnessOf(cards, order).some((ok) => !ok)) return order;
  }
  return order;
}
// Sessions started before cards existed keep stop ids; give them a card order.
function orderOf(run, cards) {
  const ids = new Set(cards.map((c) => c.id));
  const valid = run.order.length === cards.length && run.order.every((id) => ids.has(id)) &&
    new Set(run.order).size === cards.length;
  return valid ? run.order : startOrder(cards, run.id);
}
const yearsOf = (c) => `${c.start.slice(0, 4)}–${c.end?.slice(0, 4) || "açık dönem"}`;
// İpucu v2 menus (hints/career_transfer.js).
const adapter = H.register(require("./hints/career_transfer").make({puzzleOf, players, cardsOf, orderOf,
  clubOfCard, clubName: (id) => clubs.get(id)?.name, yearsOf, detailedPositions}));
function sessionView(raw) {
  const s = runOf(raw); if (!s) return null;
  const p = puzzleOf(s); const player = players.get(p.playerId);
  const v = {id: s.id, mode: s.mode, difficulty: s.difficulty, version: s.version, revision: s.revision,
    phase: s.phase, finished: s.finished, expiresAt: s.expiresAt, wrong: s.wrong, guesses: s.guesses,
    checks: s.checks, score: s.score, found: s.found, hints: s.hints,
    freeHint: !B.paid(s) && !H.active(s) && !s.freeUsed, support: B.view(s), hintMenu: H.view(s, adapter),
    adCredits: s.adCredits, adRemaining: Math.max(0, 2 - s.adGranted), feedback: s.feedback || "",
    energyCharged: s.energyCharged, masteryEligible: !s.assisted && s.first && s.difficulty !== "beginner",
    result: s.result || null, streak: s.streak || 0, ...(s.daily ? {daily: s.daily} : {})};
  if (s.phase !== "guess" || s.finished) v.player = playerView(player);
  if (s.mode === "career") {
    const cards = cardsOf(p);
    // "visit" is how many spells the club has in this career, never which one.
    v.stops = orderOf(s, cards).map((id) => {
      const card = cards.find((c) => c.id === id);
      const spells = cards.filter((c) => c.clubId === card.clubId).length;
      return {id, club: clubs.get(card.clubId), visit: spells > 1 ? spells : null};
    });
    v.correctness = s.correctness; v.maxChecks = maxChecks(cards.length);
    // Periods with no verified club (loans, free agency, unknown years) are left out.
    v.gaps = cards.some((c, i) => i > 0 && cards[i - 1].end &&
      Date.parse(c.start) - Date.parse(cards[i - 1].end) > 30 * 86400000);
    if (s.finished) {
      v.solution = cards.map((c) => ({id: c.id, clubId: c.clubId, start: c.start, end: c.end,
        club: clubs.get(c.clubId)}));
    }
  } else {
    const first = [...player.name].findIndex((c) => /\p{L}/u.test(c));
    const last = [...player.name].findLastIndex((c) => /\p{L}/u.test(c));
    const letter = s.hints.some((h) => ["letter", "shape"].includes(h.kind));
    const shape = s.hints.some((h) => h.kind === "shape");
    v.maskedName = [...player.name].map((c, i) => /\p{L}/u.test(c) ?
      s.finished || letter && i === first || shape && i === last ? c : "_" : c).join(" ");
    v.transfer = {from: clubs.get(p.fromClubId), to: clubs.get(p.toClubId), year: p.year};
    if (s.finished) {
      v.transfer = {...v.transfer, eventId: p.id, date: p.date, source: p.source,
        alsoBy: answersOf(p).filter((id) => id !== p.playerId && id !== s.answerId)
            .map((id) => players.get(id)?.name).filter(Boolean)};
      if (s.answerId && s.answerId !== p.playerId) v.answer = playerView(players.get(s.answerId));
    }
  }
  return v;
}
function createService({db, normalize, project, grantCoins, grantXp, isLinked, getRollout,
  now = Date.now, random = () => crypto.randomBytes(16).toString("hex")}) {
  async function change(uid, fn) {
    let error; const time = now();
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null; const e = normalize(structuredClone(raw)); e.careerTransfer = stateOf(e.careerTransfer);
      e.energy = energy.refreshed(e.energy, time);
      try {
        for (const r of Object.values(e.careerTransfer.sessions)) {
          B.recoverUnused(e, r, time,
              (sku) => (r.hints?.length || 0) < 3 && sku === (r.mode === "transfer" &&
              (r.hints?.length || 0) === 2 ? "boost_first_letter" :
              r.phase === "order" ? "boost_connection" : "boost_basic"));
        }
        fn(e.careerTransfer, e, time);
        for (const r of Object.values(e.careerTransfer.sessions)) {
          H.recoverUnused(e, runOf(r), time);
          B.recoverUnused(e, r, time,
              (sku) => (r.hints?.length || 0) < 3 && sku === (r.mode === "transfer" &&
              (r.hints?.length || 0) === 2 ? "boost_first_letter" :
              r.phase === "order" ? "boost_connection" : "boost_basic"));
        }
        return e;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "Aynı isteği yeniden gönder.");
    const e = normalize(tx.snapshot.val()); e.careerTransfer = stateOf(e.careerTransfer);
    await project(db, uid, e); return e;
  }
  const read = async (uid) => stateOf((await db.ref(`economyState/${uid}/careerTransfer`).get()).val());
  function check(input) {
    if (!MODES.includes(input.mode) || input.version !== catalog.version) {
      fail("failed-precondition", "Mod verisi güncellendi. Yenile.");
    }
  }
  // Reserve the shared daily allowance and durable outbox atomically. A failed
  // wallet/XP projection retries the same payment IDs, never the daily allowance.
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const e = await change(uid, (s, _, time) => {
      const day = dayKey(time); const d = s.days[day] ||= {coins: 0, xp: 0};
      for (const [key, reward] of Object.entries(s.pending).sort((a, b) =>
        a[1].at - b[1].at || a[0].localeCompare(b[0]))) {
        const coins = Math.min(reward.coins, 36 - d.coins, Math.floor((72 - d.xp) / 2));
        if (coins <= 0) break;
        const payment = `${key}__${day}`;
        // A tier is at most 4C; a split tier resumes next day.
        if (s.payments[payment]) continue;
        s.payments[payment] = {coins, xp: coins * 2, target: reward.target, paid: false};
        d.coins += coins; d.xp += coins * 2; reward.coins -= coins;
        if (!reward.coins) delete s.pending[key];
      }
    });
    for (const [id, p] of Object.entries(e.careerTransfer.payments)) {
      if (p.paid) continue;
      await grantCoins(uid, id, "career_transfer", p.target, p.coins, catalog.version);
      await grantXp(uid, id, p.xp);
      await change(uid, (s) => {
        if (s.payments[id]) s.payments[id].paid = true;
      });
    }
  }
  function award(s, run, tier, coins, time) {
    const key = `ct__${run.mode}__${run.puzzle}__${tier}`;
    if (s.claims[key]) return;
    s.claims[key] = {at: time, coins}; s.pending[key] = {coins, target: run.puzzle, at: time};
    run.earned += coins;
    const record = s.collection[`${run.mode}__${run.puzzle}`];
    record.medal = Math.max(record.medal || 0, tier);
  }
  function grade(s, run, time, correct = 0) {
    if (!run.found) return;
    if (run.mode === "transfer") {
      if (!run.first) return;
      award(s, run, 1, 2, time);
      if (run.wrong <= 1) award(s, run, 2, 1, time);
      if (!run.wrong) award(s, run, 3, 1, time);
      if (!run.wrong && !run.hints.length) award(s, run, 4, 2, time);
    } else {
      // Only the first play pays: after a skip or a reveal the answer is known.
      if (!run.first) return;
      award(s, run, 1, 3, time);
      const n = cardsOf(puzzleOf(run)).length;
      if (correct >= Math.ceil(n / 2)) award(s, run, 2, 2, time);
      if (correct === n) award(s, run, 3, 3, time);
      if (correct === n && run.checks === 1 && run.first && !run.wrong &&
          !run.hints.length && run.difficulty !== "beginner") award(s, run, 4, 4, time);
    }
  }
  function finish(s, run, time) {
    run.finished = true; run.phase = "result"; run.finishedAt = time;
    const record = s.collection[`${run.mode}__${run.puzzle}`];
    if (run.mode === "transfer") {
      const streakKey = run.assisted ? "assistedStreak" : "streak";
      // Archive replays know the answer: they neither extend nor break the streak.
      if (run.first) s[streakKey] = run.found ? (s[streakKey] || 0) + 1 : 0;
      run.streak = run.first ? s[streakKey] || 0 : 0;
      if (run.first && !run.assisted) {
        s.longestStreak = Math.max(s.longestStreak, s.streak);
        for (const b of STREAK_REWARDS) {
          const key = `ct__transfer__badge__${b.id}`;
          if (s.longestStreak >= b.at && !s.claims[key]) {
            s.claims[key] = {at: time, coins: b.coins}; s.pending[key] = {coins: b.coins, target: b.id, at: time};
            run.earned += b.coins; run.badge = b.id;
          }
        }
      }
      const multiplier = run.streak >= 4 ? 2 : run.streak === 3 ? 1.5 : run.streak === 2 ? 1.2 : 1;
      run.score = run.found ? Math.round(Math.max(0, 100 - run.wrong * 10 - run.hints.length * 10) * multiplier) : 0;
    }
    const bestKey = run.assisted ? "bestAssistedScore" : "bestScore";
    record[bestKey] = Math.max(record[bestKey] || 0, run.score);
    // A transfer counts as solved for the archive badges only when found on its first play.
    record.solved = !!record.solved || run.found && (run.mode !== "transfer" || run.first); record.lastAt = time;
    record.last = {wrong: run.wrong, hints: run.hints.length, checks: run.checks, score: run.score, found: run.found};
    record.attempts = (record.attempts || 0) + 1;
    if (run.first) record.firstResult = record.last;
    run.result = {coins: run.earned, xp: run.earned * 2, medal: record.medal || 0,
      practice: !run.found, assisted: run.assisted === true, score: run.score,
      ...(run.badge ? {badge: run.badge} : {})};
  }
  async function status(uid, input) {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz mod.");
    await change(uid, (s, _, time) => {
      const expired = runOf(s.sessions[s.active[input.mode]]);
      if (expired && !expired.finished && expired.expiresAt <= time) {
        finish(s, expired, time); s.sessions[expired.id] = expired;
      }
    });
    await settle(uid); const s = await read(uid);
    const active = runOf(s.sessions[s.active[input.mode]]);
    const e = normalize((await db.ref("economyState/" + uid).get()).val());
    return {ok: true, version: catalog.version, quality: catalog.quality, linked: await isLinked(uid),
      session: active && active.version === catalog.version && (active.finished || active.expiresAt > now()) ?
        sessionView(active) : null,
      collection: Object.entries(s.collection).filter(([k]) => k.startsWith(input.mode + "__")).map(([key, r]) => {
        const p = pool(input.mode).find((p) => key === input.mode + "__" + p.id);
        if (!p) return null;
        // Starting a session cannot reveal its answer via the collection endpoint.
        const run = active?.puzzle === p.id && !active.finished && active.phase === "guess";
        if (run || !r.last) return null;
        return {...r, id: p.id, player: playerView(players.get(p.playerId)),
          source: p.source, route: p.stops?.map((x) => ({...x, club: clubs.get(x.clubId)})) || null,
          transfer: input.mode === "transfer" ? {from: clubs.get(p.fromClubId), to: clubs.get(p.toClubId),
            date: p.date, eventId: p.id} : null};
      }).filter(Boolean),
      pendingCoins: Object.values(s.pending).reduce((n, r) => n + r.coins, 0) +
        Object.values(s.payments).filter((p) => !p.paid).reduce((n, p) => n + p.coins, 0),
      coins: e.balances.coins, longestStreak: s.longestStreak,
      badges: input.mode === "transfer" ? [
        {id: "files_10", title: "Transfer Arşivcisi", target: 10, progress: Object.entries(s.collection)
            .filter(([key, r]) => key.startsWith("transfer__") && r.solved).length},
        {id: "files_50", title: "Transfer Uzmanı", target: 50, progress: Object.entries(s.collection)
            .filter(([key, r]) => key.startsWith("transfer__") && r.solved).length},
        {id: "streak_5", title: "Keskin Dedektif", target: 5, progress: s.longestStreak},
        {id: "streak_10", title: "Kusursuz Seri", target: 10, progress: s.longestStreak},
      ].map((b) => {
        const reward = STREAK_REWARDS.find((r) => r.id === b.id);
        return {...b, earned: b.progress >= b.target,
          ...(reward ? {coins: reward.coins, xp: reward.coins * 2} : {})};
      }) : [],
      inventory: boosts.map((id) => ({id, quantity: e.inventory[id]?.quantity || 0}))};
  }
  async function start(uid, input) {
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    check(input);
    if (!validId(input.requestId)) fail("invalid-argument", "Geçersiz istek.");
    const difficulty = input.daily ? "normal" : input.mode === "career" ? input.difficulty || "normal" :
      TRANSFER_LEVELS.includes(input.difficulty) ? input.difficulty : "normal";
    const fingerprint = hash(JSON.stringify([input.mode, difficulty, input.target || null, !!input.daily]));
    const seed = random(); const rollout = {...energy.policy.rollout, ...await getRollout()};
    const charge = energy.inRollout(rollout, uid) &&
      (rollout.sessionModes || []).includes(input.mode);
    const e = await change(uid, (s, e, time) => {
      if (s.starts[input.requestId]) {
        if (s.starts[input.requestId] !== fingerprint) fail("invalid-argument", "Bu istek başka oyuna ait.");
        if (!s.sessions[input.requestId]) fail("failed-precondition", "Oturum süresi doldu.");
        return;
      }
      const active = runOf(s.sessions[s.active[input.mode]]);
      if (active && !active.finished && active.expiresAt > time) fail("already-exists", "Önce kayıtlı oyunu bitir.");
      if (active && !active.finished && active.expiresAt <= time) {
        finish(s, active, time); s.sessions[active.id] = active;
      }
      // Transfer "normal" is the mixed pool.
      let candidates = pool(input.mode).filter((p) => input.mode === "transfer" && difficulty === "normal" ||
        p.difficulty === difficulty);
      if (input.daily) {
        // Today's file: one well-known career or transfer for everyone.
        const daily = input.mode === "career" ? catalog.careers.filter((p) => p.difficulty === "normal") :
          catalog.transfers.filter((p) => p.difficulty !== "hard" && !p.alsoPlayerIds);
        candidates = [daily[parseInt(hash(input.mode + "__" + dayKey(time) + catalog.version).slice(0, 8), 16) %
          daily.length]];
      } else if (input.target) {
        if (!s.collection[`${input.mode}__${input.target}`]?.last) fail("permission-denied", "Önce arşive ekle.");
        candidates = candidates.filter((p) => p.id === input.target);
      } else {
        const unseen = candidates.filter((p) => !s.collection[`${input.mode}__${p.id}`]);
        if (unseen.length) candidates = unseen;
        if (input.mode === "transfer") {
          // A few journeymen own dozens of transfers: pick a player first, then
          // one of their files, and skip the players of the last five files.
          const recent = Object.values(s.sessions).filter((x) => x.mode === "transfer")
              .sort((a, b) => b.startedAt - a.startedAt).slice(0, 5)
              .map((x) => pool("transfer").find((p) => p.id === x.puzzle)?.playerId);
          const fresh = candidates.filter((p) => !recent.includes(p.playerId));
          if (fresh.length) candidates = fresh;
          const ids = [...new Set(candidates.map((p) => p.playerId))].sort((a, b) => a - b);
          const pid = ids[parseInt(hash(seed + ":player").slice(0, 8), 16) % ids.length];
          candidates = candidates.filter((p) => p.playerId === pid);
        }
      }
      if (!candidates.length) fail("failed-precondition", "Bu seviyede doğrulanmış içerik yok.");
      const p = candidates[parseInt(hash(seed).slice(0, 8), 16) % candidates.length];
      if (charge) {
        if (e.energy.balance - energy.held(e.energy) < 1) {
          fail("resource-exhausted", "Yeni oyun için 1 enerji gerekli.");
        }
        if (e.energy.balance === energy.policy.capacity) e.energy.refillAt = time;
        e.energy.balance--;
      }
      const key = `${input.mode}__${p.id}`; const first = !s.collection[key];
      s.collection[key] ||= {firstAt: time, firstSession: input.requestId, difficulty,
        version: catalog.version, medal: 0};
      const run = {id: input.requestId, mode: input.mode, difficulty, puzzle: p.id, first,
        version: catalog.version, startedAt: time, expiresAt: time + energy.policy.resumeMs,
        revision: 0, phase: "guess", finished: false, found: false, wrong: 0, checks: 0, score: 0,
        energyCharged: charge, earned: 0, hints: [], guesses: [], actions: {}, freeUsed: false,
        adGranted: 0, adCredits: 0, adReceipts: {}, correctness: [],
        order: p.stops ? startOrder(cardsOf(p), seed) : [], ...(input.daily ? {daily: dayKey(time)} : {})};
      H.pinAny(run, boostPolicy, e, time);
      s.sessions[run.id] = run; s.active[input.mode] = run.id; s.starts[run.id] = fingerprint;
      for (const [id, old] of Object.entries(s.sessions)) {
        if (old.expiresAt < time && !(old.adCredits > 0) && !H.pending(old) && !Object.values(s.active).includes(id)) {
          delete s.sessions[id];
        }
      }
    });
    return {ok: true, version: catalog.version, session: sessionView(e.careerTransfer.sessions[input.requestId])};
  }
  function resolve(input) {
    if (input.playerId != null) return players.get(input.playerId);
    const q = norm(input.answer).slice(0, 80);
    if (!q) return null;
    const exact = people.filter((p) => [p.name, ...(p.aliases || [])].some((v) => norm(v) === q));
    return exact.length === 1 ? exact[0] : null;
  }
  function hintFor(run, input) {
    const p = puzzleOf(run); const player = players.get(p.playerId);
    let kind = input.hint;
    if (run.mode === "transfer") kind = ["country", "position", "letter"][run.hints.length];
    if (run.hints.some((h) => h.kind === kind)) fail("already-exists", "Bu ipucu zaten açık.");
    let text;
    if (run.phase === "guess") {
      if (kind === "country") text = player.country;
      if (kind === "position") {
        text = detailedPositions[p.detailedPosition] ||
          {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", FWD: "Forvet"}[player.position];
        if (run.mode === "transfer" && p.age) text += ` · transferde ${p.age} yaşında`;
      }
      if (kind === "letter") text = `İlk harf: ${player.name.match(/\p{L}/u)?.[0] || ""}`;
    } else if (run.mode === "career" && run.phase === "order") {
      // Each hint fixes a card that is not yet in place, so three hints
      // always add three different pieces of the career.
      const cards = cardsOf(p); const order = orderOf(run, cards);
      const told = new Set(run.hints.map((h) => h.card).filter(Boolean));
      const open = cards.map((c, i) => ({c, i})).filter(({c, i}) =>
        clubOfCard(cards, order[i]) !== c.clubId && !told.has(c.id));
      const pick = open[0] || cards.map((c, i) => ({c, i})).find(({c}) => !told.has(c.id));
      if (pick) {
        const {c, i} = pick; const name = clubs.get(c.clubId).name;
        if (kind === "connection" && i + 1 < cards.length) {
          text = `${name} → ${clubs.get(cards[i + 1].clubId).name} art arda`;
        } else if (kind === "years") {
          text = `${name}: ${yearsOf(c)}`;
        } else if (kind === "short" || kind === "connection") {
          text = `${name} kariyerin ${i + 1}. durağı`;
        }
        if (text) return {kind, text, card: c.id};
      }
    }
    if (!text) fail("failed-precondition", "Bu aşamada doğrulanmış yeni ipucu yok.");
    return {kind, text};
  }
  async function act(uid, input) {
    check(input);
    if (!validId(input.sessionId) || !validId(input.requestId)) fail("invalid-argument", "Geçersiz işlem kimliği.");
    const e = await change(uid, (s, e, time) => {
      const run = runOf(s.sessions[input.sessionId]);
      if (!run || run.mode !== input.mode || run.version !== catalog.version) fail("not-found", "Oturum bulunamadı.");
      const fingerprint = hash(JSON.stringify([input.action, input.playerId ?? null, input.answer ?? null,
        input.order ?? null, input.hint ?? null, input.boost ?? null, ...B.paymentFingerprint(input),
        input.itemId ?? null]));
      if (run.actions[input.requestId]) {
        if (run.actions[input.requestId] !== fingerprint) fail("invalid-argument", "İşlem başka cevaba ait.");
        return;
      }
      if (run.finished || run.expiresAt <= time) fail("failed-precondition", "Bu oyun sona erdi.");
      if (input.revision !== run.revision) fail("aborted", "Diğer cihazdaki değişiklik için Yenile.");
      const p = puzzleOf(run);
      if (input.action === "guess" && run.phase === "guess") {
        const player = resolve(input);
        if (!player) fail("invalid-argument", "İsim tanınmadı veya belirsiz. Listeden futbolcu seç; hakkın azalmadı.");
        if (run.guesses.includes(player.id)) fail("already-exists", "Bu futbolcu zaten denendi.");
        run.guesses.push(player.id);
        if (player.id === p.playerId || run.mode === "transfer" && answersOf(p).includes(player.id)) {
          run.found = true; run.score = run.mode === "career" ? 25 : 0; run.answerId = player.id;
          grade(s, run, time); run.feedback = "Doğru futbolcu!";
          if (run.mode === "career") run.phase = "order"; else finish(s, run, time);
        } else {
          run.wrong++; run.feedback = "Yanlış futbolcu.";
          if (run.wrong >= 3) {
            if (run.mode === "career") {
              run.phase = "order"; run.feedback = "Cevap açıldı. Sıralamaya ödülsüz alıştırma olarak devam et.";
            } else finish(s, run, time);
          }
        }
      } else if (["order", "reorder"].includes(input.action) && run.phase === "order") {
        const cards = cardsOf(p); const n = cards.length;
        if (!Array.isArray(input.order) || input.order.length !== n || new Set(input.order).size !== n ||
            input.order.some((id) => !cards.some((c) => c.id === id))) {
          fail("invalid-argument", "Her kariyer dönemi bir kez yer almalı.");
        }
        run.order = input.order;
        if (input.action === "reorder") run.correctness = [];
        else {
          run.checks++;
          run.correctness = correctnessOf(cards, run.order);
          const count = run.correctness.filter(Boolean).length;
          grade(s, run, time, count);
          const left = maxChecks(n) - run.checks;
          if (count === n || left <= 0) {
            run.score = (run.found ? 25 : 0) + Math.floor(75 * count / n) +
              (count === n && run.checks === 1 ? 50 : 0);
            finish(s, run, time);
          } else run.feedback = `Doğru pozisyonlar işaretlendi: ${count}/${n}. ${left} kontrol hakkın kaldı.`;
        }
      } else if (input.action === "hint" && H.active(run)) {
        H.use(e, run, adapter, input, time);
      } else if (input.action === "hint") {
        if (run.hints.length >= 3) fail("resource-exhausted", "Bu bulmacanın üç ipucu kullanıldı.");
        const hint = hintFor(run, input);
        if (B.paid(run)) {
          const sku = hint.kind === "letter" ? "boost_first_letter" :
            ["connection", "years", "short"].includes(hint.kind) ? "boost_connection" : "boost_basic";
          B.consume(e, run, input, sku, "hint:" + hint.kind, hint, time);
        } else if (input.boost) {
          const item = e.inventory[input.boost];
          if (!boosts.includes(input.boost) || !item || item.quantity < 1) {
            fail("resource-exhausted", "Destek stokta yok.");
          }
          item.quantity--; e.storeUses[`ct__${run.id}__${run.hints.length}`] = {itemId: input.boost, usedAt: time};
        } else if (!run.freeUsed) run.freeUsed = true;
        else if (run.adCredits > 0) run.adCredits--;
        else fail("resource-exhausted", "Doğrulanmış reklam veya mağaza desteği gerekli.");
        run.hints.push(hint); run.feedback = hint.text;
      } else if (input.action === "skip") {
        run.found = run.mode === "career" && run.found; finish(s, run, time);
      } else fail("failed-precondition", "Bu işlem mevcut aşamada kullanılamaz.");
      run.actions[input.requestId] = fingerprint; run.revision++; s.sessions[run.id] = run;
    });
    await settle(uid);
    const wallet = normalize((await db.ref("economyState/" + uid).get()).val());
    return {ok: true, coins: wallet.balances.coins,
      inventory: boosts.map((id) => ({id, quantity: wallet.inventory[id]?.quantity || 0})),
      session: sessionView(e.careerTransfer.sessions[input.sessionId])};
  }
  async function search(uid, input) {
    check(input); const q = norm(input.query).slice(0, 80);
    if (q.length < 2) return {results: []};
    return {results: people.filter((p) => q.split(" ").every((t) => p.search.includes(t)))
        .sort((a, b) => Number(norm(b.name) === q) - Number(norm(a.name) === q) || a.rank - b.rank)
        .slice(0, 30).map(playerView)};
  }
  async function prepareHint(uid, placement, context) {
    const s = await read(uid); const run = runOf(s.sessions[context?.sessionId]);
    if (H.active(run)) {
      if (`${run.mode}_hint` !== placement || run.finished || run.expiresAt <= now()) {
        fail("failed-precondition", "Reklamlı ipucu hakkı yok.");
      }
      return H.adBenefit(run, context.itemId, {amount: 0, claimKey: `ct_hint_${run.id}_${run.adGranted}`,
        context: {sessionId: run.id, mode: run.mode, credit: run.adGranted}});
    }
    if (!run || `${run.mode}_hint` !== placement || run.finished || run.expiresAt <= now() ||
        run.adGranted >= 2 || run.hints.length + run.adCredits + (B.paid(run) || run.freeUsed ? 0 : 1) >= 3) {
      fail("failed-precondition", "Reklamlı ipucu hakkı yok.");
    }
    const sku = run.mode === "transfer" && run.hints.length === 2 ? "boost_first_letter" :
      run.phase === "order" ? "boost_connection" : "boost_basic";
    if (B.paid(run) && context?.boostId && context.boostId !== sku) {
      fail("failed-precondition", "Bu aşamada seçilen destek kullanılamaz.");
    }
    return B.adBenefit(run, {amount: 0, claimKey: `ct_hint_${run.id}_${run.adGranted}`,
      context: {sessionId: run.id, mode: run.mode, credit: run.adGranted}}, sku);
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e, time) => {
      const run = runOf(s.sessions[receipt.context?.sessionId]);
      if (receipt.context?.hintPolicyVersion === H.VERSION) {
        const canApply = run && H.active(run) && run.mode === receipt.context.mode &&
          run.adGranted === receipt.context.credit;
        if (H.recoverAd(e, run, receipt, time, canApply)) {
          if (run) s.sessions[run.id] = run; return;
        }
        H.grantAd(run, receipt); s.sessions[run.id] = run; return;
      }
      const sku = run?.mode === "transfer" && run.hints.length === 2 ? "boost_first_letter" :
        run?.phase === "order" ? "boost_connection" : "boost_basic";
      const canApply = run && run.hints.length + run.adCredits < 3 && run.adGranted < 2 &&
        run.adGranted === receipt.context.credit && (!receipt.context.boostId || receipt.context.boostId === sku);
      if (B.recoverAd(e, run, receipt, time, "boost_basic", canApply)) {
        if (run) s.sessions[run.id] = run; return;
      }
      if (!run || run.mode !== receipt.context?.mode || run.finished || run.expiresAt <= time ||
          run.adReceipts[receipt.id] || run.hints.length >= 3 || run.adGranted >= 2 ||
          run.adGranted !== receipt.context.credit) return;
      B.grantAd(run, receipt); s.sessions[run.id] = run;
    });
  }
  return {status, start, act, search, settle, prepareHint, settleHint};
}
module.exports = {createService, catalog, players, clubs, sessionView, shuffled, validId, playerView,
  cardsOf, maxChecks};
