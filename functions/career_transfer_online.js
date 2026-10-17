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
const fail = (c, m) => {
  throw new RewardError(c, m);
};
function questions(mode, seed, policy = fakeClub.policyOf({})) {
  if (mode === "fake_club_duel") {
    const run = {id: seed, mode: "fake_speed", answers: 0, usedPlayers: []}; const bank = [];
    for (let i = 0; i < 10; i++) {
      const q = fakeClub.pick(fakeClub.catalog, run, policy);
      if (!q) fail("failed-precondition", "On farklı doğrulanmış futbolcu bulunamadı.");
      run.usedPlayers.push(q.playerId); run.answers++;
      bank.push({id: q.questionId, kind: "fake_club_duel", duration: 10000, answer: q.fakeClubId,
        explanation: fakeClub.explanation(q), evidence: q.evidence,
        public: {player: q.player, dataVersion: q.dataVersion, difficulty: q.difficulty,
          options: q.options.map(({popularity, ...club}) => club)}});
    }
    return bank;
  }
  if (mode === "mystery_duel") {
    return shuffled(mysteryCatalog.mystery, seed).slice(0, 5).map((p, i) => {
      const options = shuffled(p.options.filter((id) => id !== p.playerId), seed + i).slice(0, 3);
      return {id: p.id, kind: "mystery_duel", duration: 30000, answer: p.playerId,
        timedHints: [p.hints[0].text, p.hints[1].text],
        public: {country: p.country, position: p.position,
          options: shuffled([p.playerId, ...options], seed + i).map((id) => playerView(players.get(id)))}};
    });
  }
  if (mode === "transfer_duel") {
    return shuffled(catalog.transfers, seed).slice(0, 5).map((p) => ({
      id: p.id, kind: "transfer", duration: 30000, answer: p.playerId,
      public: {from: clubs.get(p.fromClubId), to: clubs.get(p.toClubId), year: p.year},
    }));
  }
  const chosen = shuffled(catalog.careers, seed).slice(0, 6);
  return chosen.map((p, i) => {
    const rng = seed + i;
    if (i < 3) {
      const slot = parseInt(hash(rng).slice(0, 8), 16) % p.stops.length;
      const answer = p.stops[slot].clubId;
      const distractors = shuffled([...clubs.values()].filter((c) => !p.stops.some((s) => s.clubId === c.id)), rng)
          .slice(0, 3).map((c) => c.id);
      return {id: p.id + "_missing", kind: "missing", duration: 20000, answer,
        public: {player: playerView(players.get(p.playerId)),
          route: p.stops.map((s, j) => j === slot ? "?" : clubs.get(s.clubId).name),
          options: shuffled([answer, ...distractors], rng).map((id) => ({id, name: clubs.get(id).name}))}};
    }
    if (i < 5) {
      const stops = p.stops.slice(0, 3);
      return {id: p.id + "_order", kind: "order", duration: 25000, answer: stops.map((s) => s.id),
        public: {player: playerView(players.get(p.playerId)), options: shuffled(stops, rng).map((s) => ({
          id: s.id, name: clubs.get(s.clubId).name + (stops.filter((x) => x.clubId === s.clubId).length > 1 ?
            ` (${stops.filter((x) => x.clubId === s.clubId).indexOf(s) + 1}. dönem)` : ""),
        }))}};
    }
    const distractors = shuffled(catalog.careers.filter((x) => x.playerId !== p.playerId), rng)
        .slice(0, 3).map((x) => x.playerId);
    return {id: p.id + "_mystery", kind: "mystery", duration: 20000, answer: p.playerId,
      public: {route: p.stops.map((s) => clubs.get(s.clubId).name),
        options: shuffled([p.playerId, ...distractors], rng).map((id) => ({id, name: players.get(id).name}))}};
  });
}
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
function advance(room, time) {
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
    serverNow: time, host: uid === room.host, opponent: other || null, version: room.version,
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
      if (q.kind === "mystery_duel") {
        v.question.hints = (q.timedHints || []).slice(0, Math.floor((time - clock.start) / 10000));
      }
      if (["mystery_duel", "fake_club_duel"].includes(q.kind)) {
        v.roundToken = hash(room.id + "|" + index + "|" + room.version + "|" + clock.start);
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
    v.rewardEligible = room.status === "finished" && room.ranked &&
      (!["mystery_duel", "fake_club_duel"].includes(room.mode) || Object.keys(room.answers[uid] || {}).length > 0);
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
        if (old.status === "playing" || old.status === "waiting" && old.createdAt + 300000 > time) {
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
        if (denied.has(room.host) || (room.blocked || []).includes(uid)) {
          fail("permission-denied", "Bu odaya katılamazsın.");
        }
      } else if (input.action === "ranked") {
        for (const [id, entry] of Object.entries(s.queue)) {
          if (entry.at + 30000 <= time) {
            delete s.queue[id]; continue;
          }
          const candidate = roomOf(s.rooms[entry.id]);
          if (id !== uid && !denied.has(id) && candidate?.status === "waiting" &&
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
        if (["mystery_duel", "fake_club_duel"].includes(room.mode) && input.roundToken !==
            hash(room.id + "|" + input.round + "|" + room.version + "|" + clock.start)) {
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
        const correct = JSON.stringify(input.answer) === JSON.stringify(q.answer);
        const elapsed = time - clock.start;
        room.answers[uid][input.round] = {value: input.answer, correct, elapsed,
          score: correct ? 100 + Math.floor(50 * (q.duration - elapsed) / q.duration) : 0};
      }
      room.presence[uid] = time;
      if (room.status === "waiting" && room.createdAt + 300000 <= time) {
        room.status = "cancelled"; delete s.queue[uid];
      }
      if (room.status === "waiting" && room.ranked) s.queue[uid] = {id: room.id, at: time};
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
          if (room.status === "waiting" && room.createdAt + 300000 <= time) room.status = "cancelled";
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
module.exports = {createService, questions, timing, totals, outcome, advance, view};
