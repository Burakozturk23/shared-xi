"use strict";
const {createRequire} = require("node:module");
const requireFunctions = createRequire(require("node:path").resolve(__dirname, "../functions/package.json"));
// firebase-admin 14 exposes services through modular entry points.
const {initializeApp, cert, deleteApp} = requireFunctions("firebase-admin/app");
const {getDatabase} = requireFunctions("firebase-admin/database");
const HINTS = {
  MISSING_SERVICE_ACCOUNT: "FIREBASE_SERVICE_ACCOUNT repository secret is missing.",
  INVALID_SERVICE_ACCOUNT_JSON: "FIREBASE_SERVICE_ACCOUNT must contain the complete service-account JSON.",
  INVALID_SERVICE_ACCOUNT_KEY: "Check project_id, client_email and private_key in FIREBASE_SERVICE_ACCOUNT.",
  MISSING_DATABASE_URL: "FIREBASE_DATABASE_URL repository secret is missing.",
  INVALID_DATABASE_URL: "FIREBASE_DATABASE_URL must be the HTTPS Realtime Database root URL.",
};
function setupError(code) {
  const error = new Error(HINTS[code]); error.setupCode = code; return error;
}
function openFirebase(env = process.env) {
  const raw = env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (!raw) throw setupError("MISSING_SERVICE_ACCOUNT");
  let account;
  try { account = JSON.parse(raw); } catch (_) { throw setupError("INVALID_SERVICE_ACCOUNT_JSON"); }
  let credential;
  try { credential = cert(account); } catch (_) { throw setupError("INVALID_SERVICE_ACCOUNT_KEY"); }
  const databaseURL = env.FIREBASE_DATABASE_URL?.trim();
  if (!databaseURL) throw setupError("MISSING_DATABASE_URL");
  try {
    const url = new URL(databaseURL);
    if (url.protocol !== "https:" || url.username || url.password || url.search || url.hash ||
        url.port || url.pathname !== "/" ||
        !/\.(firebaseio\.com|firebasedatabase\.app)$/.test(url.hostname)) throw Error("Invalid URL");
  } catch (_) { throw setupError("INVALID_DATABASE_URL"); }
  const app = initializeApp({credential, databaseURL});
  try { return {db: getDatabase(app), close: () => deleteApp(app)}; } catch (error) {
    // Initialization is local; do not leave an app alive if service creation fails.
    void deleteApp(app); throw error;
  }
}
function safeFailure(label, stage, error) {
  if (Object.hasOwn(HINTS, error?.setupCode)) return `${label}: ${error.setupCode}. ${HINTS[error.setupCode]}`;
  const codes = new Set(["app/invalid-credential", "app/invalid-app-options", "PERMISSION_DENIED",
    "permission-denied", "database/permission-denied", "ENOTFOUND", "ETIMEDOUT", "ECONNRESET"]);
  const code = codes.has(error?.code) ? error.code : "UNEXPECTED_ERROR";
  // Never print raw exceptions: credentials/HTTP response bodies can contain secrets.
  return `${label}: stage=${stage}, code=${code}. Check Firebase service-account access, database URL and sync inputs.`;
}
module.exports = {openFirebase, safeFailure};
