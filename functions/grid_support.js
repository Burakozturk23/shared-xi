"use strict";
const crypto = require("node:crypto");
const P = require("./pvp_engine");
const B = require("./boosts");
const {RewardError} = require("./rewarded_ads");
const catalog = {...P.catalog, version: P.catalog.version + "-grid-v1", criteria: {...P.catalog.criteria,
  ...Object.fromEntries(Object.entries({GK: "Kaleci", DEF: "Defans", MID: "Orta Saha", ATT: "Forvet"})
      .map(([v, label]) =>
        ["position:" + v, {id: "position:" + v, type: "position", value: v, label}]))}};
const MODES = ["solo_grid_classic", "solo_grid_reverse", "solo_grid_random",
  "bot_grid_classic", "bot_grid_reverse", "bot_grid_random"];
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const bot = (r) => r.mode.startsWith("bot_");
const kind = (r) => r.mode.split("_").at(-1);
const pos = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", ATT: "Forvet"};
const lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]];
const criterionPlayers = new Map();
for (const p of Object.values(catalog.players)) {
  for (const id of [...p.clubs.map((v) => "club:" + v), ...p.countryKeys.map((v) => "country:" + v),
    "position:" + p.position]) {
    if (!criterionPlayers.has(id)) criterionPlayers.set(id, new Set());
    criterionPlayers.get(id).add(p.id);
  }
}
function matches(p, id) {
  return criterionPlayers.get(id)?.has(p.id) === true;
}
function intersection(a, b) {
  const left = criterionPlayers.get(a) || new Set(); const right = criterionPlayers.get(b) || new Set();
  return [...(left.size < right.size ? left : right)].filter((id) => (left.size < right.size ? right : left).has(id));
}
function perfect(answers) {
  const owners = new Map(); const witness = [];
  function assign(cell, visited) {
    for (const id of answers[cell]) {
      if (visited.has(id)) continue; visited.add(id);
      if (!owners.has(id) || assign(owners.get(id), visited)) {
        owners.set(id, cell); witness[cell] = id; return true;
      }
    }
    return false;
  }
  return answers.every((_, i) => assign(i, new Set())) ? witness : null;
}
function makePuzzle(r) {
  const clubs = r.pool.length ? r.pool : catalog.clubOptions;
  if (clubs.length < 3) fail("failed-precondition", "En az üç uygun kulüp gerekli.");
  for (let attempt = 0; attempt < 60; attempt++) {
    const rows = P.shuffle(clubs, r.seed + attempt).slice(0, 3);
    const viable = Object.values(catalog.criteria).filter((k) =>
      ["country", "position"].includes(k.type) || k.type === "club" && clubs.includes(k.id) && !rows.includes(k.id))
        .map((k) => k.id).filter((id) => rows.every((row) => intersection(row, id).length >= r.minimumAnswers));
    if (viable.length < 3) continue;
    const cols = P.shuffle(viable, r.seed + "cols" + attempt).slice(0, 3);
    const answers = rows.flatMap((row) => cols.map((col) => intersection(row, col)
        .sort((a, b) => catalog.players[a].rank - catalog.players[b].rank || a.localeCompare(b))));
    const witness = perfect(answers);
    if (witness) return {id: P.hash([rows, cols, witness]), rows, cols, answers, witness};
  }
  fail("failed-precondition", "Bu kulüp seçiminde çözülebilir tahta yok. Havuzu genişlet.");
}
function countryKey(value) {
  const key = P.norm(value);
  return ({turkiye: "turkey", czechia: "czechrepublic", unitedstates: "usa", unitedstatesofamerica: "usa",
    korearepublic: "southkorea", koreasouth: "southkorea", ivorycoast: "cotedivoire",
    bosniaherzegovina: "bosniaandherzegovina", holland: "netherlands", thenetherlands: "netherlands"})[key] || key;
}
function restored(raw) {
  const s = {sessions: {}, active: {}, records: {}, assistedRecords: {}, ...raw};
  for (const r of Object.values(s.sessions)) {
    r.cells ||= {}; r.axes ||= {}; r.used ||= {}; r.actions ||= {}; r.hints ||= {};
    r.rows ||= {}; r.cols ||= {}; r.pool ||= [];
  }
  return s;
}
function random(r, key) {
  return parseInt(P.hash([r.seed, r.revision, key]).slice(0, 8), 16) / 0x100000000;
}
function pick(r, a, key) {
  return a[Math.floor(random(r, key) * a.length)];
}
function open(r) {
  return Array.from({length: kind(r) === "reverse" ? 6 : 9}, (_, i) => i)
      .filter((i) => !(kind(r) === "reverse" ? r.axes[i] : r.cells[i]));
}
function answers(r, target) {
  if (target === "pending") return (r.pending?.answers || []).filter((id) => !r.used?.[id]);
  const i = Number(target); if (!Number.isInteger(i) || i < 0 || i >= 9 || r.cells[i]) return [];
  if (kind(r) === "classic") return r.puzzle.answers[i].filter((id) => !r.used?.[id]);
  if (kind(r) !== "random" || !r.rows[i / 3 | 0] || !r.cols[i % 3]) return [];
  return Object.values(catalog.players).filter((p) => !r.used?.[p.id] &&
    matches(p, r.rows[i / 3 | 0]) && matches(p, r.cols[i % 3])).map((p) => p.id);
}
function axisIds(r, i) {
  return Array.from({length: 3}, (_, j) => r.puzzle.witness[i < 3 ? i * 3 + j : j * 3 + i - 3]);
}
function common(r, i) {
  const ps = axisIds(r, i).map((id) => catalog.players[id]);
  const found = Object.values(catalog.criteria).filter((k) => ["club", "country"].includes(k.type) &&
    ps.every((p) => matches(p, k.id)));
  if (ps.every((p) => p.position === ps[0].position)) {
    found.push({id: "position:" + ps[0].position,
      type: "position", label: pos[ps[0].position]});
  }
  return found;
}
function targetKey(r, target) {
  if (kind(r) === "reverse") {
    const i = Number(target);
    if (!Number.isInteger(i) || i < 0 || i >= 6 || r.axes[i]) fail("failed-precondition", "Bu eksen kapandı.");
    return "axis_" + i;
  }
  if (target === "pending" && r.pending?.playerId) fail("failed-precondition", "Oyuncu zaten doğrulandı.");
  if (!answers(r, target).length) fail("failed-precondition", "Bu hedef için kullanılabilir bilgi yok.");
  return target === "pending" ? "pair_" + r.pairNumber : "cell_" + Number(target);
}
function hint(r, target) {
  const key = targetKey(r, target);
  if (r.hints[key]) fail("failed-precondition", "Bu yardım zaten açıldı.");
  if (kind(r) === "reverse") {
    const k = pick(r, common(r, Number(target)), key);
    if (!k) fail("failed-precondition", "Doğrulanmış ortak kriter yok.");
    return {key, text: "Üçünü bağlayan geçerli kriter türlerinden biri: " +
      ({club: "Kulüp", country: "Milliyet", position: "Mevki"}[k.type]) +
        ". Diğer doğru ortak kriterler de kabul edilir."};
  }
  const ids = answers(r, target).sort((a, b) => catalog.players[a].rank - catalog.players[b].rank);
  const p = catalog.players[ids[0]];
  return {key, text: `Geçerli bir adayın milliyeti ${p.countries.join(" / ")}; ` +
      `mevki grubu ${pos[p.position]}.`};
}
function usable(r, scope) {
  if (!r || r.finished || r.version !== catalog.version) return false;
  try {
    return hint(r, scope.target).key === scope.targetKey;
  } catch (_) {
    return false;
  }
}
function finish(r, reason, time) {
  if (r.finished) return;
  r.finished = true; r.reason = reason; r.finishedAt = time; r.turn = "done";
  r.completed = reason === "completed"; r.masteryEligible = false; r.leaderboardEligible = false;
  r.winner = r.lineWinner || (r.userScore > r.botScore ? 1 : r.userScore < r.botScore ? 2 : 0);
}
function check(r, time) {
  if (bot(r) && kind(r) !== "reverse") {
    for (const owner of [1, 2]) {
      if (lines.some((l) => l.every((i) => r.cells[i]?.owner === owner))) {
        r.lineWinner = owner; finish(r, "completed", time); return;
      }
    }
  }
  if (!open(r).length) finish(r, "completed", time);
}
function claim(r, i, id, owner, time) {
  const p = catalog.players[id]; let bonus = p.rank > 4500 ? 30 : p.rank > 2500 ? 15 : p.rank > 1000 ? 5 : 0;
  if (kind(r) === "random") {
    // Pair-relative rarity uses the complete canonical answer pool, not the question filter.
    const all = Object.values(catalog.players).filter((p) => matches(p, r.rows[i / 3 | 0]) &&
      matches(p, r.cols[i % 3])).sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id));
    const pct = (all.findIndex((p) => p.id === id) + 1) / all.length;
    bonus = pct > .75 ? 30 : pct > .5 ? 15 : pct > .25 ? 5 : 0;
  }
  r.cells[i] = {playerId: id, owner, bonus}; r.used[id] = true;
  if (owner === 1) r.userScore += bot(r) ? 1 : 20 + bonus; else r.botScore++;
  check(r, time);
}
function makePair(r) {
  if (r.roundsUsed >= 3 || r.pending) fail("failed-precondition", "Önce bekleyen çifti tamamla.");
  const used = new Set([...Object.values(r.rows), ...Object.values(r.cols)]);
  const pool = new Set(r.pool);
  const clubs = P.shuffle(pool.size ? [...pool] : catalog.clubOptions, r.seed + r.pairNumber)
      .filter((id) => !used.has(id));
  const pairs = [];
  for (let i = 0; i < clubs.length && !pairs.length; i++) {
    for (let j = i + 1; j < clubs.length; j++) {
      const ids = intersection(clubs[i], clubs[j]);
      if (ids.filter((id) => !r.used[id]).length >= r.minimumAnswers) {
        pairs.push({criteria: [clubs[i], clubs[j]], answers: ids});
      }
    }
  }
  if (!pairs.length) {
    fail(
        "failed-precondition", "Bu havuzda yeni çift yok. Kesişimleri doldurabilir veya bitirebilirsin.");
  }
  r.pending = structuredClone(pick(r, pairs, "pair" + r.pairNumber)); r.pairNumber++;
}
function place(r, i, swap, owner, time) {
  if (![2, 4, 6].includes(i) || r.cells[i] || !r.pending?.playerId || r.rows[i / 3 | 0] || r.cols[i % 3]) {
    fail("failed-precondition", "Uygun bir boş çapa seç.");
  }
  const pair = r.pending; r.rows[i / 3 | 0] = pair.criteria[swap ? 1 : 0];
  r.cols[i % 3] = pair.criteria[swap ? 0 : 1]; r.roundsUsed++; r.pending = null;
  claim(r, i, pair.playerId, owner, time);
}
function schedule(r, time) {
  if (!bot(r) || r.finished) return;
  r.turn = "bot";
  const range = kind(r) === "classic" ? {easy: [900, 1500], medium: [700, 1200], hard: [500, 900]}[r.difficulty] :
    kind(r) === "reverse" ? [1050, 2049] : [1150, 2049];
  r.botAt = time + range[0] + Math.floor(random(r, "delay") * (range[1] - range[0] + 1));
}
function botMove(r, time) {
  if (r.turn !== "bot" || r.botAt > time || r.finished) return;
  r.turn = "user";
  if (kind(r) === "reverse") {
    const i = pick(r, open(r), "axis"); const k = common(r, i)[0];
    if (k) {
      r.axes[i] = {owner: 2, criterionId: k.id, label: k.label}; r.botScore++;
    }
  } else if (kind(r) === "classic") {
    if (random(r, "accuracy") <= {easy: .60, medium: .78, hard: .92}[r.difficulty]) {
      const cells = open(r).filter((i) => answers(r, i).length);
      // Preserve legacy policy: complete a bot line, then random valid cell.
      const winning = cells.filter((i) => lines.some((l) => l.includes(i) &&
        l.filter((j) => j !== i).every((j) => r.cells[j]?.owner === 2)));
      const i = pick(r, winning.length ? winning : cells, "cell");
      if (i !== undefined) claim(r, i, pick(r, answers(r, i), "player"), 2, time);
    }
  } else {
    const i = open(r).find((i) => answers(r, i).length);
    if (i !== undefined) claim(r, i, pick(r, answers(r, i), "player"), 2, time);
    else if (r.roundsUsed < 3) {
      try {
        if (!r.pending) makePair(r);
        r.pending.playerId = pick(r, answers(r, "pending"), "pending");
        const a = pick(r, [2, 4, 6].filter((i) => !r.cells[i]), "anchor");
        place(r, a, random(r, "swap") > .5, 2, time);
      } catch (e) {
        if (!(e instanceof RewardError)) throw e; r.pending = null;
      }
    }
  }
  r.revision++; check(r, time);
}
function reconcile(s, e, time) {
  for (const [id, r] of Object.entries(s.sessions)) {
    if (r.version !== catalog.version) finish(r, "catalog_changed", time);
    if (r.expiresAt <= time) finish(r, "expired", time);
    if (r.version === catalog.version) botMove(r, time);
    B.recoverUnused(e, r, time, (_, scope) => usable(r, scope));
    if (r.finished && !r.recorded) {
      r.recorded = true;
      if (r.completed) {
        const records = r.assisted ? s.assistedRecords : s.records;
        const key = r.mode + ":" + r.difficulty; const old = records[key] || {};
        records[key] = {best: Math.max(old.best || 0, r.userScore), completed: (old.completed || 0) + 1,
          wins: (old.wins || 0) + (bot(r) && r.winner === 1 ? 1 : 0)};
      }
    }
    if (s.active[r.mode] !== id && r.finished && r.createdAt < time - 2 * 86400000 && !r.adCredits) {
      delete s.sessions[id];
    }
  }
}
function view(r) {
  if (!r) return null;
  const reverse = kind(r) === "reverse"; const criterion = (id) => id ? catalog.criteria[id] : null;
  return {id: r.id, mode: r.mode, version: r.version, revision: r.revision, difficulty: r.difficulty,
    turn: r.turn, botAt: r.botAt || null, finished: r.finished, completed: !!r.completed, reason: r.reason || null,
    rows: reverse && !r.finished ? [] : Array.from({length: 3}, (_, i) => criterion(r.rows[i])),
    cols: reverse && !r.finished ? [] : Array.from({length: 3}, (_, i) => criterion(r.cols[i])),
    witnesses: reverse ? r.puzzle.witness.map((id) => P.player(catalog, id)) : [],
    cells: Object.fromEntries(Object.entries(r.cells).map(([i, x]) =>
      [i, {...x, player: P.player(catalog, x.playerId)}])),
    axes: r.axes, pending: r.pending ? {criteria: r.pending.criteria.map(criterion),
      player: r.pending.playerId ? P.player(catalog, r.pending.playerId) : null} : null,
    roundsUsed: r.roundsUsed, pairNumber: r.pairNumber, userScore: r.userScore, botScore: r.botScore,
    winner: r.winner ?? null, feedback: r.feedback || null, hints: r.hints, support: B.view(r),
    assisted: r.assisted, adGranted: r.adGranted,
    masteryEligible: false, leaderboardEligible: false, rewardCoins: 0, rewardXp: 0};
}
function createService({db, normalize, project, isLinked, now = Date.now}) {
  const mode = (input) => {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz Grid modu."); return input.mode;
  };
  const read = async (uid) => restored((await db.ref("economyState/" + uid + "/gridSupport").get()).val());
  async function change(uid, fn) {
    const ref = db.ref("economyState/" + uid); const base = (await ref.get()).val();
    const tx = await ref.transaction((raw) => {
      const e = normalize(structuredClone(raw ?? base)); const s = restored(e.gridSupport);
      reconcile(s, e, now()); fn(s, e); reconcile(s, e, now()); e.gridSupport = s; return e;
    });
    if (!tx.committed) fail("aborted", "Oyunu yenile.");
    await project(db, uid, normalize(tx.snapshot.val())); return restored(tx.snapshot.val().gridSupport);
  }
  const response = (s, m, enabled) => ({legacy: !enabled && !s.active[m], availability: enabled,
    session: view(s.sessions[s.active[m]]), records: s.records, assistedRecords: s.assistedRecords,
    version: catalog.version, serverNow: now(),
    selectionClubIds: Object.values(catalog.criteria).filter((k) => k.type === "club").map((k) => k.id)});
  async function status(uid, input) {
    const m = mode(input); const policy = await B.policyFor(db, uid, await isLinked(uid));
    const before = await read(uid); const s = before.active[m] ? await change(uid, () => {}) : before;
    return response(s, m, policy?.readyModes?.[m] === true);
  }
  async function search(uid, input) {
    const m = mode(input); const s = await read(uid); const r = s.sessions[s.active[m]];
    if (!await isLinked(uid) || !r || r.finished || r.id !== input.sessionId || r.expiresAt <= now()) {
      fail("failed-precondition", "Aktif Grid bulunamadı.");
    }
    if (typeof input.query !== "string" || input.query.length > 80) fail("invalid-argument", "Arama geçersiz.");
    const q = P.norm(input.query); if (q.length < 2) return {players: []};
    // Search is deliberately independent of the selected cell: it is not a free answer oracle.
    return {players: Object.values(catalog.players).filter((p) => !r.used?.[p.id] &&
      [p.name, ...p.aliases].some((s) => P.norm(s).includes(q))).slice(0, 20).map((p) => ({id: p.id, name: p.name}))};
  }
  async function act(uid, input) {
    const m = mode(input);
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "")) fail("invalid-argument", "İşlem kimliği geçersiz.");
    const policy = await B.policyFor(db, uid, true); const seed = crypto.randomBytes(32).toString("hex");
    const fp = P.hash([m, input.action, input.sessionId, input.version, input.revision, input.target,
      input.playerId, input.answer, input.swap, input.difficulty, input.clubIds, input.minimumAnswers,
      ...B.paymentFingerprint(input)]);
    const s = await change(uid, (s, e) => {
      if (input.action === "start") {
        const id = "grid_" + input.requestId;
        if (s.sessions[id]) {
          if (s.sessions[id].startFingerprint !== fp) fail("invalid-argument", "İstek değiştirilemez."); return;
        }
        if (policy?.readyModes?.[m] !== true || input.version !== catalog.version) {
          fail("failed-precondition", "Yeni Grid oturumu şu anda kapalı veya katalog değişti.");
        }
        if (s.sessions[s.active[m]] && !s.sessions[s.active[m]].finished) {
          fail("failed-precondition", "Önce açık oyunu bitir.");
        }
        const difficulty = input.difficulty || "medium";
        if (!["easy", "medium", "hard"].includes(difficulty)) fail("invalid-argument", "Zorluk geçersiz.");
        const pool = input.clubIds || [];
        if (!Array.isArray(pool) || pool.length > 2000 || pool.some((id) => !catalog.criteria[id] ||
            catalog.criteria[id].type !== "club")) fail("invalid-argument", "Kulüp havuzu geçersiz.");
        const r = {id, mode: m, version: catalog.version, revision: 0, seed, difficulty, pool,
          minimumAnswers: input.minimumAnswers === 1 ? 1 : 2, startFingerprint: fp,
          createdAt: now(), expiresAt: now() + 86400000, turn: "user", finished: false,
          cells: {}, axes: {}, used: {}, rows: {}, cols: {}, actions: {}, hints: {}, roundsUsed: 0,
          pairNumber: 0, userScore: 0, botScore: 0, adCredits: 0, adGranted: 0};
        if (kind(r) !== "random") {
          r.puzzle = makePuzzle(r);
          r.rows = {...r.puzzle.rows}; r.cols = {...r.puzzle.cols};
        }
        B.pin(r, policy); s.sessions[id] = r; s.active[m] = id; return;
      }
      const r = s.sessions[input.sessionId];
      if (!r || r.mode !== m || r.version !== input.version) fail("failed-precondition", "Grid oturumu değişti.");
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek değiştirilemez."); return;
      }
      if (r.finished || r.version !== catalog.version || r.revision !== input.revision) {
        fail("failed-precondition", "Oyun güncellendi. Yenile.");
      }
      if (input.action === "finish") finish(r, "partial", now());
      else {
        if (r.turn !== "user") fail("failed-precondition", "Sıra botta.");
        if (input.action === "hint") {
          const info = hint(r, input.target);
          if (input.paymentSource === "ad" && r.adScopes?.boost_basic?.targetKey !== info.key) {
            fail("failed-precondition", "Reklam hakkı başka Grid hedefine ait.");
          }
          B.consume(e, r, input, "boost_basic", info.key, {text: info.text}, now()); r.hints[info.key] = info.text;
        } else if (input.action === "generate" && kind(r) === "random") makePair(r);
        else if (input.action === "cancel" && kind(r) === "random") r.pending = null;
        else if (input.action === "place" && kind(r) === "random") {
          place(r, Number(input.target), input.swap === true, 1, now()); schedule(r, now());
        } else if (input.action === "guess") {
          if (kind(r) === "reverse") {
            const i = Number(input.target); targetKey(r, i);
            if (typeof input.answer !== "string" || input.answer.length > 100 || !input.answer.trim()) {
              fail("invalid-argument", "Bir kriter yaz.");
            }
            const k = common(r, i).find((k) => P.norm(k.label) === P.norm(input.answer) || k.id === input.answer ||
              k.type === "country" && countryKey(k.id.slice(8)) === countryKey(input.answer));
            if (k) {
              r.axes[i] = {owner: 1, criterionId: k.id, label: k.label}; r.userScore += bot(r) ? 1 : 40;
            }
            r.feedback = k ? "Doğru." : "Bu kriter üç oyuncunun tamamına uymuyor.";
            check(r, now()); schedule(r, now());
          } else {
            const i = input.target === "pending" ? "pending" : Number(input.target);
            if (i === "pending" ? !r.pending || !!r.pending.playerId : !Number.isInteger(i) || i < 0 || i >= 9 ||
                r.cells[i] || !r.rows[i / 3 | 0] || !r.cols[i % 3]) fail("failed-precondition", "Geçersiz hedef.");
            if (!catalog.players[input.playerId] || r.used[input.playerId]) {
              fail("invalid-argument", "Oyuncu kullanılamaz.");
            }
            const ok = answers(r, i).includes(input.playerId);
            r.feedback = ok ? "Doğru." : "Oyuncu iki kritere uymuyor.";
            if (ok && i === "pending") r.pending.playerId = input.playerId;
            else {
              if (ok) claim(r, i, input.playerId, 1, now());
              if (!ok && bot(r)) r.pending = null;
              schedule(r, now());
            }
          }
        } else fail("invalid-argument", "İşlem geçersiz.");
      }
      r.actions[input.requestId] = fp; r.revision++;
    });
    return response(s, m, policy?.readyModes?.[m] === true);
  }
  async function prepareHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "grid_support_hint") fail("permission-denied", "Hesap gerekli.");
    const s = await read(uid); const r = s.sessions[input.sessionId];
    if (!B.paid(r) || r.finished || r.turn !== "user" || r.expiresAt <= now() || r.version !== catalog.version ||
        input.boostId !== "boost_basic") fail("failed-precondition", "Grid yardımı şu anda kullanılamaz.");
    if (r.adProducts?.boost_basic > 0) {
      fail("failed-precondition", "Önce bekleyen reklam hakkını kullan veya ilgili hedefi tamamla.");
    }
    const info = hint(r, input.target);
    return B.adBenefit(r, {amount: 0, claimKey: "grid_hint_" + r.id + "_" + info.key,
      context: {sessionId: r.id, target: input.target, targetKey: info.key}}, "boost_basic");
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e) => {
      const r = s.sessions[receipt.context?.sessionId];
      if (!B.recoverAd(e, r, receipt, now(), "boost_basic", usable(r, receipt.context))) B.grantAd(r, receipt);
    });
  }
  return {status, search, act, prepareHint, settleHint};
}
module.exports = {createService, MODES, catalog, hint, common, answers, view, makePuzzle, perfect};
