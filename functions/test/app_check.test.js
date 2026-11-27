"use strict";
// Maliyet güvenliği: every callable is either App Check enforced by the platform
// or behind the switchable gate (runtimeConfig/appCheck/enforce).
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {harness} = require("./support/economy_harness");

const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
const auth = {uid: "alice", token: {firebase: {identities: {"google.com": ["alice-google"]}}}};

test("every callable is App Check enforced or behind the switchable gate", () => {
  const direct = [...source.matchAll(/httpsV2\.onCall\(([\s\S]{0,260}?)(async|\()/g)];
  // The only direct onCall without enforceAppCheck is the gate's own wrapper.
  const open = direct.filter((m) => !/enforceAppCheck:\s*true|LB_WALLET_APP_CHECK/.test(m[1]));
  assert.equal(open.length, 1);
  assert.ok(source.slice(open[0].index - 80, open[0].index).includes("function lbGuardedOnCall"));
  const guarded = (source.match(/lbGuardedOnCall\(/g) || []).length - 1; // minus the definition
  assert.equal(direct.length - 1 + guarded, 71);
  assert.equal(guarded, 34);
});

test("gate: off by default, rejects a missing token once switched on, verified tokens always pass", async () => {
  const h = harness();
  const call = (app) => h.context.exports.getEconomyContract({auth, data: {}, ...(app ? {app} : {})});
  assert.equal((await call()).ok, true);
  h.seed("runtimeConfig/appCheck", {enforce: true});
  h.setTime(h.now + 61000); // past the 60 s policy cache
  await assert.rejects(call(), {code: "failed-precondition"});
  assert.equal((await call({appId: "1:android:linkball"})).ok, true);
  h.seed("runtimeConfig/appCheck", {enforce: false});
  h.setTime(h.now + 61000);
  assert.equal((await call()).ok, true);
});
