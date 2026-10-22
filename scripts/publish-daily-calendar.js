/** Publish validated Kaggle data. No API-Football key or mobile rebuild needed. */
const fs = require("node:fs");
const path = require("node:path");
const {createRequire} = require("node:module");
const requireFunctions = createRequire(path.resolve(__dirname, "../functions/package.json"));
const {publishSnapshot, validateSnapshot} = require("../functions/daily_fixture_import");
async function main() {
  const input = process.argv[2];
  if (!input || fs.statSync(input).size > 30_000_000) throw Error("Invalid input");
  const data = JSON.parse(fs.readFileSync(input, "utf8"));
  const valid = validateSnapshot(data, Date.now());
  if (process.argv.includes("--check")) {
    console.log(JSON.stringify({state: "validated", ...valid}));
    return;
  }
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  const databaseURL = process.env.FIREBASE_DATABASE_URL;
  if (!raw || !databaseURL) throw Error("Missing Firebase credentials");
  const admin = requireFunctions("firebase-admin");
  admin.initializeApp({credential: admin.credential.cert(JSON.parse(raw)), databaseURL});
  try {
    console.log(JSON.stringify(await publishSnapshot({db: admin.database(), data})));
  } finally {
    await admin.app().delete();
  }
}
main().catch(() => { console.error("Kaggle publish failed; check import validation and Firebase access."); process.exitCode = 1; });
