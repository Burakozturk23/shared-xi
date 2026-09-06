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
const {onValueWritten} = require("firebase-functions/v2/database");
const crypto = require("node:crypto");
const {GoogleAuth} = require("google-auth-library");

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

/** @param {string} dateStr @return {string} */
function lbDailyWeekKey(dateStr) {
  const date = lbParseDailyDate(dateStr);
  if (!date) return "";

  const weekday = date.getUTCDay() || 7;
  const thursday = new Date(date.getTime());
  thursday.setUTCDate(date.getUTCDate() + 4 - weekday);

  const weekYear = thursday.getUTCFullYear();
  const jan4 = new Date(Date.UTC(weekYear, 0, 4));
  const jan4Weekday = jan4.getUTCDay() || 7;
  const week1Thursday = new Date(jan4.getTime());
  week1Thursday.setUTCDate(jan4.getUTCDate() + 4 - jan4Weekday);

  const diffMs = thursday.getTime() - week1Thursday.getTime();
  const week = 1 + Math.round(diffMs / 604800000);
  return weekYear + "-W" + String(week).padStart(2, "0");
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

/** @param {string} uid @return {Promise<Object>} */
async function lbDailyPublicIdentity(uid) {
  const fallback = {
    displayName: "Oyuncu_" + uid.slice(0, 5),
    normalizedName: null,
    avatarId: "starter_ball",
  };

  try {
    const snap = await admin.database().ref("users/" + uid).get();
    if (!snap.exists() || !snap.val()) return fallback;

    const profile = snap.val();
    const rawName = String(profile.displayName || "");
    const displayName =
      rawName.trim().replace(/\s+/g, " ").slice(0, 32) ||
      fallback.displayName;

    const rawNormalized = String(profile.normalizedName || "").trim();
    const normalizedName = /^[a-z0-9_]{3,16}$/.test(rawNormalized) ?
      rawNormalized : null;

    const rawAvatar = String(profile.avatarId || "").trim();
    const avatarId = rawAvatar.slice(0, 64) || fallback.avatarId;

    return {
      displayName: displayName,
      normalizedName: normalizedName,
      avatarId: avatarId,
    };
  } catch (err) {
    logger.warn("Daily public identity lookup failed", {
      uid: uid,
      error: String(err),
    });
    return fallback;
  }
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

      const identity = await lbDailyPublicIdentity(uid);
      const displayName = identity.displayName;
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
          normalizedName: identity.normalizedName,
          avatarId: identity.avatarId,
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
      const savedScore = Number(saved.score || score);
      const weekKey = lbDailyWeekKey(dateStr);

      if (!weekKey) {
        throw new httpsV2.HttpsError(
            "internal",
            "Weekly leaderboard period could not be resolved.",
        );
      }

      await db.ref(
          "leaderboardState/weeklyUserIndex/" + uid + "/" + weekKey,
      ).set(true);

      const weeklyRef =
        db.ref("weeklyLeaderboard/" + weekKey + "/" + uid);

      const weeklyTx = await weeklyRef.transaction((current) => {
        const row = current && typeof current === "object" ?
          {...current} : {};
        const dailyScores = row.dailyScores &&
            typeof row.dailyScores === "object" ?
          {...row.dailyScores} : {};

        dailyScores[dateStr] = savedScore;

        const values = Object.values(dailyScores)
            .map((value) => Number(value || 0))
            .filter((value) => Number.isFinite(value) && value >= 0);

        const weeklyScore = values.reduce(
            (total, value) => total + value,
            0,
        );
        const bestDailyScore = values.length > 0 ?
          Math.max(...values) : 0;

        return {
          displayName: displayName,
          normalizedName: identity.normalizedName,
          avatarId: identity.avatarId,
          score: weeklyScore,
          daysPlayed: Object.keys(dailyScores).length,
          bestDailyScore: bestDailyScore,
          dailyScores: dailyScores,
          updatedAt: now,
          serverValidated: true,
          validationVersion: 1,
        };
      });

      const weeklySaved = weeklyTx.snapshot.val() || {};

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
        weekKey: weekKey,
        weeklyScore: Number(weeklySaved.score || savedScore),
      });
      return {
        ok: true,
        accepted: accepted,
        score: Number(saved.score || score),
        successRate: Number(saved.successRate ?? successRate),
        secondsLeft: Number(saved.secondsLeft ?? secondsLeft),
        streak: Number(saved.streak ?? serverStreak),
        weekKey: weekKey,
        weeklyScore: Number(weeklySaved.score || savedScore),
      };
    },
);

// LINKBALL_05B_DAILY_AUTHORITY_END


// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_START

const LB_RANKED_DEFAULT_ELO = 1000;
const LB_RANKED_K_FACTOR = 32;
const LB_RANKED_VALIDATION_VERSION = 1;

const LB_RANKED_MODES = {
  shared_xi: "matches",
  grid: "gridMatches",
  cinko: "cinkoMatches",
  five: "fiveMatches",
};

/**
 * @param {Object} request
 */
function lbRequireGoogleLinked(request) {
  if (!request.auth || !request.auth.uid) {
    throw new httpsV2.HttpsError(
        "unauthenticated",
        "Authentication is required.",
    );
  }

  const firebase = request.auth.token.firebase || {};
  const identities = firebase.identities || {};
  const googleIds = identities["google.com"];

  if (!Array.isArray(googleIds) || googleIds.length === 0) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "A Google-linked account is required.",
    );
  }
}

/**
 * @param {number} myElo
 * @param {number} opponentElo
 * @return {number}
 */
function lbRankedExpectedScore(myElo, opponentElo) {
  return 1 / (1 + Math.pow(10, (opponentElo - myElo) / 400));
}

/**
 * @param {number} myElo
 * @param {number} opponentElo
 * @param {number} score
 * @return {number}
 */
function lbRankedNextElo(myElo, opponentElo, score) {
  const expected = lbRankedExpectedScore(myElo, opponentElo);
  return Math.round(
      myElo + LB_RANKED_K_FACTOR * (score - expected),
  );
}

/**
 * @param {Object|null|undefined} raw
 * @return {Object}
 */
function lbRankedModeStat(raw) {
  const data = raw && typeof raw === "object" ? raw : {};
  return {
    wins: Number.isFinite(Number(data.wins)) ? Number(data.wins) : 0,
    losses: Number.isFinite(Number(data.losses)) ? Number(data.losses) : 0,
    draws: Number.isFinite(Number(data.draws)) ? Number(data.draws) : 0,
  };
}

/**
 * @param {Object|null|undefined} raw
 * @return {Object}
 */
function lbRankedModeStats(raw) {
  const data = raw && typeof raw === "object" ? raw : {};
  return {
    shared_xi: lbRankedModeStat(data.shared_xi),
    grid: lbRankedModeStat(data.grid),
    cinko: lbRankedModeStat(data.cinko),
    five: lbRankedModeStat(data.five),
  };
}

/**
 * @param {Object|null|undefined} raw
 * @return {Object}
 */
function lbRankedProfile(raw) {
  const data = raw && typeof raw === "object" ? raw : {};
  const elo = Number.isFinite(Number(data.elo)) ?
    Number(data.elo) : LB_RANKED_DEFAULT_ELO;
  const peakElo = Number.isFinite(Number(data.peakElo)) ?
    Math.max(Number(data.peakElo), elo) : elo;

  return {
    elo: elo,
    peakElo: peakElo,
    wins: Number.isFinite(Number(data.wins)) ? Number(data.wins) : 0,
    losses: Number.isFinite(Number(data.losses)) ? Number(data.losses) : 0,
    draws: Number.isFinite(Number(data.draws)) ? Number(data.draws) : 0,
    currentWinStreak: Number.isFinite(Number(data.currentWinStreak)) ?
      Number(data.currentWinStreak) : 0,
    bestWinStreak: Number.isFinite(Number(data.bestWinStreak)) ?
      Number(data.bestWinStreak) : 0,
    modeStats: lbRankedModeStats(data.modeStats),
  };
}

/**
 * @param {Object} profile
 * @param {string} result
 * @param {string} mode
 * @param {number} eloAfter
 * @param {number} now
 * @return {Object}
 */
function lbRankedNextProfile(profile, result, mode, eloAfter, now) {
  const modeStats = lbRankedModeStats(profile.modeStats);
  const row = lbRankedModeStat(modeStats[mode]);

  row.wins += result === "win" ? 1 : 0;
  row.losses += result === "loss" ? 1 : 0;
  row.draws += result === "draw" ? 1 : 0;
  modeStats[mode] = row;

  const currentWinStreak =
    result === "win" ? profile.currentWinStreak + 1 : 0;

  return {
    elo: eloAfter,
    peakElo: Math.max(profile.peakElo, eloAfter),
    wins: profile.wins + (result === "win" ? 1 : 0),
    losses: profile.losses + (result === "loss" ? 1 : 0),
    draws: profile.draws + (result === "draw" ? 1 : 0),
    currentWinStreak: currentWinStreak,
    bestWinStreak: Math.max(profile.bestWinStreak, currentWinStreak),
    modeStats: modeStats,
    updatedAt: now,
  };
}

/**
 * @param {string} mode
 * @param {Object} match
 * @return {Object}
 */
function lbRankedMatchFacts(mode, match) {
  const player1Uid = String(match.player1Uid || "");
  const player2Uid = String(match.player2Uid || "");

  if (!player1Uid || !player2Uid || player1Uid === player2Uid) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Ranked match participants are invalid.",
    );
  }

  if (match.ranked !== true) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "The match is not ranked.",
    );
  }

  const game = match.game && typeof match.game === "object" ?
    match.game : {};

  if (match.status !== "finished" || game.gameOver !== true) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "The ranked match is not finished.",
    );
  }

  let winnerUid = null;

  if (mode === "shared_xi") {
    const winner = String(game.winner || "");
    if (winner && winner !== "draw") {
      if (winner === player1Uid || winner === match.player1Name) {
        winnerUid = player1Uid;
      } else if (winner === player2Uid || winner === match.player2Name) {
        winnerUid = player2Uid;
      } else {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "The ranked winner cannot be resolved.",
        );
      }
    }
  } else if (game.winnerUid != null) {
    const rawWinner = String(game.winnerUid);
    if (rawWinner !== player1Uid && rawWinner !== player2Uid) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "The ranked winner is not a participant.",
      );
    }
    winnerUid = rawWinner;
  }

  const scores = game.scores && typeof game.scores === "object" ?
    game.scores : {};
  const players = match.players && typeof match.players === "object" ?
    match.players : {};

  const player1Score = mode === "shared_xi" ?
    Number((players[player1Uid] || {}).score || 0) :
    Number(scores[player1Uid] || 0);

  const player2Score = mode === "shared_xi" ?
    Number((players[player2Uid] || {}).score || 0) :
    Number(scores[player2Uid] || 0);

  return {
    player1Uid,
    player2Uid,
    winnerUid,
    player1Score,
    player2Score,
  };
}

/**
 * @param {string} uid
 * @param {string} winnerUid
 * @return {string}
 */
function lbRankedResultName(uid, winnerUid) {
  if (!winnerUid) return "draw";
  return uid === winnerUid ? "win" : "loss";
}

/**
 * @param {string} result
 * @return {number}
 */
function lbRankedResultScore(result) {
  if (result === "win") return 1;
  if (result === "loss") return 0;
  return 0.5;
}

/**
 * @param {Object} facts
 * @return {string}
 */
function lbRankedWinnerSlot(facts) {
  if (!facts.winnerUid) return "draw";
  if (facts.winnerUid === facts.player1Uid) return "player1";
  if (facts.winnerUid === facts.player2Uid) return "player2";

  throw new httpsV2.HttpsError(
      "failed-precondition",
      "Ranked winner is not a participant.",
  );
}

/**
 * @param {Object} facts
 * @return {string}
 */
function lbRankedStateSignature(facts) {
  return [
    lbRankedWinnerSlot(facts),
    Math.trunc(facts.player1Score),
    Math.trunc(facts.player2Score),
  ].join("|");
}

/**
 * Turn a caller observation into a canonical server-side attestation.
 *
 * The caller declaration is NEVER used as the result authority. Every field is
 * checked against the server-read finished match first.
 *
 * @param {string} uid
 * @param {Object} data
 * @param {Object} facts
 * @return {Object}
 */
function lbRankedObservation(uid, data, facts) {
  const result = String(data.result || "");
  const opponentUid = String(data.opponentUid || "");
  const myScore = Number(data.myScore);
  const opponentScore = Number(data.opponentScore);

  if (!["win", "loss", "draw"].includes(result)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid ranked result attestation.",
    );
  }

  const expectedOpponent = uid === facts.player1Uid ?
    facts.player2Uid : facts.player1Uid;

  if (opponentUid !== expectedOpponent) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Ranked opponent does not match the stored match.",
    );
  }

  if (!Number.isInteger(myScore) || !Number.isInteger(opponentScore) ||
      myScore < 0 || opponentScore < 0 ||
      myScore > 10000 || opponentScore > 10000) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Ranked score attestation is invalid.",
    );
  }

  const expectedResult = lbRankedResultName(uid, facts.winnerUid);
  const expectedMyScore = uid === facts.player1Uid ?
    facts.player1Score : facts.player2Score;
  const expectedOpponentScore = uid === facts.player1Uid ?
    facts.player2Score : facts.player1Score;

  if (result !== expectedResult ||
      myScore !== expectedMyScore ||
      opponentScore !== expectedOpponentScore) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Ranked observation does not match the stored final state.",
    );
  }

  return {
    result: result,
    winnerSlot: lbRankedWinnerSlot(facts),
    player1Score: facts.player1Score,
    player2Score: facts.player2Score,
    stateSignature: lbRankedStateSignature(facts),
    observedAt: Date.now(),
    serverValidated: true,
    validationVersion: LB_RANKED_VALIDATION_VERSION,
  };
}

/**
 * @param {Object} rawUser
 * @param {Object} trusted
 * @param {Object} context
 * @return {Object}
 */
function lbRankedUserMirror(rawUser, trusted, context) {
  const user = rawUser && typeof rawUser === "object" ? rawUser : {};
  const history = user.matchHistory &&
      typeof user.matchHistory === "object" ?
    {...user.matchHistory} : {};
  const recorded = user.recordedMatches &&
      typeof user.recordedMatches === "object" ?
    {...user.recordedMatches} : {};

  history[context.matchId] = {
    result: context.result,
    opponentName: context.opponentName,
    myScore: context.myScore,
    opponentScore: context.opponentScore,
    playedAt: context.now,
    eloBefore: context.eloBefore,
    eloAfter: context.eloAfter,
    eloDelta: context.eloAfter - context.eloBefore,
    serverValidated: true,
    validationVersion: LB_RANKED_VALIDATION_VERSION,
  };

  const historyKeys = Object.keys(history);
  historyKeys.sort((a, b) => {
    const av = Number((history[a] || {}).playedAt || 0);
    const bv = Number((history[b] || {}).playedAt || 0);
    return bv - av;
  });
  for (const key of historyKeys.slice(15)) {
    delete history[key];
  }

  recorded[context.matchId] = context.result;
  const recordedKeys = Object.keys(recorded);
  for (const key of recordedKeys.slice(0, Math.max(0, recordedKeys.length - 50))) {
    delete recorded[key];
  }

  return {
    elo: trusted.elo,
    wins: trusted.wins,
    losses: trusted.losses,
    draws: trusted.draws,
    matchHistory: history,
    recordedMatches: recorded,
    updatedAt: context.now,
  };
}

/**
 * @param {Object} user
 * @param {Object} trusted
 * @param {number} now
 * @return {Object}
 */
function lbRankedLeaderboardProjection(user, trusted, now) {
  const profile = user && typeof user === "object" ? user : {};
  return {
    displayName: String(profile.displayName || "Oyuncu").slice(0, 32),
    normalizedName: profile.normalizedName || null,
    avatarId: profile.avatarId || "starter_ball",
    elo: trusted.elo,
    wins: trusted.wins,
    losses: trusted.losses,
    draws: trusted.draws,
    played: trusted.wins + trusted.losses + trusted.draws,
    updatedAt: now,
    serverValidated: true,
    validationVersion: LB_RANKED_VALIDATION_VERSION,
  };
}

exports.submitRankedResult = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const data = request.data || {};
      const mode = String(data.mode || "");
      const matchId = String(data.matchId || "").trim();

      if (!Object.prototype.hasOwnProperty.call(LB_RANKED_MODES, mode)) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Unknown ranked mode.",
        );
      }

      if (!/^[A-Za-z0-9_-]{3,180}$/.test(matchId)) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid match id.",
        );
      }

      const uid = request.auth.uid;
      const db = admin.database();
      const matchPath = LB_RANKED_MODES[mode] + "/" + matchId;
      const matchSnap = await db.ref(matchPath).get();

      if (!matchSnap.exists() || !matchSnap.val()) {
        throw new httpsV2.HttpsError(
            "not-found",
            "Ranked match was not found.",
        );
      }

      const match = matchSnap.val();
      let facts = lbRankedMatchFacts(mode, match);

      if (uid !== facts.player1Uid && uid !== facts.player2Uid) {
        throw new httpsV2.HttpsError(
            "permission-denied",
            "Only ranked match participants may settle the result.",
        );
      }

      const settlementRef = db.ref(
          "rankedState/settlements/" + mode + "/" + matchId,
      );
      const previous = await settlementRef.get();

      if (previous.exists() && previous.val()) {
        const settled = previous.val();
        const mySide = uid === facts.player1Uid ? "player1" : "player2";
        return {
          ok: true,
          alreadySettled: true,
          pendingOpponent: false,
          result: settled[mySide + "Result"] || "draw",
          myElo: Number(settled[mySide + "EloAfter"] || LB_RANKED_DEFAULT_ELO),
          eloDelta: Number(settled[mySide + "EloDelta"] || 0),
        };
      }

      const observation = lbRankedObservation(uid, data, facts);
      const otherUid = uid === facts.player1Uid ?
        facts.player2Uid : facts.player1Uid;
      const attestationBase =
        "rankedState/attestations/" + mode + "/" + matchId;

      await db.ref(attestationBase + "/" + uid).set(observation);

      const peerSnap = await db.ref(attestationBase + "/" + otherUid).get();

      if (!peerSnap.exists() || !peerSnap.val()) {
        const eloSnap = await db.ref(
            "rankedState/profiles/" + uid + "/elo",
        ).get();

        return {
          ok: true,
          alreadySettled: false,
          pendingOpponent: true,
          result: observation.result,
          myElo: Number(eloSnap.val() || LB_RANKED_DEFAULT_ELO),
          eloDelta: 0,
        };
      }

      const peer = peerSnap.val();
      if (peer.serverValidated !== true ||
          Number(peer.validationVersion || 0) <
            LB_RANKED_VALIDATION_VERSION ||
          peer.stateSignature !== observation.stateSignature) {
        throw new httpsV2.HttpsError(
            "aborted",
            "Ranked participant attestations do not match.",
        );
      }

      // Close the read/attest/settle time-of-check window with one final read.
      const finalMatchSnap = await db.ref(matchPath).get();
      if (!finalMatchSnap.exists() || !finalMatchSnap.val()) {
        throw new httpsV2.HttpsError(
            "not-found",
            "Ranked match disappeared before settlement.",
        );
      }

      const finalFacts = lbRankedMatchFacts(mode, finalMatchSnap.val());
      if (lbRankedStateSignature(finalFacts) !== observation.stateSignature) {
        throw new httpsV2.HttpsError(
            "aborted",
            "Ranked final state changed during attestation.",
        );
      }
      facts = finalFacts;

      const userSnaps = await Promise.all([
        db.ref("users/" + facts.player1Uid).get(),
        db.ref("users/" + facts.player2Uid).get(),
      ]);
      const user1 = userSnaps[0].exists() ? userSnaps[0].val() : {};
      const user2 = userSnaps[1].exists() ? userSnaps[1].val() : {};
      const now = Date.now();

      const stateRef = db.ref("rankedState");
      const tx = await stateRef.transaction((current) => {
        const state = current && typeof current === "object" ?
          {...current} : {};
        const profiles = state.profiles &&
            typeof state.profiles === "object" ?
          {...state.profiles} : {};
        const settlements = state.settlements &&
            typeof state.settlements === "object" ?
          {...state.settlements} : {};
        const modeSettlements = settlements[mode] &&
            typeof settlements[mode] === "object" ?
          {...settlements[mode]} : {};

        if (modeSettlements[matchId]) {
          return;
        }

        const p1 = lbRankedProfile(profiles[facts.player1Uid]);
        const p2 = lbRankedProfile(profiles[facts.player2Uid]);
        const p1Result = lbRankedResultName(
            facts.player1Uid,
            facts.winnerUid,
        );
        const p2Result = lbRankedResultName(
            facts.player2Uid,
            facts.winnerUid,
        );

        const p1After = lbRankedNextElo(
            p1.elo,
            p2.elo,
            lbRankedResultScore(p1Result),
        );
        const p2After = lbRankedNextElo(
            p2.elo,
            p1.elo,
            lbRankedResultScore(p2Result),
        );

        const next1 = lbRankedNextProfile(
            p1,
            p1Result,
            mode,
            p1After,
            now,
        );
        const next2 = lbRankedNextProfile(
            p2,
            p2Result,
            mode,
            p2After,
            now,
        );

        profiles[facts.player1Uid] = next1;
        profiles[facts.player2Uid] = next2;

        modeSettlements[matchId] = {
          matchId,
          mode,
          player1Uid: facts.player1Uid,
          player2Uid: facts.player2Uid,
          winnerUid: facts.winnerUid,
          player1Result: p1Result,
          player2Result: p2Result,
          player1EloBefore: p1.elo,
          player2EloBefore: p2.elo,
          player1EloAfter: p1After,
          player2EloAfter: p2After,
          player1EloDelta: p1After - p1.elo,
          player2EloDelta: p2After - p2.elo,
          settledAt: now,
          serverValidated: true,
          validationVersion: LB_RANKED_VALIDATION_VERSION,
        };

        settlements[mode] = modeSettlements;
        state.profiles = profiles;
        state.settlements = settlements;
        return state;
      });

      let settlement;
      let trusted1;
      let trusted2;

      if (tx.committed) {
        const state = tx.snapshot.val() || {};
        settlement =
          (((state.settlements || {})[mode] || {})[matchId]) || null;
        trusted1 = (state.profiles || {})[facts.player1Uid] || null;
        trusted2 = (state.profiles || {})[facts.player2Uid] || null;
      } else {
        const settledSnap = await settlementRef.get();
        settlement = settledSnap.val();

        const trustedSnaps = await Promise.all([
          db.ref("rankedState/profiles/" + facts.player1Uid).get(),
          db.ref("rankedState/profiles/" + facts.player2Uid).get(),
        ]);
        trusted1 = trustedSnaps[0].val();
        trusted2 = trustedSnaps[1].val();
      }

      if (!settlement || !trusted1 || !trusted2) {
        throw new httpsV2.HttpsError(
            "aborted",
            "Ranked settlement could not be finalized.",
        );
      }

      const p1Name = String(user1.displayName || match.player1Name || "Oyuncu");
      const p2Name = String(user2.displayName || match.player2Name || "Oyuncu");

      const p1Context = {
        matchId,
        result: settlement.player1Result,
        opponentName: p2Name,
        myScore: facts.player1Score,
        opponentScore: facts.player2Score,
        now,
        eloBefore: settlement.player1EloBefore,
        eloAfter: settlement.player1EloAfter,
      };
      const p2Context = {
        matchId,
        result: settlement.player2Result,
        opponentName: p1Name,
        myScore: facts.player2Score,
        opponentScore: facts.player1Score,
        now,
        eloBefore: settlement.player2EloBefore,
        eloAfter: settlement.player2EloAfter,
      };

      const mirror1 = lbRankedUserMirror(user1, trusted1, p1Context);
      const mirror2 = lbRankedUserMirror(user2, trusted2, p2Context);

      const updates = {};
      for (const [key, value] of Object.entries(mirror1)) {
        updates["users/" + facts.player1Uid + "/" + key] = value;
      }
      for (const [key, value] of Object.entries(mirror2)) {
        updates["users/" + facts.player2Uid + "/" + key] = value;
      }

      updates["globalLeaderboard/" + facts.player1Uid] =
        lbRankedLeaderboardProjection(user1, trusted1, now);
      updates["globalLeaderboard/" + facts.player2Uid] =
        lbRankedLeaderboardProjection(user2, trusted2, now);

      await db.ref().update(updates);

      const mySide = uid === facts.player1Uid ? "player1" : "player2";

      return {
        ok: true,
        alreadySettled: !tx.committed,
        pendingOpponent: false,
        result: settlement[mySide + "Result"],
        myElo: settlement[mySide + "EloAfter"],
        eloDelta: settlement[mySide + "EloDelta"],
      };
    },
);

// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_END


// LINKBALL_16_4B_FRIENDS_FOUNDATION_START

const LB_SOCIAL_MAX_FRIENDS = 250;
const LB_SOCIAL_MAX_OUTGOING_REQUESTS = 30;
const LB_SOCIAL_AVATAR_IDS = new Set([
  "starter_ball",
  "captain_shield",
  "keeper_glove",
  "playmaker_star",
  "speedster_bolt",
  "tactician_board",
  "night_owl",
  "champion_cup",
]);

/**
 * @param {string} value
 * @return {string}
 */
function lbSocialNormalizeNickname(value) {
  let text = String(value || "").trim();

  const replacements = {
    "Ç": "c",
    "ç": "c",
    "Ğ": "g",
    "ğ": "g",
    "İ": "i",
    "I": "i",
    "ı": "i",
    "Ö": "o",
    "ö": "o",
    "Ş": "s",
    "ş": "s",
    "Ü": "u",
    "ü": "u",
  };

  for (const [from, to] of Object.entries(replacements)) {
    text = text.split(from).join(to);
  }

  return text.toLowerCase();
}

/**
 * @param {Object} raw
 * @param {string} normalizedName
 * @return {string}
 */
function lbSocialDisplayName(raw, normalizedName) {
  const value = String((raw || {}).displayName || "").trim();
  const pattern =
    /^[A-Za-z0-9ÇĞİÖŞÜçğıöşü][A-Za-z0-9_ÇĞİÖŞÜçğıöşü]{2,15}$/u;

  if (pattern.test(value)) return value;
  return normalizedName;
}

/**
 * @param {string} raw
 * @return {string}
 */
function lbSocialAvatarId(raw) {
  const value = String(raw || "").trim();
  if (LB_SOCIAL_AVATAR_IDS.has(value)) return value;
  return "starter_ball";
}

/**
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function lbSocialHasGoogleProvider(uid) {
  try {
    const authUser = await admin.auth().getUser(uid);
    return authUser.providerData.some(
        (provider) => provider.providerId === "google.com",
    );
  } catch (error) {
    if (error && error.code === "auth/user-not-found") {
      return false;
    }
    throw error;
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object|null>}
 */
async function lbSocialBuildPublicProfile(db, uid) {
  if (!await lbSocialHasGoogleProvider(uid)) {
    return null;
  }

  const userSnap = await db.ref("users/" + uid).get();
  if (!userSnap.exists() || !userSnap.val()) {
    return null;
  }

  const user = userSnap.val();
  if (!user || typeof user !== "object") return null;
  if (user.nicknameNeedsSetup === true) return null;

  let safeNickname;
  try {
    safeNickname = lbNicknameValidateDisplay(
        user.displayName,
    );
  } catch {
    return null;
  }

  const normalizedName = safeNickname.normalizedName;
  const storedNormalized = lbSocialNormalizeNickname(
      user.normalizedName || "",
  );

  if (storedNormalized !== normalizedName) {
    return null;
  }

  const ownerSnap = await db.ref(
      "usernames/" + normalizedName,
  ).get();

  if (!ownerSnap.exists() || ownerSnap.val() !== uid) {
    return null;
  }

  const rankedSnap = await db.ref(
      "rankedState/profiles/" + uid,
  ).get();
  const ranked = rankedSnap.exists() && rankedSnap.val() ?
    rankedSnap.val() : {};

  const trustedElo = Number.isFinite(Number(ranked.elo)) ?
    Number(ranked.elo) : 1000;

  return {
    uid: uid,
    displayName: lbSocialDisplayName(user, normalizedName),
    normalizedName: normalizedName,
    avatarId: lbSocialAvatarId(user.avatarId),
    elo: trustedElo,
    updatedAt: Date.now(),
    profileVersion: 1,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object|null>}
 */
async function lbSocialSyncPublicProfile(db, uid) {
  const projection = await lbSocialBuildPublicProfile(db, uid);
  await db.ref("publicProfiles/" + uid).set(projection);
  return projection;
}

/**
 * @param {string} a
 * @param {string} b
 * @return {string}
 */
function lbSocialPairKey(a, b) {
  const parts = [a, b].sort();
  return crypto.createHash("sha256")
      .update(parts.join("|"))
      .digest("hex");
}

/**
 * @param {string} uid
 * @param {string} otherUid
 * @return {Array<string>}
 */
function lbSocialSortedUids(uid, otherUid) {
  return [uid, otherUid].sort();
}

/**
 * @param {Object|null} raw
 * @param {string} uidA
 * @param {string} uidB
 * @return {Object}
 */
function lbSocialPairState(raw, uidA, uidB) {
  const state = raw && typeof raw === "object" ? {...raw} : {};
  state.uidA = uidA;
  state.uidB = uidB;

  if (!state.blocks || typeof state.blocks !== "object") {
    state.blocks = {};
  } else {
    state.blocks = {...state.blocks};
  }

  return state;
}

/**
 * @param {Object|null} state
 * @param {string} uid
 * @param {string} otherUid
 * @return {string}
 */
function lbSocialRelation(state, uid, otherUid) {
  if (!state || typeof state !== "object") return "none";

  const blocks = state.blocks && typeof state.blocks === "object" ?
    state.blocks : {};

  if (blocks[uid] === true) return "blocked_by_me";
  if (blocks[otherUid] === true) return "blocked_by_them";

  if (state.status === "friends") return "friends";

  if (state.status === "pending") {
    if (state.requesterUid === uid) return "outgoing_pending";
    if (state.requesterUid === otherUid) return "incoming_pending";
  }

  return "none";
}

/**
 * @param {Object|null} state
 * @param {string} uid
 * @return {string|null}
 */
function lbSocialOtherUid(state, uid) {
  if (!state || typeof state !== "object") return null;
  if (state.uidA === uid) return state.uidB || null;
  if (state.uidB === uid) return state.uidA || null;
  return null;
}

/**
 * @param {Object} db
 * @param {string} pairKey
 * @param {string} uidA
 * @param {string} uidB
 * @param {Object|null} state
 * @return {Promise<void>}
 */
async function lbSocialProjectPair(
    db,
    pairKey,
    uidA,
    uidB,
    state,
) {
  const updates = {};

  for (const [left, right] of [[uidA, uidB], [uidB, uidA]]) {
    updates[
        "friendRequestsIncoming/" + left + "/" + right
    ] = null;
    updates[
        "friendRequestsOutgoing/" + left + "/" + right
    ] = null;
    updates["friends/" + left + "/" + right] = null;
    updates["blocks/" + left + "/" + right] = null;
  }

  if (!state || typeof state !== "object") {
    updates[
        "socialState/userPairs/" + uidA + "/" + pairKey
    ] = null;
    updates[
        "socialState/userPairs/" + uidB + "/" + pairKey
    ] = null;
    await db.ref().update(updates);
    return;
  }

  updates[
      "socialState/userPairs/" + uidA + "/" + pairKey
  ] = true;
  updates[
      "socialState/userPairs/" + uidB + "/" + pairKey
  ] = true;

  if (state.status === "pending") {
    const sender = state.requesterUid;
    const target = sender === uidA ? uidB : uidA;

    updates[
        "friendRequestsOutgoing/" + sender + "/" + target
    ] = {
      uid: target,
      pairKey: pairKey,
      createdAt: Number(state.requestedAt || Date.now()),
    };
    updates[
        "friendRequestsIncoming/" + target + "/" + sender
    ] = {
      uid: sender,
      pairKey: pairKey,
      createdAt: Number(state.requestedAt || Date.now()),
    };
  }

  if (state.status === "friends") {
    const since = Number(state.friendsSince || Date.now());

    updates["friends/" + uidA + "/" + uidB] = {
      uid: uidB,
      pairKey: pairKey,
      since: since,
    };
    updates["friends/" + uidB + "/" + uidA] = {
      uid: uidA,
      pairKey: pairKey,
      since: since,
    };
  }

  const blocks = state.blocks && typeof state.blocks === "object" ?
    state.blocks : {};

  if (blocks[uidA] === true) {
    updates["blocks/" + uidA + "/" + uidB] = {
      uid: uidB,
      pairKey: pairKey,
      createdAt: Number(state.blockedAt || Date.now()),
    };
  }

  if (blocks[uidB] === true) {
    updates["blocks/" + uidB + "/" + uidA] = {
      uid: uidA,
      pairKey: pairKey,
      createdAt: Number(state.blockedAt || Date.now()),
    };
  }

  await db.ref().update(updates);
}

/**
 * @param {Object} data
 * @param {string} key
 * @return {string}
 */
function lbSocialTargetUid(data, key) {
  const uid = String((data || {})[key] || "").trim();

  if (!uid || uid.length > 128 || /[.#$[\]/]/.test(uid)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid Linkball user id.",
    );
  }

  return uid;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} path
 * @param {number} maximum
 * @param {string} message
 * @return {Promise<void>}
 */
async function lbSocialRequireBelowLimit(
    db,
    uid,
    path,
    maximum,
    message,
) {
  const snap = await db.ref(path + "/" + uid).get();
  const value = snap.exists() && snap.val() ?
    snap.val() : {};

  const count = value && typeof value === "object" ?
    Object.keys(value).length : 0;

  if (count >= maximum) {
    throw new httpsV2.HttpsError(
        "resource-exhausted",
        message,
    );
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} otherUid
 * @return {Promise<Object>}
 */
async function lbSocialPairSnapshot(db, uid, otherUid) {
  const pairKey = lbSocialPairKey(uid, otherUid);
  const uids = lbSocialSortedUids(uid, otherUid);
  const ref = db.ref("socialState/pairs/" + pairKey);
  const snap = await ref.get();

  return {
    pairKey: pairKey,
    uidA: uids[0],
    uidB: uids[1],
    ref: ref,
    state: snap.exists() && snap.val() ? snap.val() : null,
  };
}

exports.syncPublicProfileProjection = onValueWritten(
    {
      ref: "/users/{uid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      const uid = event.params.uid;
      const db = admin.database();

      if (!event.data.after.exists()) {
        await db.ref("publicProfiles/" + uid).remove();
        return;
      }

      await lbSocialSyncPublicProfile(db, uid);
    },
);

exports.syncMyPublicProfile = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const profile = await lbSocialSyncPublicProfile(db, uid);

      if (!profile) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Complete your Linkball nickname first.",
        );
      }

      return {
        ok: true,
        profile: profile,
      };
    },
);

exports.searchFriendByNickname = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const normalized = lbSocialNormalizeNickname(
          (request.data || {}).nickname,
      );

      if (!/^[a-z0-9_]{3,16}$/.test(normalized)) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid Linkball nickname.",
        );
      }

      const ownerSnap = await db.ref(
          "usernames/" + normalized,
      ).get();

      if (!ownerSnap.exists() || !ownerSnap.val()) {
        return {
          ok: true,
          found: false,
          relationship: "none",
        };
      }

      const targetUid = String(ownerSnap.val());
      const profile = await lbSocialSyncPublicProfile(
          db,
          targetUid,
      );

      if (!profile) {
        return {
          ok: true,
          found: false,
          relationship: "none",
        };
      }

      if (targetUid === uid) {
        return {
          ok: true,
          found: true,
          relationship: "self",
          profile: profile,
        };
      }

      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          targetUid,
      );
      const relation = lbSocialRelation(
          pair.state,
          uid,
          targetUid,
      );

      if (relation === "blocked_by_them") {
        return {
          ok: true,
          found: false,
          relationship: "none",
        };
      }

      return {
        ok: true,
        found: true,
        relationship: relation,
        profile: profile,
      };
    },
);

exports.sendFriendRequest = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );

      if (uid === targetUid) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "You cannot add yourself.",
        );
      }

      const db = admin.database();
      const targetProfile = await lbSocialSyncPublicProfile(
          db,
          targetUid,
      );

      if (!targetProfile) {
        throw new httpsV2.HttpsError(
            "not-found",
            "Linkball player was not found.",
        );
      }

      await lbSocialSyncPublicProfile(db, uid);
      await lbSocialRequireBelowLimit(
          db,
          uid,
          "friendRequestsOutgoing",
          LB_SOCIAL_MAX_OUTGOING_REQUESTS,
          "Too many pending friend requests.",
      );
      await lbSocialRequireBelowLimit(
          db,
          uid,
          "friends",
          LB_SOCIAL_MAX_FRIENDS,
          "Friend limit reached.",
      );

      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          targetUid,
      );
      const now = Date.now();
      const currentRelation = lbSocialRelation(
          pair.state,
          uid,
          targetUid,
      );

      if (currentRelation === "none") {
        await lbSafetyConsumeActionLimit(
            db,
            uid,
            "friend_request",
            now,
            LB_SAFETY_FRIEND_REQUEST_WINDOW_MS,
            LB_SAFETY_FRIEND_REQUEST_WINDOW_LIMIT,
        );
        await lbSafetyConsumePairCooldown(
            db,
            uid,
            "friend_request",
            targetUid,
            now,
            LB_SAFETY_FRIEND_REQUEST_PAIR_COOLDOWN_MS,
        );
      }

      const tx = await pair.ref.transaction((current) => {
        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );
        const relation = lbSocialRelation(
            state,
            uid,
            targetUid,
        );

        if (relation === "blocked_by_me" ||
            relation === "blocked_by_them") {
          return;
        }

        if (relation === "friends" ||
            relation === "outgoing_pending" ||
            relation === "incoming_pending") {
          return state;
        }

        state.status = "pending";
        state.requesterUid = uid;
        state.requestedAt = now;
        state.updatedAt = now;
        delete state.friendsSince;
        delete state.blockedAt;
        return state;
      });

      const state = tx.snapshot.exists() ?
        tx.snapshot.val() : null;
      const relation = lbSocialRelation(
          state,
          uid,
          targetUid,
      );

      if (!tx.committed &&
          (relation === "blocked_by_me" ||
           relation === "blocked_by_them")) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Friend request is unavailable.",
        );
      }

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          state,
      );

      return {
        ok: true,
        relationship: relation,
      };
    },
);

exports.respondFriendRequest = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const senderUid = lbSocialTargetUid(
          request.data,
          "senderUid",
      );
      const accept = (request.data || {}).accept === true;

      if (uid === senderUid) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid friend request.",
        );
      }

      const db = admin.database();

      if (accept) {
        await lbSocialRequireBelowLimit(
            db,
            uid,
            "friends",
            LB_SOCIAL_MAX_FRIENDS,
            "Friend limit reached.",
        );
        await lbSocialRequireBelowLimit(
            db,
            senderUid,
            "friends",
            LB_SOCIAL_MAX_FRIENDS,
            "The other player's friend list is full.",
        );
      }

      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          senderUid,
      );
      const now = Date.now();

      const tx = await pair.ref.transaction((current) => {
        if (!current || typeof current !== "object") {
          return;
        }

        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );
        const relation = lbSocialRelation(
            state,
            uid,
            senderUid,
        );

        if (relation !== "incoming_pending") {
          return;
        }

        if (!accept) {
          return null;
        }

        state.status = "friends";
        state.friendsSince = now;
        state.updatedAt = now;
        delete state.requesterUid;
        delete state.requestedAt;
        return state;
      });

      if (!tx.committed) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Friend request is no longer pending.",
        );
      }

      const state = tx.snapshot.exists() ?
        tx.snapshot.val() : null;

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          state,
      );

      await lbSocialSyncPublicProfile(db, uid);
      await lbSocialSyncPublicProfile(db, senderUid);

      return {
        ok: true,
        relationship: accept ? "friends" : "none",
      };
    },
);

exports.cancelFriendRequest = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );
      const db = admin.database();
      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          targetUid,
      );

      const tx = await pair.ref.transaction((current) => {
        if (!current || typeof current !== "object") {
          return;
        }

        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );

        if (lbSocialRelation(
            state,
            uid,
            targetUid,
        ) !== "outgoing_pending") {
          return;
        }

        return null;
      });

      if (!tx.committed) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Outgoing request is no longer pending.",
        );
      }

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          null,
      );

      return {
        ok: true,
        relationship: "none",
      };
    },
);

exports.removeFriend = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const friendUid = lbSocialTargetUid(
          request.data,
          "friendUid",
      );
      const db = admin.database();
      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          friendUid,
      );

      const tx = await pair.ref.transaction((current) => {
        if (!current || typeof current !== "object") {
          return;
        }

        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );

        if (lbSocialRelation(
            state,
            uid,
            friendUid,
        ) !== "friends") {
          return;
        }

        return null;
      });

      if (!tx.committed) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Friendship no longer exists.",
        );
      }

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          null,
      );

      return {
        ok: true,
        relationship: "none",
      };
    },
);

exports.blockUser = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );

      if (uid === targetUid) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "You cannot block yourself.",
        );
      }

      const db = admin.database();
      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          targetUid,
      );
      const now = Date.now();

      const tx = await pair.ref.transaction((current) => {
        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );

        state.blocks[uid] = true;
        state.status = "blocked";
        state.blockedAt = now;
        state.updatedAt = now;
        delete state.requesterUid;
        delete state.requestedAt;
        delete state.friendsSince;
        return state;
      });

      const state = tx.snapshot.val();

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          state,
      );
      await lbSafetyPurgePairInvites(
          db,
          uid,
          targetUid,
      );

      return {
        ok: true,
        relationship: "blocked_by_me",
      };
    },
);

exports.unblockUser = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );
      const db = admin.database();
      const pair = await lbSocialPairSnapshot(
          db,
          uid,
          targetUid,
      );

      const tx = await pair.ref.transaction((current) => {
        if (!current || typeof current !== "object") {
          return;
        }

        const state = lbSocialPairState(
            current,
            pair.uidA,
            pair.uidB,
        );

        if (state.blocks[uid] !== true) {
          return;
        }

        delete state.blocks[uid];

        if (Object.values(state.blocks).some((value) => value === true)) {
          state.status = "blocked";
          state.updatedAt = Date.now();
          return state;
        }

        return null;
      });

      if (!tx.committed) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Block no longer exists.",
        );
      }

      const state = tx.snapshot.exists() ?
        tx.snapshot.val() : null;

      await lbSocialProjectPair(
          db,
          pair.pairKey,
          pair.uidA,
          pair.uidB,
          state,
      );

      return {
        ok: true,
        relationship: "none",
      };
    },
);

// LINKBALL_16_4B_FRIENDS_FOUNDATION_END

// LINKBALL_16_4D_FRIEND_MATCH_INVITES_START

const LB_SOCIAL_INVITE_TTL_MS = 10 * 60 * 1000;
const LB_SOCIAL_MAX_INCOMING_MATCH_INVITES = 20;
const LB_SOCIAL_INVITE_MODES = new Set([
  "club_club",
  "club_country",
  "grid_classic",
  "grid_random",
  "grid_reverse",
  "random_five",
  "cinko",
  "loto",
  "club_manager",
]);

/**
 * @param {Object} data
 * @return {string}
 */
function lbSocialInviteMode(data) {
  const mode = String((data || {}).mode || "").trim();

  if (!LB_SOCIAL_INVITE_MODES.has(mode)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unsupported friend match mode.",
    );
  }

  return mode;
}

/**
 * @param {Object} data
 * @return {string}
 */
function lbSocialInviteRoomCode(data) {
  const roomCode = String(
      (data || {}).roomCode || "",
  ).trim().toUpperCase();

  if (!/^[A-Z0-9]{4,8}$/.test(roomCode)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid friend match room.",
    );
  }

  return roomCode;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} targetUid
 * @return {Promise<void>}
 */
async function lbSocialRequireFriends(
    db,
    uid,
    targetUid,
) {
  const pair = await lbSocialPairSnapshot(
      db,
      uid,
      targetUid,
  );

  if (lbSocialRelation(
      pair.state,
      uid,
      targetUid,
  ) !== "friends") {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Players are no longer friends.",
    );
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} mode
 * @param {string} roomCode
 * @param {Object} senderProfile
 * @return {Promise<void>}
 */
async function lbSocialValidateInviteRoom(
    db,
    uid,
    mode,
    roomCode,
    senderProfile,
) {
  if (mode === "club_club" ||
      mode === "club_country" ||
      mode === "loto") {
    const snap = await db.ref(
        "rooms/" + roomCode,
    ).get();
    const room = snap.exists() && snap.val() ?
      snap.val() : null;

    const ownsRoom =
      room &&
      (
        room.hostUid === uid ||
        (
          !room.hostUid &&
          room.host === senderProfile.displayName
        )
      );

    if (!room ||
        !ownsRoom ||
        room.status !== "waiting" ||
        room.matchType !== mode) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "Friend match room is no longer available.",
      );
    }

    return;
  }

  if (mode === "club_manager") {
    const snap = await db.ref(
        "rooms/" + roomCode,
    ).get();
    const room = snap.exists() && snap.val() ?
      snap.val() : null;

    const ownsRoom =
      room &&
      (
        room.hostUid === uid ||
        (
          !room.hostUid &&
          room.host === senderProfile.displayName
        )
      );
    const players = room &&
      room.players &&
      typeof room.players === "object" ?
      room.players : {};
    const statusAllowed =
      room &&
      (
        room.status === "waiting" ||
        room.status === "squad"
      );

    if (!room ||
        !ownsRoom ||
        room.mode !== "clubManager" ||
        !statusAllowed ||
        Object.keys(players).length >= 2) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "Club Manager room is no longer available.",
      );
    }

    return;
  }

  let root = "";
  if (mode.startsWith("grid_")) root = "gridMatches";
  if (mode === "random_five") root = "fiveMatches";
  if (mode === "cinko") root = "cinkoMatches";

  if (!root) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unsupported friend match mode.",
    );
  }

  const snap = await db.ref(
      root + "/" + roomCode,
  ).get();
  const match = snap.exists() && snap.val() ?
    snap.val() : null;

  if (!match ||
      match.status !== "waiting" ||
      match.player1Uid !== uid ||
      match.player2Uid != null) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Friend match room is no longer available.",
    );
  }

  if (mode.startsWith("grid_")) {
    const expectedSubtype = mode.substring("grid_".length);

    if (String(match.subType || "") !== expectedSubtype) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "Grid invite mode does not match the room.",
      );
    }
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} inviteId
 * @return {Promise<Object>}
 */
