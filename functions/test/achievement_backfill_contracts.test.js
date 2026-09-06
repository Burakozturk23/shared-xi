"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

function block(startNeedle, endNeedle) {
  const start = source.indexOf(startNeedle);
  const end = source.indexOf(endNeedle);

  assert.notEqual(start, -1, startNeedle);
  assert.notEqual(end, -1, endNeedle);
  assert.ok(end > start);

  return source.slice(start, end);
}

test("achievement history backfill is versioned and one-time", () => {
  const text = block(
      "const LB_ACHIEVEMENT_BACKFILL_VERSION",
      "exports.syncMyAchievements",
  );

  assert.ok(text.includes("LB_ACHIEVEMENT_BACKFILL_VERSION = 2"));
  assert.ok(text.includes("state.backfillVersion"));
  assert.ok(text.includes("history_backfill"));
});

test("daily history uses the existing per-user weekly index", () => {
  const text = block(
      "async function lbAchievementDailyHistory",
      "async function lbAchievementBackfillHistory",
  );

  assert.ok(text.includes("leaderboardState/weeklyUserIndex/"));
  assert.ok(text.includes("weeklyLeaderboard/"));
  assert.ok(text.includes("dailyLeaderboard/"));
  assert.ok(text.includes("LB_ACHIEVEMENT_MAX_HISTORY_WEEKS"));
  assert.ok(text.includes("LB_ACHIEVEMENT_MAX_HISTORY_DAYS"));
});

test("ranked history repairs mode stats streak and peak Elo", () => {
  const text = block(
      "async function lbAchievementRankedHistory",
      "async function lbAchievementDailyHistory",
  );

  assert.ok(text.includes("rankedState/settlements"));
  assert.ok(text.includes("currentWinStreak"));
  assert.ok(text.includes("bestWinStreak"));
  assert.ok(text.includes("peakElo"));
  assert.ok(text.includes("modeStats"));
});

test("manual achievement sync executes history backfill first", () => {
  const text = block(
      "exports.syncMyAchievements",
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_END",
  );

  assert.ok(text.includes("lbAchievementBackfillHistory("));
  assert.ok(text.includes("historyBackfilled"));
  assert.ok(text.includes("backfillVersion"));
});
