"use strict";
const crypto = require("node:crypto");
const {RewardError} = require("./rewarded_ads");
const {catalog, players, clubs, shuffled, validId, playerView} = require("./career_transfer");
const mysteryCatalog = require("./config/mystery_chain_catalog.json");
const fakeClub = require("./fake_club");
const MODES = ["career_race", "transfer_duel", "mystery_duel", "fake_club_duel"];
const modeVersion = (mode) => mode === "fake_club_duel" ? fakeClub.catalog.version :
  mode === "mystery_duel" ? mysteryCatalog.version : catalog.version;
const hash = (v) => crypto.createHash("sha256").update(v).digest("hex");
// Career Race: club country, league and popularity come from the PvP catalog (same club ids).
const clubMeta = require("./pvp_engine").catalog.clubs;
// Clubs that appear in some career; a distractor nobody ever played for is too easy to rule out.
const careerClubs = [...new Set(catalog.careers.flatMap((p) => p.stops.map((s) => s.clubId)))];
const RACE_MIX = ["beginner", "normal", "legend"];
const once = (p, clubId) => p.stops.filter((s) => s.clubId === clubId).length === 1;
// Three wrong clubs close to the answer: same country first, then the nearest popularity.
function clubDistractors(p, answer, rng) {
  const a = clubMeta[String(answer)] || {}; const names = new Set(p.stops.map((s) => clubs.get(s.clubId).name));
  const near = careerClubs.filter((id) => id !== answer && !p.stops.some((s) => s.clubId === id) &&
    !names.has(clubs.get(id).name)).map((id) => {
    const m = clubMeta[String(id)] || {};
    return [id, (m.country === a.country ? 0 : m.league === a.league ? 500 : 1000) +
      Math.abs((m.rank || 0) - (a.rank || 0))];
  }).sort((x, y) => x[1] - y[1] || x[0] - y[0]).slice(0, 8).map(([id]) => id);
  return shuffled(near, rng + "near").slice(0, 3);
}
// Order rounds: a random run of three stops with three different clubs when there is one.
function orderWindow(p, rng) {
  const starts = Array.from({length: Math.max(0, p.stops.length - 2)}, (_, i) => i);
  const clean = starts.filter((i) => new Set(p.stops.slice(i, i + 3).map((s) => s.clubId)).size === 3);
  const pool = clean.length ? clean : starts;
  const start = pool[parseInt(hash(rng + "window").slice(0, 8), 16) % pool.length];
  return p.stops.slice(start, start + 3);
}
// Fake Club Duel: difficulty climbs over the match (2 easy, 3 normal, 3 hard, 2 legend); the
// last round counts double. No person twice, and a fake club never shows up again in the
// match, not even as an option; real clubs repeat only when nothing else is left. Options are
// shuffled per match, so the fake club's place carries no signal.
const FAKE_MIX = ["easy", "easy", "normal", "normal", "normal", "hard", "hard", "hard", "legend", "legend"];
const FAKE_FINAL_MULTIPLIER = 2;
function fakeClubDuel(seed, policy) {
  const bank = []; const people = new Set(); const shown = new Set(); const fakes = new Set();
  const off = new Set(policy.disabledQuestions || []);
  for (const [i, level] of FAKE_MIX.entries()) {
    let pool = fakeClub.catalog.questions.filter((q) => q.difficulty === level && !off.has(q.questionId) &&
      !people.has(q.playerId) && !shown.has(q.fakeClubId) && q.options.every((o) => !fakes.has(o.id)));
    const fresh = pool.filter((q) => q.options.every((o) => !shown.has(o.id)));
    if (fresh.length) pool = fresh;
    const q = shuffled(pool, seed + "fake" + i)[0];
    if (!q) fail("failed-precondition", "On farklı doğrulanmış futbolcu bulunamadı.");
    people.add(q.playerId); fakes.add(q.fakeClubId);
    for (const o of q.options) shown.add(o.id);
    const last = i === FAKE_MIX.length - 1;
    bank.push({id: q.questionId, kind: "fake_club_duel", duration: 10000, answer: q.fakeClubId,
      explanation: fakeClub.explanation(q), evidence: q.evidence, ...last ? {multiplier: FAKE_FINAL_MULTIPLIER} : {},
      public: {player: q.player, dataVersion: q.dataVersion, difficulty: q.difficulty,
        ...last ? {multiplier: FAKE_FINAL_MULTIPLIER} : {},
        options: shuffled(q.options, seed + "options" + i).map(({popularity, ...club}) => club)}});
  }
  return bank;
}
// Mystery Duel: 2 easy, 2 medium, 1 hard; well-known players first; no first-hint club or
// more than two of one position in a match. Hints open at 8, 16 and 24 s (club, period, a
// second club). A wrong option who played for a hinted club is left out, so a hint never
// fits two options. An answer before the first hint earns no speed bonus.
const MYSTERY_MIX = ["easy", "easy", "medium", "medium", "hard"];
const MYSTERY_HINT_MS = [8000, 16000, 24000];
const pvpClubs = require("./pvp_engine").catalog;
const clubIdsByName = new Map();
for (const [id, c] of Object.entries(pvpClubs.clubs)) {
  if (!clubIdsByName.has(c.name)) clubIdsByName.set(c.name, []);
  clubIdsByName.get(c.name).push(id);
}
// Club ids the shown hints name: the two club hints and the period's club.
function hintClubs(p) {
  const ids = new Set(p.hints.filter((h) => /^club_\d+$/.test(h.id)).map((h) => h.id.slice(5)));
  const period = p.hints.find((h) => h.id === "period")?.text.match(/^[^:]+:\s*(.+),\s*\d{4}/)?.[1];
  for (const id of clubIdsByName.get(period) || []) ids.add(id);
  return ids;
}
// Wrong options who never played for a hinted club.
const cleanOptions = new Map();
function clean(p) {
  if (!cleanOptions.has(p.id)) {
    const shown = hintClubs(p);
    cleanOptions.set(p.id, p.options.filter((id) => id !== p.playerId &&
      !(pvpClubs.players[String(id)]?.clubs || []).some((c) => shown.has(String(c)))));
  }
  return cleanOptions.get(p.id);
}
function mysteryDuel(seed) {
  const picked = []; const firstClubs = new Set(); const positions = {};
  for (const [i, level] of MYSTERY_MIX.entries()) {
    let pool = mysteryCatalog.mystery.filter((p) => p.difficulty === level && !picked.includes(p) &&
      !firstClubs.has(p.hints[0].id) && (positions[p.position] || 0) < 2);
    // Players with three unambiguous wrong options first, then the well-known ones.
    for (const keep of [(p) => clean(p).length >= 3, (p) => players.get(p.playerId).rank <= TRANSFER_KNOWN_RANK]) {
      if (pool.some(keep)) pool = pool.filter(keep);
    }
    const p = shuffled(pool, seed + "mystery" + i)[0];
    if (!p) fail("failed-precondition", "Gizem düellosu için yeterli futbolcu yok.");
    picked.push(p); firstClubs.add(p.hints[0].id); positions[p.position] = (positions[p.position] || 0) + 1;
  }
  return picked.map((p, i) => {
    const fine = clean(p); const rest = p.options.filter((id) => id !== p.playerId && !fine.includes(id));
    const options = [...shuffled(fine, seed + i), ...shuffled(rest, seed + i)].slice(0, 3);
    const teammate = p.hints.find((h) => h.id === "teammate");
    return {id: p.id, kind: "mystery_duel", duration: 30000, answer: p.playerId, difficulty: p.difficulty,
      timedHints: [p.hints[0].text, p.hints[1].text, p.hints[2].text], hintAt: MYSTERY_HINT_MS,
      explanation: [players.get(p.playerId).name, p.hints[1].text.replace(/^[^:]+:\s*/, ""),
        teammate?.text].filter(Boolean).join(" · "),
      public: {country: p.countryLabel || p.country, position: p.position, difficulty: p.difficulty,
        hintAt: MYSTERY_HINT_MS,
        options: shuffled([p.playerId, ...options], seed + i).map((id) => playerView(players.get(id)))}};
  });
}
// Transfer Duel: 2 easy, 2 medium, 1 hard; a player is drawn first and then one of their
// moves, so players with many loans do not crowd the match; no player or club pair twice,
// one move before 2015 when there is one. A move several players made the same day accepts
// all of them. Country opens at 10 s, position at 20 s; each open hint lowers the base by 15.
const TRANSFER_MIX = ["easy", "easy", "medium", "medium", "hard"];
const TRANSFER_HINT_MS = [10000, 20000];
const TRANSFER_HINT_COST = 15;
const TRANSFER_KNOWN_RANK = 3000;
const POSITIONS = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", FWD: "Forvet", ATT: "Forvet"};
function transferDuel(seed) {
  const picked = []; const usedPlayers = new Set(); const usedPairs = new Set();
  const pair = (p) => [p.fromClubId, p.toClubId].sort((a, b) => a - b).join("-");
  for (const [i, level] of TRANSFER_MIX.entries()) {
    const fits = (p) => p.difficulty === level && ![p.playerId, ...p.alsoPlayerIds || []]
        .some((id) => usedPlayers.has(id)) && !usedPairs.has(pair(p)) &&
      (i !== 0 || p.year < 2015);
    let pool = catalog.transfers.filter(fits);
    if (!pool.length && i === 0) {
      pool = catalog.transfers.filter((p) => p.difficulty === level && !usedPairs.has(pair(p)));
    }
    // Well-known players first (the 3000 best known); the whole tier only when none is left.
    const known = pool.filter((p) => players.get(p.playerId).rank <= TRANSFER_KNOWN_RANK);
    if (known.length) pool = known;
    const byPlayer = [...new Set(pool.map((p) => p.playerId))];
    if (!byPlayer.length) fail("failed-precondition", "Transfer düellosu için yeterli transfer yok.");
    const player = shuffled(byPlayer, seed + "player" + i)[0];
    const p = shuffled(pool.filter((x) => x.playerId === player), seed + "move" + i)[0];
    picked.push(p); usedPairs.add(pair(p));
    for (const id of [p.playerId, ...p.alsoPlayerIds || []]) usedPlayers.add(id);
  }
  return picked.map((p) => {
    const who = players.get(p.playerId);
    const accepted = [p.playerId, ...p.alsoPlayerIds || []];
    return {id: p.id, kind: "transfer", duration: 30000, answer: p.playerId, difficulty: p.difficulty,
      ...accepted.length > 1 ? {accepted} : {},
      timedHints: [`Milliyet: ${who.country || "bilinmiyor"}`, `Mevki: ${p.detailedPosition ||
        POSITIONS[who.position] || who.position}`],
      explanation: `${who.name} · ${p.date}${p.age ? ` · ${p.age} yaşında` : ""}` +
        (accepted.length > 1 ? ` · aynı gün geçen ${accepted.slice(1).map((id) => players.get(id).name)
            .join(", ")} de doğru sayıldı` : ""),
      public: {from: clubs.get(p.fromClubId), to: clubs.get(p.toClubId), year: p.year,
        difficulty: p.difficulty}};
  });
}
// Six careers: two of each difficulty; missing-club careers need a club that appears once.
function raceCareers(seed) {
  const picked = []; const fits = [(p) => p.stops.some((s) => once(p, s.clubId)), (p) => p.stops.length >= 3,
    () => true];
  const plan = [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [1, 2]];
  for (const [d, kind] of plan) {
    const p = shuffled(catalog.careers.filter((x) => x.difficulty === RACE_MIX[d] && fits[kind](x) &&
      !picked.includes(x)), seed + "race" + picked.length)[0];
    if (!p) fail("failed-precondition", "Kariyer yarışı için yeterli kariyer yok.");
    picked.push(p);
  }
  return picked;
}
const fail = (c, m) => {
  throw new RewardError(c, m);
};
function questions(mode, seed, policy = fakeClub.policyOf({})) {
  if (mode === "fake_club_duel") return fakeClubDuel(seed, policy);
  if (mode === "mystery_duel") return mysteryDuel(seed);
  if (mode === "transfer_duel") return transferDuel(seed);
  // Missing clubs hide a club the route shows only once, with distractors from the same
  // country and popularity; order rounds use a random run of stops; 2 careers per difficulty.
  const chosen = raceCareers(seed);
  return chosen.map((p, i) => {
    const rng = seed + i;
    if (i < 3) {
      const slots = p.stops.map((s, j) => j).filter((j) => once(p, p.stops[j].clubId));
      const slot = slots[parseInt(hash(rng).slice(0, 8), 16) % slots.length];
      const answer = p.stops[slot].clubId;
      return {id: p.id + "_missing", kind: "missing", duration: 20000, answer, difficulty: p.difficulty,
        public: {player: playerView(players.get(p.playerId)), difficulty: p.difficulty,
          route: p.stops.map((s, j) => j === slot ? "?" : clubs.get(s.clubId).name),
          years: p.stops.map((s) => (s.start || "").slice(0, 4)),
          options: shuffled([answer, ...clubDistractors(p, answer, rng)], rng)
              .map((id) => ({id, name: clubs.get(id).name}))}};
    }
    if (i < 5) {
      const stops = orderWindow(p, rng);
      return {id: p.id + "_order", kind: "order", duration: 25000, answer: stops.map((s) => s.id),
        public: {player: playerView(players.get(p.playerId)), difficulty: p.difficulty,
          options: shuffled(stops, rng).map((s) => ({
            id: s.id, name: clubs.get(s.clubId).name + (stops.filter((x) => x.clubId === s.clubId).length > 1 ?
            ` (${stops.filter((x) => x.clubId === s.clubId).indexOf(s) + 1}. dönem)` : ""),
          }))}};
    }
    // Wrong players who share a club with this route, so the route alone does not give it away.
    const route = new Set(p.stops.map((s) => s.clubId));
    const others = catalog.careers.filter((x) => x.playerId !== p.playerId);
    const close = shuffled(others.filter((x) => x.stops.some((s) => route.has(s.clubId))), rng);
    const distractors = [...close, ...shuffled(others.filter((x) => !close.includes(x)), rng)]
        .slice(0, 3).map((x) => x.playerId);
    return {id: p.id + "_mystery", kind: "mystery", duration: 20000, answer: p.playerId,
      public: {difficulty: p.difficulty, route: p.stops.map((s) => clubs.get(s.clubId).name),
        options: shuffled([p.playerId, ...distractors], rng).map((id) => ({id, name: players.get(id).name}))}};
  });
}
// A round's token: answers must name the round as it stood when the question opened.
const roundToken = (room, index) => hash(room.id + "|" + index + "|" + room.version + "|" + timing(room, index).start);
function roomOf(raw) {
  if (!raw) return null;
  return {...raw, answers: raw.answers || {}, receipts: raw.receipts || {}, presence: raw.presence || {}};
}
function timing(room, index) {
  const start = room.startedAt + room.questions.slice(0, index).reduce((n, q) => n + q.duration + 2000, 0);
  return {start, end: start + room.questions[index].duration};
}
function totals(room, uid, time = Infinity) {
  let score = 0; let correct = 0; let elapsed = 0;
  for (let i = 0; i < room.questions.length; i++) {
    if (timing(room, i).end > time) continue;
    const a = room.answers[uid]?.[i];
    if (a?.correct) {
      score += a.score; correct++; elapsed += a.elapsed;
    }
  }
  return {score, correct, elapsed};
}
function outcome(room) {
  const a = totals(room, room.host); const b = totals(room, room.guest);
  const delta = a.score - b.score || a.correct - b.correct || b.elapsed - a.elapsed;
  return delta > 0 ? room.host : delta < 0 ? room.guest : null;
}
const expiresAt = (room) => room.createdAt + (room.ranked ? 30000 : 300000);
function advance(room, time) {
  if (room.status === "waiting" && time >= expiresAt(room)) {
    room.status = "cancelled"; room.finishedAt = expiresAt(room);
  }
  if (room.status !== "playing") return;
  const end = timing(room, room.questions.length - 1).end;
  // A participant missing for 60s forfeits before even a late final poll.
  const absent = [room.host, room.guest].filter((u) => Math.min(time, end) - room.presence[u] > 60000);
  if (absent.length) {
    room.status = "forfeit"; room.winner = absent.length === 1 ?
      [room.host, room.guest].find((u) => u !== absent[0]) : null;
    room.finishedAt = time;
  } else if (time >= end) {
    room.status = "finished"; room.winner = outcome(room); room.finishedAt = end;
  }
}
function view(room, uid, time) {
  const other = uid === room.host ? room.guest : room.host;
  const v = {id: room.id, code: room.code, mode: room.mode, ranked: room.ranked, status: room.status,
    serverNow: time, expiresAt: expiresAt(room), host: uid === room.host,
    opponent: other || null, version: room.version,
    totalRounds: room.questions.length, startedAt: room.startedAt || null,
    mine: totals(room, uid, time), theirs: other ? totals(room, other, time) : null};
  if (room.status === "playing") {
    const index = room.questions.findIndex((_, i) => timing(room, i).end + 2000 > time);
    const q = room.questions[index]; const clock = timing(room, index);
    const a = room.answers[uid]?.[index];
    v.round = index; v.startsAt = clock.start; v.deadline = clock.end;
    if (time >= clock.start) {
      v.questionId = hash(room.id + "|" + index + "|" + q.id);
      v.question = {kind: q.kind, ...q.public};
      if (q.kind === "mystery_duel" || q.kind === "transfer" && q.timedHints) {
        // Hints open on the question's own schedule (older rooms: every 10 s).
        const open = q.hintAt ? q.hintAt.filter((ms) => time - clock.start >= ms).length :
          Math.floor((time - clock.start) / 10000);
        v.question.hints = (q.timedHints || []).slice(0, open);
      }
      if (["mystery_duel", "fake_club_duel", "career_race", "transfer_duel"].includes(room.mode)) {
        v.roundToken = roundToken(room, index);
      }
    }
    v.submitted = !!a;
    if (time >= clock.end || room.mode === "fake_club_duel" && a && room.answers[other]?.[index]) {
      if (q.explanation) v.explanation = q.explanation;
      v.reveal = q.answer; v.opponentAnswer = room.answers[other]?.[index]?.value ?? null;
      v.correct = a?.correct || false;
    }
  }
  if (["finished", "forfeit"].includes(room.status)) {
    v.result = room.winner == null ? "draw" : room.winner === uid ? "win" : "loss";
    // A player who answered nothing earns no ranked reward in any duel.
    v.rewardEligible = room.status === "finished" && room.ranked && Object.keys(room.answers[uid] || {}).length > 0;
    v.rounds = room.questions.map((q, i) => ({kind: q.kind, ...q.public, answer: q.answer,
      ...(q.explanation ? {explanation: q.explanation, evidence: q.evidence} : {}),
      mine: room.answers[uid]?.[i] || null, theirs: room.answers[other]?.[i] || null}));
  }
  return v;
}
function createService({db, isLinked, blocked, settleRanked, getFakePolicy = async () => ({}), now = Date.now,
  random = () => crypto.randomBytes(16).toString("hex")}) {
  async function change(mode, fn) {
    let error; const time = now();
    const tx = await db.ref(`careerTransferOnline/${mode}`).transaction((raw) => {
      error = null; const s = {rooms: {}, queue: {}, active: {}, requests: {}, ...raw};
      try {
        fn(s, time); return s;
      } catch (err) {
        error = err; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "İsteği tekrar gönder.");
    return {rooms: {}, queue: {}, active: {}, requests: {}, ...tx.snapshot.val()};
  }
  function check(input) {
    if (!MODES.includes(input.mode) || input.version !== modeVersion(input.mode)) {
      fail("failed-precondition", "Online sürüm güncellendi; yeniden aç.");
    }
  }
  async function enter(uid, input) {
    check(input);
    if (!await isLinked(uid)) fail("permission-denied", "Online oyun için Google hesabını bağla.");
    if (!validId(input.requestId) || !["create", "join", "ranked", "resume"].includes(input.action)) {
      fail("invalid-argument", "Geçersiz oda isteği.");
    }
    if (input.action === "join" && !/^[A-F0-9]{8}$/.test(input.code || "")) {
      fail("invalid-argument", "Oda kodu 8 karakter.");
    }
    const policy = fakeClub.policyOf(await getFakePolicy());
    if (input.mode === "fake_club_duel" && input.action !== "resume" &&
      (!policy.dataEnabled || !policy.friendsEnabled || input.action === "ranked" && !policy.rankedEnabled)) {
      fail("failed-precondition", "Sahte Kulüp Düellosu bu eşleşme türünde henüz açılmadı.");
    }
    const seed = random(); const bank = input.action === "resume" ? [] : questions(input.mode, seed, policy);
    // Block lists are read server-side; clients cannot choose opponents in ranked.
    const denied = await blocked(uid);
    const peers = new Set();
    if (input.action === "join") {
      const room = (await db.ref(`careerTransferOnline/${input.mode}/rooms/${input.code}`).get()).val();
      if (room?.host) peers.add(room.host);
    } else if (input.action === "ranked") {
      const queue = (await db.ref(`careerTransferOnline/${input.mode}/queue`).get()).val() || {};
      for (const peer of Object.keys(queue)) if (peer !== uid) peers.add(peer);
    }
    const allowedPeers = new Set();
    await Promise.all([...peers].map(async (peer) => {
      if (!denied.has(peer) && await isLinked(peer) && !(await blocked(peer)).has(uid)) allowedPeers.add(peer);
    }));
    const fingerprint = hash(JSON.stringify([input.action, input.code || null]));
    const s = await change(input.mode, (s, time) => {
      const key = uid + "__" + input.requestId;
      if (s.requests[key]?.expired) fail("failed-precondition", "Eski oda süresi doldu; yeni oda oluştur.");
      if (s.requests[key]) {
        if (s.requests[key].fingerprint !== fingerprint) fail("invalid-argument", "İstek başka odaya ait.");
        return;
      }
      const old = roomOf(s.rooms[s.active[uid]]);
      if (old) {
        advance(old, time); s.rooms[old.id] = old;
        if (old.status === "playing" || old.status === "waiting") {
          if (input.action !== "resume" && (old.ranked !== (input.action === "ranked") ||
              input.action === "join" && input.code !== old.code)) {
            fail("already-exists", "Bu modda devam eden başka maçın var. Önce kayıtlı maçını tamamla veya iptal et.");
          }
          s.requests[key] = {id: old.id, fingerprint}; return;
        }
        if (input.action === "resume") {
          s.requests[key] = {id: old.id, fingerprint}; return;
        }
      }
      if (input.action === "resume") fail("not-found", "Devam eden maç bulunamadı.");
      let room;
      if (input.action === "join") {
        room = roomOf(s.rooms[input.code]);
        if (!room || room.ranked || room.status !== "waiting" || room.createdAt + 300000 <= time || room.host === uid) {
          fail("failed-precondition", "Oda dolu, süresi dolmuş veya bulunamadı.");
        }
        if (!allowedPeers.has(room.host) || denied.has(room.host) || (room.blocked || []).includes(uid)) {
          fail("permission-denied", "Bu odaya katılamazsın.");
        }
      } else if (input.action === "ranked") {
        for (const [id, entry] of Object.entries(s.queue)) {
          if (entry.at + 30000 <= time) {
            delete s.queue[id]; continue;
          }
          const candidate = roomOf(s.rooms[entry.id]);
          if (id !== uid && !denied.has(id) && (!peers.has(id) || allowedPeers.has(id)) &&
              candidate?.status === "waiting" && expiresAt(candidate) > time &&
              !(candidate.blocked || []).includes(uid)) {
            room = candidate; delete s.queue[id]; break;
          }
        }
      }
      if (room) {
        room.guest = uid; room.status = "playing"; room.startedAt = time + 5000;
        room.presence = {[uid]: time, [room.host]: time};
        delete s.queue[uid];
      } else {
        const code = hash(uid + input.requestId).slice(0, 8).toUpperCase();
        if (s.rooms[code]) fail("already-exists", "Yeni oda isteği oluştur.");
        room = {id: code, code, host: uid, guest: null, ranked: input.action === "ranked", blocked: [...denied],
          status: "waiting", mode: input.mode, version: modeVersion(input.mode), questions: bank, createdAt: time,
          answers: {}, receipts: {}, presence: {[uid]: time}};
        if (room.ranked) s.queue[uid] = {id: code, at: time};
      }
      s.rooms[room.id] = room; s.active[uid] = room.id; s.active[room.host] = room.id;
      s.requests[key] = {id: room.id, fingerprint};
    });
    const room = roomOf(s.rooms[s.requests[uid + "__" + input.requestId].id]);
    return {room: view(room, uid, now())};
  }
  async function act(uid, input) {
    check(input);
    if (!/^[A-F0-9]{8}$/.test(input.roomId || "") || !["poll", "answer", "leave"].includes(input.action)) {
      fail("invalid-argument", "Geçersiz maç işlemi.");
    }
    if (input.action !== "poll" && !validId(input.requestId)) fail("invalid-argument", "İşlem kimliği gerekli.");
    const s = await change(input.mode, (s, time) => {
      const room = roomOf(s.rooms[input.roomId]);
      if (!room || ![room.host, room.guest].includes(uid)) fail("permission-denied", "Bu maçın oyuncusu değilsin.");
      const fingerprint = hash(JSON.stringify([input.action, input.round ?? null, input.answer ?? null,
        input.roundToken ?? null]));
      if (input.requestId && room.receipts[uid + input.requestId]) {
        if (room.receipts[uid + input.requestId] !== fingerprint) fail("invalid-argument", "İstek başka cevaba ait.");
        advance(room, time); s.rooms[room.id] = room; return;
      }
      advance(room, time);
      if (input.action === "leave") {
        if (room.status === "waiting") room.status = "cancelled";
        else if (room.status === "playing") {
          room.status = "forfeit"; room.winner = uid === room.host ? room.guest : room.host; room.finishedAt = time;
        }
        delete s.queue[uid];
      } else if (input.action === "answer") {
        if (room.status !== "playing" || !Number.isInteger(input.round) || !room.questions[input.round]) {
          fail("failed-precondition", "Tur açık değil.");
        }
        const q = room.questions[input.round]; const clock = timing(room, input.round);
        if (["mystery_duel", "fake_club_duel", "career_race", "transfer_duel"].includes(room.mode) &&
            input.roundToken !==
            roundToken(room, input.round)) {
          fail("failed-precondition", "Tur kimliği güncel değil. Yeniden bağlan.");
        }
        if (time < clock.start || time >= clock.end) {
          fail("failed-precondition", "Tur süresi dışında cevap kabul edilmez.");
        }
        room.answers[uid] ||= {};
        if (room.answers[uid][input.round]) fail("already-exists", "Bu tur için kesin cevabın kaydedildi.");
        if (q.kind === "order") {
          if (!Array.isArray(input.answer) || input.answer.length !== 3 || new Set(input.answer).size !== 3 ||
              input.answer.some((id) => !q.public.options.some((o) => o.id === id))) {
            fail("invalid-argument", "Üç farklı dönemi sırala.");
          }
        } else if (!Number.isSafeInteger(input.answer) || (q.kind === "transfer" ? !players.has(input.answer) :
          !q.public.options.some((o) => o.id === input.answer))) fail("invalid-argument", "Geçerli cevap seç.");
        const correct = q.accepted ? q.accepted.includes(input.answer) :
          JSON.stringify(input.answer) === JSON.stringify(q.answer);
        const elapsed = time - clock.start;
        // Transfer Duel: every hint already open lowers the base score.
        const base = 100 - (q.kind === "transfer" && q.timedHints ?
          TRANSFER_HINT_MS.filter((ms) => elapsed >= ms).length * TRANSFER_HINT_COST : 0);
        // Mystery Duel: no speed bonus before the first hint; full bonus right when it opens.
        const from = q.hintAt ? q.hintAt[0] : 0;
        const bonus = elapsed < from ? 0 : Math.floor(50 * (q.duration - elapsed) / (q.duration - from));
        room.answers[uid][input.round] = {value: input.answer, correct, elapsed,
          score: correct ? (base + bonus) * (q.multiplier || 1) : 0};
      }
      room.presence[uid] = time;
      if (room.status !== "waiting") delete s.queue[uid];
      // Polling is presence, not an extension of the 30-second matchmaking window.
      if (room.status === "waiting" && room.ranked) s.queue[uid] = {id: room.id, at: room.createdAt};
      if (input.requestId) room.receipts[uid + input.requestId] = fingerprint;
      s.rooms[room.id] = room;
    });
    const room = roomOf(s.rooms[input.roomId]);
    if ((room.status === "finished" || room.mode === "fake_club_duel" && room.status === "forfeit") &&
        room.ranked && !room.settled) {
      await settleRanked(room);
    }
    return {room: view(room, uid, now())};
  }
  async function sweep() {
    for (const mode of MODES) {
      const state = await change(mode, (s, time) => {
        for (const [id, raw] of Object.entries(s.rooms)) {
          const room = roomOf(raw); advance(room, time);
          s.rooms[id] = room;
          if (room.createdAt + 7 * 86400000 < time) {
            delete s.rooms[id];
            for (const [uid, active] of Object.entries(s.active)) if (active === id) delete s.active[uid];
            for (const r of Object.values(s.requests)) if (r.id === id) r.expired = true;
          }
        }
        for (const [uid, q] of Object.entries(s.queue)) {
          if (q.at + 30000 <= time || s.rooms[q.id]?.status !== "waiting") delete s.queue[uid];
        }
      });
      for (const room of Object.values(state.rooms)) {
        if ((room.status === "finished" || room.mode === "fake_club_duel" && room.status === "forfeit") &&
        room.ranked && !room.settled) {
          await settleRanked(room);
        }
      }
    }
  }
  return {enter, act, sweep};
}
module.exports = {createService, questions, timing, totals, outcome, advance, view, roundToken,
  TRANSFER_MIX, TRANSFER_HINT_COST, TRANSFER_KNOWN_RANK, MYSTERY_MIX, MYSTERY_HINT_MS, hintClubs,
  FAKE_MIX, FAKE_FINAL_MULTIPLIER};