async function lbSocialLoadInvite(
    db,
    uid,
    inviteId,
) {
  const ref = db.ref(
      "matchInvites/" + uid + "/" + inviteId,
  );
  const snap = await ref.get();

  if (!snap.exists() || !snap.val()) {
    throw new httpsV2.HttpsError(
        "not-found",
        "Friend match invite was not found.",
    );
  }

  return {
    invite: snap.val(),
  };
}

exports.sendFriendMatchInvite = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );

      if (uid === targetUid) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "You cannot invite yourself.",
        );
      }

      const mode = lbSocialInviteMode(request.data);
      const roomCode = lbSocialInviteRoomCode(request.data);
      const db = admin.database();

      await lbSocialRequireFriends(
          db,
          uid,
          targetUid,
      );

      const senderProfile = await lbSocialSyncPublicProfile(
          db,
          uid,
      );

      if (!senderProfile) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Linkball social profile is unavailable.",
        );
      }

      await lbSocialValidateInviteRoom(
          db,
          uid,
          mode,
          roomCode,
          senderProfile,
      );

      await lbSocialRequireBelowLimit(
          db,
          targetUid,
          "matchInvites",
          LB_SOCIAL_MAX_INCOMING_MATCH_INVITES,
          "The player has too many pending match invites.",
      );

      const now = Date.now();
      await lbSafetyConsumeActionLimit(
          db,
          uid,
          "match_invite",
          now,
          LB_SAFETY_INVITE_WINDOW_MS,
          LB_SAFETY_INVITE_WINDOW_LIMIT,
      );
      await lbSafetyConsumePairCooldown(
          db,
          uid,
          "match_invite",
          targetUid,
          now,
          LB_SAFETY_INVITE_PAIR_COOLDOWN_MS,
      );

      const inviteId = crypto.randomBytes(12).toString("hex");
      const invite = {
        inviteId: inviteId,
        senderUid: uid,
        senderDisplayName: senderProfile.displayName,
        senderAvatarId: senderProfile.avatarId,
        senderElo: senderProfile.elo,
        mode: mode,
        roomCode: roomCode,
        createdAt: now,
        expiresAt: now + LB_SOCIAL_INVITE_TTL_MS,
      };

      const updates = {};
      updates[
          "matchInvites/" + targetUid + "/" + inviteId
      ] = invite;
      updates[
          "socialState/userInvites/" + uid + "/" + inviteId
      ] = targetUid;

      await db.ref().update(updates);

      return {
        ok: true,
        inviteId: inviteId,
        expiresAt: invite.expiresAt,
      };
    },
);

exports.acceptFriendMatchInvite = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const inviteId = lbSocialTargetUid(
          request.data,
          "inviteId",
      );
      const db = admin.database();

      const loaded = await lbSocialLoadInvite(
          db,
          uid,
          inviteId,
      );
      const invite = loaded.invite;
      const senderUid = String(
          invite.senderUid || "",
      );

      if (!senderUid ||
          Number(invite.expiresAt || 0) <= Date.now()) {
        const updates = {};
        updates[
            "matchInvites/" + uid + "/" + inviteId
        ] = null;

        if (senderUid) {
          updates[
              "socialState/userInvites/" +
            senderUid +
            "/" +
            inviteId
          ] = null;
        }

        await db.ref().update(updates);

        throw new httpsV2.HttpsError(
            "deadline-exceeded",
            "Friend match invite expired.",
        );
      }

      await lbSocialRequireFriends(
          db,
          uid,
          senderUid,
      );

      const senderProfile = await lbSocialSyncPublicProfile(
          db,
          senderUid,
      );

      if (!senderProfile) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Inviter profile is unavailable.",
        );
      }

      await lbSocialValidateInviteRoom(
          db,
          senderUid,
          String(invite.mode || ""),
          String(invite.roomCode || ""),
          senderProfile,
      );

      const updates = {};
      updates[
          "matchInvites/" + uid + "/" + inviteId
      ] = null;
      updates[
          "socialState/userInvites/" +
        senderUid +
        "/" +
        inviteId
      ] = null;

      await db.ref().update(updates);

      return {
        ok: true,
        invite: invite,
      };
    },
);

exports.declineFriendMatchInvite = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const inviteId = lbSocialTargetUid(
          request.data,
          "inviteId",
      );
      const db = admin.database();

      const loaded = await lbSocialLoadInvite(
          db,
          uid,
          inviteId,
      );
      const senderUid = String(
          loaded.invite.senderUid || "",
      );

      const updates = {};
      updates[
          "matchInvites/" + uid + "/" + inviteId
      ] = null;

      if (senderUid) {
        updates[
            "socialState/userInvites/" +
          senderUid +
          "/" +
          inviteId
        ] = null;
      }

      await db.ref().update(updates);

      return {
        ok: true,
      };
    },
);

// LINKBALL_16_4D_FRIEND_MATCH_INVITES_END

// LINKBALL_16_11B_SOCIAL_SAFETY_FOUNDATION_START

const LB_SAFETY_REPORT_CATEGORIES = new Set([
  "harassment",
  "hate_speech",
  "cheating",
  "inappropriate_name",
  "spam",
  "other",
]);
const LB_SAFETY_REPORT_STATUSES = new Set([
  "open",
  "reviewing",
  "actioned",
  "closed",
]);
const LB_SAFETY_REPORT_SOURCES = new Set([
  "profile",
  "friends",
  "match_invite",
  "match",
  "other",
]);
const LB_SAFETY_REPORT_WINDOW_MS = 15 * 60 * 1000;
const LB_SAFETY_REPORT_WINDOW_LIMIT = 5;
const LB_SAFETY_REPORT_DAILY_LIMIT = 15;
const LB_SAFETY_REPORT_TARGET_COOLDOWN_MS = 5 * 60 * 1000;
const LB_SAFETY_REPORT_LIST_LIMIT = 30;
const LB_SAFETY_FRIEND_REQUEST_WINDOW_MS = 15 * 60 * 1000;
const LB_SAFETY_FRIEND_REQUEST_WINDOW_LIMIT = 10;
const LB_SAFETY_FRIEND_REQUEST_PAIR_COOLDOWN_MS = 60 * 1000;
const LB_SAFETY_INVITE_WINDOW_MS = 5 * 60 * 1000;
const LB_SAFETY_INVITE_WINDOW_LIMIT = 10;
const LB_SAFETY_INVITE_PAIR_COOLDOWN_MS = 30 * 1000;

/**
 * @param {string} value
 * @param {boolean} allowWhitespace
 * @return {boolean}
 */
function lbSafetyHasControlChars(value, allowWhitespace) {
  for (let i = 0; i < value.length; i += 1) {
    const code = value.charCodeAt(i);

    if (code === 0x7F) return true;
    if (code >= 0x20) continue;

    if (allowWhitespace &&
        (code === 0x09 || code === 0x0A || code === 0x0D)) {
      continue;
    }

    return true;
  }

  return false;
}

/**
 * @param {Object} data
 * @param {string} field
 * @param {number} maxLength
 * @param {boolean} allowWhitespace
 * @return {string|null}
 */
function lbSafetyOptionalText(
    data,
    field,
    maxLength,
    allowWhitespace,
) {
  const value = String((data || {})[field] || "").trim();
  if (!value) return null;

  if (value.length > maxLength ||
      lbSafetyHasControlChars(value, allowWhitespace)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid " + field + ".",
    );
  }

  return value;
}

/**
 * @param {Object} data
 * @return {string}
 */
function lbSafetyReportCategory(data) {
  const category = String((data || {}).category || "").trim();

  if (!LB_SAFETY_REPORT_CATEGORIES.has(category)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unsupported player report category.",
    );
  }

  return category;
}

/**
 * @param {Object} data
 * @return {string}
 */
function lbSafetyReportSource(data) {
  const source = String(
      (data || {}).sourceContext || "other",
  ).trim();

  if (!LB_SAFETY_REPORT_SOURCES.has(source)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unsupported player report source.",
    );
  }

  return source;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} action
 * @param {number} now
 * @param {number} windowMs
 * @param {number} maximum
 * @return {Promise<void>}
 */
async function lbSafetyConsumeActionLimit(
    db,
    uid,
    action,
    now,
    windowMs,
    maximum,
) {
  const ref = db.ref(
      "safetyState/actionLimits/" + uid + "/" + action,
  );
  let blocked = false;

  const tx = await ref.transaction((raw) => {
    const state = raw && typeof raw === "object" ? {...raw} : {};
    let windowStart = Number(state.windowStart || 0);
    let count = Number(state.count || 0);

    if (!Number.isFinite(windowStart) ||
        !Number.isFinite(count) ||
        now < windowStart ||
        now - windowStart >= windowMs) {
      windowStart = now;
      count = 0;
    }

    if (count >= maximum) {
      blocked = true;
      return;
    }

    return {
      windowStart: windowStart,
      count: count + 1,
      lastActionAt: now,
    };
  });

  if (!tx.committed || blocked) {
    throw new httpsV2.HttpsError(
        "resource-exhausted",
        "Too many social actions. Please try again later.",
    );
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} action
 * @param {string} targetUid
 * @param {number} now
 * @param {number} cooldownMs
 * @return {Promise<void>}
 */
async function lbSafetyConsumePairCooldown(
    db,
    uid,
    action,
    targetUid,
    now,
    cooldownMs,
) {
  const ref = db.ref(
      "safetyState/pairCooldowns/" +
      uid + "/" + action + "/" + targetUid,
  );
  let blocked = false;

  const tx = await ref.transaction((raw) => {
    const lastAt = raw && typeof raw === "object" ?
      Number(raw.lastAt || 0) : 0;

    if (Number.isFinite(lastAt) &&
        lastAt > 0 &&
        now >= lastAt &&
        now - lastAt < cooldownMs) {
      blocked = true;
      return;
    }

    return {
      lastAt: now,
    };
  });

  if (!tx.committed || blocked) {
    throw new httpsV2.HttpsError(
        "resource-exhausted",
        "Please wait before repeating this action.",
    );
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {number} now
 * @return {Promise<void>}
 */
async function lbSafetyConsumeReportLimit(db, uid, now) {
  const ref = db.ref("safetyState/reportLimits/" + uid);
  const dayKey = new Date(now).toISOString().slice(0, 10);
  let blocked = false;

  const tx = await ref.transaction((raw) => {
    const state = raw && typeof raw === "object" ? {...raw} : {};
    let windowStart = Number(state.windowStart || 0);
    let windowCount = Number(state.windowCount || 0);

    if (!Number.isFinite(windowStart) ||
        !Number.isFinite(windowCount) ||
        now < windowStart ||
        now - windowStart >= LB_SAFETY_REPORT_WINDOW_MS) {
      windowStart = now;
      windowCount = 0;
    }

    let dailyCount = state.dayKey === dayKey ?
      Number(state.dailyCount || 0) : 0;

    if (!Number.isFinite(dailyCount)) dailyCount = 0;

    if (windowCount >= LB_SAFETY_REPORT_WINDOW_LIMIT ||
        dailyCount >= LB_SAFETY_REPORT_DAILY_LIMIT) {
      blocked = true;
      return;
    }

    return {
      windowStart: windowStart,
      windowCount: windowCount + 1,
      dayKey: dayKey,
      dailyCount: dailyCount + 1,
      lastReportAt: now,
    };
  });

  if (!tx.committed || blocked) {
    throw new httpsV2.HttpsError(
        "resource-exhausted",
        "Too many player reports. Please try again later.",
    );
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} targetUid
 * @return {Promise<void>}
 */
async function lbSafetyPurgePairInvites(db, uid, targetUid) {
  const updates = {};

  for (const pair of [
    [uid, targetUid],
    [targetUid, uid],
  ]) {
    const senderUid = pair[0];
    const receiverUid = pair[1];
    const snap = await db.ref(
        "socialState/userInvites/" + senderUid,
    ).get();

    if (!snap.exists() || !snap.val()) continue;

    for (const [inviteId, rawTarget] of Object.entries(snap.val())) {
      if (String(rawTarget || "") !== receiverUid) continue;

      updates[
          "socialState/userInvites/" + senderUid + "/" + inviteId
      ] = null;
      updates[
          "matchInvites/" + receiverUid + "/" + inviteId
      ] = null;
    }
  }

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
  }
}

/**
 * @param {Object} report
 * @return {Object}
 */
function lbSafetyReportProjection(report) {
  return {
    reportId: report.reportId,
    targetUid: report.targetUid,
    targetDisplayName: report.targetDisplayName,
    targetAvatarId: report.targetAvatarId,
    category: report.category,
    sourceContext: report.sourceContext,
    modeId: report.modeId,
    status: report.status,
    createdAt: report.createdAt,
    updatedAt: report.updatedAt,
  };
}

exports.reportPlayer = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const targetUid = lbSocialTargetUid(
          request.data,
          "targetUid",
      );

      if (uid === targetUid) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "You cannot report yourself.",
        );
      }

      const category = lbSafetyReportCategory(request.data);
      const sourceContext = lbSafetyReportSource(request.data);
      const description = lbSafetyOptionalText(
          request.data,
          "description",
          500,
          true,
      );
      const modeId = lbSafetyOptionalText(
          request.data,
          "modeId",
          64,
          false,
      );

      const db = admin.database();
      const targetProfile = await lbSocialSyncPublicProfile(
          db,
          targetUid,
      );

      if (!targetProfile) {
        throw new httpsV2.HttpsError(
            "not-found",
            "Linkball player was not found.",
        );
      }

      const now = Date.now();
      await lbSafetyConsumePairCooldown(
          db,
          uid,
          "player_report",
          targetUid,
          now,
          LB_SAFETY_REPORT_TARGET_COOLDOWN_MS,
      );
      await lbSafetyConsumeReportLimit(db, uid, now);

      const reportRef = db.ref("safetyReports").push();
      const reportId = reportRef.key;

      if (!reportId) {
        throw new httpsV2.HttpsError(
            "internal",
            "Could not create player report.",
        );
      }

      const report = {
        reportId: reportId,
        reporterUid: uid,
        targetUid: targetUid,
        targetDisplayName: targetProfile.displayName,
        targetAvatarId: targetProfile.avatarId,
        category: category,
        description: description,
        sourceContext: sourceContext,
        modeId: modeId,
        status: "open",
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
      };
      const projection = lbSafetyReportProjection(report);
      const updates = {};

      updates["safetyReports/" + reportId] = report;
      updates[
          "safetyReportIndex/" + uid + "/" + reportId
      ] = projection;
      updates[
          "safetyReportsByTarget/" + targetUid + "/" + reportId
      ] = true;

      await db.ref().update(updates);

      return {
        ok: true,
        report: projection,
      };
    },
);

exports.getMyPlayerReports = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const snap = await db.ref(
          "safetyReportIndex/" + uid,
      ).get();

      if (!snap.exists() || !snap.val()) {
        return {
          ok: true,
          reports: [],
        };
      }

      const reports = Object.values(snap.val())
          .filter((item) => item && typeof item === "object")
          .filter((item) =>
            LB_SAFETY_REPORT_CATEGORIES.has(
                String(item.category || ""),
            ) &&
            LB_SAFETY_REPORT_STATUSES.has(
                String(item.status || ""),
            ),
          )
          .sort((a, b) =>
            Number(b.createdAt || 0) - Number(a.createdAt || 0),
          )
          .slice(0, LB_SAFETY_REPORT_LIST_LIMIT);

      return {
        ok: true,
        reports: reports,
      };
    },
);

// LINKBALL_16_11B_SOCIAL_SAFETY_FOUNDATION_END

// LINKBALL_16_11C_NICKNAME_AUTHORITY_START

const LB_NICKNAME_MIN_LENGTH = 3;
const LB_NICKNAME_MAX_LENGTH = 16;
const LB_NICKNAME_CHANGE_COOLDOWN_MS = 24 * 60 * 60 * 1000;
const LB_NICKNAME_LOCK_MS = 30 * 1000;

const LB_NICKNAME_RESERVED = new Set([
  "admin",
  "administrator",
  "moderator",
  "mod",
  "support",
  "official",
  "system",
  "linkball",
  "linkballteam",
  "developer",
  "owner",
  "firebase",
  "googleplay",
  "playstore",
]);

const LB_NICKNAME_BLOCKED_EXACT = new Set([
  "amk",
  "aq",
  "oc",
  "pic",
  "sik",
  "ibne",
  "kahpe",
  "fuck",
  "fck",
  "shit",
  "bitch",
  "cunt",
  "nigga",
  "nigger",
  "faggot",
  "retard",
]);

const LB_NICKNAME_BLOCKED_PARTS = [
  "orospu",
  "yarrak",
  "gotveren",
  "pezevenk",
  "siktir",
  "sikik",
  "sikeyim",
  "sikerim",
  "amcik",
  "fuck",
  "shit",
  "bitch",
  "cunt",
  "nigga",
  "nigger",
  "faggot",
];

/**
 * @param {Object} request
 * @return {string}
 */
function lbNicknameRequireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new httpsV2.HttpsError(
        "unauthenticated",
        "Authentication is required.",
        {reason: "signed_out"},
    );
  }

  return request.auth.uid;
}

/**
 * @param {string} code
 * @param {string} message
 * @param {string} reason
 * @param {Object=} extra
 */
function lbNicknameFail(code, message, reason, extra) {
  throw new httpsV2.HttpsError(
      code,
      message,
      {
        reason: reason,
        ...(extra || {}),
      },
  );
}

/**
 * @param {string} raw
 * @return {string}
 */
function lbNicknameSafetyKey(raw) {
  let text = lbSocialNormalizeNickname(raw);

  const replacements = {
    "0": "o",
    "1": "i",
    "2": "z",
    "3": "e",
    "4": "a",
    "5": "s",
    "7": "t",
    "8": "b",
    "9": "g",
  };

  for (const [from, to] of Object.entries(replacements)) {
    text = text.split(from).join(to);
  }

  text = text.split("_").join("");
  return text.replace(/(.)\1+/g, "$1");
}

/**
 * @param {string} raw
 * @return {{displayName: string, normalizedName: string}}
 */
function lbNicknameValidateDisplay(raw) {
  const displayName = String(raw || "").trim();

  if (displayName.length < LB_NICKNAME_MIN_LENGTH ||
      displayName.length > LB_NICKNAME_MAX_LENGTH) {
    lbNicknameFail(
        "invalid-argument",
        "Takma ad 3–16 karakter olmalı.",
        "invalid_length",
    );
  }

  const pattern =
    /^[A-Za-z0-9ÇĞİÖŞÜçğıöşü][A-Za-z0-9_ÇĞİÖŞÜçğıöşü]{2,15}$/u;

  if (!pattern.test(displayName)) {
    lbNicknameFail(
        "invalid-argument",
        "Takma ad yalnız harf, rakam ve alt çizgi içerebilir.",
        "invalid_characters",
    );
  }

  const normalizedName = lbSocialNormalizeNickname(displayName);
  const safetyKey = lbNicknameSafetyKey(displayName);

  if (LB_NICKNAME_RESERVED.has(normalizedName) ||
      LB_NICKNAME_RESERVED.has(safetyKey)) {
    lbNicknameFail(
        "failed-precondition",
        "Bu takma ad Linkball tarafından ayrılmış.",
        "reserved",
    );
  }

  const blockedExact =
    LB_NICKNAME_BLOCKED_EXACT.has(normalizedName) ||
    LB_NICKNAME_BLOCKED_EXACT.has(safetyKey);
  const blockedPart = LB_NICKNAME_BLOCKED_PARTS.some(
      (part) => safetyKey.includes(part),
  );

  if (blockedExact || blockedPart) {
    lbNicknameFail(
        "failed-precondition",
        "Bu takma ad kullanılamaz.",
        "inappropriate",
    );
  }

  return {
    displayName: displayName,
    normalizedName: normalizedName,
  };
}

/**
 * @param {string} uid
 * @return {string}
 */
