"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {spawnSync} = require("node:child_process");
const path = require("node:path");

test("real Firebase SDK loads every handler with modular Admin APIs", () => {
  // Contract tests replace Firebase transport. This separate process loads the
  // real packages too, so removed SDK exports cannot silently pass those tests.
  const script = `
    const assert = require("node:assert/strict");
    const handlers = require("./index");
    for (const name of ["getPlayerJourney", "submitPlayerJourney", "buyPlayerJourneyHint", "setJourneyShowcase",
      "getUclMoments", "submitUclMoment"]) {
      assert.equal(typeof handlers[name], "function", name);
      assert.ok(handlers[name].__endpoint, name + " is registered");
    }
    const {getApp, deleteApp} = require("firebase-admin/app");
    const {getAuth} = require("firebase-admin/auth");
    const {getDatabase} = require("firebase-admin/database");
    assert.equal(getAuth().app.name, getApp().name);
    assert.equal(getDatabase().app.name, getApp().name);
    deleteApp(getApp()).then(() => process.exit(0)).catch(() => process.exit(1));
  `;
  const result = spawnSync(process.execPath, ["-e", script], {
    cwd: path.resolve(__dirname, ".."), encoding: "utf8", timeout: 15000,
    env: {...process.env, GCLOUD_PROJECT: "demo-linkball-sdk",
      FIREBASE_CONFIG: JSON.stringify({projectId: "demo-linkball-sdk",
        databaseURL: "https://demo-linkball-sdk.firebaseio.com"}),
      FIREBASE_DATABASE_EMULATOR_HOST: "127.0.0.1:9000", FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099"},
  });
  assert.equal(result.error, undefined, result.error?.message);
  assert.equal(result.status, 0, result.stderr || result.stdout);
});
