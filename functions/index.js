/**
 * Shared XI - Daily Fixtures Cloud Functions
 *
 * Secret: API_FOOTBALL_KEY
 *   firebase functions:secrets:set API_FOOTBALL_KEY
 *
 * RTDB: daily_fixtures/{YYYY-MM-DD}/ { updatedAt, matches[], topMatch }
 */
const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const httpsV2 = require("firebase-functions/v2/https");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

const apiKey = defineSecret("API_FOOTBALL_KEY");

// Onemli ligler (API-Football league ids)
const LEAGUE_WEIGHT = {
  2: 100, // UEFA Champions League
  3: 70, // UEFA Europa League
  848: 50, // UEFA Europa Conference League
  203: 55, // Super Lig
  39: 45, // Premier League
  140: 45, // La Liga
  135: 40, // Serie A
  78: 40, // Bundesliga
  61: 40, // Ligue 1
  88: 25, // Eredivisie
  94: 25, // Primeira Liga
  144: 20, // Belgian Pro League
  179: 20, // Scottish Premiership
};

const DERBY_PAIRS = [];
const DERBY_NAME_PATTERNS = [
  [/galatasaray/i, /fenerbah/i],
  [/galatasaray/i, /be[sş]ikta[sş]/i],
  [/fenerbah/i, /be[sş]ikta[sş]/i],
  [/real madrid/i, /barcelona/i],
  [/atl[eé]tico/i, /real madrid/i],
  [/manchester united/i, /manchester city/i],
  [/manchester united/i, /liverpool/i],
  [/liverpool/i, /everton/i],
  [/arsenal/i, /tottenham/i],
  [/ac milan|milan/i, /inter/i],
  [/roma/i, /lazio/i],
  [/bayern/i, /dortmund/i],
  [/dortmund/i, /schalke/i],
  [/psg|paris saint/i, /marseille/i],
  [/ajax/i, /feyenoord/i],
  [/benfica/i, /porto/i],
  [/celtic/i, /rangers/i],
  [/boca/i, /river/i],
];

/**
 * @param {Date=} d
 * @return {string}
 */
function dateKey(d) {
  const date = d || new Date();
  return date.toISOString().slice(0, 10);
}

/**
 * @param {number} homeId
 * @param {number} awayId
 * @return {boolean}
 */
function isDerbyById(homeId, awayId) {
  return DERBY_PAIRS.some((pair) => {
    const a = pair[0];
    const b = pair[1];
    return (a === homeId && b === awayId) || (a === awayId && b === homeId);
  });
}

/**
 * @param {string} homeName
 * @param {string} awayName
 * @return {boolean}
 */
function isDerbyByName(homeName, awayName) {
  return DERBY_NAME_PATTERNS.some((pair) => {
    const reA = pair[0];
    const reB = pair[1];
    return (reA.test(homeName) && reB.test(awayName)) ||
      (reA.test(awayName) && reB.test(homeName));
  });
}

/**
 * @param {Object} match
 * @return {number}
 */
function importance(match) {
  let score = LEAGUE_WEIGHT[match.leagueId] || 10;
  if (match.isDerby) {
    score += 80;
  }
  const big = new RegExp(
      "madrid|barcelona|city|united|liverpool|chelsea|arsenal|" +
      "bayern|juventus|milan|inter|psg|paris|dortmund|" +
      "galatasaray|fenerbah|be[sş]ikta[sş]|napoli|atletico|tottenham",
      "i",
  );
  if (big.test(match.homeName) && big.test(match.awayName)) {
    score += 30;
  }
  return score;
}

/**
 * @param {string} dateStr
 * @param {string} key
 * @return {Promise<Array>}
 */