function lbNicknameGenerated(uid) {
  const clean = String(uid || "")
      .replace(/[^A-Za-z0-9]/g, "")
      .slice(0, 5);
  const suffix = clean || "user";
  return "Oyuncu_" + suffix;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {number} now
 * @return {Promise<Object>}
 */
async function lbNicknameAcquireLock(db, uid, now) {
  const ref = db.ref("safetyState/nicknameLocks/" + uid);
  const token = crypto.randomUUID();
  let blocked = false;

  const tx = await ref.transaction((raw) => {
    const state = raw && typeof raw === "object" ? raw : {};
    const lockedUntil = Number(state.lockedUntil || 0);

    if (Number.isFinite(lockedUntil) && lockedUntil > now) {
      blocked = true;
      return;
    }

    return {
      token: token,
      lockedUntil: now + LB_NICKNAME_LOCK_MS,
    };
  });

  if (!tx.committed || blocked) {
    lbNicknameFail(
        "resource-exhausted",
        "Takma ad işlemi sürüyor. Lütfen tekrar dene.",
        "busy",
    );
  }

  return {
    ref: ref,
    token: token,
  };
}

/**
 * @param {Object} lock
 * @return {Promise<void>}
 */
async function lbNicknameReleaseLock(lock) {
  try {
    await lock.ref.transaction((raw) => {
      if (!raw || typeof raw !== "object") return null;
      if (raw.token === lock.token) return null;
      return;
    });
  } catch (error) {
    logger.warn("Nickname lock release failed", {
      error: String(error),
    });
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} normalizedName
 * @return {Promise<{newlyClaimed: boolean}>}
 */
async function lbNicknameClaimIndex(db, uid, normalizedName) {
  const ref = db.ref("usernames/" + normalizedName);
  const before = await ref.get();

  if (before.exists() && before.val() !== uid) {
    lbNicknameFail(
        "already-exists",
        "Bu takma ad başka bir oyuncu tarafından kullanılıyor.",
        "taken",
    );
  }

  const newlyClaimed = !before.exists();
  let taken = false;

  const tx = await ref.transaction((current) => {
    if (current === null || current === uid) {
      return uid;
    }

    taken = true;
    return;
  });

  if (!tx.committed || taken || tx.snapshot.val() !== uid) {
    lbNicknameFail(
        "already-exists",
        "Bu takma ad başka bir oyuncu tarafından kullanılıyor.",
        "taken",
    );
  }

  return {
    newlyClaimed: newlyClaimed,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} normalizedName
 * @return {Promise<void>}
 */
async function lbNicknameRollbackClaim(db, uid, normalizedName) {
  try {
    const ref = db.ref("usernames/" + normalizedName);
    await ref.transaction((current) => {
      if (current === uid) return null;
      return;
    });
  } catch (error) {
    logger.warn("Nickname claim rollback failed", {
      error: String(error),
    });
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} normalizedName
 * @param {Object} updates
 * @return {Promise<void>}
 */
async function lbNicknameReleaseOldIndex(
    db,
    uid,
    normalizedName,
    updates,
) {
  if (!normalizedName) return;

  const snap = await db.ref(
      "usernames/" + normalizedName,
  ).get();

  if (snap.exists() && snap.val() === uid) {
    updates["usernames/" + normalizedName] = null;
  }
}

/**
 * @param {string} uid
 * @param {string} displayName
 * @return {Promise<void>}
 */
async function lbNicknameSyncAuthDisplayName(uid, displayName) {
  try {
    await admin.auth().updateUser(uid, {
      displayName: displayName,
    });
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") {
      logger.warn("Firebase Auth nickname sync failed", {
        error: String(error),
      });
    }
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} profile
 * @param {number} now
 * @return {Promise<Object>}
 */
async function lbNicknameApplySetupFallback(
    db,
    uid,
    profile,
    now,
) {
  const fallback = lbNicknameGenerated(uid);
  const oldNormalized = lbSocialNormalizeNickname(
      profile.normalizedName || "",
  );
  const updates = {};

  await lbNicknameReleaseOldIndex(
      db,
      uid,
      oldNormalized,
      updates,
  );

  updates["users/" + uid + "/displayName"] = fallback;
  updates["users/" + uid + "/normalizedName"] = null;
  updates["users/" + uid + "/nicknameNeedsSetup"] = true;
  updates["users/" + uid + "/updatedAt"] = now;
  updates["publicProfiles/" + uid] = null;

  await db.ref().update(updates);
  await lbNicknameSyncAuthDisplayName(uid, fallback);

  return {
    ok: true,
    displayName: fallback,
    normalizedName: null,
    nicknameNeedsSetup: true,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} profile
 * @param {number} now
 * @return {Promise<Object>}
 */
async function lbNicknameSyncProfile(db, uid, profile, now) {
  const fallback = lbNicknameGenerated(uid);
  const storedDisplayName = String(
      profile.displayName || "",
  ).trim();
  const storedNormalized = lbSocialNormalizeNickname(
      profile.normalizedName || "",
  );

  if (profile.nicknameNeedsSetup === true &&
      storedDisplayName === fallback &&
      !storedNormalized) {
    await db.ref("publicProfiles/" + uid).remove();
    await lbNicknameSyncAuthDisplayName(uid, fallback);

    return {
      ok: true,
      displayName: fallback,
      normalizedName: null,
      nicknameNeedsSetup: true,
    };
  }

  let nickname;
  try {
    nickname = lbNicknameValidateDisplay(storedDisplayName);
  } catch {
    return lbNicknameApplySetupFallback(
        db,
        uid,
        profile,
        now,
    );
  }

  let claim;
  try {
    claim = await lbNicknameClaimIndex(
        db,
        uid,
        nickname.normalizedName,
    );
  } catch (error) {
    if (error &&
        error.details &&
        error.details.reason === "taken") {
      return lbNicknameApplySetupFallback(
          db,
          uid,
          profile,
          now,
      );
    }
    throw error;
  }

  const updates = {};
  const oldNormalized = storedNormalized;

  if (oldNormalized &&
      oldNormalized !== nickname.normalizedName) {
    await lbNicknameReleaseOldIndex(
        db,
        uid,
        oldNormalized,
        updates,
    );
  }

  updates[
      "users/" + uid + "/displayName"
  ] = nickname.displayName;
  updates[
      "users/" + uid + "/normalizedName"
  ] = nickname.normalizedName;
  updates[
      "users/" + uid + "/nicknameNeedsSetup"
  ] = false;
  updates["users/" + uid + "/updatedAt"] = now;
  updates[
      "usernames/" + nickname.normalizedName
  ] = uid;

  try {
    await db.ref().update(updates);
  } catch (error) {
    if (claim.newlyClaimed &&
        oldNormalized !== nickname.normalizedName) {
      await lbNicknameRollbackClaim(
          db,
          uid,
          nickname.normalizedName,
      );
    }
    throw error;
  }

  await lbNicknameSyncAuthDisplayName(
      uid,
      nickname.displayName,
  );
  await lbSocialSyncPublicProfile(db, uid);

  return {
    ok: true,
    displayName: nickname.displayName,
    normalizedName: nickname.normalizedName,
    nicknameNeedsSetup: false,
  };
}

exports.checkNicknameAvailability = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      const uid = lbNicknameRequireAuth(request);
      const nickname = lbNicknameValidateDisplay(
          (request.data || {}).nickname,
      );
      const db = admin.database();
      const snap = await db.ref(
          "usernames/" + nickname.normalizedName,
      ).get();

      return {
        ok: true,
        available: !snap.exists() || snap.val() === uid,
        normalizedName: nickname.normalizedName,
      };
    },
);

exports.syncMyNickname = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      const uid = lbNicknameRequireAuth(request);
      const db = admin.database();
      const now = Date.now();
      const lock = await lbNicknameAcquireLock(
          db,
          uid,
          now,
      );

      try {
        const snap = await db.ref("users/" + uid).get();

        if (!snap.exists() || !snap.val()) {
          lbNicknameFail(
              "failed-precondition",
              "Linkball profili henüz hazır değil.",
              "profile_missing",
          );
        }

        const profile = snap.val();
        const result = await lbNicknameSyncProfile(
            db,
            uid,
            profile,
            now,
        );
        return result;
      } finally {
        await lbNicknameReleaseLock(lock);
      }
    },
);

exports.setMyNickname = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 30,
    },
    async (request) => {
      const uid = lbNicknameRequireAuth(request);
      const nickname = lbNicknameValidateDisplay(
          (request.data || {}).nickname,
      );
      const db = admin.database();
      const now = Date.now();
      const lock = await lbNicknameAcquireLock(
          db,
          uid,
          now,
      );

      try {
        const userSnap = await db.ref("users/" + uid).get();

        if (!userSnap.exists() || !userSnap.val()) {
          lbNicknameFail(
              "failed-precondition",
              "Linkball profili henüz hazır değil.",
              "profile_missing",
          );
        }

        const profile = userSnap.val();
        const currentDisplayName = String(
            profile.displayName || "",
        ).trim();
        const oldNormalized = lbSocialNormalizeNickname(
            profile.normalizedName || "",
        );

        if (currentDisplayName === nickname.displayName &&
            oldNormalized === nickname.normalizedName) {
          await lbNicknameClaimIndex(
              db,
              uid,
              nickname.normalizedName,
          );

          if (profile.nicknameNeedsSetup === true) {
            await db.ref("users/" + uid).update({
              nicknameNeedsSetup: false,
              updatedAt: now,
            });
          }

          await lbNicknameSyncAuthDisplayName(
              uid,
              nickname.displayName,
          );
          await lbSocialSyncPublicProfile(db, uid);

          return {
            ok: true,
            alreadyCurrent: true,
            displayName: nickname.displayName,
            normalizedName: nickname.normalizedName,
            nicknameNeedsSetup: false,
          };
        }

        const stateSnap = await db.ref(
            "safetyState/nicknameChanges/" + uid,
        ).get();
        const state = stateSnap.exists() && stateSnap.val() ?
          stateSnap.val() : {};
        const lastChangedAt = Number(
            state.lastChangedAt || 0,
        );
        const bypassCooldown =
          profile.nicknameNeedsSetup === true ||
          !Number.isFinite(lastChangedAt) ||
          lastChangedAt <= 0;

        if (!bypassCooldown &&
            now >= lastChangedAt &&
            now - lastChangedAt <
            LB_NICKNAME_CHANGE_COOLDOWN_MS) {
          const nextChangeAt =
            lastChangedAt + LB_NICKNAME_CHANGE_COOLDOWN_MS;

          lbNicknameFail(
              "resource-exhausted",
              "Takma adını 24 saatte bir değiştirebilirsin.",
              "cooldown",
              {nextChangeAt: nextChangeAt},
          );
        }

        const claim = await lbNicknameClaimIndex(
            db,
            uid,
            nickname.normalizedName,
        );
        const updates = {};

        if (oldNormalized &&
            oldNormalized !== nickname.normalizedName) {
          await lbNicknameReleaseOldIndex(
              db,
              uid,
              oldNormalized,
              updates,
          );
        }

        updates[
            "users/" + uid + "/displayName"
        ] = nickname.displayName;
        updates[
            "users/" + uid + "/normalizedName"
        ] = nickname.normalizedName;
        updates[
            "users/" + uid + "/nicknameNeedsSetup"
        ] = false;
        updates["users/" + uid + "/updatedAt"] = now;
        updates[
            "usernames/" + nickname.normalizedName
        ] = uid;
        updates[
            "safetyState/nicknameChanges/" + uid
        ] = {
          lastChangedAt: now,
          nextChangeAt:
            now + LB_NICKNAME_CHANGE_COOLDOWN_MS,
          lastNormalizedName: nickname.normalizedName,
        };

        try {
          await db.ref().update(updates);
        } catch (error) {
          if (claim.newlyClaimed &&
              oldNormalized !== nickname.normalizedName) {
            await lbNicknameRollbackClaim(
                db,
                uid,
                nickname.normalizedName,
            );
          }
          throw error;
        }

        await lbNicknameSyncAuthDisplayName(
            uid,
            nickname.displayName,
        );
        await lbSocialSyncPublicProfile(db, uid);

        return {
          ok: true,
          alreadyCurrent: false,
          displayName: nickname.displayName,
          normalizedName: nickname.normalizedName,
          nicknameNeedsSetup: false,
          nextChangeAt:
            now + LB_NICKNAME_CHANGE_COOLDOWN_MS,
        };
      } finally {
        await lbNicknameReleaseLock(lock);
      }
    },
);

// LINKBALL_16_11C_NICKNAME_AUTHORITY_END


// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_START

const LB_ACHIEVEMENT_CATALOG_VERSION = 1;
const LB_ACHIEVEMENT_DEFINITIONS = [
  {
    id: "first_whistle",
    signal: "ranked_played",
    target: 1,
  },
  {
    id: "first_victory",
    signal: "ranked_wins",
    target: 1,
  },
  {
    id: "challenger_10",
    signal: "ranked_played",
    target: 10,
  },
  {
    id: "loyal_rival_50",
    signal: "ranked_played",
    target: 50,
  },
  {
    id: "centurion_100",
    signal: "ranked_played",
    target: 100,
  },
  {
    id: "winner_10",
    signal: "ranked_wins",
    target: 10,
  },
  {
    id: "winner_50",
    signal: "ranked_wins",
    target: 50,
  },
  {
    id: "winner_100",
    signal: "ranked_wins",
    target: 100,
  },
  {
    id: "streak_3",
    signal: "best_win_streak",
    target: 3,
  },
  {
    id: "streak_5",
    signal: "best_win_streak",
    target: 5,
  },
  {
    id: "streak_10",
    signal: "best_win_streak",
    target: 10,
  },
  {
    id: "elo_1100",
    signal: "peak_elo",
    target: 1100,
  },
  {
    id: "elo_1250",
    signal: "peak_elo",
    target: 1250,
  },
  {
    id: "elo_1400",
    signal: "peak_elo",
    target: 1400,
  },
  {
    id: "elo_1600",
    signal: "peak_elo",
    target: 1600,
  },
  {
    id: "shared_xi_master",
    signal: "ranked_shared_xi_wins",
    target: 10,
  },
  {
    id: "grid_master",
    signal: "ranked_grid_wins",
    target: 10,
  },
  {
    id: "cinko_master",
    signal: "ranked_cinko_wins",
    target: 10,
  },
  {
    id: "five_master",
    signal: "ranked_five_wins",
    target: 10,
  },
  {
    id: "daily_first",
    signal: "daily_days",
    target: 1,
  },
  {
    id: "daily_7",
    signal: "daily_days",
    target: 7,
  },
  {
    id: "daily_30",
    signal: "daily_days",
    target: 30,
  },
  {
    id: "daily_streak_7",
    signal: "best_daily_streak",
    target: 7,
  },
  {
    id: "daily_perfect",
    signal: "perfect_daily_count",
    target: 1,
  },
  {
    id: "weekly_5",
    signal: "weekly_days",
    target: 5,
  },
  {
    id: "first_friend",
    signal: "friend_count_peak",
    target: 1,
  },
  {
    id: "friends_5",
    signal: "friend_count_peak",
    target: 5,
  },
  {
    id: "friends_25",
    signal: "friend_count_peak",
    target: 25,
  },
];

/**
 * @param {*} value
 * @return {number}
 */
function lbAchievementNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

/**
 * @param {Object|null|undefined} raw
 * @return {Object}
 */
function lbAchievementState(raw) {
  const data = raw && typeof raw === "object" ? raw : {};
  const signals = data.signals && typeof data.signals === "object" ?
    {...data.signals} : {};
  const unlocks = data.unlocks && typeof data.unlocks === "object" ?
    {...data.unlocks} : {};
  const dailyDates = data.dailyDates &&
      typeof data.dailyDates === "object" ?
    {...data.dailyDates} : {};

  return {
    signals: signals,
    unlocks: unlocks,
    dailyDates: dailyDates,
    backfillVersion: lbAchievementNumber(data.backfillVersion),
    backfilledAt: lbAchievementNumber(data.backfilledAt),
    updatedAt: lbAchievementNumber(data.updatedAt),
  };
}

/**
 * @param {Object} state
 * @param {string} source
 * @param {number} now
 * @return {Object}
 */
function lbAchievementEvaluate(state, source, now) {
  for (const definition of LB_ACHIEVEMENT_DEFINITIONS) {
    const value = lbAchievementNumber(
        state.signals[definition.signal],
    );

    if (value < definition.target || state.unlocks[definition.id]) {
      continue;
    }

    state.unlocks[definition.id] = {
      unlockedAt: now,
      source: source,
      catalogVersion: LB_ACHIEVEMENT_CATALOG_VERSION,
    };
  }

  state.updatedAt = now;
  return state;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<boolean>}
 */
async function lbAchievementEligible(db, uid) {
  const userSnap = await db.ref("users/" + uid).get();

  if (!userSnap.exists() || !userSnap.val()) {
    return false;
  }

  return lbSocialHasGoogleProvider(uid);
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} state
 * @return {Promise<void>}
 */
async function lbAchievementProject(db, uid, state) {
  const updates = {};

  for (const definition of LB_ACHIEVEMENT_DEFINITIONS) {
    const unlock = state.unlocks[definition.id] || null;
    const value = lbAchievementNumber(
        state.signals[definition.signal],
    );
    const progressPath =
      "achievementProgress/" + uid + "/" + definition.id;

    updates[progressPath] = {
      value: Math.min(value, definition.target),
      rawValue: value,
      target: definition.target,
      unlocked: unlock != null,
      unlockedAt: unlock ? unlock.unlockedAt : null,
      updatedAt: state.updatedAt,
      catalogVersion: LB_ACHIEVEMENT_CATALOG_VERSION,
    };

    if (unlock) {
      const unlockPath =
        "userAchievements/" + uid + "/" + definition.id;

      updates[unlockPath] = {
        unlockedAt: unlock.unlockedAt,
        source: unlock.source,
        catalogVersion: LB_ACHIEVEMENT_CATALOG_VERSION,
      };
    }
  }

  await db.ref().update(updates);
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} signalUpdates
 * @param {string} source
 * @return {Promise<Object>}
 */
async function lbAchievementMergeSignals(
    db,
    uid,
    signalUpdates,
    source,
) {
  const ref = db.ref("achievementState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbAchievementState(current);

    for (const [signal, rawValue] of Object.entries(signalUpdates)) {
      const incoming = lbAchievementNumber(rawValue);
      const previous = lbAchievementNumber(state.signals[signal]);
      state.signals[signal] = Math.max(previous, incoming);
    }

    return lbAchievementEvaluate(state, source, now);
  });

  const state = lbAchievementState(tx.snapshot.val());
  await lbAchievementProject(db, uid, state);
  return state;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} dateKey
 * @param {Object} row
 * @return {Promise<Object>}
 */
async function lbAchievementRecordDaily(db, uid, dateKey, row) {
  const ref = db.ref("achievementState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbAchievementState(current);
    const successRate = lbAchievementNumber(row.successRate);
    const previousDay = lbAchievementNumber(state.dailyDates[dateKey]);

    state.dailyDates[dateKey] =
      Math.max(previousDay, successRate >= 0.999 ? 2 : 1);

    const dailyValues = Object.values(state.dailyDates);
    const perfectCount = dailyValues.filter(
        (value) => lbAchievementNumber(value) >= 2,
    ).length;

    state.signals.daily_days = dailyValues.length;
    state.signals.perfect_daily_count = perfectCount;
    state.signals.best_daily_streak = Math.max(
        lbAchievementNumber(state.signals.best_daily_streak),
        lbAchievementNumber(row.streak),
    );

    return lbAchievementEvaluate(
        state,
        "daily",
        now,
    );
  });

  const state = lbAchievementState(tx.snapshot.val());
  await lbAchievementProject(db, uid, state);
  return state;
}

/**
 * @param {Object} profile
 * @return {Object}
 */
function lbAchievementRankedSignals(profile) {
  const ranked = lbRankedProfile(profile);
  const modes = lbRankedModeStats(ranked.modeStats);

  return {
    ranked_played: ranked.wins + ranked.losses + ranked.draws,
    ranked_wins: ranked.wins,
    best_win_streak: ranked.bestWinStreak,
    peak_elo: ranked.peakElo,
    ranked_shared_xi_wins: modes.shared_xi.wins,
    ranked_grid_wins: modes.grid.wins,
    ranked_cinko_wins: modes.cinko.wins,
    ranked_five_wins: modes.five.wins,
  };
}

exports.syncRankedAchievements = onValueWritten(
    {
      ref: "/rankedState/profiles/{uid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      if (!event.data.after.exists()) return;

      const uid = event.params.uid;
      const db = admin.database();

      if (!await lbAchievementEligible(db, uid)) return;

      await lbAchievementMergeSignals(
          db,
          uid,
          lbAchievementRankedSignals(event.data.after.val()),
          "ranked",
      );
    },
);

exports.syncDailyAchievements = onValueWritten(
    {
      ref: "/dailyLeaderboard/{dateKey}/{uid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      if (!event.data.after.exists()) return;

      const uid = event.params.uid;
      const dateKey = event.params.dateKey;
      const row = event.data.after.val() || {};

      if (row.serverValidated !== true) return;

      const db = admin.database();
      if (!await lbAchievementEligible(db, uid)) return;

      await lbAchievementRecordDaily(
          db,
          uid,
          dateKey,
          row,
      );
    },
);

exports.syncWeeklyAchievements = onValueWritten(
    {
      ref: "/weeklyLeaderboard/{weekKey}/{uid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      if (!event.data.after.exists()) return;

      const uid = event.params.uid;
      const row = event.data.after.val() || {};

      if (row.serverValidated !== true) return;

      const db = admin.database();
      if (!await lbAchievementEligible(db, uid)) return;

      await lbAchievementMergeSignals(
          db,
          uid,
          {
            weekly_days: lbAchievementNumber(row.daysPlayed),
          },
          "weekly",
      );
    },
);

exports.syncFriendAchievements = onValueWritten(
    {
      ref: "/friends/{uid}/{friendUid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      const uid = event.params.uid;
      const db = admin.database();

      if (!await lbAchievementEligible(db, uid)) return;

      const friendsSnap = await db.ref("friends/" + uid).get();
      const friends = friendsSnap.exists() && friendsSnap.val() ?
        friendsSnap.val() : {};
      const count = friends && typeof friends === "object" ?
        Object.keys(friends).length : 0;

      await lbAchievementMergeSignals(
          db,
          uid,
          {
            friend_count_peak: count,
          },
          "social",
      );
    },
);

const LB_ACHIEVEMENT_BACKFILL_VERSION = 2;
const LB_ACHIEVEMENT_HISTORY_BATCH = 24;
const LB_ACHIEVEMENT_MAX_HISTORY_WEEKS = 520;
const LB_ACHIEVEMENT_MAX_HISTORY_DAYS = 3660;

/**
 * @param {Object} db
 * @param {Array<string>} paths
 * @return {Promise<Array<Object>>}
 */
async function lbAchievementReadPaths(db, paths) {
  const snapshots = [];

  for (
    let offset = 0;
    offset < paths.length;
    offset += LB_ACHIEVEMENT_HISTORY_BATCH
  ) {
    const batch = paths.slice(
        offset,
        offset + LB_ACHIEVEMENT_HISTORY_BATCH,
    );
    const rows = await Promise.all(
        batch.map((path) => db.ref(path).get()),
    );
    snapshots.push(...rows);
  }

  return snapshots;
}

/**
 * @param {Object} base
 * @param {Object} historical
 * @return {Object}
 */
function lbAchievementMergeModeStats(base, historical) {
  const merged = lbRankedModeStats(base);

  for (const mode of Object.keys(LB_RANKED_MODES)) {
    const current = lbRankedModeStat(merged[mode]);
    const old = lbRankedModeStat(historical[mode]);

    merged[mode] = {
      wins: Math.max(current.wins, old.wins),
      losses: Math.max(current.losses, old.losses),
      draws: Math.max(current.draws, old.draws),
    };
  }

  return merged;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} rawProfile
 * @return {Promise<Object>}
 */
