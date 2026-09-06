"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);
const rules = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "..", "database.rules.json"),
    "utf8",
));

function progressionBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_10B_PROGRESSION_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_10B_PROGRESSION_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

function deletionBlock() {
  const start = source.indexOf(
      "// LINKBALL_08B_ACCOUNT_DELETION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_08B_ACCOUNT_DELETION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);

  return source.slice(start, end);
}

test("progression callables are Google-linked and server-time based", () => {
  const block = progressionBlock();

  assert.ok(block.includes("exports.getMyProgression"));
  assert.ok(block.includes("exports.claimDailyReward"));
  assert.ok(block.includes("lbRequireGoogleLinked(request)"));
  assert.ok(block.includes("LB_PROGRESSION_TIME_ZONE = \"Europe/Istanbul\""));
  assert.equal(block.includes("(request.data || {}).dateKey"), false);
  assert.equal(block.includes("(request.data || {}).amount"), false);
});

test("daily reward schedule is canonical seven-day 20 to 80 coins", () => {
  const block = progressionBlock();

  for (const amount of [20, 30, 40, 50, 60, 70, 80]) {
    assert.ok(block.includes(`  ${amount},`), amount);
  }

  assert.ok(block.includes("((Math.max(1, nextStreak) - 1) % 7) + 1"));
  assert.ok(block.includes("LB_PROGRESSION_DAILY_XP = 25"));
});

test("premium only multiplies rewards and protects one missed day", () => {
  const block = progressionBlock();

  assert.ok(block.includes("benefits.dailyRewardMultiplier"));
  assert.ok(block.includes("benefits.streakProtection === true"));
  assert.ok(block.includes("gap === 2"));
  assert.ok(block.includes("streakProtected: streakProtected"));
  assert.equal(block.includes("eloBoost"), false);
  assert.equal(block.includes("matchPower"), false);
});

test("daily reward is idempotent across progression and economy state", () => {
  const block = progressionBlock();

  assert.ok(block.includes("crypto.randomUUID()"));
  assert.ok(block.includes("state.daily.lastClaimDay === dayKey"));
  assert.ok(block.includes("\"daily_reward__\" + dayKey"));
  assert.ok(block.includes("state.claims[claimId]"));
  assert.ok(block.includes("lbEconomyProject(db, uid, state)"));
});

test("xp has lifetime and July to June season projections", () => {
  const block = progressionBlock();

  assert.ok(block.includes("lifetimeXp"));
  assert.ok(block.includes("season.xp"));
  assert.ok(block.includes("\"-07-01\""));
  assert.ok(block.includes("\"-06-30\""));
  assert.ok(block.includes("LB_PROGRESSION_LEVEL_CAP = 100"));
  assert.ok(block.includes("LB_PROGRESSION_SEASON_LEVEL_CAP = 50"));
});

test("progression state is private and projection is owner read-only", () => {
  assert.equal(rules.rules.progressionState[".read"], false);
  assert.equal(rules.rules.progressionState[".write"], false);

  const owner = rules.rules.progressionProfiles["$uid"];

  assert.equal(owner[".write"], false);
  assert.ok(String(owner[".read"]).includes("google.com"));
  assert.ok(String(owner[".read"]).includes("auth.uid == $uid"));
});

test("account deletion clears progression state and projection", () => {
  const block = deletionBlock();

  assert.ok(block.includes("progressionState/"));
  assert.ok(block.includes("progressionProfiles/"));
});

test("progression foundation does not add mode-specific mission logic", () => {
  const block = progressionBlock();

  for (const mode of [
    "shared_xi",
    "grid",
    "cinko",
    "five",
    "7a0",
  ]) {
    assert.equal(block.includes(mode), false, mode);
  }
});
