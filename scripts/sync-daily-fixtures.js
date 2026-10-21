/** Import the bundled calendar and request ONLY Süper Lig from API-Football. */
const admin = require("firebase-admin");
const {syncDay} = require("../functions/daily_fixture_feed");
const {dayKey} = require("../functions/rewarded_ads");
async function main() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  const databaseURL = process.env.FIREBASE_DATABASE_URL;
  if (!raw || !databaseURL) throw Error("Firebase sync credentials missing");
  admin.initializeApp({credential: admin.credential.cert(JSON.parse(raw)), databaseURL});
  const now = Date.now();
  const days = process.env.FIXTURE_DATE ? [process.env.FIXTURE_DATE] : [dayKey(now), dayKey(now + 86400000)];
  let degraded = false;
  for (const date of days) {
    const result = await syncDay({db: admin.database(), date, apiKey: process.env.API_FOOTBALL_KEY, now});
    console.log(JSON.stringify({date, matches: result.matches?.length || 0, sources: result.sources}));
    degraded ||= result.sources.turkey.state !== "ok";
  }
  await admin.app().delete();
  if (degraded) process.exitCode = 2;
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