async function lbAchievementRankedHistory(db, uid, rawProfile) {
  const profile = lbRankedProfile(rawProfile);
  const modeStats = lbRankedModeStats(null);
  const rows = [];
  const settlementsSnap = await db.ref(
      "rankedState/settlements",
  ).get();

  if (settlementsSnap.exists() && settlementsSnap.val()) {
    for (const [mode, rawMatches] of Object.entries(
        settlementsSnap.val(),
    )) {
      if (!rawMatches || typeof rawMatches !== "object") continue;

      for (const [matchId, rawSettlement] of Object.entries(
          rawMatches,
      )) {
        if (!rawSettlement ||
            typeof rawSettlement !== "object" ||
            rawSettlement.serverValidated !== true) {
          continue;
        }

        const isPlayer1 = rawSettlement.player1Uid === uid;
        const isPlayer2 = rawSettlement.player2Uid === uid;

        if (!isPlayer1 && !isPlayer2) continue;

        const result = String(
            rawSettlement[
                isPlayer1 ? "player1Result" : "player2Result"
            ] || "draw",
        );
        const eloAfter = lbAchievementNumber(
            rawSettlement[
                isPlayer1 ? "player1EloAfter" : "player2EloAfter"
            ],
        );

        rows.push({
          matchId: matchId,
          mode: mode,
          result: result,
          eloAfter: eloAfter,
          settledAt: lbAchievementNumber(rawSettlement.settledAt),
        });
      }
    }
  }

  rows.sort((a, b) => {
    const timeCompare = a.settledAt - b.settledAt;
    if (timeCompare !== 0) return timeCompare;

    const modeCompare = a.mode.localeCompare(b.mode);
    if (modeCompare !== 0) return modeCompare;

    return a.matchId.localeCompare(b.matchId);
  });

  let currentWinStreak = 0;
  let bestWinStreak = profile.bestWinStreak;
  let peakElo = profile.peakElo;

  for (const row of rows) {
    if (Object.prototype.hasOwnProperty.call(modeStats, row.mode)) {
      const stat = lbRankedModeStat(modeStats[row.mode]);
      stat.wins += row.result === "win" ? 1 : 0;
      stat.losses += row.result === "loss" ? 1 : 0;
      stat.draws += row.result === "draw" ? 1 : 0;
      modeStats[row.mode] = stat;
    }

    currentWinStreak =
      row.result === "win" ? currentWinStreak + 1 : 0;
    bestWinStreak = Math.max(
        bestWinStreak,
        currentWinStreak,
    );
    peakElo = Math.max(peakElo, row.eloAfter);
  }

  return {
    modeStats: lbAchievementMergeModeStats(
        profile.modeStats,
        modeStats,
    ),
    currentWinStreak: rows.length > 0 ?
      currentWinStreak : profile.currentWinStreak,
    bestWinStreak: bestWinStreak,
    peakElo: peakElo,
    historyMatches: rows.length,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbAchievementDailyHistory(db, uid) {
  const weeklyIndexSnap = await db.ref(
      "leaderboardState/weeklyUserIndex/" + uid,
  ).get();
  const rawIndex = weeklyIndexSnap.exists() && weeklyIndexSnap.val() ?
    weeklyIndexSnap.val() : {};
  const allWeekKeys = rawIndex && typeof rawIndex === "object" ?
    Object.keys(rawIndex).sort() : [];
  const weekKeys = allWeekKeys.slice(
      -LB_ACHIEVEMENT_MAX_HISTORY_WEEKS,
  );
  const weeklyPaths = weekKeys.map(
      (weekKey) => "weeklyLeaderboard/" + weekKey + "/" + uid,
  );
  const weeklySnapshots = await lbAchievementReadPaths(
      db,
      weeklyPaths,
  );

  let weeklyDays = 0;
  const dateKeys = new Set();

  for (let i = 0; i < weeklySnapshots.length; i += 1) {
    const snap = weeklySnapshots[i];

    if (!snap.exists() || !snap.val()) continue;

    const row = snap.val();

    if (row.serverValidated !== true) continue;

    weeklyDays = Math.max(
        weeklyDays,
        lbAchievementNumber(row.daysPlayed),
    );

    const dailyScores = row.dailyScores &&
        typeof row.dailyScores === "object" ?
      row.dailyScores : {};

    for (const dateKey of Object.keys(dailyScores)) {
      dateKeys.add(dateKey);
    }
  }

  const dates = [...dateKeys]
      .sort()
      .slice(-LB_ACHIEVEMENT_MAX_HISTORY_DAYS);
  const dailyPaths = dates.map(
      (dateKey) => "dailyLeaderboard/" + dateKey + "/" + uid,
  );
  const dailySnapshots = await lbAchievementReadPaths(
      db,
      dailyPaths,
  );

  const dailyDates = {};
  let bestDailyStreak = 0;
  let perfectDailyCount = 0;

  for (let i = 0; i < dailySnapshots.length; i += 1) {
    const snap = dailySnapshots[i];

    if (!snap.exists() || !snap.val()) continue;

    const row = snap.val();

    if (row.serverValidated !== true) continue;

    const dateKey = dates[i];
    const perfect =
      lbAchievementNumber(row.successRate) >= 0.999;

    dailyDates[dateKey] = perfect ? 2 : 1;

    if (perfect) {
      perfectDailyCount += 1;
    }

    bestDailyStreak = Math.max(
        bestDailyStreak,
        lbAchievementNumber(row.streak),
    );
  }

  return {
    dailyDates: dailyDates,
    signals: {
      daily_days: Object.keys(dailyDates).length,
      perfect_daily_count: perfectDailyCount,
      best_daily_streak: bestDailyStreak,
      weekly_days: weeklyDays,
    },
    historyWeeks: weekKeys.length,
    historyDays: Object.keys(dailyDates).length,
    weeksTruncated:
      allWeekKeys.length > LB_ACHIEVEMENT_MAX_HISTORY_WEEKS,
    daysTruncated:
      dateKeys.size > LB_ACHIEVEMENT_MAX_HISTORY_DAYS,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} rawProfile
 * @return {Promise<Object>}
 */
async function lbAchievementBackfillHistory(
    db,
    uid,
    rawProfile,
) {
  const currentStateSnap = await db.ref(
      "achievementState/" + uid,
  ).get();
  const currentState = lbAchievementState(
      currentStateSnap.exists() ?
        currentStateSnap.val() : null,
  );

  if (
    currentState.backfillVersion >=
    LB_ACHIEVEMENT_BACKFILL_VERSION
  ) {
    return {
      applied: false,
      state: currentState,
      rankedProfile: lbRankedProfile(rawProfile),
      historyMatches: 0,
      historyWeeks: 0,
      historyDays: 0,
    };
  }

  const histories = await Promise.all([
    lbAchievementRankedHistory(db, uid, rawProfile),
    lbAchievementDailyHistory(db, uid),
  ]);
  const rankedHistory = histories[0];
  const dailyHistory = histories[1];

  const profileRef = db.ref(
      "rankedState/profiles/" + uid,
  );
  const profileTx = await profileRef.transaction((current) => {
    const raw = current && typeof current === "object" ?
      {...current} : {};
    const profile = lbRankedProfile(raw);

    return {
      ...raw,
      peakElo: Math.max(
          profile.peakElo,
          rankedHistory.peakElo,
      ),
      currentWinStreak: rankedHistory.currentWinStreak,
      bestWinStreak: Math.max(
          profile.bestWinStreak,
          rankedHistory.bestWinStreak,
      ),
      modeStats: lbAchievementMergeModeStats(
          profile.modeStats,
          rankedHistory.modeStats,
      ),
    };
  });
  const rankedProfile = lbRankedProfile(
      profileTx.snapshot.val(),
  );
  const rankedSignals = lbAchievementRankedSignals(
      rankedProfile,
  );
  const now = Date.now();
  const stateRef = db.ref("achievementState/" + uid);

  const stateTx = await stateRef.transaction((current) => {
    const state = lbAchievementState(current);

    for (const [dateKey, marker] of Object.entries(
        dailyHistory.dailyDates,
    )) {
      const previous = lbAchievementNumber(
          state.dailyDates[dateKey],
      );
      state.dailyDates[dateKey] = Math.max(previous, marker);
    }

    const signals = {
      ...rankedSignals,
      ...dailyHistory.signals,
    };

    for (const [signal, rawValue] of Object.entries(signals)) {
      const incoming = lbAchievementNumber(rawValue);
      const previous = lbAchievementNumber(
          state.signals[signal],
      );
      state.signals[signal] = Math.max(previous, incoming);
    }

    state.backfillVersion = LB_ACHIEVEMENT_BACKFILL_VERSION;
    state.backfilledAt = now;

    return lbAchievementEvaluate(
        state,
        "history_backfill",
        now,
    );
  });

  const state = lbAchievementState(stateTx.snapshot.val());
  await lbAchievementProject(db, uid, state);

  logger.info("Achievement history backfill", {
    uid: uid,
    version: LB_ACHIEVEMENT_BACKFILL_VERSION,
    rankedMatches: rankedHistory.historyMatches,
    weeklyRows: dailyHistory.historyWeeks,
    dailyRows: dailyHistory.historyDays,
    weeksTruncated: dailyHistory.weeksTruncated,
    daysTruncated: dailyHistory.daysTruncated,
  });

  return {
    applied: true,
    state: state,
    rankedProfile: rankedProfile,
    historyMatches: rankedHistory.historyMatches,
    historyWeeks: dailyHistory.historyWeeks,
    historyDays: dailyHistory.historyDays,
  };
}

exports.syncMyAchievements = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 10,
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();

      const snapshots = await Promise.all([
        db.ref("rankedState/profiles/" + uid).get(),
        db.ref("friends/" + uid).get(),
      ]);

      const ranked = snapshots[0].exists() && snapshots[0].val() ?
        snapshots[0].val() : {};
      const friends = snapshots[1].exists() && snapshots[1].val() ?
        snapshots[1].val() : {};
      const friendCount = friends && typeof friends === "object" ?
        Object.keys(friends).length : 0;

      const backfill = await lbAchievementBackfillHistory(
          db,
          uid,
          ranked,
      );
      const signals = {
        ...lbAchievementRankedSignals(backfill.rankedProfile),
        friend_count_peak: friendCount,
      };

      const state = await lbAchievementMergeSignals(
          db,
          uid,
          signals,
          "manual_sync",
      );

      return {
        ok: true,
        unlockedCount: Object.keys(state.unlocks).length,
        catalogVersion: LB_ACHIEVEMENT_CATALOG_VERSION,
        backfillVersion: LB_ACHIEVEMENT_BACKFILL_VERSION,
        historyBackfilled: backfill.applied,
        historyMatches: backfill.historyMatches,
        historyWeeks: backfill.historyWeeks,
        historyDays: backfill.historyDays,
      };
    },
);

// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_END

// LINKBALL_16_6B_ECONOMY_FOUNDATION_START

const LB_ECONOMY_VERSION = 2;
const LB_ACHIEVEMENT_COIN_REWARDS = Object.freeze({
  first_whistle: 10,
  first_victory: 15,
  challenger_10: 20,
  loyal_rival_50: 40,
  centurion_100: 75,
  winner_10: 20,
  winner_50: 50,
  winner_100: 100,
  streak_3: 15,
  streak_5: 40,
  streak_10: 75,
  elo_1100: 20,
  elo_1250: 50,
  elo_1400: 100,
  elo_1600: 200,
  shared_xi_master: 50,
  grid_master: 50,
  cinko_master: 50,
  five_master: 50,
  daily_first: 10,
  daily_7: 25,
  daily_30: 75,
  daily_streak_7: 40,
  daily_perfect: 60,
  weekly_5: 35,
  first_friend: 10,
  friends_5: 30,
  friends_25: 100,
});

// LINKBALL_16_7B_COIN_STORE_FOUNDATION_START

const LB_STORE_CATALOG_VERSION = 1;
const LB_STORE_COIN_OFFERS = Object.freeze({
  avatar_speedster_bolt: Object.freeze({
    title: "Şimşek",
    subtitle: "Hız tutkunları için premium avatar.",
    badge: "AVATAR",
    priceCoins: 150,
    itemId: "speedster_bolt",
    itemType: "avatar",
    oneTime: true,
    enabled: true,
    sortOrder: 10,
  }),
  avatar_tactician_board: Object.freeze({
    title: "Taktisyen",
    subtitle: "Oyunu tahtada kazananlar için premium avatar.",
    badge: "AVATAR",
    priceCoins: 250,
    itemId: "tactician_board",
    itemType: "avatar",
    oneTime: true,
    enabled: true,
    sortOrder: 20,
  }),
  avatar_night_owl: Object.freeze({
    title: "Gece Kuşu",
    subtitle: "Gece maçlarının vazgeçilmez premium avatarı.",
    badge: "AVATAR",
    priceCoins: 400,
    itemId: "night_owl",
    itemType: "avatar",
    oneTime: true,
    enabled: true,
    sortOrder: 30,
  }),
  avatar_champion_cup: Object.freeze({
    title: "Şampiyon",
    subtitle: "Kupa koleksiyonunun premium avatarı.",
    badge: "AVATAR",
    priceCoins: 600,
    itemId: "champion_cup",
    itemType: "avatar",
    oneTime: true,
    enabled: true,
    sortOrder: 40,
  }),
});

/**
 * @param {*} value
 * @param {number} maxLength
 * @return {string}
 */
function lbStoreText(value, maxLength) {
  return String(value || "").trim().slice(0, maxLength);
}

/**
 * @param {Object} raw
 * @param {string} offerId
 * @return {Object|null}
 */
function lbStoreOffer(raw, offerId) {
  const economy = lbEconomyOffer(raw, offerId);

  if (!economy) return null;

  const data = raw && typeof raw === "object" ? raw : {};
  const title = lbStoreText(data.title, 48);
  const subtitle = lbStoreText(data.subtitle, 120);
  const badge = lbStoreText(data.badge, 24);
  const sortOrder = lbEconomyNumber(data.sortOrder);

  if (!title) return null;

  return {
    ...economy,
    title: title,
    subtitle: subtitle,
    badge: badge,
    sortOrder: sortOrder,
  };
}

/**
 * @param {Object} offer
 * @return {Object}
 */
function lbStoreOfferProjection(offer) {
  return {
    offerId: offer.offerId,
    title: offer.title,
    subtitle: offer.subtitle,
    badge: offer.badge,
    priceCoins: offer.priceCoins,
    itemId: offer.itemId,
    itemType: offer.itemType,
    oneTime: true,
    sortOrder: offer.sortOrder,
    version: LB_STORE_CATALOG_VERSION,
  };
}

/**
 * @param {Object} db
 * @return {Promise<Array<Object>>}
 */
async function lbStoreCatalog(db) {
  const snap = await db.ref("economyCatalog/offers").get();
  const privateRows = snap.exists() && snap.val() ?
    snap.val() : {};
  const offers = [];

  for (const [offerId, builtin] of Object.entries(
      LB_STORE_COIN_OFFERS,
  )) {
    const override = privateRows &&
      typeof privateRows === "object" ?
      privateRows[offerId] : null;
    const raw = override && typeof override === "object" ?
      {...builtin, ...override} : builtin;
    const offer = lbStoreOffer(raw, offerId);

    if (offer) offers.push(lbStoreOfferProjection(offer));
  }

  offers.sort((a, b) => {
    if (a.sortOrder !== b.sortOrder) {
      return a.sortOrder - b.sortOrder;
    }
    return a.offerId.localeCompare(b.offerId);
  });

  return offers;
}

// LINKBALL_16_7B_COIN_STORE_FOUNDATION_END

// LINKBALL_16_7F_PREMIUM_ENTITLEMENT_FOUNDATION_START

const LB_PREMIUM_VERSION = 1;
const LB_PREMIUM_PLANS = new Set([
  "monthly",
  "yearly",
  "lifetime",
]);

/**
 * @param {*} value
 * @return {number}
 */
function lbPremiumNumber(value) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }

  return Math.floor(parsed);
}

/**
 * @param {*} value
 * @param {number} maxLength
 * @return {string}
 */
function lbPremiumText(value, maxLength) {
  return String(value || "").trim().slice(0, maxLength);
}

/**
 * Normalizes the server-private premium record.
 *
 * A record only becomes active when a future trusted verifier writes
 * verified=true. Client code never writes premiumState.
 *
 * @param {Object|null|undefined} raw
 * @param {number=} now
 * @return {Object}
 */
function lbPremiumState(raw, now) {
  const data = raw && typeof raw === "object" ? raw : {};
  const currentTime = lbPremiumNumber(now) || Date.now();
  const rawPlan = lbPremiumText(data.plan, 24);
  const plan = LB_PREMIUM_PLANS.has(rawPlan) ? rawPlan : "none";
  const verified = data.verified === true;
  const startedAt = lbPremiumNumber(data.startedAt);
  const expiresAt = lbPremiumNumber(data.expiresAt);
  const lifetime = plan === "lifetime";
  const subscriptionActive =
    (plan === "monthly" || plan === "yearly") &&
    expiresAt > currentTime;
  const active = verified && (lifetime || subscriptionActive);

  return {
    version: LB_PREMIUM_VERSION,
    active: active,
    plan: active ? plan : "none",
    provider: active ? lbPremiumText(data.provider, 32) : "",
    productId: active ? lbPremiumText(data.productId, 120) : "",
    startedAt: active ? startedAt : 0,
    expiresAt: active && !lifetime ? expiresAt : 0,
    autoRenewing: active && !lifetime && data.autoRenewing === true,
    verified: verified,
    updatedAt: lbPremiumNumber(data.updatedAt),
  };
}

/**
 * Non-competitive premium benefits.
 *
 * These flags intentionally contain no match strength, Elo, matchmaking,
 * answer, or gameplay-stat advantage. Retention systems may consume the
 * reward/streak fields later in Phase 16.10.
 *
 * @param {boolean} active
 * @return {Object}
 */
function lbPremiumBenefits(active) {
  return {
    adFree: active,
    premiumCosmetics: active,
    dailyRewardMultiplier: active ? 2 : 1,
    streakProtection: active,
  };
}

/**
 * @param {Object} state
 * @return {Object}
 */
function lbPremiumProjection(state) {
  return {
    active: state.active,
    plan: state.plan,
    provider: state.provider,
    productId: state.productId,
    startedAt: state.startedAt,
    expiresAt: state.expiresAt,
    autoRenewing: state.autoRenewing,
    benefits: lbPremiumBenefits(state.active),
    updatedAt: state.updatedAt,
    version: LB_PREMIUM_VERSION,
  };
}

/**
 * Repairs the owner-readable premium projection.
 *
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbPremiumEnsureProjection(db, uid) {
  const snap = await db.ref("premiumState/" + uid).get();
  const state = lbPremiumState(
      snap.exists() ? snap.val() : null,
      Date.now(),
  );
  const projection = lbPremiumProjection(state);

  await db.ref("premiumEntitlements/" + uid).set(projection);
  return projection;
}

exports.getMyPremiumStatus = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const entitlement = await lbPremiumEnsureProjection(
          admin.database(),
          uid,
      );

      return {
        ok: true,
        entitlement: entitlement,
        version: LB_PREMIUM_VERSION,
      };
    },
);

// LINKBALL_16_7F_PREMIUM_ENTITLEMENT_FOUNDATION_END

// LINKBALL_16_7I_PLAY_PURCHASE_VERIFICATION_START

const LB_PLAY_PACKAGE_NAME = "com.burakozturk.linkball";
const LB_PLAY_ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const LB_PLAY_PREMIUM_PRODUCTS = new Map([
  ["linkball_premium_monthly", "monthly"],
  ["linkball_premium_yearly", "yearly"],
  ["linkball_premium_lifetime", "lifetime"],
]);
const LB_PLAY_ACTIVE_SUBSCRIPTION_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);
let lbPlayGoogleAuth = null;

/**
 * @param {*} value
 * @return {string}
 */
function lbPlayText(value) {
  return String(value || "").trim();
}

/**
 * @param {*} value
 * @return {number}
 */
function lbPlayTimestamp(value) {
  const parsed = Date.parse(lbPlayText(value));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

/**
 * @param {string} productId
 * @return {string}
 */
function lbPlayPremiumPlan(productId) {
  const plan = LB_PLAY_PREMIUM_PRODUCTS.get(productId);
  if (!plan) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unknown Google Play Premium product.",
    );
  }
  return plan;
}

/**
 * @param {string} token
 * @return {string}
 */
function lbPlayPurchaseTokenHash(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

/**
 * @return {GoogleAuth}
 */
function lbPlayAuth() {
  if (!lbPlayGoogleAuth) {
    lbPlayGoogleAuth = new GoogleAuth({
      scopes: [LB_PLAY_ANDROID_PUBLISHER_SCOPE],
    });
  }
  return lbPlayGoogleAuth;
}

/**
 * @param {string} url
 * @return {Promise<Object>}
 */
async function lbPlayAuthorizedGet(url) {
  const auth = lbPlayAuth();
  const client = await auth.getClient();
  const response = await client.request({
    url: url,
    method: "GET",
  });
  return response.data && typeof response.data === "object" ?
    response.data :
    {};
}

/**
 * @param {Object} purchase
 * @param {string} productId
 * @param {number=} now
 * @return {Object}
 */
function lbPlayNormalizeSubscription(purchase, productId, now) {
  const data = purchase && typeof purchase === "object" ? purchase : {};
  const lineItems = Array.isArray(data.lineItems) ? data.lineItems : [];
  const matchingItems = lineItems.filter((item) => {
    return item && item.productId === productId;
  });

  if (matchingItems.length === 0) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Google Play subscription product does not match.",
    );
  }

  let expiresAt = 0;
  let autoRenewing = false;

  for (const item of matchingItems) {
    expiresAt = Math.max(expiresAt, lbPlayTimestamp(item.expiryTime));
    if (
      item.autoRenewingPlan &&
      item.autoRenewingPlan.autoRenewEnabled === true
    ) {
      autoRenewing = true;
    }
  }

  const currentTime = lbPremiumNumber(now) || Date.now();
  const state = lbPlayText(data.subscriptionState);
  const entitled =
    LB_PLAY_ACTIVE_SUBSCRIPTION_STATES.has(state) &&
    expiresAt > currentTime;

  return {
    entitled: entitled,
    startedAt: lbPlayTimestamp(data.startTime),
    expiresAt: expiresAt,
    autoRenewing: autoRenewing,
    orderId: "",
    purchaseState: state,
    acknowledgementState: lbPlayText(data.acknowledgementState),
    testPurchase: Boolean(data.testPurchase),
  };
}

/**
 * @param {Object} purchase
 * @param {string} productId
 * @return {Object}
 */
function lbPlayNormalizeLifetime(purchase, productId) {
  const data = purchase && typeof purchase === "object" ? purchase : {};
  const responseProductId = lbPlayText(data.productId);

  if (responseProductId && responseProductId !== productId) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Google Play product does not match.",
    );
  }

  const purchaseState = Number(data.purchaseState);
  const entitled = purchaseState === 0;

  return {
    entitled: entitled,
    startedAt: lbPremiumNumber(data.purchaseTimeMillis),
    expiresAt: 0,
    autoRenewing: false,
    orderId: lbPlayText(data.orderId).slice(0, 160),
    purchaseState: String(purchaseState),
    acknowledgementState: String(data.acknowledgementState ?? ""),
    testPurchase: Number(data.purchaseType) === 0,
  };
}

/**
 * @param {string} productId
 * @param {string} purchaseToken
 * @return {Promise<Object>}
 */
async function lbPlayVerifyWithGoogle(productId, purchaseToken) {
  const plan = lbPlayPremiumPlan(productId);
  const packageName = encodeURIComponent(LB_PLAY_PACKAGE_NAME);
  const token = encodeURIComponent(purchaseToken);

  if (plan === "lifetime") {
    const product = encodeURIComponent(productId);
    const url =
      "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
      "applications/" + packageName + "/purchases/products/" + product +
      "/tokens/" + token;
    const purchase = await lbPlayAuthorizedGet(url);
    return {
      plan: plan,
      result: lbPlayNormalizeLifetime(purchase, productId),
    };
  }

  const url =
    "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    "applications/" + packageName +
    "/purchases/subscriptionsv2/tokens/" + token;
  const purchase = await lbPlayAuthorizedGet(url);

  return {
    plan: plan,
    result: lbPlayNormalizeSubscription(
        purchase,
        productId,
        Date.now(),
    ),
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} tokenHash
 * @param {string} productId
 * @return {Promise<void>}
 */
async function lbPlayClaimPurchaseToken(
    db,
    uid,
    tokenHash,
    productId,
) {
  const ref = db.ref("premiumPurchaseOwners/" + tokenHash);
  const result = await ref.transaction((current) => {
    if (
      current &&
      typeof current === "object" &&
      current.uid &&
      current.uid !== uid
    ) {
      return;
    }

    return {
      uid: uid,
      productId: productId,
      provider: "google_play",
      updatedAt: Date.now(),
      version: 1,
    };
  });

  const owner = result.snapshot && result.snapshot.exists() ?
    result.snapshot.val() :
    null;

  if (
    !result.committed ||
    !owner ||
    owner.uid !== uid
  ) {
    throw new httpsV2.HttpsError(
        "already-exists",
        "This Google Play purchase is linked to another Linkball account.",
    );
  }

  await db.ref(
      "premiumPurchaseClaimsByUser/" + uid + "/" + tokenHash,
  ).set(true);
}

/**
 * @param {Object} error
 * @return {never}
 */
function lbPlayThrowVerificationError(error) {
  if (error instanceof httpsV2.HttpsError) {
    throw error;
  }

  const status = Number(
      error && (error.code || (error.response && error.response.status)),
  );

  logger.error("Google Play Premium verification failed", {
    status: Number.isFinite(status) ? status : 0,
    message: String(error && error.message || error),
  });

  if (status === 401 || status === 403) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Google Play Developer API access is not configured yet.",
    );
  }

  if (status === 404 || status === 410) {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Google Play purchase could not be verified.",
    );
  }

  throw new httpsV2.HttpsError(
      "internal",
      "Premium purchase verification failed.",
  );
}

