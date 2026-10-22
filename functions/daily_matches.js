"use strict";
const {dayKey, RewardError} = require("./rewarded_ads");
const catalog = require("./config/daily_catalog.json");
const fail = (message) => {
  throw new RewardError("failed-precondition", message);
};
const previousDay = (key, days = 1) => new Date(Date.parse(key + "T12:00:00Z") - days * 86400000)
    .toISOString().slice(0, 10);
const {norm, fixtureClub} = require("./fixture_clubs");
function resolveFixture(m) {
  if (!m || typeof m !== "object" || m.stale === true) return null;
  if (!Number.isSafeInteger(m.fixtureId) || !Number.isFinite(Date.parse(m.kickoff)) ||
      ![2, 3, 848, 203, 39, 40, 71, 140, 135, 78, 61, 88, 94, 179].includes(m.leagueId)) return null;
  if (!["NS", "1H", "HT", "2H", "ET", "P", "FT", "AET", "PEN", "LIVE"].includes(m.status)) return null;
  const homeClubId = fixtureClub(m, "home");
  const awayClubId = fixtureClub(m, "away");
  if (!homeClubId || !awayClubId || homeClubId === awayClubId) return null;
  const key = [homeClubId, awayClubId].sort((a, b) => a - b).join("-");
  const answers = catalog.pairs[key];
  if (!answers || answers.length < 4) return null;
  const priority = (m.isDerby ? 300 : 0) + ([2, 3, 848].includes(m.leagueId) ? 150 : 0) +
    (m.importance || 0) + Math.min(answers.length, 15);
  return {...m, homeClubId, awayClubId, sharedCount: answers.length, target: 3, priority, catalogKey: key};
}
function initial(raw) {
  const state = {sessions: {}, pending: {}, progress: {}, streak: 0, lastWin: "", lastRepair: "", ...raw};
  // RTDB drops empty arrays too: a newly created match has no found/wrong nodes.
  state.sessions = Object.fromEntries(Object.entries(state.sessions || {}).map(([key, session]) =>
    [key, {...session, found: Array.isArray(session.found) ? session.found : [],
      wrong: Array.isArray(session.wrong) ? session.wrong : []}]));
  return state;
}
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
  async function fixtureFeed() {
    const today = dayKey(now());
    const raw = (await db.ref("daily_fixtures/" + today).get()).val();
    const feed = require("./daily_fixture_feed").readDay(raw, today, now());
    const selected = feed.calendar.map(resolveFixture).filter(Boolean)
        .sort((a, b) => b.priority - a.priority || a.fixtureId - b.fixtureId).slice(0, 6);
    return {...feed, selected};
  }
  async function fixtures() {
    return (await fixtureFeed()).selected;
  }
  async function status(uid) {
    await settle(uid);
    const today = dayKey(now());
    const s = initial((await ref(uid).get()).val());
    const feed = await fixtureFeed();
    const matches = feed.selected;
    for (const round of Object.values(s.sessions)) {
      if (round.day === today && round.match && !matches.some((m) => m.fixtureId === round.fixtureId)) {
        matches.push(round.match);
      }
    }
    const missed = await missedDays(s, today);
    return {ok: true, dayKey: today, streak: missed.length === 0 && s.lastWin >= previousDay(today, 31) ? s.streak : 0,
      repairStreak: canRepair(s, today, missed) ? s.streak : 0, dailyLimit: 3,
      remaining: Math.max(0, 3 - Object.values(s.sessions).filter((x) => x.day === today).length),
      feed: {sources: feed.sources, updatedAt: feed.updatedAt, snapshotUsed: feed.snapshotUsed,
        snapshotUpdatedAt: feed.snapshotUpdatedAt, coverageStart: feed.coverageStart, coverageEnd: feed.coverageEnd,
        competitions: feed.competitions,
        state: matches.length ? "ready" : feed.calendar.length ? "no-playable" :
          feed.sources.snapshot?.state === "out-of-range" ? "out-of-coverage" : "empty"},
      calendar: feed.calendar.map((m) => ({fixtureId: m.fixtureId, homeName: m.homeName, awayName: m.awayName,
        homeClubId: fixtureClub(m, "home") || null, awayClubId: fixtureClub(m, "away") || null,
        leagueId: m.leagueId, leagueName: m.leagueName || "", kickoff: m.kickoff, status: m.status || "TBD",
        homeScore: m.homeScore ?? null, awayScore: m.awayScore ?? null, isDerby: m.isDerby === true,
        source: m.source || "api-football", stale: m.stale,
        playable: matches.some((chosen) => chosen.fixtureId === m.fixtureId)})),
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
