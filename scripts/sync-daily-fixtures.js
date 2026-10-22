/** Manual sync shares the production request budget and lease. */
const {createRequire} = require("node:module");
const requireFunctions = createRequire(require("node:path").resolve(__dirname, "../functions/package.json"));
const admin = requireFunctions("firebase-admin");
const {runTurkeySync} = require("../functions/daily_fixture_budget");
async function main() {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  const databaseURL = process.env.FIREBASE_DATABASE_URL;
  if (!raw || !databaseURL) throw Error("Firebase sync credentials missing");
  admin.initializeApp({credential: admin.credential.cert(JSON.parse(raw)), databaseURL});
  try {
    const result = await runTurkeySync({db: admin.database(), apiKey: process.env.API_FOOTBALL_KEY,
      mode: process.env.FIXTURE_SYNC_MODE || "baseline", date: process.env.FIXTURE_DATE || undefined});
    console.log(JSON.stringify(result));
    if (result.state !== "ok") process.exitCode = 2;
  } finally {
    await admin.app().delete();
  }
}
main().catch(() => { console.error("Fixture sync failed; check credentials and sync configuration."); process.exitCode = 1; });