exports.verifyPremiumPurchase = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const data = request.data && typeof request.data === "object" ?
        request.data :
        {};
      const productId = lbPlayText(data.productId).slice(0, 160);
      const purchaseToken = lbPlayText(data.purchaseToken);

      lbPlayPremiumPlan(productId);

      if (
        purchaseToken.length < 16 ||
        purchaseToken.length > 4096
      ) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid Google Play purchase token.",
        );
      }

      try {
        const verified = await lbPlayVerifyWithGoogle(
            productId,
            purchaseToken,
        );

        if (!verified.result.entitled) {
          throw new httpsV2.HttpsError(
              "failed-precondition",
              "Google Play purchase is not currently entitled.",
          );
        }

        const db = admin.database();
        const tokenHash = lbPlayPurchaseTokenHash(purchaseToken);

        await lbPlayClaimPurchaseToken(
            db,
            uid,
            tokenHash,
            productId,
        );

        const now = Date.now();
        const state = {
          version: LB_PREMIUM_VERSION,
          plan: verified.plan,
          provider: "google_play",
          productId: productId,
          startedAt: verified.result.startedAt || now,
          expiresAt: verified.result.expiresAt,
          autoRenewing: verified.result.autoRenewing,
          verified: true,
          purchaseTokenHash: tokenHash,
          orderId: verified.result.orderId,
          purchaseState: verified.result.purchaseState,
          acknowledgementState:
            verified.result.acknowledgementState,
          testPurchase: verified.result.testPurchase,
          updatedAt: now,
        };
        const normalized = lbPremiumState(state, now);
        const entitlement = lbPremiumProjection(normalized);

        await db.ref().update({
          ["premiumState/" + uid]: state,
          ["premiumEntitlements/" + uid]: entitlement,
        });

        return {
          ok: true,
          entitlement: entitlement,
          productId: productId,
          provider: "google_play",
        };
      } catch (error) {
        lbPlayThrowVerificationError(error);
      }
    },
);

// LINKBALL_16_7I_PLAY_PURCHASE_VERIFICATION_END


/**
 * @param {*} value
 * @return {number}
 */
function lbEconomyNumber(value) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }

  return Math.floor(parsed);
}

/**
 * @param {Object|null|undefined} raw
 * @return {Object}
 */
function lbEconomyState(raw) {
  const data = raw && typeof raw === "object" ? raw : {};
  const balances = data.balances && typeof data.balances === "object" ?
    data.balances : {};
  const claims = data.claims && typeof data.claims === "object" ?
    {...data.claims} : {};
  const purchases = data.purchases && typeof data.purchases === "object" ?
    {...data.purchases} : {};
  const inventory = data.inventory && typeof data.inventory === "object" ?
    {...data.inventory} : {};

  return {
    version: LB_ECONOMY_VERSION,
    balances: {
      coins: lbEconomyNumber(balances.coins),
    },
    lifetimeEarned: lbEconomyNumber(data.lifetimeEarned),
    lifetimeSpent: lbEconomyNumber(data.lifetimeSpent),
    claims: claims,
    purchases: purchases,
    inventory: inventory,
    createdAt: lbEconomyNumber(data.createdAt),
    updatedAt: lbEconomyNumber(data.updatedAt),
  };
}

/**
 * @param {Object} state
 * @return {Object}
 */
function lbEconomyWalletProjection(state) {
  return {
    coins: state.balances.coins,
    lifetimeEarned: state.lifetimeEarned,
    lifetimeSpent: state.lifetimeSpent,
    updatedAt: state.updatedAt,
    version: LB_ECONOMY_VERSION,
  };
}

/**
 * @param {Object} claim
 * @return {Object}
 */
function lbEconomyLedgerProjection(claim) {
  return {
    txId: claim.txId,
    type: "grant",
    currency: "coin",
    amount: claim.amount,
    balanceAfter: claim.balanceAfter,
    sourceType: claim.sourceType,
    sourceId: claim.sourceId,
    createdAt: claim.claimedAt,
    version: LB_ECONOMY_VERSION,
  };
}

/**
 * @param {Object} purchase
 * @return {Object}
 */
function lbEconomySpendLedgerProjection(purchase) {
  return {
    txId: purchase.txId,
    type: "spend",
    currency: "coin",
    amount: -purchase.priceCoins,
    balanceAfter: purchase.balanceAfter,
    sourceType: "offer",
    sourceId: purchase.offerId,
    itemId: purchase.itemId,
    createdAt: purchase.purchasedAt,
    version: LB_ECONOMY_VERSION,
  };
}

/**
 * @param {Object} claim
 * @return {Object}
 */
function lbEconomyClaimProjection(claim) {
  return {
    txId: claim.txId,
    sourceType: claim.sourceType,
    sourceId: claim.sourceId,
    amount: claim.amount,
    claimedAt: claim.claimedAt,
    version: LB_ECONOMY_VERSION,
  };
}

/**
 * @param {Object} item
 * @return {Object}
 */
function lbEconomyInventoryProjection(item) {
  return {
    itemId: item.itemId,
    itemType: item.itemType,
    sourceType: item.sourceType,
    sourceId: item.sourceId,
    acquiredAt: item.acquiredAt,
    version: LB_ECONOMY_VERSION,
  };
}

/**
 * Repairs owner-readable projections from private canonical state.
 *
 * @param {Object} db
 * @param {string} uid
 * @param {Object} state
 * @return {Promise<void>}
 */
async function lbEconomyProject(db, uid, state) {
  const updates = {
    ["walletBalances/" + uid]: lbEconomyWalletProjection(state),
  };

  for (const [claimId, claim] of Object.entries(state.claims)) {
    if (!claim || typeof claim !== "object" || !claim.txId) {
      continue;
    }

    updates[
        "rewardClaims/" + uid + "/" + claimId
    ] = lbEconomyClaimProjection(claim);
    updates[
        "economyLedger/" + uid + "/" + claim.txId
    ] = lbEconomyLedgerProjection(claim);
  }

  for (const purchase of Object.values(state.purchases)) {
    if (!purchase || typeof purchase !== "object" || !purchase.txId) {
      continue;
    }

    updates[
        "economyLedger/" + uid + "/" + purchase.txId
    ] = lbEconomySpendLedgerProjection(purchase);
  }

  for (const [itemId, item] of Object.entries(state.inventory)) {
    if (!item || typeof item !== "object") {
      continue;
    }

    updates[
        "inventory/" + uid + "/" + itemId
    ] = lbEconomyInventoryProjection(item);

    if (item.itemType === "avatar" &&
        LB_SOCIAL_AVATAR_IDS.has(itemId)) {
      updates[
          "users/" + uid + "/ownedAvatars/" + itemId
      ] = true;
    }
  }

  await db.ref().update(updates);
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbEconomyEnsure(db, uid) {
  const ref = db.ref("economyState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbEconomyState(current);

    if (state.createdAt <= 0) {
      state.createdAt = now;
    }

    if (state.updatedAt <= 0) {
      state.updatedAt = now;
    }

    return state;
  });

  const state = lbEconomyState(tx.snapshot.val());
  await lbEconomyProject(db, uid, state);
  return state;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} achievementId
 * @param {number} amount
 * @return {Promise<Object>}
 */
async function lbEconomyClaimAchievement(
    db,
    uid,
    achievementId,
    amount,
) {
  const claimId = "achievement__" + achievementId;
  const ref = db.ref("economyState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbEconomyState(current);

    if (state.claims[claimId]) {
      return;
    }

    const balanceAfter = state.balances.coins + amount;

    state.balances.coins = balanceAfter;
    state.lifetimeEarned += amount;
    state.claims[claimId] = {
      txId: claimId,
      sourceType: "achievement",
      sourceId: achievementId,
      amount: amount,
      balanceAfter: balanceAfter,
      claimedAt: now,
    };
    state.createdAt = state.createdAt > 0 ? state.createdAt : now;
    state.updatedAt = now;

    return state;
  });

  const state = lbEconomyState(tx.snapshot.val());
  const claim = state.claims[claimId];

  if (!claim || typeof claim !== "object") {
    throw new httpsV2.HttpsError(
        "internal",
        "Achievement reward claim could not be resolved.",
    );
  }

  await lbEconomyProject(db, uid, state);

  return {
    granted: tx.committed === true,
    state: state,
    claim: claim,
  };
}

// LINKBALL_16_6C_ECONOMY_TRANSACTIONS_START

/**
 * @param {*} raw
 * @param {string} offerId
 * @return {Object|null}
 */
function lbEconomyOffer(raw, offerId) {
  const data = raw && typeof raw === "object" ? raw : {};
  const priceCoins = lbEconomyNumber(data.priceCoins);
  const itemId = String(data.itemId || "").trim();
  const itemType = String(data.itemType || "").trim();

  if (data.enabled !== true ||
      data.oneTime !== true ||
      priceCoins <= 0 ||
      !/^[a-z0-9_:-]{2,80}$/.test(itemId) ||
      !["avatar", "cosmetic"].includes(itemType)) {
    return null;
  }

  return {
    offerId: offerId,
    priceCoins: priceCoins,
    itemId: itemId,
    itemType: itemType,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} offer
 * @return {Promise<Object>}
 */
async function lbEconomyPurchaseOffer(db, uid, offer) {
  const ref = db.ref("economyState/" + uid);
  const now = Date.now();
  const txId = "purchase__" + offer.itemId;

  const tx = await ref.transaction((current) => {
    const state = lbEconomyState(current);

    if (state.inventory[offer.itemId]) {
      return;
    }

    if (state.balances.coins < offer.priceCoins) {
      return;
    }

    const balanceAfter = state.balances.coins - offer.priceCoins;

    state.balances.coins = balanceAfter;
    state.lifetimeSpent += offer.priceCoins;
    state.purchases[offer.itemId] = {
      txId: txId,
      offerId: offer.offerId,
      itemId: offer.itemId,
      itemType: offer.itemType,
      priceCoins: offer.priceCoins,
      balanceAfter: balanceAfter,
      purchasedAt: now,
    };
    state.inventory[offer.itemId] = {
      itemId: offer.itemId,
      itemType: offer.itemType,
      sourceType: "purchase",
      sourceId: offer.offerId,
      acquiredAt: now,
    };
    state.createdAt = state.createdAt > 0 ? state.createdAt : now;
    state.updatedAt = now;

    return state;
  });

  const state = lbEconomyState(tx.snapshot.val());
  const item = state.inventory[offer.itemId];
  const purchase = state.purchases[offer.itemId];

  if (tx.committed !== true) {
    await lbEconomyProject(db, uid, state);

    if (item && typeof item === "object") {
      return {
        purchased: false,
        alreadyOwned: true,
        state: state,
        item: item,
      };
    }

    if (state.balances.coins < offer.priceCoins) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "Insufficient coin balance.",
      );
    }

    throw new httpsV2.HttpsError(
        "aborted",
        "Purchase could not be committed.",
    );
  }

  if (!purchase || typeof purchase !== "object" ||
      !item || typeof item !== "object") {
    throw new httpsV2.HttpsError(
        "internal",
        "Purchase result could not be resolved.",
    );
  }

  await lbEconomyProject(db, uid, state);

  return {
    purchased: true,
    alreadyOwned: false,
    state: state,
    item: item,
  };
}

// LINKBALL_16_6C_ECONOMY_TRANSACTIONS_END

exports.syncMyWallet = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const state = await lbEconomyEnsure(db, uid);

      return {
        ok: true,
        wallet: lbEconomyWalletProjection(state),
        version: LB_ECONOMY_VERSION,
      };
    },
);

exports.claimAchievementReward = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const achievementId = String(
          (request.data || {}).achievementId || "",
      ).trim();
      const amount = LB_ACHIEVEMENT_COIN_REWARDS[achievementId];

      if (!achievementId ||
          !Object.prototype.hasOwnProperty.call(
              LB_ACHIEVEMENT_COIN_REWARDS,
              achievementId,
          ) ||
          !Number.isInteger(amount) ||
          amount <= 0) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Unknown achievement reward.",
        );
      }

      const achievementSnap = await admin.database().ref(
          "userAchievements/" + uid + "/" + achievementId,
      ).get();

      if (!achievementSnap.exists() || !achievementSnap.val()) {
        throw new httpsV2.HttpsError(
            "failed-precondition",
            "Achievement is not unlocked.",
        );
      }

      const result = await lbEconomyClaimAchievement(
          admin.database(),
          uid,
          achievementId,
          amount,
      );

      return {
        ok: true,
        granted: result.granted,
        alreadyClaimed: !result.granted,
        amount: amount,
        coins: result.state.balances.coins,
        claim: lbEconomyClaimProjection(result.claim),
        version: LB_ECONOMY_VERSION,
      };
    },
);

exports.getStoreCatalog = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const state = await lbEconomyEnsure(db, uid);
      const offers = await lbStoreCatalog(db);

      return {
        ok: true,
        catalogVersion: LB_STORE_CATALOG_VERSION,
        wallet: lbEconomyWalletProjection(state),
        offers: offers,
      };
    },
);

exports.purchaseEconomyOffer = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const offerId = String(
          (request.data || {}).offerId || "",
      ).trim();

      if (!/^[a-z0-9_:-]{2,80}$/.test(offerId)) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid economy offer.",
        );
      }

      const db = admin.database();
      const offerSnap = await db.ref(
          "economyCatalog/offers/" + offerId,
      ).get();
      const builtin = LB_STORE_COIN_OFFERS[offerId] || null;
      const privateOffer = offerSnap.exists() ?
        offerSnap.val() : null;
      const rawOffer = privateOffer &&
        typeof privateOffer === "object" ?
        {...builtin, ...privateOffer} : builtin;
      const storeOffer = lbStoreOffer(rawOffer, offerId);
      const offer = storeOffer ? {
        offerId: storeOffer.offerId,
        priceCoins: storeOffer.priceCoins,
        itemId: storeOffer.itemId,
        itemType: storeOffer.itemType,
      } : null;

      if (!offer) {
        throw new httpsV2.HttpsError(
            "not-found",
            "Economy offer is unavailable.",
        );
      }

      const result = await lbEconomyPurchaseOffer(
          db,
          uid,
          offer,
      );

      return {
        ok: true,
        purchased: result.purchased,
        alreadyOwned: result.alreadyOwned,
        priceCoins: offer.priceCoins,
        coins: result.state.balances.coins,
        item: lbEconomyInventoryProjection(result.item),
        version: LB_ECONOMY_VERSION,
      };
    },
);

// LINKBALL_16_6B_ECONOMY_FOUNDATION_END

// LINKBALL_16_8B_COMMUNITY_FOUNDATION_START

const LB_COMMUNITY_CATEGORIES = new Set([
  "suggestion",
  "bug_report",
  "help",
  "matchmaking_issue",
  "feedback",
]);
const LB_COMMUNITY_STATUSES = new Set([
  "open",
  "reviewing",
  "resolved",
  "closed",
]);
const LB_COMMUNITY_WINDOW_MS = 15 * 60 * 1000;
const LB_COMMUNITY_WINDOW_LIMIT = 5;
const LB_COMMUNITY_DAILY_LIMIT = 20;
const LB_COMMUNITY_LIST_LIMIT = 30;

/**
 * @param {Object} request
 * @return {string}
 */
function lbCommunityRequireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new httpsV2.HttpsError(
        "unauthenticated",
        "Authentication is required.",
    );
  }
  return request.auth.uid;
}

/**
 * @param {Object} request
 * @return {string}
 */
function lbCommunityAccountType(request) {
  const firebase =
    request.auth && request.auth.token ?
      request.auth.token.firebase : null;
  const identities =
    firebase && firebase.identities ?
      firebase.identities : null;

  if (identities && identities["google.com"] != null) {
    return "google";
  }
  return "anonymous";
}

/**
 * @param {Object} data
 * @return {string}
 */
function lbCommunityCategory(data) {
  const category = String((data || {}).category || "").trim();

  if (!LB_COMMUNITY_CATEGORIES.has(category)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unsupported community request category.",
    );
  }
  return category;
}

/**
 * @param {string} value
 * @param {boolean} allowWhitespaceControls
 * @return {boolean}
 */
function lbCommunityHasDisallowedControlChars(
    value,
    allowWhitespaceControls,
) {
  for (let i = 0; i < value.length; i += 1) {
    const code = value.charCodeAt(i);

    if (code === 0x7F) {
      return true;
    }

    if (code >= 0x20) {
      continue;
    }

    if (allowWhitespaceControls &&
        (code === 0x09 || code === 0x0A || code === 0x0D)) {
      continue;
    }

    return true;
  }

  return false;
}

/**
 * @param {Object} data
 * @param {string} field
 * @param {number} minLength
 * @param {number} maxLength
 * @return {string}
 */
function lbCommunityRequiredText(data, field, minLength, maxLength) {
  const value = String((data || {})[field] || "").trim();

  if (value.length < minLength || value.length > maxLength) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid " + field + " length.",
    );
  }

  if (lbCommunityHasDisallowedControlChars(value, true)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid control characters.",
    );
  }

  return value;
}

/**
 * @param {Object} data
 * @param {string} field
 * @param {number} maxLength
 * @return {string|null}
 */
function lbCommunityOptionalText(data, field, maxLength) {
  const value = String((data || {})[field] || "").trim();
  if (!value) return null;

  if (value.length > maxLength ||
      lbCommunityHasDisallowedControlChars(value, false)) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Invalid " + field + ".",
    );
  }

  return value;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {number} now
 * @return {Promise<void>}
 */
async function lbCommunityConsumeRateLimit(db, uid, now) {
  const ref = db.ref("communityState/rateLimits/" + uid);
  const dayKey = new Date(now).toISOString().slice(0, 10);
  let blocked = false;

  const tx = await ref.transaction((raw) => {
    const state = raw && typeof raw === "object" ? {...raw} : {};

    let windowStart = Number(state.windowStart || 0);
    let windowCount = Number(state.windowCount || 0);

    if (!Number.isFinite(windowStart) ||
        now - windowStart >= LB_COMMUNITY_WINDOW_MS ||
        now < windowStart) {
      windowStart = now;
      windowCount = 0;
    }

    let dailyCount =
      state.dayKey === dayKey ?
        Number(state.dailyCount || 0) : 0;

    if (!Number.isFinite(windowCount)) windowCount = 0;
    if (!Number.isFinite(dailyCount)) dailyCount = 0;

    if (windowCount >= LB_COMMUNITY_WINDOW_LIMIT ||
        dailyCount >= LB_COMMUNITY_DAILY_LIMIT) {
      blocked = true;
      return;
    }

    return {
      windowStart: windowStart,
      windowCount: windowCount + 1,
      dayKey: dayKey,
      dailyCount: dailyCount + 1,
      lastSubmittedAt: now,
    };
  });

  if (!tx.committed || blocked) {
    throw new httpsV2.HttpsError(
        "resource-exhausted",
        "Too many community requests. Please try again later.",
    );
  }
}

/**
 * @param {Object} record
 * @return {Object}
 */
function lbCommunityProjection(record) {
  return {
    submissionId: record.submissionId,
    category: record.category,
    subject: record.subject,
    status: record.status,
    contextTag: record.contextTag,
    modeId: record.modeId,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  };
}

exports.submitCommunityRequest = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 10,
    },
    async (request) => {
      const uid = lbCommunityRequireAuth(request);
      const data = request.data || {};
      const category = lbCommunityCategory(data);
      const subject = lbCommunityRequiredText(
          data,
          "subject",
          4,
          80,
      );
      const message = lbCommunityRequiredText(
          data,
          "message",
          10,
          2000,
      );
      const contextTag = lbCommunityOptionalText(
          data,
          "contextTag",
          64,
      );
      const modeId = lbCommunityOptionalText(
          data,
          "modeId",
          64,
      );

      const db = admin.database();
      const now = Date.now();

      await lbCommunityConsumeRateLimit(db, uid, now);

      const submissionRef = db.ref("communitySubmissions").push();
      const submissionId = submissionRef.key;

      if (!submissionId) {
        throw new httpsV2.HttpsError(
            "internal",
            "Could not create community request.",
        );
      }

      const record = {
        submissionId: submissionId,
        uid: uid,
        accountType: lbCommunityAccountType(request),
        category: category,
        subject: subject,
        message: message,
        contextTag: contextTag,
        modeId: modeId,
        status: "open",
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
      };

      const projection = lbCommunityProjection(record);
      const updates = {};

      updates[
          "communitySubmissions/" + submissionId
      ] = record;
      updates[
          "communitySubmissionIndex/" + uid + "/" + submissionId
      ] = projection;

      await db.ref().update(updates);

      return {
        ok: true,
        submission: projection,
      };
    },
);

exports.getMyCommunityRequests = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 10,
    },
    async (request) => {
      const uid = lbCommunityRequireAuth(request);
      const db = admin.database();

      const indexSnap =
        await db.ref("communitySubmissionIndex/" + uid).get();

      if (!indexSnap.exists() || !indexSnap.val()) {
        return {
          ok: true,
          submissions: [],
        };
      }

      const indexed = Object.values(indexSnap.val())
          .filter((item) => item && typeof item === "object")
          .filter((item) =>
            LB_COMMUNITY_CATEGORIES.has(String(item.category || "")) &&
            LB_COMMUNITY_STATUSES.has(String(item.status || "")),
          )
          .sort((a, b) =>
            Number(b.createdAt || 0) - Number(a.createdAt || 0),
          )
          .slice(0, LB_COMMUNITY_LIST_LIMIT);

      const submissions = [];

      for (const summary of indexed) {
        const submissionId =
          String(summary.submissionId || "").trim();
        if (!submissionId) continue;

        const recordSnap = await db.ref(
            "communitySubmissions/" + submissionId,
        ).get();

        if (!recordSnap.exists() || !recordSnap.val()) continue;

        const record = recordSnap.val();
        if (!record || typeof record !== "object") continue;
        if (record.uid !== uid) continue;

        submissions.push({
          submissionId: submissionId,
          category: record.category,
          subject: record.subject,
          message: record.message,
          contextTag: record.contextTag || null,
          modeId: record.modeId || null,
          status: record.status,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        });
      }

      return {
        ok: true,
        submissions: submissions,
      };
    },
);

