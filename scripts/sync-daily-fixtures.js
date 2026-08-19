/**
 * Shared XI – Daily fixtures sync (GitHub Actions / lokal)
 *
 * Ortam degiskenleri:
 *   API_FOOTBALL_KEY          – API-Football key
 *   FIREBASE_SERVICE_ACCOUNT  – Service account JSON (tek satir veya dosya icerigi)
 *   FIREBASE_DATABASE_URL     – ornek: https://sharedix-default-rtdb.firebaseio.com
 *
 * Opsiyonel:
 *   FIXTURE_DATE=YYYY-MM-DD   – tek gun (yoksa bugun+yarin)
 */

const admin = require("firebase-admin");

const LEAGUE_WEIGHT = {
  2: 100,
  3: 70,
  848: 50,
  203: 55,
  39: 45,
  140: 45,
  135: 40,
  78: 40,
  61: 40,
  88: 25,
  94: 25,
  144: 20,
  179: 20,
};

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

function dateKey(d) {
  return d.toISOString().slice(0, 10);
}

function isDerbyByName(homeName, awayName) {
  return DERBY_NAME_PATTERNS.some((pair) => {
    const reA = pair[0];
    const reB = pair[1];
    return (
      (reA.test(homeName) && reB.test(awayName)) ||
      (reA.test(awayName) && reB.test(homeName))
    );
  });
}

function importance(match) {
  let score = LEAGUE_WEIGHT[match.leagueId] || 10;
  if (match.isDerby) score += 80;
  const big = new RegExp(
    "madrid|barcelona|city|united|liverpool|chelsea|arsenal|" +
      "bayern|juventus|milan|inter|psg|paris|dortmund|" +
      "galatasaray|fenerbah|be[sş]ikta[sş]|napoli|atletico|tottenham",
    "i",
  );
  if (big.test(match.homeName) && big.test(match.awayName)) score += 30;
  return score;
}

async function fetchFixturesForDate(dateStr, key) {
  const url = "https://v3.football.api-sports.io/fixtures?date=" + dateStr;
  const res = await fetch(url, {
    headers: {"x-apisports-key": key},
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error("API-Football error " + res.status + ": " + body);
  }
  const json = await res.json();
  return json.response || [];
}

function normalize(rawList) {
  const out = [];
  for (const item of rawList) {
    const league = item.league || {};
    const teams = item.teams || {};
    const fixture = item.fixture || {};
    const home = teams.home || {};
    const away = teams.away || {};
    const leagueId = league.id;
    if (!LEAGUE_WEIGHT[leagueId]) continue;

    const homeName = home.name || "?";
    const awayName = away.name || "?";
    const derby = isDerbyByName(homeName, awayName);

    const match = {
      fixtureId: fixture.id || null,
      homeApiId: home.id || null,
      awayApiId: away.id || null,
      homeName,
      awayName,
      leagueId,
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

function initFirebase() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  const dbUrl = process.env.FIREBASE_DATABASE_URL;
  if (!raw) throw new Error("FIREBASE_SERVICE_ACCOUNT eksik");
  if (!dbUrl) throw new Error("FIREBASE_DATABASE_URL eksik");

  const sa = JSON.parse(raw);
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      databaseURL: dbUrl,
    });
  }
  return admin.database();
}

async function writeDay(db, dateStr, matches) {
  const topMatch = matches.length > 0 ? matches[0] : null;
  await db.ref("daily_fixtures/" + dateStr).set({
    updatedAt: Date.now(),
    matches,
    topMatch,
  });
  const top = topMatch
    ? topMatch.homeName + " vs " + topMatch.awayName + " (" + topMatch.importance + ")"
    : "none";
  console.log("Wrote " + matches.length + " matches for " + dateStr + " | top: " + top);
}

async function main() {
  const apiKey = process.env.API_FOOTBALL_KEY;
  if (!apiKey) throw new Error("API_FOOTBALL_KEY eksik");

  const db = initFirebase();

  const dates = [];
  if (process.env.FIXTURE_DATE) {
    dates.push(process.env.FIXTURE_DATE);
  } else {
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    dates.push(dateKey(today), dateKey(tomorrow));
  }

  for (const d of dates) {
    const raw = await fetchFixturesForDate(d, apiKey);
    const matches = normalize(raw);
    await writeDay(db, d, matches);
  }

  console.log("Done.");
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
