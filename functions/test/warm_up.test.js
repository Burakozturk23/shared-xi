"use strict";
// Isınma: a cold function opens its module and catalog without touching any account data.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");

const WARMABLE = ["getArcade", "prepareArcade", "actArcade", "getChoice", "prepareChoice", "actChoice",
  "getBotSupport", "actBotSupport", "getGridSupport", "actGridSupport",
  "getPvp", "enterPvp", "actPvp", "searchPvp", "enterCareerTransferOnline", "actCareerTransferOnline"];

test("a warm-up call loads the game and writes nothing", async () => {
  const h = harness({runtimeConfig: {arcade: {enabled: true}}}, {omitEmptyObjects: true});
  for (const name of WARMABLE) {
    assert.equal(JSON.stringify(await h.call(name, {warm: true})), "{\"warm\":true}", name);
  }
  assert.equal(h.read("economyState/alice"), null);
  assert.equal(h.read("arcadeCatalogs"), null);
});

test("warm-up still needs a signed-in caller, and a real call is not a warm-up", async () => {
  const h = harness({runtimeConfig: {arcade: {enabled: true}}}, {omitEmptyObjects: true});
  await assert.rejects(h.call("getArcade", {warm: true}, null), {code: "unauthenticated"});
  const status = await h.call("getArcade", {mode: "burst", warm: "yes"});
  assert.notEqual(JSON.stringify(status), "{\"warm\":true}");
});
