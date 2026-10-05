"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

function achievementBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  return source.slice(start, end);
}

test("first canonical achievement catalog has stable unique ids", () => {
  const block = achievementBlock();
  const ids = [...block.matchAll(/id: "([a-z0-9_]+)"/g)]
      .map((match) => match[1]);

  assert.equal(ids.length, 28);
  assert.equal(new Set(ids).size, ids.length);
});

test("achievement definitions have positive targets", () => {
  const block = achievementBlock();
  const targets = [...block.matchAll(/target: ([0-9]+)/g)]
      .map((match) => Number(match[1]));

  assert.equal(targets.length, 28);
  assert.ok(targets.every((value) => value > 0));
});

test("achievement engine keeps unlocks in private canonical state", () => {
  const block = achievementBlock();

  assert.ok(block.includes("state.unlocks[definition.id]"));
  assert.ok(block.includes("achievementState/"));
  assert.ok(block.includes("achievementProgress/"));
  assert.ok(block.includes("userAchievements/"));
});

test("expanded server and Flutter catalog retain all legacy IDs and agree on targets", () => {
  const additions = require("../config/achievement_expansion.json");
  const old = [...achievementBlock().matchAll(/id: "([a-z0-9_]+)",\s*signal: "([a-z0-9_]+)",\s*target: (\d+)/g)]
      .map((m) => ({id: m[1], signal: m[2], target: Number(m[3])}));
  const all = [...old, ...additions];
  assert.equal(all.length, 54);
  assert.equal(new Set(all.map((r) => r.id)).size, 54);
  const dart = fs.readFileSync(path.join(__dirname, "../../lib/models/achievement_catalog.dart"), "utf8");
  for (const d of all) {
    const block = dart.slice(dart.indexOf("id: '" + d.id + "'"));
    const definition = block.slice(0, block.indexOf("    ),"));
    assert.ok(definition.includes("signal: '" + d.signal + "'"), d.id);
    assert.ok(definition.includes("target: " + d.target + ","), d.id);
    assert.ok(d.target > 0);
  }
});

test("new badge reward requires server unlock and is idempotent", async () => {
  const {harness} = require("./support/economy_harness");
  const h = harness();
  await assert.rejects(h.call("claimAchievementReward", {achievementId: "winner_750"}),
      {code: "failed-precondition"});
  h.seed("userAchievements/alice/winner_750", {unlockedAt: h.now});
  const a = await h.call("claimAchievementReward", {achievementId: "winner_750"});
  const b = await h.call("claimAchievementReward", {achievementId: "winner_750"});
  assert.equal(a.amount, 150);
  assert.equal(b.alreadyClaimed, true);
  assert.equal(h.read("economyState/alice/balances/coins"), 150);
});