// LINKBALL_16_8B_COMMUNITY_FOUNDATION_END

// LINKBALL_16_10B_PROGRESSION_FOUNDATION_START

const LB_PROGRESSION_VERSION = 1;
const LB_PROGRESSION_TIME_ZONE = "Europe/Istanbul";
const LB_PROGRESSION_DAILY_COINS = Object.freeze([
  20,
  30,
  40,
  50,
  60,
  70,
  80,
]);
const LB_PROGRESSION_DAILY_XP = 25;
const LB_PROGRESSION_LEVEL_CAP = 100;
const LB_PROGRESSION_SEASON_LEVEL_CAP = 50;

/**
 * @param {*} value
 * @return {number}
 */
function lbProgressionNumber(value) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 0;
  }

  return Math.floor(parsed);
}

/**
 * @param {*} value
 * @param {number} maxLength
 * @return {string}
 */
function lbProgressionText(value, maxLength) {
  return String(value || "").trim().slice(0, maxLength);
}

/**
 * Resolves the canonical retention day using server time only.
 *
 * @param {number=} now
 * @return {string}
 */
function lbProgressionDateKey(now) {
  const date = new Date(lbProgressionNumber(now) || Date.now());
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: LB_PROGRESSION_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = formatter.formatToParts(date);
  const values = {};

  for (const part of parts) {
    if (part.type === "literal") continue;
    values[part.type] = part.value;
  }

  return [
    values.year,
    values.month,
    values.day,
  ].join("-");
}

/**
 * @param {string} fromDay
 * @param {string} toDay
 * @return {number}
 */
function lbProgressionDayDiff(fromDay, toDay) {
  const from = Date.parse(fromDay + "T00:00:00Z");
  const to = Date.parse(toDay + "T00:00:00Z");

  if (!Number.isFinite(from) || !Number.isFinite(to)) {
    return 0;
  }

  return Math.round((to - from) / 86400000);
}

/**
 * Uses the July -> June football season boundary.
 *
 * @param {string} dayKey
 * @return {Object}
 */
function lbProgressionSeason(dayKey) {
  const parts = dayKey.split("-");
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const startYear = month >= 7 ? year : year - 1;
  const endYear = startYear + 1;

  return {
    id: startYear + "-" + endYear,
    title: startYear + "-" + endYear + " Sezonu",
    startsOn: startYear + "-07-01",
    endsOn: endYear + "-06-30",
  };
}

/**
 * @param {number} xp
 * @param {number} cap
 * @return {Object}
 */
function lbProgressionLevel(xp, cap) {
  let remaining = lbProgressionNumber(xp);
  let level = 1;

  while (level < cap) {
    const required = 100 + ((level - 1) * 25);

    if (remaining < required) {
      return {
        level: level,
        currentXp: remaining,
        nextLevelXp: required,
      };
    }

    remaining -= required;
    level += 1;
  }

  return {
    level: cap,
    currentXp: 0,
    nextLevelXp: 0,
  };
}

/**
 * @param {Object|null|undefined} raw
 * @param {number=} now
 * @return {Object}
 */
function lbProgressionState(raw, now) {
  const currentTime = lbProgressionNumber(now) || Date.now();
  const dayKey = lbProgressionDateKey(currentTime);
  const currentSeason = lbProgressionSeason(dayKey);
  const data = raw && typeof raw === "object" ? raw : {};
  const rawSeason = data.season && typeof data.season === "object" ?
    data.season : {};
  const rawDaily = data.daily && typeof data.daily === "object" ?
    data.daily : {};
  const rawLastClaim = rawDaily.lastClaim &&
      typeof rawDaily.lastClaim === "object" ?
    rawDaily.lastClaim : {};
  const sameSeason =
    lbProgressionText(rawSeason.id, 32) === currentSeason.id;

  return {
    version: LB_PROGRESSION_VERSION,
    lifetimeXp: lbProgressionNumber(data.lifetimeXp),
    season: {
      id: currentSeason.id,
      title: currentSeason.title,
      startsOn: currentSeason.startsOn,
      endsOn: currentSeason.endsOn,
      xp: sameSeason ? lbProgressionNumber(rawSeason.xp) : 0,
    },
    daily: {
      lastClaimDay: lbProgressionText(rawDaily.lastClaimDay, 10),
      currentStreak: lbProgressionNumber(rawDaily.currentStreak),
      bestStreak: lbProgressionNumber(rawDaily.bestStreak),
      lastClaim: {
        dateKey: lbProgressionText(rawLastClaim.dateKey, 10),
        dayIndex: lbProgressionNumber(rawLastClaim.dayIndex),
        baseCoins: lbProgressionNumber(rawLastClaim.baseCoins),
        multiplier: lbProgressionNumber(rawLastClaim.multiplier) || 1,
        coins: lbProgressionNumber(rawLastClaim.coins),
        xp: lbProgressionNumber(rawLastClaim.xp),
        streakProtected: rawLastClaim.streakProtected === true,
        claimedAt: lbProgressionNumber(rawLastClaim.claimedAt),
        nonce: lbProgressionText(rawLastClaim.nonce, 80),
      },
    },
    createdAt: lbProgressionNumber(data.createdAt),
    updatedAt: lbProgressionNumber(data.updatedAt),
  };
}

/**
 * @param {Object} state
 * @param {string} dayKey
 * @param {Object} benefits
 * @return {Object}
 */
function lbProgressionNextDaily(state, dayKey, benefits) {
  const lastDay = state.daily.lastClaimDay;
  const currentStreak = state.daily.currentStreak;
  const gap = lastDay ? lbProgressionDayDiff(lastDay, dayKey) : 0;
  const alreadyClaimed = lastDay === dayKey;
  const streakProtected =
    !alreadyClaimed &&
    gap === 2 &&
    benefits.streakProtection === true;
  let nextStreak = 1;

  if (alreadyClaimed) {
    nextStreak = currentStreak;
  } else if (gap === 1 || streakProtected) {
    nextStreak = Math.max(1, currentStreak + 1);
  }

  const dayIndex = ((Math.max(1, nextStreak) - 1) % 7) + 1;
  const baseCoins = LB_PROGRESSION_DAILY_COINS[dayIndex - 1];
  const multiplier = Math.max(
      1,
      lbProgressionNumber(benefits.dailyRewardMultiplier) || 1,
  );

  return {
    canClaim: !alreadyClaimed,
    nextStreak: nextStreak,
    dayIndex: dayIndex,
    baseCoins: baseCoins,
    multiplier: multiplier,
    coins: baseCoins * multiplier,
    xp: LB_PROGRESSION_DAILY_XP,
    streakProtected: streakProtected,
  };
}

/**
 * @param {Object} state
 * @param {Object} benefits
 * @param {number=} now
 * @return {Object}
 */
function lbProgressionProjection(state, benefits, now) {
  const currentTime = lbProgressionNumber(now) || Date.now();
  const dayKey = lbProgressionDateKey(currentTime);
  const next = lbProgressionNextDaily(state, dayKey, benefits);
  const lifetimeLevel = lbProgressionLevel(
      state.lifetimeXp,
      LB_PROGRESSION_LEVEL_CAP,
  );
  const seasonLevel = lbProgressionLevel(
      state.season.xp,
      LB_PROGRESSION_SEASON_LEVEL_CAP,
  );

  return {
    lifetimeXp: state.lifetimeXp,
    level: {
      level: lifetimeLevel.level,
      currentXp: lifetimeLevel.currentXp,
      nextLevelXp: lifetimeLevel.nextLevelXp,
      cap: LB_PROGRESSION_LEVEL_CAP,
    },
    season: {
      id: state.season.id,
      title: state.season.title,
      startsOn: state.season.startsOn,
      endsOn: state.season.endsOn,
      xp: state.season.xp,
      level: seasonLevel.level,
      currentXp: seasonLevel.currentXp,
      nextLevelXp: seasonLevel.nextLevelXp,
      levelCap: LB_PROGRESSION_SEASON_LEVEL_CAP,
    },
    dailyReward: {
      dateKey: dayKey,
      canClaim: next.canClaim,
      currentStreak: state.daily.currentStreak,
      bestStreak: state.daily.bestStreak,
      nextStreak: next.nextStreak,
      nextDayIndex: next.dayIndex,
      baseCoins: next.baseCoins,
      multiplier: next.multiplier,
      rewardCoins: next.coins,
      xpReward: next.xp,
      streakProtectionAvailable: benefits.streakProtection === true,
      wouldUseStreakProtection: next.streakProtected,
      lastClaimedAt: state.daily.lastClaim.claimedAt,
    },
    updatedAt: state.updatedAt,
    version: LB_PROGRESSION_VERSION,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbProgressionPremiumBenefits(db, uid) {
  const premiumSnap = await db.ref("premiumState/" + uid).get();
  const premium = lbPremiumState(
      premiumSnap.exists() ? premiumSnap.val() : null,
      Date.now(),
  );

  return lbPremiumBenefits(premium.active);
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} state
 * @param {Object} benefits
 * @param {number=} now
 * @return {Promise<Object>}
 */
async function lbProgressionProject(db, uid, state, benefits, now) {
  const projection = lbProgressionProjection(
      state,
      benefits,
      now,
  );

  await db.ref("progressionProfiles/" + uid).set(projection);
  return projection;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbProgressionEnsure(db, uid) {
  const ref = db.ref("progressionState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbProgressionState(current, now);

    if (state.createdAt <= 0) {
      state.createdAt = now;
    }

    if (state.updatedAt <= 0) {
      state.updatedAt = now;
    }

    return state;
  });

  return lbProgressionState(tx.snapshot.val(), now);
}

/**
 * Idempotently credits a server-defined progression reward through the
 * canonical Phase 16.6 wallet/ledger.
 *
 * @param {Object} db
 * @param {string} uid
 * @param {string} claimId
 * @param {string} sourceType
 * @param {string} sourceId
 * @param {number} amount
 * @return {Promise<Object>}
 */
async function lbProgressionGrantCoins(
    db,
    uid,
    claimId,
    sourceType,
    sourceId,
    amount,
) {
  if (!Number.isInteger(amount) || amount <= 0) {
    throw new httpsV2.HttpsError(
        "internal",
        "Progression reward amount is invalid.",
    );
  }

  const ref = db.ref("economyState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbEconomyState(current);

    if (state.claims[claimId]) {
      return;
    }

    const balanceAfter = state.balances.coins + amount;

    state.balances.coins = balanceAfter;
    state.lifetimeEarned += amount;
    state.claims[claimId] = {
      txId: claimId,
      sourceType: sourceType,
      sourceId: sourceId,
      amount: amount,
      balanceAfter: balanceAfter,
      claimedAt: now,
    };
    state.createdAt = state.createdAt > 0 ? state.createdAt : now;
    state.updatedAt = now;

    return state;
  });

  const state = lbEconomyState(tx.snapshot.val());
  const claim = state.claims[claimId];

  if (!claim || typeof claim !== "object") {
    throw new httpsV2.HttpsError(
        "internal",
        "Progression reward could not be resolved.",
    );
  }

  await lbEconomyProject(db, uid, state);

  return {
    granted: tx.committed === true,
    state: state,
    claim: claim,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} benefits
 * @return {Promise<Object>}
 */
async function lbProgressionClaimDaily(db, uid, benefits) {
  const ref = db.ref("progressionState/" + uid);
  const now = Date.now();
  const dayKey = lbProgressionDateKey(now);
  const nonce = crypto.randomUUID();

  const tx = await ref.transaction((current) => {
    const state = lbProgressionState(current, now);

    if (state.daily.lastClaimDay === dayKey) {
      return;
    }

    const next = lbProgressionNextDaily(
        state,
        dayKey,
        benefits,
    );

    state.lifetimeXp += next.xp;
    state.season.xp += next.xp;
    state.daily.lastClaimDay = dayKey;
    state.daily.currentStreak = next.nextStreak;
    state.daily.bestStreak = Math.max(
        state.daily.bestStreak,
        next.nextStreak,
    );
    state.daily.lastClaim = {
      dateKey: dayKey,
      dayIndex: next.dayIndex,
      baseCoins: next.baseCoins,
      multiplier: next.multiplier,
      coins: next.coins,
      xp: next.xp,
      streakProtected: next.streakProtected,
      claimedAt: now,
      nonce: nonce,
    };
    state.createdAt = state.createdAt > 0 ? state.createdAt : now;
    state.updatedAt = now;

    return state;
  });

  const state = lbProgressionState(tx.snapshot.val(), now);
  const claim = state.daily.lastClaim;

  if (claim.dateKey !== dayKey || claim.coins <= 0) {
    throw new httpsV2.HttpsError(
        "internal",
        "Daily reward claim could not be resolved.",
    );
  }

  const economy = await lbProgressionGrantCoins(
      db,
      uid,
      "daily_reward__" + dayKey,
      "daily_reward",
      dayKey,
      claim.coins,
  );
  const profile = await lbProgressionProject(
      db,
      uid,
      state,
      benefits,
      now,
  );

  return {
    granted: claim.nonce === nonce,
    alreadyClaimed: claim.nonce !== nonce,
    amount: claim.coins,
    xp: claim.xp,
    dayIndex: claim.dayIndex,
    multiplier: claim.multiplier,
    streakProtected: claim.streakProtected,
    walletCoins: economy.state.balances.coins,
    profile: profile,
  };
}

exports.getMyProgression = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const state = await lbProgressionEnsure(db, uid);
      const benefits = await lbProgressionPremiumBenefits(db, uid);
      const profile = await lbProgressionProject(
          db,
          uid,
          state,
          benefits,
          Date.now(),
      );

      return {
        ok: true,
        profile: profile,
        version: LB_PROGRESSION_VERSION,
      };
    },
);

exports.claimDailyReward = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const benefits = await lbProgressionPremiumBenefits(db, uid);
      const result = await lbProgressionClaimDaily(
          db,
          uid,
          benefits,
      );

      return {
        ok: true,
        granted: result.granted,
        alreadyClaimed: result.alreadyClaimed,
        amount: result.amount,
        xp: result.xp,
        dayIndex: result.dayIndex,
        multiplier: result.multiplier,
        streakProtected: result.streakProtected,
        walletCoins: result.walletCoins,
        profile: result.profile,
        version: LB_PROGRESSION_VERSION,
      };
    },
);

// LINKBALL_16_10B_PROGRESSION_FOUNDATION_END

// LINKBALL_16_10C_MISSION_ENGINE_START

const LB_MISSION_VERSION = 1;
const LB_MISSION_DAILY_DEFINITIONS = Object.freeze([
  Object.freeze({
    id: "daily_ranked_play_3",
    title: "Bugün 3 sıralamalı maç oyna",
    description: "Güvenilir sıralamalı maç sonuçlarından ilerler.",
    metric: "rankedPlayed",
    target: 3,
    rewardCoins: 10,
  }),
  Object.freeze({
    id: "daily_ranked_win_1",
    title: "Bugün 1 sıralamalı maç kazan",
    description: "Sunucuda doğrulanmış bir sıralamalı galibiyet kazan.",
    metric: "rankedWins",
    target: 1,
    rewardCoins: 10,
  }),
  Object.freeze({
    id: "daily_challenge_1",
    title: "Günlük Mücadeleyi tamamla",
    description: "Sunucuda doğrulanmış Günlük Mücadeleyi bitir.",
    metric: "dailyChallenge",
    target: 1,
    rewardCoins: 10,
  }),
]);

const LB_MISSION_GENERAL_CHAINS = Object.freeze([
  Object.freeze({
    id: "ranked_played",
    metric: "rankedPlayed",
    stages: Object.freeze([
      Object.freeze({
        id: "general_ranked_play_5",
        title: "5 sıralamalı maç oyna",
        target: 5,
        rewardCoins: 10,
      }),
      Object.freeze({
        id: "general_ranked_play_25",
        title: "25 sıralamalı maç oyna",
        target: 25,
        rewardCoins: 25,
      }),
      Object.freeze({
        id: "general_ranked_play_100",
        title: "100 sıralamalı maç oyna",
        target: 100,
        rewardCoins: 60,
      }),
      Object.freeze({
        id: "general_ranked_play_250",
        title: "250 sıralamalı maç oyna",
        target: 250,
        rewardCoins: 150,
      }),
    ]),
  }),
  Object.freeze({
    id: "ranked_wins",
    metric: "rankedWins",
    stages: Object.freeze([
      Object.freeze({
        id: "general_ranked_wins_3",
        title: "3 sıralamalı maç kazan",
        target: 3,
        rewardCoins: 10,
      }),
      Object.freeze({
        id: "general_ranked_wins_10",
        title: "10 sıralamalı maç kazan",
        target: 10,
        rewardCoins: 25,
      }),
      Object.freeze({
        id: "general_ranked_wins_50",
        title: "50 sıralamalı maç kazan",
        target: 50,
        rewardCoins: 75,
      }),
      Object.freeze({
        id: "general_ranked_wins_100",
        title: "100 sıralamalı maç kazan",
        target: 100,
        rewardCoins: 150,
      }),
    ]),
  }),
  Object.freeze({
    id: "daily_days",
    metric: "dailyDays",
    stages: Object.freeze([
      Object.freeze({
        id: "general_daily_days_3",
        title: "3 Günlük Mücadele tamamla",
        target: 3,
        rewardCoins: 10,
      }),
      Object.freeze({
        id: "general_daily_days_7",
        title: "7 Günlük Mücadele tamamla",
        target: 7,
        rewardCoins: 25,
      }),
      Object.freeze({
        id: "general_daily_days_30",
        title: "30 Günlük Mücadele tamamla",
        target: 30,
        rewardCoins: 75,
      }),
      Object.freeze({
        id: "general_daily_days_100",
        title: "100 Günlük Mücadele tamamla",
        target: 100,
        rewardCoins: 150,
      }),
    ]),
  }),
]);

/**
 * @param {Object|null|undefined} raw
 * @param {number=} now
 * @return {Object}
 */