async function fetchFixturesForDate(dateStr, key) {
  const url = "https://v3.football.api-sports.io/fixtures?date=" + dateStr;
  const res = await fetch(url, {
    headers: {
      "x-apisports-key": key,
    },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error("API-Football error " + res.status + ": " + body);
  }
  const json = await res.json();
  return json.response || [];
}

/**
 * @param {Array} rawList
 * @return {Array}
 */
function normalize(rawList) {
  const out = [];
  for (let i = 0; i < rawList.length; i++) {
    const item = rawList[i];
    const league = item.league || {};
    const teams = item.teams || {};
    const fixture = item.fixture || {};
    const home = teams.home || {};
    const away = teams.away || {};

    const leagueId = league.id;
    if (!LEAGUE_WEIGHT[leagueId]) {
      continue;
    }
    const homeId = home.id;
    const awayId = away.id;
    const homeName = home.name || "?";
    const awayName = away.name || "?";
    const derby = isDerbyById(homeId, awayId) ||
      isDerbyByName(homeName, awayName);
    const match = {
      fixtureId: fixture.id || null,
      homeApiId: homeId || null,
      awayApiId: awayId || null,
      homeName: homeName,
      awayName: awayName,
      leagueId: leagueId,
      leagueName: league.name || "",
      leagueCountry: league.country || "",
      kickoff: fixture.date || null,
      isDerby: derby,
      importance: 0,
    };
    match.importance = importance(match);
    out.push(match);
  }

  out.sort((a, b) => b.importance - a.importance);
  return out;
}

/**
 * @param {string} dateStr
 * @param {Array} matches
 * @return {Promise<void>}
 */
async function writeDay(dateStr, matches) {
  const db = admin.database();
  const topMatch = matches.length > 0 ? matches[0] : null;
  await db.ref("daily_fixtures/" + dateStr).set({
    updatedAt: Date.now(),
    matches: matches,
    topMatch: topMatch,
  });
  let topLabel = "none";
  if (topMatch) {
    topLabel = topMatch.homeName + " vs " + topMatch.awayName +
      " (" + topMatch.importance + ")";
  }
  logger.info("Wrote " + matches.length + " matches for " + dateStr, {
    top: topLabel,
  });
}

/** Her gun 03:00 Europe/Istanbul — bugun + yarin */
exports.syncDailyFixtures = onSchedule(
    {
      schedule: "0 3 * * *",
      timeZone: "Europe/Istanbul",
      secrets: [apiKey],
      memory: "256MiB",
    },
    async () => {
      const key = apiKey.value();
      const today = new Date();
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      const days = [today, tomorrow];
      for (let i = 0; i < days.length; i++) {
        const keyDate = dateKey(days[i]);
        try {
          const raw = await fetchFixturesForDate(keyDate, key);
          const matches = normalize(raw);
          await writeDay(keyDate, matches);
        } catch (err) {
          logger.error("Failed for " + keyDate, err);
        }
      }
    },
);
// LINKBALL_05B_DAILY_AUTHORITY_START

/** @param {string} value @return {Date|null} */
function lbParseDailyDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const parsed = new Date(value + "T00:00:00.000Z");
  if (Number.isNaN(parsed.getTime())) return null;
  if (parsed.toISOString().slice(0, 10) !== value) return null;
  return parsed;
}

/** @param {Date} date @return {string} */
function lbDailyDateKey(date) {
  return date.toISOString().slice(0, 10);
}

/** @param {string} dateStr @param {number} delta @return {string} */
function lbShiftDailyDate(dateStr, delta) {
  const date = lbParseDailyDate(dateStr);
  if (!date) return dateStr;
  date.setUTCDate(date.getUTCDate() + delta);
  return lbDailyDateKey(date);
}

/** @param {string} dateStr @return {Promise<Object>} */
async function lbDailyLimits(dateStr) {
  const db = admin.database();
  const snap = await db.ref("daily_fixtures/" + dateStr + "/topMatch").get();
  if (snap.exists() && snap.val()) {
    const fixture = snap.val();
    const leagueId = Number(fixture.leagueId || 0);
    const derby = fixture.isDerby === true;
    if (derby || leagueId === 2 || leagueId === 3 || leagueId === 848) {
      return {roundSeconds: 60, maxLives: 3};
    }
    return {roundSeconds: 90, maxLives: 5};
  }
  const date = lbParseDailyDate(dateStr);
  const weekday = date ? date.getUTCDay() : 0;
  if (weekday === 1 || weekday === 2) {
    return {roundSeconds: 90, maxLives: 5};
  }
  return {roundSeconds: 60, maxLives: 3};
}

/** @param {string} dateStr */
function lbValidateDailyDateWindow(dateStr) {
  const date = lbParseDailyDate(dateStr);
  if (!date) {
    throw new httpsV2.HttpsError("invalid-argument", "Invalid daily challenge date.");
  }
  const now = new Date();
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const ageDays = Math.floor((today.getTime() - date.getTime()) / 86400000);
  if (ageDays < -1 || ageDays > 1095) {
    throw new httpsV2.HttpsError("invalid-argument", "Daily challenge date is outside the allowed window.");
  }
}

/** @param {*} value @param {string} field @param {number} min @param {number} max @return {number} */
function lbDailyInt(value, field, min, max) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new httpsV2.HttpsError("invalid-argument", field + " is outside the allowed range.");
  }
  return parsed;
}

/** @param {string} uid @return {Promise<string>} */
async function lbDailyDisplayName(uid) {
  try {
    const snap = await admin.database().ref("users/" + uid + "/displayName").get();
    const raw = snap.exists() ? String(snap.val() || "") : "";
    const cleaned = raw.trim().replace(/\s+/g, " ").slice(0, 32);
    if (cleaned) return cleaned;
  } catch (err) {
    logger.warn("Daily display name lookup failed", {uid: uid, error: String(err)});
  }
  return "Oyuncu_" + uid.slice(0, 5);
}

