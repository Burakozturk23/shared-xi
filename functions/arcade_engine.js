"use strict";
const crypto = require("node:crypto");
const {normalize} = require("./daily_words");
const {shuffled} = require("./career_transfer");
const {RewardError} = require("./rewarded_ads");
const catalog = require("./config/arcade_catalog.json");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const list = (x) => Array.isArray(x) ? x : Object.values(x || {});
const edge = (c, a, b) => c.edges[[a, b].sort().join("|")] || null;
const label = (c, evidence) => evidence.type === "nationality" ? "Doğrulanmış milliyet" :
  `${evidence.type === "sharedClub" ? "Ortak kulüp" : "A takım kariyeri"}: ${c.clubs[evidence.clubId].name}`;
function solve(c, board, input, budget = 18000) {
  const filled = {...input}; const used = new Set(Object.values(filled));
  if (used.size !== Object.keys(filled).length) return null;
  const neighbours = Object.fromEntries(board.slots.map((x) => [x.id, []]));
  for (const slot of board.slots) {
    for (const id of slot.supports) {
      neighbours[slot.id].push(id); neighbours[id].push(slot.id);
    }
  }
  for (const [id, value] of Object.entries(filled)) {
    if (!c.entities[value] || !neighbours[id] || neighbours[id].some((n) => filled[n] && !edge(c, value,
        filled[n]))) return null;
  }
  // A compatible saved certificate makes ordinary moves constant-time.
  if (Object.entries(filled).every(([k, v]) => board.certificate[k] === v)) return {...board.certificate};
  let visits = 0; const keys = Object.keys(c.entities);
  function walk() {
    if (++visits > budget) return null;
    let target; let choices;
    for (const slot of board.slots) {
      if (filled[slot.id]) continue;
      const known = neighbours[slot.id].filter((n) => filled[n]);
      const domain = keys.filter((id) => !used.has(id) && known.every((n) => edge(c, id, filled[n])));
      if (!domain.length) return null;
      if (!choices || domain.length < choices.length) {
        target = slot.id; choices = domain;
      }
    }
    if (!target) {
      const interior = board.slots.filter((x) => !Object.hasOwn(board.initial, x.id)).map((x) => filled[x.id]);
      const common = c.entities[interior[0]].clubs.filter((club) =>
        interior.every((id) => c.entities[id].clubs.includes(club)));
      return common.length ? null : {...filled};
    }
    choices.sort((a, b) => Number(b === board.certificate[target]) - Number(a === board.certificate[target]));
    for (const value of choices) {
      filled[target] = value; used.add(value);
      const result = walk(); if (result) return result;
      delete filled[target]; used.delete(value);
      if (visits > budget) break;
    }
    return null;
  }
  return walk();
}
function matching(c, difficulty, seed) {
  const count = c.policy.matchingPairs[difficulty];
  const all = c.careers.flatMap((p) => p.clubs.map((clubId) => ({playerId: p.playerId, clubId,
    excluded: p.excluded, sources: p.sources})));
  for (let attempt = 0; attempt < 40; attempt++) {
    const choices = shuffled(all, seed + ":" + attempt);
    // Recognisability combines player ranking, familiar club and readable labels.
    if (difficulty === "easy") {
      choices.sort((a, b) =>
        (c.players[a.playerId].rank / 1000 - c.clubs[a.clubId].popularity / 10 + c.clubs[a.clubId].name.length / 10) -
      (c.players[b.playerId].rank / 1000 - c.clubs[b.clubId].popularity / 10 + c.clubs[b.clubId].name.length / 10));
    }
    const pairs = []; const names = new Set();
    for (const p of choices) {
      const pn = normalize(c.players[p.playerId].name); const cn = normalize(c.clubs[p.clubId].name);
      if (pn === cn || names.has(pn) || names.has(cn) || pairs.some((q) => q.playerId === p.playerId ||
        q.clubId === p.clubId || q.excluded.includes(p.clubId) || p.excluded.includes(q.clubId))) continue;
      pairs.push(p); names.add(pn); names.add(cn);
      if (pairs.length === count) {
        const cards = shuffled(pairs.flatMap((p, i) => [
          {id: `p${i}`, pair: i, type: "player", entityId: p.playerId, name: c.players[p.playerId].name},
          {id: `c${i}`, pair: i, type: "club", entityId: p.clubId, name: c.clubs[p.clubId].name},
        ]), seed + ":layout");
        return {id: seed, seed, cards, pairs, count};
      }
    }
  }
  fail("unavailable", "Bu zorlukta çapraz bağı olmayan yeterli çift bulunamadı. Enerji harcanmadı.");
}
function tier(r) {
  return ["easy", "normal", "hard", "legend"][Math.min(3, Math.floor(r.rounds / 3))];
}
function round(c, r) {
  const pool = c.burst.filter((q) => q.pairType === r.pairType && !r.used.includes(q.id) &&
    (r.style === "speed" || q.difficulty === tier(r)));
  const rank = (q) => crypto.createHash("sha256").update(`${r.id}:${r.used.length}:${q.id}`).digest("hex");
  const q = pool.map((q) => ({q, rank: rank(q)})).sort((a, b) => a.rank.localeCompare(b.rank))[0]?.q;
  if (!q || q.answers.length < 6) {
    r.finished = true; r.reason = "Doğrulanmış soru havuzu tükendi."; return;
  }
  r.question = q; r.used.push(q.id); r.found = []; r.hinted = []; r.hint = "";
  r.roundAt = r.activeMs;
}
function create(c, input, time) {
  const r = {id: input.requestId, mode: input.mode, style: input.style || "speed", pairType: input.pairType ||
    "clubClub",
  difficulty: input.difficulty || "normal", dataVersion: c.version, revision: 0, phase: "prepared",
  createdAt: time, expiresAt: time + 86400000, activeMs: 0, lastAt: time, paused: true,
  finished: false, won: false, lives: 5, score: 0, correct: 0, wrong: 0, hints: 0, passes: 0,
  rounds: 0, streak: 0, bestStreak: 0, moves: 0, actions: {}, history: [], filled: {}, undo: [],
  wrongInputs: {}, used: [], found: [], hinted: [], matched: [], open: [], lockUntil: 0,
  adCredits: 0, adGranted: 0, adReceipts: {}, freeUsed: false, earnedCoins: 0, rewardKeys: [], message: ""};
  if (r.mode === "burst") {
    round(c, r);
    if (r.finished) fail("unavailable", "Doğrulanmış soru bulunamadı. Enerji harcanmadı.");
  } else if (r.mode === "pyramid") {
    r.board = shuffled(c.pyramids.filter((b) => b.difficulty === r.difficulty), r.id)[0];
    if (!r.board || !solve(c, r.board, r.board.initial)) {
      fail("unavailable",
          "Çözülebilir tahta bulunamadı; enerji harcanmadı.");
    }
    r.filled = {...r.board.initial};
  } else r.board = matching(c, r.difficulty, r.id);
  return r;
}
function hydrate(r) {
  if (!r) return null;
  for (const k of ["used", "found", "hinted", "history", "undo", "matched", "open", "rewardKeys"]) r[k] = list(r[k]);
  for (const k of ["actions", "filled", "wrongInputs", "adReceipts"]) r[k] ||= {};
  if (r.board?.initial) r.board.initial = Object.fromEntries(Object.entries(r.board.initial).filter(([, v]) => v));
  if (r.board?.slots) r.board.slots = list(r.board.slots).map((s) => ({...s, supports: list(s.supports)}));
  if (r.board?.cards) {
    r.board.cards = list(r.board.cards); r.board.pairs = list(r.board.pairs);
  }
  r.filled = Object.fromEntries(Object.entries(r.filled).filter(([, value]) => value != null));
  if (r.question) r.question.answers = list(r.question.answers);
  return r;
}
function tick(c, r, time) {
  if (r.finished || r.phase !== "active") return;
  if (!r.paused) r.activeMs += Math.max(0, time - r.lastAt);
  r.lastAt = time;
  if (r.mode === "matching" && r.lockUntil && time >= r.lockUntil) {
    r.open = []; r.lockUntil = 0;
  }
  if (time >= r.expiresAt) {
    r.finished = true; r.reason = "24 saatlik devam süresi doldu.";
  }
  if (r.mode === "burst" && r.style === "speed") {
    if (r.activeMs + (r.penaltyMs || 0) >= 120000) {
      r.finished = true; r.reason = "Toplam süre doldu.";
    } else if (r.activeMs - r.roundAt >= 30000) {
      r.history.push({question: r.question.id, found: r.found, cause: "timeout"}); r.streak = 0;
      round(c, r); r.message = "Tur süresi doldu. Yeni tur.";
    }
  }
}
const nameIndexes = new WeakMap();
function resolve(c, query, entityId, mode) {
  const pool = mode === "pyramid" ? c.entities : c.players;
  if (entityId) return pool[entityId] ? entityId : null;
  const q = normalize(String(query || "").slice(0, 120)); if (!q) return null;
  let index = nameIndexes.get(pool);
  if (!index) {
    index = new Map();
    for (const p of Object.values(pool)) {
      for (const name of [p.name, ...(p.aliases || [])]) {
        const key = normalize(name); const ids = index.get(key) || new Set(); ids.add(p.id); index.set(key, ids);
      }
    }
    nameIndexes.set(pool, index);
  }
  const matches = index.get(q);
  return matches?.size === 1 ? [...matches][0] : null;
}
function act(c, r, input, time) {
  r.message = "";
  if (input.action === "finish") {
    r.finished = true; r.reason = "Oyunu bitirdin."; return;
  }
  if (input.action === "pause") {
    r.paused = true; r.open = []; // lockUntil deliberately persists, including across pause/restart.
    return;
  }
  if (input.action === "resume") {
    r.paused = false; r.lastAt = time; r.open = []; return;
  }
  if (input.action === "tick") return;
  if (r.paused) fail("failed-precondition", "Önce oyuna devam et.");
  if (r.mode === "burst") {
    if (input.questionId !== r.question.id) fail("aborted", "Tur değişti; güncel soruyu kullan.");
    if (input.action === "pass") {
      if (r.passes >= 2) fail("resource-exhausted", "İki pas hakkın kullanıldı.");
      r.passes++; r.streak = 0; if (r.style === "speed") r.penaltyMs = (r.penaltyMs || 0) + 5000;
      r.history.push({question: r.question.id, found: r.found, cause: "pass"}); round(c, r);
    } else if (input.action === "hint") {
      if (r.style !== "survival") fail("failed-precondition", "Hız Atağı ipucu içermez.");
      const player = r.question.answers.map((id) => c.players[id]).find((p) => !r.found.includes(p.id) &&
        !r.hinted.includes(p.id));
      if (!player) fail("failed-precondition", "Yeni ipucu kalmadı.");
      if (r.boostPolicy?.version !== 1) {
        if (!r.freeUsed) r.freeUsed = true;
        else if (r.adCredits > 0) r.adCredits--;
        else fail("resource-exhausted", "Ücretsiz ipucu kullanıldı. Doğrulanmış reklam hakkı gerekli.");
      }
      r.hints++; r.hinted.push(player.id);
      r.hint = player.name.split(/\s+/).map((s) => s[0] + ".").join(" ") + " · " + player.country;
    } else if (input.action === "answer") {
      const id = resolve(c, input.query, input.entityId, "burst");
      if (!id) {
        r.message = "Oyuncu bulunamadı veya ad belirsiz. Listeden seç; ceza yok."; return;
      }
      if (r.found.includes(id)) {
        r.message = "Bu oyuncuyu zaten buldun."; return;
      }
      if (!r.question.answers.includes(id)) {
        r.wrong++; r.streak = 0;
        if (r.style === "speed") r.penaltyMs = (r.penaltyMs || 0) + 3000; else r.lives--;
        r.message = r.style === "speed" ? "Bu eşleşme doğru değil. −3 saniye." : "Bu eşleşme doğru değil. −1 can.";
      } else {
        r.found.push(id); r.correct++; r.streak++; r.bestStreak = Math.max(r.streak, r.bestStreak);
        r.score += 100 * (r.streak >= 10 ? 2 : r.streak >= 5 ? 1.5 : 1);
        if (r.found.length === 3) {
          r.rounds++; r.score += 50; r.history.push({question: r.question.id, found: r.found, cause: "complete"});
          if (r.style === "survival" && r.rounds >= 12) {
            r.finished = true; r.won = true; r.reason = "12 tur tamamlandı!";
          } else {
            round(c, r); r.message = "3/3 · +50 tur bonusu!";
          }
        }
      }
      if (r.lives <= 0) {
        r.finished = true; r.reason = "Canların bitti.";
      }
    } else fail("invalid-argument", "Geçersiz Burst işlemi.");
    tick(c, r, time);
  } else if (r.mode === "pyramid") {
    if (input.action === "undo") {
      const previous = r.undo.pop(); if (previous) {
        delete r.filled[previous]; r.correct--; r.score = r.correct * 100;
      }
      return;
    }
    const slot = r.board.slots.find((x) => x.id === String(input.slotId));
    if (!slot || r.filled[slot.id] || slot.supports.length !== 2 || slot.supports.some((s) => !r.filled[s])) {
      fail("failed-precondition", "İki alt desteği dolu bir boş hücre seç.");
    }
    if (input.action === "hint") {
      if (r.hints >= (r.difficulty === "hard" ? 1 : 2)) fail("resource-exhausted", "Bu tahtanın ipuçları kullanıldı.");
      const solution = solve(c, r.board, r.filled);
      if (!solution) fail("unavailable", "Çözüm kontrolü tamamlanamadı. Hak harcanmadı.");
      const candidate = c.entities[solution[slot.id]]; r.hints++;
      const type = {player: "Oyuncu", club: "Kulüp", country: "Ülke"}[candidate.type];
      r.hint = `Aday türü: ${type}. ` + label(c, edge(c, candidate.id, r.filled[slot.supports[0]]));
    } else if (input.action === "answer") {
      const id = resolve(c, input.query, input.entityId, "pyramid");
      if (!id || Object.values(r.filled).includes(id)) {
        r.message = "Belirsiz, bilinmeyen veya kullanılmış ad; can kaybı yok."; return;
      }
      const supports = slot.supports.map((s) => r.filled[s]); if (slot.row === 1) supports.push(r.filled["0"]);
      if (supports.some((s) => !edge(c, id, s))) {
        const k = slot.id + "__" + id;
        if (!r.wrongInputs[k]) {
          r.wrongInputs[k] = true; r.wrong++; r.lives--;
        }
        r.message = "Gerekli kariyer/milliyet bağlantılarının tümü bulunmuyor. Aynı cevap yeniden can götürmez.";
        if (r.lives <= 0) {
          r.finished = true; r.reason = "Beş canın bitti.";
        }
        return;
      }
      const solution = solve(c, r.board, {...r.filled, [slot.id]: id});
      if (!solution) {
        r.message = "Bu seçimden sonra kalan çözüm doğrulanamadı. Can kaybı yok; başka aday dene."; return;
      }
      r.filled[slot.id] = id; r.board.certificate = solution; r.undo.push(slot.id); r.correct++; r.score += 100;
      r.message = supports.map((s) => label(c, edge(c, id, s))).join(" · ");
      if (Object.keys(r.filled).length === r.board.slots.length) {
        r.finished = true; r.won = true; r.reason = "Piramidin tüm bağları tamamlandı!";
      }
    } else fail("invalid-argument", "Geçersiz Pyramid işlemi.");
  } else {
    if (input.action === "hint") {
      if (!require("./boosts").paid(r)) fail("failed-precondition", "Bu oyunda çift desteği açık değil.");
      if (r.lockUntil > time || r.open.length) fail("failed-precondition", "Önce açık kartları tamamla.");
      if (r.hints >= 1) fail("resource-exhausted", "Bu oyunun çift önerisi kullanıldı.");
      const player = r.board.cards.find((x) => x.type === "player" && !r.matched.includes(x.pair));
      const club = player && r.board.cards.find((x) => x.type === "club" && x.pair === player.pair);
      const career = player && c.careers.find((x) => x.playerId === player.entityId);
      if (!club || !career?.clubs.includes(club.entityId) || !career.sources?.length) {
        fail("unavailable", "Doğrulanmış çift bulunamadı; destek harcanmadı.");
      }
      const cards = [player, club].map((x) => ({id: x.id, position: r.board.cards.indexOf(x) + 1,
        name: x.name}));
      r.matchingHint = {cards, sources: career.sources};
      r.hint = cards.map((x) => `${x.position}. kart: ${x.name}`).join(" · ");
      r.hints++;
      return;
    }
    if (input.action !== "flip") fail("invalid-argument", "Geçersiz Matching işlemi.");
    if (r.lockUntil > time) fail("failed-precondition", "Kartlar kapanana kadar bekle.");
    const card = r.board.cards.find((x) => x.id === input.cardId);
    if (!card || r.open.includes(card.id) || r.matched.includes(card.pair)) return;
    r.open.push(card.id);
    if (r.open.length === 2) {
      r.moves++;
      const first = r.board.cards.find((x) => x.id === r.open[0]);
      if (first.pair === card.pair) {
        r.matched.push(card.pair); r.open = []; r.correct++;
      } else {
        r.lockUntil = time + 1000; r.wrong++;
      }
      if (r.matched.length === r.board.count) {
        r.finished = true; r.won = true; r.reason = "Tüm çiftler bulundu!";
        r.stars = r.moves <= r.board.count * c.policy.stars.threePerPair ? 3 :
          r.moves <= r.board.count * c.policy.stars.twoPerPair ? 2 : 1;
      }
    }
  }
}
function publicRun(c, raw, time) {
  const r = hydrate(raw); if (!r) return null;
  const {question, board, filled, undo, history} = r;
  const support = require("./boosts").view(r);
  const v = {...r, ...(support ? {support} : {})};
  delete v.boostPolicy; delete v.boostUses;
  for (const key of ["actions", "question", "board", "filled", "undo", "wrongInputs", "adReceipts", "history",
    "used", "hinted"]) delete v[key];
  v.serverNow = time; v.totalRemainingMs = Math.max(0, 120000 - r.activeMs - (r.penaltyMs || 0));
  v.roundRemainingMs = Math.max(0, 30000 - (r.activeMs - (r.roundAt || 0)));
  if (r.mode === "burst") {
    v.roundIds = r.used; v.hintedIds = r.hinted;
    v.question = {id: question.id, left: question.left, right: question.right, difficulty: question.difficulty};
    v.found = r.found.map((id) => ({id, name: c.players[id].name}));
    if (r.finished) {
      v.history = [...history, ...(!history.some((x) => x.question === question.id) ? [{question: question.id,
        found: r.found, cause: "end"}] : [])].map((x) => {
        const q = c.burst.find((q) => q.id === x.question);
        return {...x, title: q.left + " × " + q.right,
          missed: q.answers.filter((id) => !list(x.found).includes(id)).map((id) => c.players[id].name)};
      });
    }
  }
  if (r.mode === "pyramid") {
    v.board = {id: board.id, levels: board.levels, slots: board.slots, initial: Object.keys(board.initial)};
    v.filled = Object.fromEntries(Object.entries(filled).map(([k, id]) => [k, c.entities[id]]));
    v.canUndo = undo.length > 0;
    if (r.finished) {
      v.solution = Object.fromEntries(Object.entries(board.certificate).map(([k, id]) => [k,
        c.entities[id]]));
      v.solutionProof = board.slots.flatMap((slot) => slot.supports.map((n) => ({
        from: slot.id, to: n, evidence: label(c, edge(c, board.certificate[slot.id], board.certificate[n])),
      })));
    }
  }
  if (r.mode === "matching") {
    v.board = {id: board.id, count: board.count, cards: board.cards.map((card) =>
      r.finished || r.open.includes(card.id) || r.matched.includes(card.pair) ? {...card, visible: true,
        matched: r.matched.includes(card.pair)} : {id: card.id, visible: false})};
    if (r.finished) {
      v.proof = board.pairs.map((p) => ({player: c.players[p.playerId].name,
        club: c.clubs[p.clubId].name, sources: p.sources}));
    }
  }
  return v;
}
module.exports = {catalog, create, hydrate, tick, act, publicRun, solve, matching, edge, label, resolve, fail, list};
