"use strict";
const {dayKey, RewardError} = require("./rewarded_ads");
const catalog = require("./config/daily_catalog.json");
const fail = (message) => {
  throw new RewardError("failed-precondition", message);
};
const previousDay = (key, days = 1) => new Date(Date.parse(key + "T12:00:00Z") - days * 86400000)
    .toISOString().slice(0, 10);
const norm = (value) => String(value).toLocaleLowerCase("tr").replace(/ı/g, "i").normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9 ]/g, " ").replace(/\b(fc|cf|ac|afc|sc|jk|de)\b/g, "")
    .replace(/\s/g, "");
const aliases = {"Manchester United": 985, "Manchester City": 281, "Atletico Madrid": 13,
  "Athletic Club": 621, "Real Sociedad": 681, "Inter": 46, "AC Milan": 5, "Bayern München": 27,
  "Bayern Munich": 27, "Borussia Dortmund": 16, "Bayer Leverkusen": 15, "RB Leipzig": 23826,
  "Borussia Mönchengladbach": 18, "Paris Saint Germain": 583, "Paris Saint-Germain": 583, "PSG": 583,
  "Lyon": 1041, "Marseille": 244, "Monaco": 162, "Lille": 1082, "Ajax": 610, "Benfica": 294,
  "Sporting CP": 336, "Sporting Lisbon": 336, "Celtic": 371, "Rangers": 124, "PSV Eindhoven": 383,
  "Fenerbahce": 36, "Besiktas": 114, "Tottenham": 148, "Newcastle": 762, "West Ham": 379,
  "Leicester": 1003, "Napoli": 6195, "Roma": 12, "Lazio": 398, "Fiorentina": 430, "Atalanta": 800,
  "Villarreal": 1050, "Valencia": 1049, "Real Betis": 150, "Porto": 720};
