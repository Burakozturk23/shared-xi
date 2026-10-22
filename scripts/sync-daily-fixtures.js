/** Manual sync shares the production request budget and lease. */
const {openFirebase, safeFailure} = require("./firebase-sync-runtime");
const {runSupplementalSync} = require("../functions/daily_fixture_budget");
let stage = "firebase-setup";
async function main() {
  const runtime = openFirebase();
  try {
    stage = "fixture-sync";
    const result = await runSupplementalSync({db: runtime.db, apiKey: process.env.API_FOOTBALL_KEY?.trim(),
      mode: process.env.FIXTURE_SYNC_MODE || "baseline", date: process.env.FIXTURE_DATE || undefined});
    console.log(JSON.stringify(result));
    if (result.state !== "ok") process.exitCode = 2;
  } finally {
    await runtime.close();
  }
}
main().catch((error) => { console.error(safeFailure("Fixture sync failed", stage, error)); process.exitCode = 1; });
