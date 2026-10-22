"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {generateKeyPairSync} = require("node:crypto");
const {spawnSync} = require("node:child_process");
const path = require("node:path");
const {openFirebase, safeFailure} = require("../../scripts/firebase-sync-runtime");
// Ephemeral test key, never a real account credential. No network reads/writes.
const {privateKey} = generateKeyPairSync("rsa", {modulusLength: 2048,
  privateKeyEncoding: {type: "pkcs8", format: "pem"}, publicKeyEncoding: {type: "spki", format: "pem"}});
const env = {FIREBASE_SERVICE_ACCOUNT: JSON.stringify({project_id: "demo-fixture-sync",
  client_email: "test@demo-fixture-sync.iam.gserviceaccount.com", private_key: privateKey}),
FIREBASE_DATABASE_URL: "https://demo-fixture-sync-default-rtdb.firebaseio.com"};
test("real installed Firebase Admin modular SDK creates and deletes the sync database client", async () => {
  const runtime = openFirebase(env);
  assert.equal(typeof runtime.db.ref, "function");
  assert.equal(runtime.db.ref("daily_fixtures").key, "daily_fixtures");
  await runtime.close();
  const second = openFirebase(env); // Default app must have been deleted correctly.
  await second.close();
});
test("setup diagnostics distinguish missing/malformed secrets without echoing credentials", () => {
  for (const [input, code] of [
    [{}, "MISSING_SERVICE_ACCOUNT"],
    [{...env, FIREBASE_SERVICE_ACCOUNT: "secret-invalid-json"}, "INVALID_SERVICE_ACCOUNT_JSON"],
    [{...env, FIREBASE_SERVICE_ACCOUNT: "{}"}, "INVALID_SERVICE_ACCOUNT_KEY"],
    [{...env, FIREBASE_DATABASE_URL: ""}, "MISSING_DATABASE_URL"],
    [{...env, FIREBASE_DATABASE_URL: "https://console.firebase.google.com/project/demo"}, "INVALID_DATABASE_URL"],
  ]) {
    assert.throws(() => openFirebase(input), (error) => {
      assert.equal(error.setupCode, code);
      const log = safeFailure("Sync failed", "setup", error);
      assert.ok(log.includes(code));
      assert.ok(!log.includes("secret-invalid-json") && !log.includes(privateKey));
      return true;
    });
  }
  const log = safeFailure("Sync failed", "database", {code: "PERMISSION_DENIED", message: privateKey});
  assert.ok(log.includes("PERMISSION_DENIED") && !log.includes(privateKey));
});
test("actual manual CLI reaches unconfigured API result instead of crashing on removed Admin APIs", () => {
  const result = spawnSync(process.execPath, [path.resolve(__dirname, "../../scripts/sync-daily-fixtures.js")], {
    env: {...process.env, ...env, API_FOOTBALL_KEY: "", FIXTURE_SYNC_MODE: "refresh", FIXTURE_DATE: ""},
    encoding: "utf8", timeout: 10000,
  });
  assert.equal(result.status, 2, result.stderr);
  assert.equal(JSON.parse(result.stdout).state, "unconfigured");
  assert.ok(!result.stdout.includes(privateKey) && !result.stderr.includes(privateKey));
});