const clubNames = new Map(Object.entries(catalog.clubs).map(([id, name]) => [norm(name), Number(id)]));
for (const [name, id] of Object.entries(aliases)) clubNames.set(norm(name), id);
function resolveFixture(m) {
  if (!m || typeof m !== "object") return null;
  if (!Number.isSafeInteger(m.fixtureId) || !Number.isFinite(Date.parse(m.kickoff)) ||
      ![2, 3, 848, 203, 39, 140, 135, 78, 61, 88, 94, 179].includes(m.leagueId)) return null;
  if (["PST", "CANC", "ABD", "AWD", "WO", "TBD"].includes(m.status)) return null;
  const homeClubId = clubNames.get(norm(m.homeName));
  const awayClubId = clubNames.get(norm(m.awayName));
  if (!homeClubId || !awayClubId || homeClubId === awayClubId) return null;
  const key = [homeClubId, awayClubId].sort((a, b) => a - b).join("-");
  const answers = catalog.pairs[key];
  if (!answers || answers.length < 4) return null;
  const priority = (m.isDerby ? 300 : 0) + ([2, 3, 848].includes(m.leagueId) ? 150 : 0) +
    (m.importance || 0) + Math.min(answers.length, 15);
  return {...m, homeClubId, awayClubId, sharedCount: answers.length, target: 3, priority, catalogKey: key};
}
const initial = (raw) => ({sessions: {}, pending: {}, progress: {}, streak: 0, lastWin: "", lastRepair: "", ...raw});
function coins(found, total) {
  return found < 3 ? 0 : 15 + Math.min(found * 5, 30) + (found === total ? 15 : 0);
}
function createService({db, grantCoins, isLinked, recordWin = async () => {}, now = Date.now}) {
  const ref = (uid) => db.ref("dailyMatchState/" + uid);
  async function change(uid, fn) {
    let error;
    const tx = await ref(uid).transaction((raw) => {
      error = null;
      const s = initial(raw);
      try {
        fn(s); return s;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    return initial(tx.snapshot.val());
  }
  async function settle(uid) {
    const s = initial((await ref(uid).get()).val());
    for (const [key, result] of Object.entries(s.progress)) {
      await recordWin(uid, result.day, result);
      await change(uid, (state) => {
        delete state.progress[key];
      });
    }
    if (!await isLinked(uid)) return;
    for (const [key, amount] of Object.entries(s.pending)) {
      await grantCoins(uid, "daily_match__" + key, "daily_match", key, amount, "daily-v1");
      await change(uid, (state) => {
        delete state.pending[key];
      });
    }
  }
  function canRepair(s, today, missed) {
    return s.streak > 0 && missed.length === 1 && s.lastWin >= previousDay(today, 31) &&
      (!s.lastRepair || s.lastRepair <= previousDay(today, 7));
  }
  function view(session) {
    if (!session) return null;
    const {answers, ...safe} = session;
    return {...safe, total: answers.length, foundPlayers: session.found.map((id) => ({id, ...catalog.players[id]})),
      remainingPlayers: session.finished ? answers.filter((id) => !session.found.includes(id))
          .map((id) => ({id, ...catalog.players[id]})) : []};
  }
  async function missedDays(s, today) {
    if (!s.lastWin || s.lastWin === today) return [];
    const from = s.lastWin < previousDay(today, 31) ? previousDay(today, 31) : s.lastWin;
    const dates = [];
    for (let date = previousDay(today); date > from; date = previousDay(date)) dates.push(date);
    const rows = await Promise.all(dates.map(async (date) => {
      const raw = (await db.ref("daily_fixtures/" + date).get()).val();
      const matches = Array.isArray(raw?.matches) ? raw.matches : Object.values(raw?.matches || {});
      return matches.some((m) => resolveFixture(m) && dayKey(Date.parse(m.kickoff)) === date) ? date : null;
    }));
    return rows.filter(Boolean).sort();
  }
  async function fixtures() {
    const today = dayKey(now());
    const raw = (await db.ref("daily_fixtures/" + today).get()).val();
    if (!raw || !raw.updatedAt || now() - raw.updatedAt > 30 * 3600000) return [];
    return (Array.isArray(raw.matches) ? raw.matches : Object.values(raw.matches || {}))
        .map(resolveFixture).filter((m) => m && dayKey(Date.parse(m.kickoff)) === today)
        .sort((a, b) => b.priority - a.priority || a.fixtureId - b.fixtureId).slice(0, 6);
  }
  async function status(uid) {
    await settle(uid);
    const today = dayKey(now());
    const s = initial((await ref(uid).get()).val());
    const matches = await fixtures();
    for (const round of Object.values(s.sessions)) {
      if (round.day === today && round.match && !matches.some((m) => m.fixtureId === round.fixtureId)) {
        matches.push(round.match);
      }
    }
    const missed = await missedDays(s, today);
    return {ok: true, dayKey: today, streak: missed.length === 0 && s.lastWin >= previousDay(today, 31) ? s.streak : 0,
      repairStreak: canRepair(s, today, missed) ? s.streak : 0, dailyLimit: 3,
      remaining: Math.max(0, 3 - Object.values(s.sessions).filter((x) => x.day === today).length),
      pendingCoins: Object.values(s.pending).reduce((a, b) => a + b, 0),
      matches: matches.map(({catalogKey, ...m}) => ({...m, session: view(s.sessions[today + "_" + m.fixtureId])}))};
  }
  async function start(uid, fixtureId) {
    const today = dayKey(now());
    if (!Number.isSafeInteger(fixtureId) || fixtureId <= 0) fail("Geçersiz maç.");
    const key = today + "_" + fixtureId;
    const existing = initial((await ref(uid).get()).val()).sessions[key];
    if (existing) return {ok: true, session: view(existing)};
    const match = (await fixtures()).find((m) => m.fixtureId === fixtureId);
    if (!match) fail("Bu maç şu anda oynanabilir listede değil. Listeyi yenile.");
    const s = await change(uid, (state) => {
      if (state.sessions[key]) return;
      if (Object.values(state.sessions).filter((x) =>
        x.day === today).length >= 3) fail("Bugünkü 3 maç hakkını kullandın.");
      for (const [id, old] of Object.entries(state.sessions)) {
        if (old.day < previousDay(today,
            14)) delete state.sessions[id];
      }
      state.sessions[key] = {key, day: today, fixtureId, found: [], wrong: [], lives: 3, target: 3,
        answers: catalog.pairs[match.catalogKey], finished: false, reward: 0, doubled: false,
        hintUsed: false, adHint: false, createdAt: now(), homeName: match.homeName, awayName: match.awayName,
        match: {...match}};
    });
    return {ok: true, session: view(s.sessions[key])};
  }
  function getSession(state, key) {
    if (typeof key !== "string" || !/^\d{4}-\d{2}-\d{2}_\d+$/.test(key)) fail("Geçersiz maç.");
    const s = state.sessions[key];
    if (!s || s.day !== dayKey(now())) fail("Bu maçın günü sona erdi.");
    return s;
  }
  function finish(state, s, missed) {
    if (s.finished) return;
    s.finished = true;
    s.reward = coins(s.found.length, s.answers.length);
    if (!s.reward) return;
    state.pending[s.key + "_base"] = s.reward;
    if (state.lastWin !== s.day) {
      state.streak = state.lastWin && state.lastWin >= previousDay(s.day, 31) &&
          missed.length === 0 ? state.streak + 1 : 1;
      state.lastWin = s.day;
    }
    state.progress[s.key] = {day: s.day, successRate: s.found.length / s.answers.length, streak: state.streak};
  }
  function hint(s, extended) {
    const id = s.answers.find((p) => !s.found.includes(p));
    if (!id) return "Tüm oyuncuları buldun.";
    const p = catalog.players[id];
    const surname = p.name.split(" ").at(-1);
    const position = {Goalkeeper: "Kaleci", Defender: "Defans", Midfield: "Orta saha",
      Attack: "Hücum"}[p.position] || p.position;
    return extended ? `${p.country} · ${position} · ${surname.slice(0,
        3)}…` : `${p.country} · Soyadı ${surname[0]} ile başlıyor`;
  }
  async function play(uid, input) {
    const before = initial((await ref(uid).get()).val());
    const missed = await missedDays(before, dayKey(now()));
    const s = await change(uid, (state) => {
      const round = getSession(state, input.key);
      if (round.finished) return;
      if (input.action === "finish") {
        finish(state, round, missed); return;
      }
      if (input.action === "hint") {
        if (!round.hintUsed) {
          round.hintUsed = true; round.hint = hint(round, false);
        }
        return;
      }
      if (input.action !== "answer" || typeof input.answer !== "string" ||
          input.answer.length > 100) fail("Geçersiz cevap.");
      const answer = norm(input.answer);
      if (answer.length < 2) fail("En az iki harf yaz.");
      const hits = round.answers.filter((id) => {
        const p = catalog.players[id];
        return [p.name, ...p.aliases, p.name.split(" ").at(-1)].some((n) => norm(n) === answer);
      });
      if (hits.length > 1) fail("Birden fazla oyuncu var. Tam adını yaz.");
      if (hits.length === 1) {
        if (!round.found.includes(hits[0])) {
          round.found.push(hits[0]); round.feedback = "Doğru cevap!";
        } else round.feedback = "Bu oyuncuyu zaten buldun.";
        if (round.found.length === round.answers.length) finish(state, round, missed);
      } else if (!round.wrong.includes(answer)) {
        round.wrong.push(answer); round.lives -= 1; round.feedback = "Bu cevap eşleşmedi.";
        if (round.lives === 0) finish(state, round, missed);
      }
    });
    await settle(uid);
    return {ok: true, session: view(s.sessions[input.key]), streak: s.streak};
  }
  async function prepareReward(uid, placement, context) {
    const s = initial((await ref(uid).get()).val());
    const today = dayKey(now());
    if (placement === "daily_streak") {
      if (!canRepair(s, today, await missedDays(s, today))) fail("Seri koruması şu anda kullanılamıyor.");
      return {amount: 0, claimKey: "daily_streak_" + today, context: {day: today}};
    }
    const round = getSession(s, context?.key);
    if (placement === "daily_double") {
      if (!round.finished || !round.reward || round.doubled) fail("Bu maçın 2x ödülü alınamıyor.");
      return {amount: round.reward, claimKey: "daily_double_" + round.key, context: {key: round.key}};
    }
    if (placement !== "daily_hint" || round.finished || round.adHint ||
        !round.hintUsed) fail("Önce ücretsiz ipucunu kullan.");
    return {amount: 0, claimKey: "daily_hint_" + round.key, context: {key: round.key}};
  }
  async function settleReward(uid, receipt) {
    const before = initial((await ref(uid).get()).val());
    const missed = await missedDays(before, dayKey(now()));
    await change(uid, (state) => {
      const today = dayKey(now());
      if (receipt.placement === "daily_streak") {
        if (receipt.context.day === today && canRepair(state, today, missed)) {
          state.lastWin = missed[0]; state.lastRepair = today;
        }
        return;
      }
      // A late verified callback may settle a completed match after midnight.
      const round = state.sessions[receipt.context.key];
      if (!round) return;
      if (receipt.placement === "daily_double" && round.finished && round.reward && !round.doubled) {
        round.doubled = true; state.pending[round.key + "_double"] = round.reward;
      }
      if (receipt.placement === "daily_hint" && !round.adHint) {
        round.adHint = true; round.hint = hint(round, true);
      }
    });
    await settle(uid);
  }
  return {status, start, play, prepareReward, settleReward};
}
module.exports = {createService, resolveFixture, norm, coins, previousDay};
