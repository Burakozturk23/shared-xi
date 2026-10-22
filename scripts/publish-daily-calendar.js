/** Publish validated Kaggle data. No API-Football key or mobile rebuild needed. */
const fs = require("node:fs");
const {openFirebase, safeFailure} = require("./firebase-sync-runtime");
const {publishSnapshot, validateSnapshot} = require("../functions/daily_fixture_import");
let stage = "calendar-validation";
async function main() {
  const input = process.argv[2];
  if (!input || fs.statSync(input).size > 30_000_000) throw Error("Invalid input");
  const data = JSON.parse(fs.readFileSync(input, "utf8"));
  const valid = validateSnapshot(data, Date.now());
  if (process.argv.includes("--check")) {
    console.log(JSON.stringify({state: "validated", ...valid}));
    return;
  }
  stage = "firebase-setup";
  const runtime = openFirebase();
  try {
    stage = "calendar-publish";
    console.log(JSON.stringify(await publishSnapshot({db: runtime.db, data})));
  } finally {
    await runtime.close();
  }
}
main().catch((error) => { console.error(safeFailure("Kaggle publish failed", stage, error)); process.exitCode = 1; });