function lbMissionState(raw, now) {
  const currentTime = lbProgressionNumber(now) || Date.now();
  const dayKey = lbProgressionDateKey(currentTime);
  const data = raw && typeof raw === "object" ? raw : {};
  const rawDaily = data.daily && typeof data.daily === "object" ?
    data.daily : {};
  const sameDay = String(rawDaily.dateKey || "") === dayKey;
  const rawCounters = sameDay &&
      rawDaily.counters &&
      typeof rawDaily.counters === "object" ?
    rawDaily.counters : {};
  const rawProcessed = sameDay &&
      rawDaily.processed &&
      typeof rawDaily.processed === "object" ?
    rawDaily.processed : {};
  const rawClaims = sameDay &&
      rawDaily.claims &&
      typeof rawDaily.claims === "object" ?
    rawDaily.claims : {};
  const rawGeneralClaims =
    data.generalClaims && typeof data.generalClaims === "object" ?
      data.generalClaims : {};

  return {
    version: LB_MISSION_VERSION,
    daily: {
      dateKey: dayKey,
      counters: {
        rankedPlayed: lbProgressionNumber(rawCounters.rankedPlayed),
        rankedWins: lbProgressionNumber(rawCounters.rankedWins),
        dailyChallenge: Math.min(
            1,
            lbProgressionNumber(rawCounters.dailyChallenge),
        ),
      },
      processed: {...rawProcessed},
      claims: {...rawClaims},
    },
    generalClaims: {...rawGeneralClaims},
    createdAt: lbProgressionNumber(data.createdAt),
    updatedAt: lbProgressionNumber(data.updatedAt),
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbMissionTrustedTotals(db, uid) {
  const snapshots = await Promise.all([
    db.ref("rankedState/profiles/" + uid).get(),
    db.ref("achievementState/" + uid).get(),
  ]);
  const ranked = lbRankedProfile(
      snapshots[0].exists() ? snapshots[0].val() : null,
  );
  const achievement = snapshots[1].exists() && snapshots[1].val() ?
    snapshots[1].val() : {};
  const signals = achievement.signals &&
      typeof achievement.signals === "object" ?
    achievement.signals : {};

  return {
    rankedPlayed: ranked.wins + ranked.losses + ranked.draws,
    rankedWins: ranked.wins,
    dailyDays: lbAchievementNumber(signals.daily_days),
  };
}

/**
 * @param {Object} definition
 * @param {Object} state
 * @param {Object} totals
 * @param {string} kind
 * @param {Object|null=} chain
 * @param {number=} stageIndex
 * @return {Object}
 */
function lbMissionProjectionItem(
    definition,
    state,
    totals,
    kind,
    chain,
    stageIndex,
) {
  const isDaily = kind === "daily";
  const progress = isDaily ?
    lbProgressionNumber(
        state.daily.counters[definition.metric],
    ) :
    lbProgressionNumber(totals[definition.metric]);
  const claim = isDaily ?
    state.daily.claims[definition.id] :
    state.generalClaims[definition.id];
  const claimed = claim != null;
  const target = lbProgressionNumber(definition.target);

  return {
    id: definition.id,
    kind: kind,
    title: definition.title,
    description: String(definition.description || ""),
    progress: Math.min(progress, target),
    rawProgress: progress,
    target: target,
    rewardCoins: lbProgressionNumber(definition.rewardCoins),
    claimable: !claimed && progress >= target,
    claimed: claimed,
    claimedAt: claim && typeof claim === "object" ?
      lbProgressionNumber(claim.claimedAt) : 0,
    chainId: chain ? chain.id : "",
    stage: chain ? (lbProgressionNumber(stageIndex) + 1) : 0,
    stageCount: chain ? chain.stages.length : 0,
  };
}

/**
 * @param {Object} chain
 * @param {Object} state
 * @param {Object} totals
 * @return {Object}
 */
function lbMissionGeneralProjection(chain, state, totals) {
  let selectedIndex = chain.stages.length - 1;

  for (let i = 0; i < chain.stages.length; i += 1) {
    if (!state.generalClaims[chain.stages[i].id]) {
      selectedIndex = i;
      break;
    }
  }

  return lbMissionProjectionItem(
      chain.stages[selectedIndex],
      state,
      totals,
      "general",
      chain,
      selectedIndex,
  );
}

/**
 * @param {Object} state
 * @param {Object} totals
 * @return {Object}
 */
function lbMissionProjection(state, totals) {
  const daily = LB_MISSION_DAILY_DEFINITIONS.map(
      (definition) => lbMissionProjectionItem(
          definition,
          state,
          totals,
          "daily",
      ),
  );
  const general = LB_MISSION_GENERAL_CHAINS.map(
      (chain) => lbMissionGeneralProjection(chain, state, totals),
  );

  return {
    dateKey: state.daily.dateKey,
    daily: daily,
    general: general,
    dailyCompletedCount: daily.filter(
        (mission) => mission.claimed,
    ).length,
    generalCompletedCount: Object.keys(
        state.generalClaims,
    ).length,
    updatedAt: state.updatedAt,
    version: LB_MISSION_VERSION,
  };
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbMissionEnsure(db, uid) {
  const ref = db.ref("missionState/" + uid);
  const now = Date.now();

  const tx = await ref.transaction((current) => {
    const state = lbMissionState(current, now);

    state.createdAt = state.createdAt > 0 ?
      state.createdAt : now;
    state.updatedAt = state.updatedAt > 0 ?
      state.updatedAt : now;

    return state;
  });

  return lbMissionState(tx.snapshot.val(), now);
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {Object} state
 * @return {Promise<Object>}
 */
async function lbMissionProject(db, uid, state) {
  const totals = await lbMissionTrustedTotals(db, uid);
  const projection = lbMissionProjection(state, totals);

  await db.ref("missionProfiles/" + uid).set(projection);
  return projection;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} mode
 * @param {string} matchId
 * @param {string} result
 * @param {number} settledAt
 * @return {Promise<void>}
 */
async function lbMissionRecordRanked(
    db,
    uid,
    mode,
    matchId,
    result,
    settledAt,
) {
  const now = Date.now();
  const currentDay = lbProgressionDateKey(now);
  const eventDay = lbProgressionDateKey(settledAt);

  if (eventDay !== currentDay) return;

  const ref = db.ref("missionState/" + uid);
  const eventKey = "ranked__" + mode + "__" + matchId;
  const tx = await ref.transaction((current) => {
    const state = lbMissionState(current, now);

    if (state.daily.processed[eventKey]) {
      return;
    }

    state.daily.processed[eventKey] = true;
    state.daily.counters.rankedPlayed += 1;

    if (result === "win") {
      state.daily.counters.rankedWins += 1;
    }

    state.createdAt = state.createdAt > 0 ?
      state.createdAt : now;
    state.updatedAt = now;
    return state;
  });

  if (!tx.committed) return;

  await lbMissionProject(
      db,
      uid,
      lbMissionState(tx.snapshot.val(), now),
  );
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} dateKey
 * @return {Promise<void>}
 */
async function lbMissionRecordDailyChallenge(db, uid, dateKey) {
  const now = Date.now();

  if (dateKey !== lbProgressionDateKey(now)) return;

  const ref = db.ref("missionState/" + uid);
  const eventKey = "daily_challenge__" + dateKey;
  const tx = await ref.transaction((current) => {
    const state = lbMissionState(current, now);

    if (state.daily.processed[eventKey]) {
      return;
    }

    state.daily.processed[eventKey] = true;
    state.daily.counters.dailyChallenge = 1;
    state.createdAt = state.createdAt > 0 ?
      state.createdAt : now;
    state.updatedAt = now;
    return state;
  });

  if (!tx.committed) return;

  await lbMissionProject(
      db,
      uid,
      lbMissionState(tx.snapshot.val(), now),
  );
}

/**
 * @param {string} missionId
 * @return {Object|null}
 */
function lbMissionDefinition(missionId) {
  for (const definition of LB_MISSION_DAILY_DEFINITIONS) {
    if (definition.id === missionId) {
      return {
        kind: "daily",
        definition: definition,
        chain: null,
        stageIndex: -1,
      };
    }
  }

  for (const chain of LB_MISSION_GENERAL_CHAINS) {
    for (let i = 0; i < chain.stages.length; i += 1) {
      if (chain.stages[i].id === missionId) {
        return {
          kind: "general",
          definition: chain.stages[i],
          chain: chain,
          stageIndex: i,
        };
      }
    }
  }

  return null;
}

/**
 * @param {Object} resolved
 * @param {Object} state
 * @param {Object} totals
 * @return {number}
 */
function lbMissionProgress(resolved, state, totals) {
  if (resolved.kind === "daily") {
    return lbProgressionNumber(
        state.daily.counters[resolved.definition.metric],
    );
  }

  return lbProgressionNumber(
      totals[resolved.definition.metric],
  );
}

/**
 * @param {Object} resolved
 * @param {Object} state
 * @return {void}
 */
function lbMissionRequirePreviousStages(resolved, state) {
  if (resolved.kind !== "general" ||
      !resolved.chain ||
      resolved.stageIndex <= 0) {
    return;
  }

  for (let i = 0; i < resolved.stageIndex; i += 1) {
    const previousId = resolved.chain.stages[i].id;

    if (!state.generalClaims[previousId]) {
      throw new httpsV2.HttpsError(
          "failed-precondition",
          "Complete the previous mission stage first.",
      );
    }
  }
}

/**
 * @param {Object} db
 * @param {string} uid
 * @param {string} missionId
 * @return {Promise<Object>}
 */
async function lbMissionClaim(db, uid, missionId) {
  const resolved = lbMissionDefinition(missionId);

  if (!resolved) {
    throw new httpsV2.HttpsError(
        "invalid-argument",
        "Unknown mission.",
    );
  }

  const now = Date.now();
  const totals = await lbMissionTrustedTotals(db, uid);
  const ref = db.ref("missionState/" + uid);
  const nonce = crypto.randomUUID();

  const tx = await ref.transaction((current) => {
    const state = lbMissionState(current, now);

    lbMissionRequirePreviousStages(resolved, state);

    const progress = lbMissionProgress(
        resolved,
        state,
        totals,
    );
    const target = lbProgressionNumber(
        resolved.definition.target,
    );

    if (progress < target) {
      return;
    }

    const claims = resolved.kind === "daily" ?
      state.daily.claims : state.generalClaims;

    if (claims[missionId]) {
      return;
    }

    claims[missionId] = {
      claimedAt: now,
      rewardCoins: resolved.definition.rewardCoins,
      nonce: nonce,
    };
    state.createdAt = state.createdAt > 0 ?
      state.createdAt : now;
    state.updatedAt = now;

    return state;
  });

  const state = lbMissionState(tx.snapshot.val(), now);
  const claims = resolved.kind === "daily" ?
    state.daily.claims : state.generalClaims;
  const claim = claims[missionId];

  if (!claim || typeof claim !== "object") {
    throw new httpsV2.HttpsError(
        "failed-precondition",
        "Mission is not complete yet.",
    );
  }

  const periodKey = resolved.kind === "daily" ?
    state.daily.dateKey : "general";
  const amount = lbProgressionNumber(
      resolved.definition.rewardCoins,
  );
  const economy = await lbProgressionGrantCoins(
      db,
      uid,
      "mission_reward__" + periodKey + "__" + missionId,
      "mission_reward",
      periodKey + "__" + missionId,
      amount,
  );
  const profile = await lbMissionProject(db, uid, state);

  return {
    granted: economy.granted,
    alreadyClaimed: !economy.granted,
    amount: amount,
    walletCoins: economy.state.balances.coins,
    profile: profile,
    missionId: missionId,
    periodKey: periodKey,
  };
}

exports.syncRankedMissions = onValueWritten(
    {
      ref: "/rankedState/settlements/{mode}/{matchId}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      if (event.data.before.exists() ||
          !event.data.after.exists()) {
        return;
      }

      const settlement = event.data.after.val() || {};

      if (settlement.serverValidated !== true) return;

      const db = admin.database();
      const mode = String(event.params.mode || "");
      const matchId = String(event.params.matchId || "");
      const settledAt = lbProgressionNumber(
          settlement.settledAt,
      );
      const participants = [
        {
          uid: String(settlement.player1Uid || ""),
          result: String(settlement.player1Result || ""),
        },
        {
          uid: String(settlement.player2Uid || ""),
          result: String(settlement.player2Result || ""),
        },
      ];

      for (const participant of participants) {
        if (!participant.uid) continue;
        if (!await lbAchievementEligible(
            db,
            participant.uid,
        )) {
          continue;
        }

        await lbMissionRecordRanked(
            db,
            participant.uid,
            mode,
            matchId,
            participant.result,
            settledAt,
        );
      }
    },
);

exports.syncDailyMissions = onValueWritten(
    {
      ref: "/dailyLeaderboard/{dateKey}/{uid}",
      instance: "sharedix-default-rtdb",
      region: "europe-west1",
    },
    async (event) => {
      if (!event.data.after.exists()) return;

      const row = event.data.after.val() || {};

      if (row.serverValidated !== true) return;

      const uid = String(event.params.uid || "");
      const dateKey = String(event.params.dateKey || "");
      const db = admin.database();

      if (!uid || !await lbAchievementEligible(db, uid)) {
        return;
      }

      await lbMissionRecordDailyChallenge(
          db,
          uid,
          dateKey,
      );
    },
);

exports.getMyMissions = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const db = admin.database();
      const state = await lbMissionEnsure(db, uid);
      const profile = await lbMissionProject(
          db,
          uid,
          state,
      );

      return {
        ok: true,
        profile: profile,
        version: LB_MISSION_VERSION,
      };
    },
);

exports.claimMissionReward = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 20,
    },
    async (request) => {
      lbRequireGoogleLinked(request);

      const uid = request.auth.uid;
      const missionId = String(
          (request.data || {}).missionId || "",
      ).trim();

      if (!/^[a-z0-9_]{3,80}$/.test(missionId)) {
        throw new httpsV2.HttpsError(
            "invalid-argument",
            "Invalid mission id.",
        );
      }

      const result = await lbMissionClaim(
          admin.database(),
          uid,
          missionId,
      );

      return {
        ok: true,
        ...result,
        version: LB_MISSION_VERSION,
      };
    },
);

// LINKBALL_16_10C_MISSION_ENGINE_END


// LINKBALL_08B_ACCOUNT_DELETION_START

const LB_ACCOUNT_SHARED_COLLECTIONS = [
  "matches",
  "rooms",
  "gridMatches",
  "cinkoMatches",
  "fiveMatches",
];

const LB_ACCOUNT_QUEUE_PATHS = [
  "matchmaking/queue",
  "matchmaking/gridQueue",
  "matchmaking/cinkoQueue",
  "matchmaking/fiveQueue",
  "matchmaking/lotoQueue",
];

/**
 * @param {*} value
 * @param {string} uid
 * @return {boolean}
 */
function lbAccountContainsUid(value, uid) {
  if (value === uid) return true;
  if (Array.isArray(value)) {
    return value.some((item) => lbAccountContainsUid(item, uid));
  }
  if (!value || typeof value !== "object") return false;
  if (Object.prototype.hasOwnProperty.call(value, uid)) return true;
  return Object.values(value).some(
      (item) => lbAccountContainsUid(item, uid),
  );
}

/**
 * @param {*} value
 * @param {string} uid
 * @return {*}
 */
function lbAccountScrubUid(value, uid) {
  if (Array.isArray(value)) {
    return value.map((item) => {
      if (item === uid) return "";
      return lbAccountScrubUid(item, uid);
    });
  }

  if (!value || typeof value !== "object") {
    return value === uid ? null : value;
  }

  const out = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === uid) continue;
    out[key] = lbAccountScrubUid(child, uid);
  }

  const identityPairs = [
    ["player1Uid", "player1Name"],
    ["player2Uid", "player2Name"],
    ["hostUid", "hostName"],
    ["ownerUid", "ownerName"],
    ["uid", "displayName"],
  ];

  for (const pair of identityPairs) {
    const uidField = pair[0];
    const nameField = pair[1];
    if (value[uidField] !== uid) continue;
    out[uidField] = null;
    if (Object.prototype.hasOwnProperty.call(out, nameField)) {
      out[nameField] = "Silinmiş oyuncu";
    }
  }

  return out;
}

/**
 * @param {Object} db
 * @param {string} uid
 * @return {Promise<Object>}
 */
async function lbBuildAccountDeletionUpdates(db, uid) {
  const updates = {};
  const affectedMatchIds = new Set();
  let leaderboardEntriesRemoved = 0;
  let sharedRecordsScrubbed = 0;

  const profileSnap = await db.ref("users/" + uid).get();
  if (profileSnap.exists() && profileSnap.val()) {
    const profile = profileSnap.val();
    let normalizedName = "";

    if (typeof profile.normalizedName === "string") {
      normalizedName = profile.normalizedName.trim();
    }

    if (/^[a-z0-9_]{3,16}$/.test(normalizedName)) {
      const nicknameSnap =
        await db.ref("usernames/" + normalizedName).get();

      if (nicknameSnap.exists() && nicknameSnap.val() === uid) {
        updates["usernames/" + normalizedName] = null;
      }
    }
  }

  updates["users/" + uid] = null;
  updates["dailyScoreSessions/" + uid] = null;
  updates["globalLeaderboard/" + uid] = null;
  updates["rankedState/profiles/" + uid] = null;

  updates["achievementState/" + uid] = null;
  updates["achievementProgress/" + uid] = null;
  updates["userAchievements/" + uid] = null;

  updates["economyState/" + uid] = null;
  updates["walletBalances/" + uid] = null;
  updates["economyLedger/" + uid] = null;
  updates["rewardClaims/" + uid] = null;
  updates["inventory/" + uid] = null;
  updates["premiumState/" + uid] = null;
  updates["premiumEntitlements/" + uid] = null;

  const premiumClaimsSnap =
    await db.ref("premiumPurchaseClaimsByUser/" + uid).get();

  if (premiumClaimsSnap.exists() && premiumClaimsSnap.val()) {
    for (const tokenHash of Object.keys(premiumClaimsSnap.val())) {
      updates["premiumPurchaseOwners/" + tokenHash] = null;
    }
  }

  updates["premiumPurchaseClaimsByUser/" + uid] = null;

  const communityIndexSnap =
    await db.ref("communitySubmissionIndex/" + uid).get();

  if (communityIndexSnap.exists() && communityIndexSnap.val()) {
    for (const submissionId of Object.keys(communityIndexSnap.val())) {
      updates["communitySubmissions/" + submissionId] = null;
    }
  }

  updates["communitySubmissionIndex/" + uid] = null;
  updates["communityState/rateLimits/" + uid] = null;

  updates["progressionState/" + uid] = null;
  updates["progressionProfiles/" + uid] = null;
  updates["missionState/" + uid] = null;
  updates["missionProfiles/" + uid] = null;

  const safetyReporterIndexSnap =
    await db.ref("safetyReportIndex/" + uid).get();

  if (safetyReporterIndexSnap.exists() &&
      safetyReporterIndexSnap.val()) {
    for (const reportId of Object.keys(
        safetyReporterIndexSnap.val(),
    )) {
      const reportSnap = await db.ref(
          "safetyReports/" + reportId,
      ).get();
      const report = reportSnap.exists() && reportSnap.val() ?
        reportSnap.val() : null;
      const targetUid = report && report.targetUid ?
        String(report.targetUid) : "";

      updates["safetyReports/" + reportId] = null;
      updates[
          "safetyReportIndex/" + uid + "/" + reportId
      ] = null;

      if (targetUid) {
        updates[
            "safetyReportsByTarget/" + targetUid + "/" + reportId
        ] = null;
      }
    }
  }

  const safetyTargetIndexSnap =
    await db.ref("safetyReportsByTarget/" + uid).get();

  if (safetyTargetIndexSnap.exists() &&
      safetyTargetIndexSnap.val()) {
    for (const reportId of Object.keys(
        safetyTargetIndexSnap.val(),
    )) {
      const reportSnap = await db.ref(
          "safetyReports/" + reportId,
      ).get();
      const report = reportSnap.exists() && reportSnap.val() ?
        reportSnap.val() : null;
      const reporterUid = report && report.reporterUid ?
        String(report.reporterUid) : "";

      updates["safetyReports/" + reportId] = null;
      updates[
          "safetyReportsByTarget/" + uid + "/" + reportId
      ] = null;

      if (reporterUid) {
        updates[
            "safetyReportIndex/" + reporterUid + "/" + reportId
        ] = null;
      }
    }
  }

  updates["safetyReportIndex/" + uid] = null;
  updates["safetyReportsByTarget/" + uid] = null;
  updates["safetyState/actionLimits/" + uid] = null;
  updates["safetyState/pairCooldowns/" + uid] = null;
  updates["safetyState/reportLimits/" + uid] = null;
  updates["safetyState/nicknameChanges/" + uid] = null;
  updates["safetyState/nicknameLocks/" + uid] = null;

  updates["publicProfiles/" + uid] = null;
  updates["friendRequestsIncoming/" + uid] = null;
  updates["friendRequestsOutgoing/" + uid] = null;
  updates["friends/" + uid] = null;
  updates["blocks/" + uid] = null;

  const socialPairIndexSnap =
    await db.ref("socialState/userPairs/" + uid).get();

  if (socialPairIndexSnap.exists() && socialPairIndexSnap.val()) {
    for (const pairKey of Object.keys(socialPairIndexSnap.val())) {
      const pairSnap =
        await db.ref("socialState/pairs/" + pairKey).get();
      const pair = pairSnap.exists() && pairSnap.val() ?
        pairSnap.val() : null;

      const otherUid = lbSocialOtherUid(pair, uid);

      updates["socialState/pairs/" + pairKey] = null;
      updates[
          "socialState/userPairs/" + uid + "/" + pairKey
      ] = null;

      if (!otherUid) continue;

      updates[
          "socialState/userPairs/" + otherUid + "/" + pairKey
      ] = null;
      updates[
          "friendRequestsIncoming/" + otherUid + "/" + uid
      ] = null;
      updates[
          "friendRequestsOutgoing/" + otherUid + "/" + uid
      ] = null;
      updates["friends/" + otherUid + "/" + uid] = null;
      updates["blocks/" + otherUid + "/" + uid] = null;
    }
  }

  updates["socialState/userPairs/" + uid] = null;

  updates["matchInvites/" + uid] = null;

  const sentInvitesSnap =
    await db.ref("socialState/userInvites/" + uid).get();

  if (sentInvitesSnap.exists() && sentInvitesSnap.val()) {
    for (const [inviteId, targetUid] of Object.entries(
        sentInvitesSnap.val(),
    )) {
      updates[
          "matchInvites/" + targetUid + "/" + inviteId
      ] = null;
    }
  }

  updates["socialState/userInvites/" + uid] = null;

  const weeklyIndexSnap =
    await db.ref("leaderboardState/weeklyUserIndex/" + uid).get();

  if (weeklyIndexSnap.exists() && weeklyIndexSnap.val()) {
    for (const weekKey of Object.keys(weeklyIndexSnap.val())) {
      updates["weeklyLeaderboard/" + weekKey + "/" + uid] = null;
      leaderboardEntriesRemoved += 1;
    }
  }

  updates["leaderboardState/weeklyUserIndex/" + uid] = null;

  const rankedSettlementsSnap =
    await db.ref("rankedState/settlements").get();

  if (rankedSettlementsSnap.exists() && rankedSettlementsSnap.val()) {
    const modes = rankedSettlementsSnap.val();

    for (const [mode, rawMatches] of Object.entries(modes)) {
      if (!rawMatches || typeof rawMatches !== "object") continue;

      for (const [matchId, rawSettlement] of Object.entries(rawMatches)) {
        if (!rawSettlement || typeof rawSettlement !== "object") continue;

        const settlement = {...rawSettlement};
        let changed = false;

        if (settlement.player1Uid === uid) {
          settlement.player1Uid = null;
          changed = true;
        }
        if (settlement.player2Uid === uid) {
          settlement.player2Uid = null;
          changed = true;
        }
        if (settlement.winnerUid === uid) {
          settlement.winnerUid = null;
          changed = true;
        }

        if (changed) {
          updates[
              "rankedState/settlements/" + mode + "/" + matchId
          ] = settlement;
        }
      }
    }
  }

  const rankedAttestationsSnap =
    await db.ref("rankedState/attestations").get();

  if (rankedAttestationsSnap.exists() && rankedAttestationsSnap.val()) {
    const modes = rankedAttestationsSnap.val();

    for (const [mode, rawMatches] of Object.entries(modes)) {
      if (!rawMatches || typeof rawMatches !== "object") continue;

      for (const [matchId, rawByUid] of Object.entries(rawMatches)) {
        if (!rawByUid || typeof rawByUid !== "object") continue;
        if (!Object.prototype.hasOwnProperty.call(rawByUid, uid)) continue;

        updates[
            "rankedState/attestations/" + mode + "/" + matchId + "/" + uid
        ] = null;
      }
    }
  }

  for (const queuePath of LB_ACCOUNT_QUEUE_PATHS) {
    const snap = await db.ref(queuePath).get();
    if (!snap.exists() || !snap.val()) continue;
    const raw = snap.val();
    if (!lbAccountContainsUid(raw, uid)) continue;

    const scrubbed = lbAccountScrubUid(raw, uid);
    updates[queuePath] = scrubbed;
  }

  const leaderboardSnap = await db.ref("dailyLeaderboard").get();
  if (leaderboardSnap.exists() && leaderboardSnap.val()) {
    const days = leaderboardSnap.val();
    for (const dateKey of Object.keys(days)) {
      const day = days[dateKey];
      if (!day || typeof day !== "object") continue;
      if (!Object.prototype.hasOwnProperty.call(day, uid)) continue;
      updates["dailyLeaderboard/" + dateKey + "/" + uid] = null;
      leaderboardEntriesRemoved += 1;
    }
  }

  for (const collection of LB_ACCOUNT_SHARED_COLLECTIONS) {
    const snap = await db.ref(collection).get();
    if (!snap.exists() || !snap.val()) continue;
    const records = snap.val();

    for (const [recordId, record] of Object.entries(records)) {
      if (!lbAccountContainsUid(record, uid)) continue;
      affectedMatchIds.add(recordId);
      updates[collection + "/" + recordId] =
        lbAccountScrubUid(record, uid);
      sharedRecordsScrubbed += 1;
    }
  }

  if (affectedMatchIds.size > 0) {
    const usersSnap = await db.ref("users").get();
    if (usersSnap.exists() && usersSnap.val()) {
      const users = usersSnap.val();

      for (const [otherUid, profile] of Object.entries(users)) {
        if (otherUid === uid) continue;
        if (!profile || typeof profile !== "object") continue;
        const history = profile.matchHistory;

        if (!history || typeof history !== "object") continue;
        for (const matchId of affectedMatchIds) {
          if (!Object.prototype.hasOwnProperty.call(history, matchId)) {
            continue;
          }
          updates[
              "users/" + otherUid + "/matchHistory/" +
              matchId + "/opponentName"
          ] = "Silinmiş oyuncu";
        }
      }
    }
  }

  return {
    updates: updates,
    leaderboardEntriesRemoved: leaderboardEntriesRemoved,
    sharedRecordsScrubbed: sharedRecordsScrubbed,
  };
}

exports.deleteMyAccount = httpsV2.onCall(
    {
      region: "europe-west1",
      maxInstances: 10,
    },
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new httpsV2.HttpsError(
            "unauthenticated",
            "Authentication is required.",
        );
      }

      const uid = request.auth.uid;
      const db = admin.database();

      try {
        const plan = await lbBuildAccountDeletionUpdates(db, uid);
        await db.ref().update(plan.updates);

        try {
          await admin.auth().deleteUser(uid);
        } catch (error) {
          if (error && error.code !== "auth/user-not-found") {
            throw error;
          }
        }

        logger.info("Linkball account deletion completed", {
          leaderboardEntriesRemoved: plan.leaderboardEntriesRemoved,
          sharedRecordsScrubbed: plan.sharedRecordsScrubbed,
        });

        return {
          ok: true,
          leaderboardEntriesRemoved: plan.leaderboardEntriesRemoved,
          sharedRecordsScrubbed: plan.sharedRecordsScrubbed,
        };
      } catch (error) {
        logger.error("Linkball account deletion failed", {
          error: String(error),
        });
        throw new httpsV2.HttpsError(
            "internal",
            "Account deletion could not be completed.",
        );
      }
    },
);

// LINKBALL_08B_ACCOUNT_DELETION_END