exports.startDailyScoreSession = httpsV2.onCall(
    {region: "europe-west1", maxInstances: 30},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new httpsV2.HttpsError("unauthenticated", "Authentication is required.");
      }
      const data = request.data || {};
      const dateStr = String(data.dateKey || "");
      lbValidateDailyDateWindow(dateStr);
      const uid = request.auth.uid;
      const limits = await lbDailyLimits(dateStr);
      const ref = admin.database().ref("dailyScoreSessions/" + uid + "/" + dateStr);
      const now = Date.now();
      const result = await ref.transaction((current) => {
        if (current && typeof current === "object" && Number.isFinite(Number(current.startedAt))) {
          return current;
        }
        return {
          dateKey: dateStr,
          startedAt: now,
          roundSeconds: limits.roundSeconds,
          maxLives: limits.maxLives,
          validationVersion: 1,
        };
      });
      const session = result.snapshot.val() || {};
      return {
        ok: true,
        dateKey: dateStr,
        startedAt: Number(session.startedAt || now),
        roundSeconds: Number(session.roundSeconds || limits.roundSeconds),
        maxLives: Number(session.maxLives || limits.maxLives),
        alreadySubmitted: session.submittedAt != null,
      };
    },
);

exports.submitDailyScore = httpsV2.onCall(
    {region: "europe-west1", maxInstances: 30},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new httpsV2.HttpsError("unauthenticated", "Authentication is required.");
      }
      const data = request.data || {};
      const dateStr = String(data.dateKey || "");
      lbValidateDailyDateWindow(dateStr);
      const foundCount = lbDailyInt(data.foundCount, "foundCount", 0, 80);
      const targetCount = lbDailyInt(data.targetCount, "targetCount", 1, 80);
      const wrongCount = lbDailyInt(data.wrongCount, "wrongCount", 0, 10);
      if (foundCount > targetCount) {
        throw new httpsV2.HttpsError("invalid-argument", "foundCount cannot exceed targetCount.");
      }

      const uid = request.auth.uid;
      const db = admin.database();
      const sessionRef = db.ref("dailyScoreSessions/" + uid + "/" + dateStr);
      const sessionSnap = await sessionRef.get();
      if (!sessionSnap.exists() || !sessionSnap.val()) {
        throw new httpsV2.HttpsError("failed-precondition", "Daily score session was not started.");
      }
      const session = sessionSnap.val();
      const startedAt = Number(session.startedAt || 0);
      const roundSeconds = lbDailyInt(session.roundSeconds, "roundSeconds", 30, 180);
      const maxLives = lbDailyInt(session.maxLives, "maxLives", 1, 10);
      if (wrongCount > maxLives) {
        throw new httpsV2.HttpsError("invalid-argument", "wrongCount exceeds the server challenge limit.");
      }
      if (!Number.isFinite(startedAt) || startedAt <= 0) {
        throw new httpsV2.HttpsError("failed-precondition", "Daily score session is invalid.");
      }

      const now = Date.now();
      const elapsedSeconds = Math.floor(Math.max(0, now - startedAt) / 1000);
      const secondsLeft = Math.max(0, roundSeconds - elapsedSeconds);
      const score = foundCount * 10;
      const successRate = Math.max(0, Math.min(1, foundCount / targetCount));

      const previousDate = lbShiftDailyDate(dateStr, -1);
      const previousSnap = await db.ref("dailyLeaderboard/" + previousDate + "/" + uid).get();
      let serverStreak = 1;
      if (previousSnap.exists() && previousSnap.val()) {
        const previousStreak = Number(previousSnap.val().streak || 0);
        if (Number.isFinite(previousStreak) && previousStreak > 0) {
          serverStreak = Math.min(3660, previousStreak + 1);
        }
      }

      const displayName = await lbDailyDisplayName(uid);
      const leaderboardRef = db.ref("dailyLeaderboard/" + dateStr + "/" + uid);
      let accepted = false;
      const transaction = await leaderboardRef.transaction((current) => {
        if (current && typeof current === "object") {
          const oldScore = Number(current.score || 0);
          const oldSeconds = Number(current.secondsLeft || -1);
          if (score < oldScore) return current;
          if (score === oldScore && secondsLeft <= oldSeconds) return current;
        }
        accepted = true;
        return {
          displayName: displayName,
          score: score,
          successRate: successRate,
          secondsLeft: secondsLeft,
          streak: serverStreak,
          foundCount: foundCount,
          targetCount: targetCount,
          wrongCount: wrongCount,
          finishedAt: now,
          serverValidated: true,
          validationVersion: 1,
        };
      });

      const saved = transaction.snapshot.val() || {};
      await sessionRef.update({
        submittedAt: now,
        lastSubmittedScore: Number(saved.score || score),
        lastSubmittedSecondsLeft: Number(saved.secondsLeft ?? secondsLeft),
      });
      logger.info("Daily leaderboard submission", {
        uid: uid,
        dateKey: dateStr,
        accepted: accepted,
        score: Number(saved.score || score),
        secondsLeft: Number(saved.secondsLeft ?? secondsLeft),
      });
      return {
        ok: true,
        accepted: accepted,
        score: Number(saved.score || score),
        successRate: Number(saved.successRate ?? successRate),
        secondsLeft: Number(saved.secondsLeft ?? secondsLeft),
        streak: Number(saved.streak ?? serverStreak),
      };
    },
);

// LINKBALL_05B_DAILY_AUTHORITY_END
