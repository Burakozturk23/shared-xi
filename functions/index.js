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
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

const apiKey = defineSecret("c7303714761c5b2d63e5ffccd75ffc60");

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

/** Manuel test: GET /refreshDailyFixtures?date=2026-08-20 */
exports.refreshDailyFixtures = onRequest(
    {
      secrets: [apiKey],
      memory: "256MiB",
    },
    async (req, res) => {
      try {
        const key = apiKey.value();
        const dateStr = req.query.date || dateKey(new Date());
        const raw = await fetchFixturesForDate(dateStr, key);
        const matches = normalize(raw);
        await writeDay(dateStr, matches);
        res.json({
          ok: true,
          date: dateStr,
          count: matches.length,
          topMatch: matches[0] || null,
          matches: matches.slice(0, 10),
        });
      } catch (err) {
        logger.error(err);
        res.status(500).json({
          ok: false,
          error: String(err.message || err),
        });
      }
    },
);
