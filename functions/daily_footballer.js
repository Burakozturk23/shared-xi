"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const {RewardError, dayKey} = require("./rewarded_ads");
const catalog = require("./config/daily_footballer_catalog.json");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const hash = (v) => crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex");
function targetFor(c, day) {
  const ordered = [...c.players];
  // Match Dart's String.compareTo and unsigned 32-bit permutation exactly.
  ordered.sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  let seed = 73;
  for (let i = 0; i < c.version.length; i++) seed = (Math.imul(seed, 31) + c.version.charCodeAt(i)) & 0x7fffffff;
  for (let i = ordered.length - 1; i > 0; i--) {
    seed = (Math.imul(1664525, seed) + 1013904223) >>> 0;
    const j = seed % (i + 1); [ordered[i], ordered[j]] = [ordered[j], ordered[i]];
  }
  const days = Math.floor((Date.parse(day + "T00:00:00Z") - Date.parse("2026-01-01T00:00:00Z")) / 86400000);
  return ordered[((days % ordered.length) + ordered.length) % ordered.length];
}
function age(p, day) {
  const [y, m, d] = day.split("-").map(Number); const [by, bm, bd] = p.birthDate.split("-").map(Number);
  return y - by - (m < bm || m === bm && d < bd ? 1 : 0);
}
function clues(target, guess, day) {
  const same = (a, b) => a === b ? "same" : "different";
  const number = (a, b) => a === b ? "same" : a > b ? "higher" : "lower";
  return [
    {label: "Ülke", value: guess.country, match: same(target.country, guess.country)},
    {label: "Kulüp", value: guess.club, match: same(target.clubId, guess.clubId)},
    {label: "Lig", value: guess.league, match: same(target.leagueId, guess.leagueId)},
    {label: "Mevki", value: {G: "Kaleci", D: "Defans", M: "Orta saha", F: "Forvet"}[guess.position] || "Forvet",
      match: same(target.position, guess.position)},
    {label: "Yaş", value: String(age(guess, day)), match: number(age(target, day), age(guess, day))},
    {label: "Forma", value: "#" + guess.shirtNumber, match: number(target.shirtNumber, guess.shirtNumber)},
  ];
}
function normalizeState(raw) {
  const s = {days: {}, wins: {}, assistedWins: {}, outbox: {}, paid: {}, ...raw};
  for (const r of Object.values(s.days)) {
    r.guesses ||= []; r.actions ||= {};
  }
  return s;
}
const canHint = (r) => !r.finished && !r.hintUsed && r.guesses.length > 0 && r.guesses.length < (r.extraUsed ? 7 : 6);
const canExtra = (r) => !r.finished && !r.extraUsed && r.guesses.length === 6;
function reconcile(s, e, time) {
  for (const r of Object.values(s.days)) {
    B.recoverUnused(e, r, time, () => canHint(r));
    if (r.finished && r.won && !r.recorded) {
      r.recorded = true; (r.assisted ? s.assistedWins : s.wins)[r.day] = {at: time, guesses: r.guesses.length};
    }
  }
}
function view(r, c) {
  const players = new Map(c.players.map((p) => [p.id, p]));
  return {id: r.id, mode: r.mode, dayKey: r.day, catalogVersion: c.version, asOf: c.asOf, revision: r.revision,
    guesses: r.guesses.map((id) => players.get(id)),
    clues: Object.fromEntries(r.guesses.map((id) => [id, clues(r.target, players.get(id), r.day)])),
    hintUsed: r.hintUsed, extraUsed: r.extraUsed, revealed: r.revealed, won: r.won, finished: r.finished,
    hint: r.hintUsed ? r.hint : null, target: r.finished ? r.target : null,
    support: B.view(r), assisted: r.assisted, adCredits: r.adCredits, adGranted: r.adGranted,
    masteryEligible: !r.assisted, expiresAt: r.expiresAt, reward: r.reward ?? null};
}
// Reward design 2026-10-30: a solve pays 3 coin / 8 XP; an assisted solve
// keeps the coin and half the XP, as the daily word games do.
function settleReward(s, r, policy) {
  if (!r.finished || !r.won || r.reward) return;
  const enabled = policy.rewardsEnabled === true;
  r.reward = {coins: enabled ? 3 : 0, xp: enabled ? (r.assisted ? 4 : 8) : 0, rewardEnabled: enabled};
  if (enabled) s.outbox["df__" + r.day] = {coins: r.reward.coins, xp: r.reward.xp, day: r.day};
}
function createService({db, normalize, project, isLinked, grantCoins, grantXp,
  getPolicy = async () => ({}), onPlayed = async () => {}, now = Date.now}) {
  async function pinned(day) {
    const ref = db.ref("dailyFootballerPrivate/" + day); let pack = (await ref.get()).val();
    if (!pack) {
      const value = {catalog, target: targetFor(catalog, day)};
      pack = (await ref.transaction((old) => old || value)).snapshot.val();
    }
    return pack;
  }
  const read = async (uid) => normalizeState((await db.ref("economyState/" + uid + "/dailyFootballer").get()).val());
  async function change(uid, fn) {
    const ref = db.ref("economyState/" + uid); const base = (await ref.get()).val();
    const tx = await ref.transaction((raw) => {
      const e = normalize(structuredClone(raw ?? base)); const s = normalizeState(e.dailyFootballer);
      reconcile(s, e, now()); fn(s, e); reconcile(s, e, now()); e.dailyFootballer = s; return e;
    });
    if (!tx.committed) fail("aborted", "Oyunu yenile.");
    await project(db, uid, normalize(tx.snapshot.val())); return normalizeState(tx.snapshot.val().dailyFootballer);
  }
  // Pays queued rewards; both grants are idempotent by the reward id.
  async function settle(uid) {
    if (!grantCoins || !await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, reward] of Object.entries(s.outbox)) {
      if (reward.coins > 0) {
        await grantCoins(uid, id, "daily_footballer_reward", reward.day, reward.coins, "daily-footballer-v1");
      }
      if (reward.xp > 0) await grantXp(uid, id, reward.xp);
      await change(uid, (next) => {
        next.paid[id] = true; delete next.outbox[id];
      });
    }
  }
  async function status(uid, input = {}) {
    const day = dayKey(now()); const policy = await B.policyFor(db, uid, await isLinked(uid));
    const before = await read(uid);
    if (!before.days[day] && policy?.readyModes?.daily_footballer !== true) return {legacy: true};
    const pack = await pinned(day);
    const s = await change(uid, (s) => {
      if (!s.adoptedAt) {
        s.adoptedAt = now();
        // One bounded transition day preserves an already-open local game;
        // client history never earns server wins, currency or ad entitlements.
        if (input.legacyDay === day) s.legacyDay = day;
      }
      if (s.legacyDay === day || s.days[day]) return;
      const r = {id: "df_" + day + "_" + hash(pack.catalog.version).slice(0, 16), mode: "daily_footballer",
        entry: "daily", day, version: pack.catalog.version, revision: 0, target: pack.target,
        guesses: [], hintUsed: false, extraUsed: false, revealed: false, won: false, finished: false,
        actions: {}, createdAt: now(), expiresAt: Date.parse(day + "T00:00:00+03:00") + 86400000,
        adCredits: 0, adGranted: 0, adReceipts: {}};
      B.pin(r, policy); s.days[day] = r;
    });
    if (s.legacyDay === day) return {legacy: true, legacyDay: day};
    await settle(uid);
    if (s.days[day]?.finished) await onPlayed(uid, day, "daily_footballer");
    return {legacy: false, availability: true, catalog: pack.catalog, session: view(s.days[day], pack.catalog),
      serverNow: now(), wins: Object.keys(s.wins).length, assistedWins: Object.keys(s.assistedWins).length};
  }
  async function act(uid, input) {
    if (!await isLinked(uid)) fail("permission-denied", "Hesabını bağla.");
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "") || input.day !== dayKey(now())) {
      fail("failed-precondition", "Günün futbolcusu değişti. Yenile.");
    }
    const pack = await pinned(input.day); const policy = await getPolicy();
    const fp = hash([input.day, input.sessionId, input.revision, input.action, input.playerId ?? null,
      ...B.paymentFingerprint(input)]);
    await change(uid, (s, e) => {
      const r = s.days[input.day];
      if (!B.paid(r) || r.id !== input.sessionId) fail("failed-precondition", "Oturum değişti.");
      if (r.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fp) fail("invalid-argument", "İstek değiştirilemez.");
        return;
      }
      if (r.finished || r.revision !== input.revision) fail("failed-precondition", "Oyunu yenile.");
      if (input.action === "guess") {
        if (r.guesses.length >= (r.extraUsed ? 7 : 6) || r.guesses.includes(input.playerId)) {
          fail("failed-precondition", "Bu tahmin kullanılamaz.");
        }
        if (!pack.catalog.players.some((p) => p.id === input.playerId)) fail("invalid-argument", "Oyuncu bulunamadı.");
        r.guesses.push(input.playerId); r.won = input.playerId === r.target.id;
        r.finished = r.won || r.extraUsed && r.guesses.length === 7;
      } else if (input.action === "hint") {
        if (!canHint(r)) fail("failed-precondition", "İpucu ilk tahminden sonra açılır.");
        const words = r.target.name.trim().split(/\s+/);
        const text = `Adı ${words[0][0].toUpperCase()} harfiyle başlıyor` +
          (words.length > 1 ? `, son kelimesinin ilk harfi ${words.at(-1)[0].toUpperCase()}.` : ".");
        B.consume(e, r, input, "boost_basic", "name_hint", {text}, now()); r.hintUsed = true; r.hint = text;
      } else if (input.action === "reveal") {
        if (!canExtra(r)) fail("failed-precondition", "Önce tahminlerini tamamla.");
        r.revealed = true; r.finished = true;
      } else fail("invalid-argument", "Geçersiz işlem.");
      settleReward(s, r, policy);
      r.revision++; r.actions[input.requestId] = fp;
    });
    await settle(uid);
    const r = (await read(uid)).days[input.day];
    if (r?.finished) await onPlayed(uid, input.day, "daily_footballer");
    return {legacy: false, session: view(r, pack.catalog)};
  }
  async function prepareHint(uid, placement, input) {
    if (!await isLinked(uid) || placement !== "daily_footballer_hint") fail("permission-denied", "Hesap gerekli.");
    const s = await read(uid); const r = s.days[dayKey(now())];
    const action = input.action;
    if (!B.paid(r) || r.id !== input.sessionId || input.boostId !== "boost_basic" ||
      !["hint", "extra"].includes(action) ||
      !(action === "extra" ? canExtra(r) : canHint(r))) fail("failed-precondition", "Bu yardım şu anda kullanılamaz.");
    return B.adBenefit(r, {amount: 0, claimKey: "df_hint_" + r.id + "_" + action,
      context: {day: r.day, sessionId: r.id, action}}, "boost_basic");
  }
  async function settleHint(uid, receipt) {
    await change(uid, (s, e) => {
      const r = s.days[receipt.context?.day]; const extra = receipt.context?.action === "extra";
      const usable = r?.id === receipt.context?.sessionId && (extra ? canExtra(r) : canHint(r));
      if (B.recoverAd(e, r, receipt, now(), "boost_basic", usable)) return;
      B.grantAd(r, receipt);
      if (extra) {
        B.consume(e, r, {boostId: "boost_basic", paymentSource: "ad", requestId: receipt.id},
            "boost_basic", "extra_guess", {extraGuess: 1}, now());
        r.extraUsed = true; r.revision++;
      }
    });
  }
  return {status, act, prepareHint, settleHint};
}
module.exports = {createService, catalog, targetFor, clues};
