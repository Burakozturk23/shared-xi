"use strict";
const crypto = require("node:crypto");
const B = require("./boosts");
const {RewardError, dayKey} = require("./rewarded_ads");
const catalog = require("./config/daily_words_catalog.json");
const MODES = ["daily_lingo", "passa_daily", "daily_anagram", "passa_weekly"];
const DAILY = MODES.slice(0, 3);
const defaults = {enabled: false, rewardsEnabled: false, disabledQuestions: []};
const hash = (v) => crypto.createHash("sha256").update(JSON.stringify(v)).digest("hex");
const fail = (code, message) => {
  throw new RewardError(code, message);
};
const normalize = (raw) => String(raw || "").replace(/[ıİøØłŁßẞæÆœŒđĐðÐ]/g,
    (c) => ({ı: "i", İ: "I", ø: "o", Ø: "O", ł: "l", Ł: "L", ß: "ss", ẞ: "SS",
      æ: "ae", Æ: "AE", œ: "oe", Œ: "OE", đ: "d", Đ: "D", ð: "d", Ð: "D"})[c])
    .normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toUpperCase().replace(/[^A-Z]/g, "");
const stateOf = (raw) => ({days: {}, weeks: {}, outbox: {}, paid: {}, ...raw});
const endOfDay = (day) => Date.parse(day + "T00:00:00+03:00") + 86400000;
function weekKey(time) {
  const day = dayKey(time); const d = new Date(day + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7); return d.toISOString().slice(0, 10);
}
function feedback(answer, guess) {
  const marks = Array(guess.length).fill("absent"); const remaining = {};
  for (let i = 0; i < answer.length; i++) {
    if (answer[i] === guess[i]) marks[i] = "exact";
    else remaining[answer[i]] = (remaining[answer[i]] || 0) + 1;
  }
  for (let i = 0; i < guess.length; i++) {
    if (marks[i] !== "exact" && remaining[guess[i]] > 0) {
      marks[i] = "present"; remaining[guess[i]]--;
    }
  }
  return marks;
}
function compiled(period, weekly) {
  const entry = (weekly ? catalog.weekly : catalog.daily)[period]; if (!entry) return null;
  const question = (id) => catalog.questions.find((q) => q.id === id);
  const result = weekly ? {questions: entry.questionIds.map(question)} : {
    lingo: {...catalog.lingo.find((q) => q.id === entry.lingoId), difficulty: entry.lingoDifficulty},
    anagram: entry.anagram.map((a) => ({...catalog.players.find((p) => p.id === a.playerId),
      questionId: "an-" + hash([period, a.playerId]).slice(0, 24), scrambled: a.scrambled})),
    questions: entry.passaIds.map(question),
  };
  result.period = period; result.contentVersion = catalog.version;
  result.packId = "pack-" + hash([weekly, period, result]).slice(0, 32);
  if (!weekly) result.dictionary = catalog.dictionaries[result.lingo.category];
  return result;
}
function newRun(mode, pack, time, boostPolicy) {
  const weekly = mode === "passa_weekly";
  const r = {mode, period: pack.period, packId: pack.packId, contentVersion: pack.contentVersion,
    revision: 0, startedAt: time, closesAt: endOfDay(pack.period) + (weekly ? 6 * 86400000 : 0),
    deadline: weekly ? Math.min(time + 240000, endOfDay(pack.period) + 6 * 86400000) : null,
    finished: false, eligible: false, attempts: 0, index: 0, score: 0, actions: {}, result: null};
  if (mode === "daily_lingo") {
    r.puzzle = pack.lingo; r.guesses = []; r.hint = false;
  } else if (mode === "daily_anagram") {
    r.questions = pack.anagram;
    r.rounds = pack.anagram.map(() => ({status: "pending", guesses: [], bio: false, first: false, score: 0}));
  } else {
    r.questions = pack.questions;
    r.rounds = pack.questions.map(() => ({status: "pending", passed: false}));
    r.queue = pack.questions.map((_, i) => i);
  }
  r.id = "dw_" + hash([mode, pack.packId]).slice(0, 32); r.version = pack.contentVersion;
  r.entry = weekly ? "weekly" : "daily"; r.expiresAt = r.deadline || r.closesAt;
  r.adCredits = 0; r.adGranted = 0; r.adReceipts = {};
  B.pin(r, boostPolicy);
  return r;
}
function restored(r) {
  if (!r) return null;
  r.actions ||= {}; r.guesses ||= []; r.rounds ||= []; r.queue ||= [];
  for (const round of r.rounds) round.guesses ||= [];
  return r;
}
function finish(s, r, reason, time, policy) {
  if (r.finished) return;
  r.finished = true;
  let coins = 0; let xp = 0; let medal = "Katılım"; let solved = 0;
  const normal = ["completed", "timeout"].includes(reason);
  if (r.mode === "daily_lingo") {
    solved = r.guesses.at(-1)?.word === r.puzzle.answer ? 1 : 0;
    r.eligible = normal && (solved === 1 || r.guesses.length === 6);
    if (r.eligible) {
      coins = solved ? 3 : 0; xp = solved ? 6 : 2;
    }
    medal = solved ? r.guesses.length <= 2 && !r.hint ? "Ustalık" : r.guesses.length <= 4 ? "Altın" : "Gümüş" :
      "Tamamlandı";
  } else if (r.mode === "daily_anagram") {
    solved = r.rounds.filter((x) => x.status === "correct").length;
    // A reveal-only day is not participation. Explicit give-up never earns the trio bonus.
    r.eligible = normal && r.attempts > 0 && r.rounds.every((x) => x.status !== "pending");
    if (r.eligible) {
      coins = solved; xp = solved ? solved * 2 : 1;
    }
    const mastery = solved === 3 && r.score >= 250 && r.rounds.every((x) => !x.bio && !x.first);
    medal = mastery ? "Ustalık" : solved === 3 ? "Altın" : solved === 2 ? "Gümüş" : solved === 1 ? "Bronz" : "Katılım";
  } else {
    solved = r.rounds.filter((x) => x.status === "correct").length;
    r.eligible = normal && r.attempts > 0 && r.rounds.every((x) => x.status !== "pending");
    if (r.mode === "passa_daily") {
      if (r.eligible) {
        coins = solved === 7 ? 3 : solved >= 5 ? 2 : solved >= 3 ? 1 : 0; xp = coins ? coins * 2 : 1;
      }
      medal = solved === 7 ? "Ustalık" : solved >= 5 ? "Altın" : solved >= 3 ? "Gümüş" : "Katılım";
    } else {
      if (r.eligible) {
        coins = solved >= 16 ? 2 : 0; xp = solved >= 16 ? 6 : solved > 0 ? 3 : 0;
      }
      medal = solved >= 26 ? "Ustalık" : solved >= 22 ? "Altın" : solved >= 16 ? "Gümüş" : solved ? "Bronz" : "Katılım";
    }
  }
  const ledgerId = `dw__${r.mode}__${r.period}`;
  if (r.assisted && medal === "Ustalık") medal = "Altın";
  r.result = {solved, coins, xp, medal, reason, score: r.score,
    ...(B.paid(r) ? {assisted: r.assisted, masteryEligible: !r.assisted, leaderboardEligible: !r.assisted} : {}),
    eligibleForDailyBonus: r.eligible && r.mode !== "passa_weekly",
    finishedAt: time, ledgerId, rewardEnabled: policy.rewardsEnabled === true};
  if (!policy.rewardsEnabled) {
    r.result.coins = 0; r.result.xp = 0;
  }
  if (policy.rewardsEnabled && (coins || xp)) s.outbox[ledgerId] = {coins, xp, mode: r.mode, period: r.period};
}
function trio(s, day, time, policy) {
  const d = s.days[day]; if (!d || d.bonus) return;
  if (DAILY.every((m) => d[m]?.finished && d[m]?.eligible)) {
    const id = "dw__trio__" + day;
    d.bonus = {coins: policy.rewardsEnabled ? 2 : 0, xp: policy.rewardsEnabled ? 4 : 0,
      at: time, ledgerId: id};
    if (policy.rewardsEnabled) s.outbox[id] = {coins: 2, xp: 4, mode: "daily_trio", period: day};
  }
}
function refresh(s, time, policy) {
  for (const r of [...Object.values(s.days).flatMap((d) => DAILY.map((m) => d[m])), ...Object.values(s.weeks)]) {
    if (!r || r.finished) continue; restored(r);
    const ids = r.puzzle ? [r.puzzle.id] : r.questions.map((q) => q.questionId || q.id);
    if (ids.some((id) => (policy.disabledQuestions || []).includes(id))) {
      finish(s, r, "void", time, policy); r.revision++; continue;
    }
    if (r.mode === "passa_weekly" && time >= r.deadline) {
      for (const round of r.rounds) if (round.status === "pending") round.status = "timeout";
      r.queue = []; finish(s, r, "timeout", r.deadline, policy); r.revision++;
    } else if (time >= r.closesAt) {
      finish(s, r, "expired", r.closesAt, policy); r.revision++;
    }
  }
}
function publicRun(raw, time, paid = {}) {
  const r = restored(raw); if (!r) return null;
  const out = {mode: r.mode, period: r.period, packId: r.packId, contentVersion: r.contentVersion,
    revision: r.revision, serverNow: time, closesAt: r.closesAt, deadline: r.deadline, startedAt: r.startedAt,
    finished: r.finished, index: r.index, score: r.score, attempts: r.attempts, result: r.result,
    rewardPaid: !!paid[r.result?.ledgerId]};
  if (B.paid(r)) {
    Object.assign(out, {id: r.id, support: B.view(r), assisted: r.assisted,
      adCredits: r.adCredits, adGranted: r.adGranted});
  }
  if (r.mode === "daily_lingo") {
    Object.assign(out, {category: r.puzzle.category, length: r.puzzle.answer.length, questionId: r.puzzle.id,
      guesses: r.guesses, hintUsed: r.hint, hintAvailable: r.guesses.length >= 3,
      ...(r.hint ? {hint: r.puzzle.hint} : {}),
      ...(r.finished ? {answer: r.puzzle.answer, display: r.puzzle.display, proof: r.puzzle.proof} : {})});
  } else if (r.mode === "daily_anagram") {
    out.rounds = r.rounds.map((round, i) => {
      const q = r.questions[i]; const ended = round.status !== "pending" || r.finished;
      return {status: round.status, guesses: round.guesses, bio: round.bio, first: round.first, score: round.score,
        ...(i === r.index || ended ? {questionId: q.questionId, scrambledLetters: q.scrambled} : {}),
        ...(round.bio ? {hint: q.countryLabel + " · " + ({Goalkeeper: "Kaleci", Defender: "Defans",
          Midfield: "Orta saha", Attack: "Forvet"}[q.position] || q.position)} : {}),
        ...(round.first ? {firstLetter: q.answer[0]} : {}),
        ...(ended ? {answer: q.answer, name: q.name, playerId: q.id, proof: q.proof} : {})};
    });
    out.questionId = r.questions[r.index].questionId;
  } else {
    out.rounds = r.rounds.map((round, i) => ({status: round.status, passed: round.passed,
      letter: r.questions[i].letter,
      ...(r.finished ? {answer: r.questions[i].answer, explanation: r.questions[i].explanation,
        prompt: r.questions[i].prompt, proof: r.questions[i].proof, submitted: round.submitted || ""} : {})}));
    if (!r.finished) {
      const q = r.questions[r.index];
      out.question = {id: q.id, letter: q.letter, rule: q.rule, prompt: q.prompt, category: q.category,
        difficulty: q.difficulty, passAvailable: !r.rounds[r.index].passed,
        ...(r.rounds[r.index].hint ? {hint: r.rounds[r.index].hint} : {})};
      out.questionId = q.id;
    }
  }
  return out;
}
function archive(s, today) {
  const days = []; let streak = 0; let open = true;
  for (let n = 0; n < 30; n++) {
    const day = dayKey(endOfDay(today) - 1 - n * 86400000); const d = s.days[day] || {};
    const complete = DAILY.some((m) => d[m]?.eligible && !d[m]?.assisted);
    if (open && complete) streak++;
    else if (n > 0 || Object.values(d).some((r) => r?.eligible)) open = false;
    days.push({day, status: complete ? "completed" : DAILY.some((m) => d[m]) ? "played" : "missed",
      results: Object.fromEntries(DAILY.filter((m) => d[m]?.result).map((m) => [m, d[m].result])),
      bonus: d.bonus || null});
  }
  // Continue beyond the visible 30-day window without resetting a longer streak.
  if (open) {
    for (let n = 30; n < Object.keys(s.days).length + 1; n++) {
      const d = s.days[dayKey(endOfDay(today) - 1 - n * 86400000)] || {};
      if (!DAILY.some((m) => d[m]?.eligible && !d[m]?.assisted)) break; streak++;
    }
  }
  return {days, streak, weeks: Object.entries(s.weeks).sort(([a], [b]) => b.localeCompare(a)).slice(0, 8)
      .map(([period, r]) => ({period, result: r.result || null}))};
}
function createService({db, isLinked, grantCoins, grantXp, normalize: economy, project,
  getPolicy = async () => ({}), now = Date.now}) {
  const read = async (uid) => {
    const canonical = (await db.ref(`economyState/${uid}/dailyWords`).get()).val();
    return stateOf(canonical?.storageVersion === 2 ? canonical :
      (await db.ref("dailyWordState/" + uid).get()).val());
  };
  async function change(uid, fn) {
    let error; const time = now(); const legacy = await read(uid);
    const tx = await db.ref("economyState/" + uid).transaction((raw) => {
      error = null; const e = economy(structuredClone(raw));
      const s = stateOf(e.dailyWords?.storageVersion === 2 ? e.dailyWords : structuredClone(legacy));
      try {
        fn(s, time, e); s.storageVersion = 2; s.projectionRevision = (s.projectionRevision || 0) + 1;
        e.dailyWords = s; return e;
      } catch (e) {
        error = e; return raw;
      }
    });
    if (error) throw error;
    if (!tx.committed) fail("aborted", "Aynı isteği yeniden gönder.");
    const value = tx.snapshot.val(); const s = stateOf(value.dailyWords);
    // Compatibility mirror and existing mission trigger; a delayed projection
    // cannot overwrite a later canonical mutation or restore an old wallet.
    await db.ref("dailyWordState/" + uid).transaction((old) =>
      (old?.projectionRevision || 0) > s.projectionRevision ? old : s);
    await project(db, uid, economy(value));
    return s;
  }
  function modeOf(input) {
    if (!MODES.includes(input.mode)) fail("invalid-argument", "Geçersiz günlük oyun."); return input.mode;
  }
  async function pinned(period, weekly, create = true) {
    const ref = db.ref(`dailyWordPrivate/${weekly ? "weekly" : "daily"}/${period}`);
    const current = (await ref.get()).val(); if (current) return current;
    const content = compiled(period, weekly); if (!create || !content) return null;
    return (await ref.transaction((old) => old || content)).snapshot.val();
  }
  async function settle(uid) {
    if (!await isLinked(uid)) return;
    const s = await read(uid);
    for (const [id, reward] of Object.entries(s.outbox)) {
      if (reward.coins) {
        await grantCoins(uid, id, "daily_word_reward", reward.mode + "__" + reward.period,
            reward.coins, "daily-words-v1");
      }
      if (reward.xp) await grantXp(uid, id, reward.xp);
      await change(uid, (next) => {
        next.paid[id] = true; delete next.outbox[id];
      });
    }
  }
  async function status(uid, input) {
    const mode = modeOf(input); const weekly = mode === "passa_weekly";
    const time = now(); const period = weekly ? weekKey(time) : dayKey(time);
    const policy = {...defaults, ...await getPolicy()};
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    const pack = await pinned(period, weekly, policy.enabled);
    await change(uid, (s, t) => {
      refresh(s, t, policy);
      if (!weekly && policy.enabled && pack) {
        const d = s.days[period] ||= {};
        d[mode] ||= newRun(mode, pack, t, boostPolicy); refresh(s, t, policy);
      }
    });
    await settle(uid); const s = await read(uid);
    const r = weekly ? s.weeks[period] : s.days[period]?.[mode];
    return {mode, period, serverNow: time, availability: policy.enabled && !!pack,
      rewardsEnabled: policy.rewardsEnabled, linked: await isLinked(uid),
      reason: !policy.enabled ? "Günlük oyunlar test aşamasında; henüz açılmadı." :
        !pack ? "Bu tarih için onaylı içerik henüz yayımlanmadı." : "",
      packId: pack?.packId || null, contentVersion: pack?.contentVersion || null,
      session: publicRun(r, time, s.paid), archive: archive(s, dayKey(time)),
      bonus: s.days[dayKey(time)]?.bonus || null,
      dailyCompletion: Object.fromEntries(DAILY.map((m) => [m, !!s.days[dayKey(time)]?.[m]?.eligible]))};
  }
  async function act(uid, input) {
    const mode = modeOf(input); const weekly = mode === "passa_weekly";
    if (!/^[a-f0-9]{32}$/.test(input.requestId || "") || typeof input.period !== "string" ||
        !/^\d{4}-\d{2}-\d{2}$/.test(input.period)) fail("invalid-argument", "Geçersiz işlem kimliği.");
    if (input.answer != null && (typeof input.answer !== "string" || input.answer.length > 100)) {
      fail("invalid-argument", "Cevap çok uzun.");
    }
    const policy = {...defaults, ...await getPolicy()};
    const boostPolicy = await B.policyFor(db, uid, await isLinked(uid));
    const fingerprint = hash([mode, input.period, input.packId, input.contentVersion, input.revision,
      input.questionId, input.action, input.answer, ...B.paymentFingerprint(input)]);
    const legacyFingerprint = hash([mode, input.period, input.packId, input.contentVersion, input.revision,
      input.questionId, input.action, input.answer]);
    const pack = await pinned(input.period, weekly, false);
    const s = await change(uid, (s, time, e) => {
      const current = weekly ? weekKey(time) : dayKey(time);
      let r = restored(weekly ? s.weeks[input.period] : s.days[input.period]?.[mode]);
      refresh(s, time, policy);
      // A lost success can be acknowledged after midnight, but can never mutate the old period.
      if (r?.actions[input.requestId]) {
        if (r.actions[input.requestId] !== fingerprint &&
          (B.paid(r) || r.actions[input.requestId] !== legacyFingerprint)) {
          fail("invalid-argument", "İstek içeriği değişti.");
        }
        return;
      }
      if (!policy.enabled) fail("failed-precondition", "Günlük oyunlar şu anda kapalı.");
      if (input.period !== current) fail("failed-precondition", "Gün/hafta değişti. Arşiv korunuyor; yenile.");
      if (!pack || input.packId !== pack.packId || input.contentVersion !== pack.contentVersion) {
        fail("failed-precondition", "İçerik kimliği değişti. Yenile.");
      }
      if (input.action === "start" && weekly) {
        if (r) return;
        r = newRun(mode, pack, time, boostPolicy); s.weeks[current] = r;
        refresh(s, time, policy); r.actions[input.requestId] = fingerprint; return;
      }
      if (!r) fail("failed-precondition", "Önce günlük oyunu aç.");
      // A timed-out game commits its terminal state even if a late response arrives.
      if (r.finished && r.result.reason === "timeout") return;
      if (r.finished) fail("failed-precondition", "Resmî sonuç kilitlendi.");
      if (input.revision !== r.revision) fail("aborted", "Başka cihazda ilerleme var. Yenile.");
      const q = r.puzzle || r.questions[r.index];
      if (input.questionId !== (q.questionId || q.id)) fail("failed-precondition", "Soru değişti. Yenile.");
      const word = normalize(input.answer);
      if (B.paid(r) && ["hint", "bio", "first"].includes(input.action)) {
        const info = help(r, input.action);
        B.consume(e, r, input, info.sku, (q.questionId || q.id) + ":" + input.action, {text: info.text}, time);
      }
      if (input.action === "giveup") {
        finish(s, r, "giveup", time, policy);
      } else if (mode === "daily_lingo") {
        if (input.action === "hint") {
          if (r.guesses.length < 3) fail("failed-precondition", "İpucu üçüncü geçerli tahminden sonra açılır.");
          r.hint = true;
        } else if (input.action === "guess") {
          if (word.length !== q.answer.length || !pack.dictionary.includes(word)) {
            fail("invalid-argument", "Aynı uzunlukta, kategori sözlüğüne ait bir kelime yaz. Hakkın azalmadı.");
          }
          if (r.guesses.some((g) => g.word === word)) fail("already-exists", "Bu kelimeyi zaten denedin.");
          r.guesses.push({word, marks: feedback(q.answer, word)}); r.attempts++;
          if (word === q.answer || r.guesses.length === 6) finish(s, r, "completed", time, policy);
        } else fail("invalid-argument", "Bu yardım günlük Lingo'da yok.");
      } else if (mode === "daily_anagram") {
        const round = r.rounds[r.index];
        if (input.action === "next") {
          if (round.status === "pending" || r.index >= 2) fail("failed-precondition", "Önce bu soruyu bitir.");
          r.index++;
        } else {
          if (round.status !== "pending") fail("failed-precondition", "Bu futbolcunun sonucu kilitlendi.");
          if (input.action === "bio") round.bio = true;
          else if (input.action === "first") round.first = true;
          else if (input.action === "shuffle") {
            const shuffled = [...q.answer].map((c, i) => ({c, key: hash([r.packId, r.revision, i])}))
                .sort((a, b) => a.key.localeCompare(b.key)).map((x) => x.c).join("");
            q.scrambled = shuffled;
            if (q.scrambled === q.answer) {
              for (let shift = 1; shift < q.answer.length; shift++) {
                q.scrambled = q.answer.slice(shift) + q.answer.slice(0, shift);
                if (q.scrambled !== q.answer) break;
              }
            }
          } else if (input.action === "reveal") round.status = "revealed";
          else if (input.action === "guess") {
            if (!word) fail("invalid-argument", "Bir cevap yaz. Hakkın azalmadı.");
            if (round.guesses.includes(word)) fail("already-exists", "Bu cevabı zaten denedin. Hakkın azalmadı.");
            round.guesses.push(word); r.attempts++;
            if (q.aliases.includes(word)) {
              round.status = "correct"; round.score = 100 - (round.guesses.length - 1) * 10 -
                (round.bio ? 15 : 0) - (round.first ? 25 : 0); r.score += round.score;
            } else if (round.guesses.length === 3) round.status = "wrong";
          } else fail("invalid-argument", "Geçersiz Anagram işlemi.");
          if (r.rounds.every((x) => x.status !== "pending")) finish(s, r, "completed", time, policy);
        }
      } else {
        const round = r.rounds[r.index];
        if (input.action === "hint" && B.paid(r)) {
          round.hint = help(r, "hint").text;
        } else if (input.action === "pass") {
          if (round.passed) fail("failed-precondition", "İkinci pas yok; cevapla veya bu soruyu boş bırak.");
          round.passed = true; r.queue.push(r.queue.shift());
        } else if (["guess", "skip"].includes(input.action)) {
          if (input.action === "guess" && !word) fail("invalid-argument", "Cevap yaz veya boş bırak.");
          round.submitted = input.action === "guess" ? word : "";
          const letter = normalize(q.letter);
          const obeys = q.rule === "contains" ? word.includes(letter) : word.startsWith(letter);
          round.status = input.action === "guess" && obeys && q.acceptedAnswers.includes(word) ? "correct" : "wrong";
          if (input.action === "guess") r.attempts++;
          r.queue.shift();
        } else fail("invalid-argument", "Geçersiz Passaparola işlemi.");
        if (!r.queue.length) finish(s, r, "completed", time, policy); else r.index = r.queue[0];
      }
      r.revision++; r.actions[input.requestId] = fingerprint;
      if (!weekly) trio(s, current, time, policy);
    });
    await settle(uid);
    // Return only the requested period, even when retrying an old successful action.
    const latest = await read(uid);
    const run = weekly ? latest.weeks[input.period] : latest.days[input.period]?.[mode];
    return {session: publicRun(run, now(), latest.paid),
      bonus: s.days[input.period]?.bonus || null};
  }
  async function history(uid, input) {
    const mode = modeOf(input);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.period || "") || input.period > dayKey(now())) {
      fail("invalid-argument", "Geçersiz arşiv tarihi.");
    }
    const policy = {...defaults, ...await getPolicy()}; await change(uid, (s, t) => refresh(s, t, policy));
    await settle(uid); const s = await read(uid);
    const r = mode === "passa_weekly" ? s.weeks[input.period] : s.days[input.period]?.[mode];
    return {session: publicRun(r, now(), s.paid), readOnly: true};
  }
  function findRun(s, context) {
    const r = context?.mode === "passa_weekly" ? s.weeks[context.period] : s.days[context?.period]?.[context?.mode];
    return r?.id === context.sessionId ? restored(r) : null;
  }
  async function prepareHint(uid, placement, context) {
    if (placement !== "daily_words_hint" || !await isLinked(uid)) fail("permission-denied", "Hesap gerekli.");
    const policy = {...defaults, ...await getPolicy()};
    if (!policy.enabled) fail("failed-precondition", "Günlük oyunlar şu anda kapalı.");
    const state = await read(uid); refresh(state, now(), policy);
    const r = findRun(state, context);
    if (!B.paid(r) || r.finished || r.expiresAt <= now()) fail("failed-precondition", "Aktif günlük oyun yok.");
    const action = r.mode === "daily_anagram" ? context.boostId === "boost_first_letter" ? "first" : "bio" : "hint";
    const info = help(r, action);
    if (context.boostId !== info.sku) fail("invalid-argument", "Destek türü uyuşmuyor.");
    return B.adBenefit(r, {amount: 0, claimKey: `dw_hint_${r.id}_${r.adGranted}`,
      context: {sessionId: r.id, mode: r.mode, period: r.period, questionId: info.questionId, action}}, info.sku);
  }
  async function settleHint(uid, receipt) {
    const policy = {...defaults, ...await getPolicy()};
    await change(uid, (s, time, e) => {
      refresh(s, time, policy);
      const r = findRun(s, receipt.context);
      let canApply = false;
      if (r && !r.finished && r.expiresAt > time) {
        try {
          canApply = help(r, receipt.context.action).questionId === receipt.context.questionId;
        } catch (_) {
          // A no-longer-useful verified hint is preserved as stock.
        }
      }
      if (B.recoverAd(e, r, receipt, time, "boost_basic", canApply)) return;
      if (!r || !B.paid(r)) fail("failed-precondition", "Reklam oturumu yok.");
      if (!r.adReceipts?.[receipt.id]) B.grantAd(r, receipt);
    });
  }
  return {status, act, history, settle, prepareHint, settleHint};
}
function help(r, action) {
  const q = r.puzzle || r.questions[r.index]; const round = r.rounds?.[r.index];
  if (r.mode === "daily_lingo") {
    if (action !== "hint" || r.hint || r.guesses.length < 3) fail("failed-precondition", "İpucu henüz uygun değil.");
    return {sku: "boost_basic", text: q.hint, questionId: q.id};
  }
  if (r.mode === "daily_anagram") {
    if (!["bio", "first"].includes(action) || round.status !== "pending" || round[action]) {
      fail("failed-precondition", "Bu ipucu açık veya soru bitmiş.");
    }
    return {sku: action === "first" ? "boost_first_letter" : "boost_basic",
      text: action === "first" ? q.answer[0] : q.countryLabel + " · " + q.position, questionId: q.questionId};
  }
  if (action !== "hint" || round.hint || round.status !== "pending") {
    fail("failed-precondition", "İpucu açık veya soru bitmiş.");
  }
  return {sku: "boost_basic", text: `Cevap ${normalize(q.answer).length} harften oluşur.`, questionId: q.id};
}
module.exports = {createService, catalog, compiled, normalize, feedback, weekKey, MODES, defaults};
