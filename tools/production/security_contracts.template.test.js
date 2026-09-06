"use strict";

// STEP 07B.3.1
//
// Fast, emulator-free security contract tests.
// These protect the server-authoritative Daily and secret-management contract.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sourcePath = path.join(__dirname, "..", "index.js");
const source = fs.readFileSync(sourcePath, "utf8");

const authGuard = "if (!request.auth || !request.auth.uid) {";
const foundGuard =
    "lbDailyInt(data.foundCount, \"foundCount\", 0, 80)";
const targetGuard =
    "lbDailyInt(data.targetCount, \"targetCount\", 1, 80)";
const wrongGuard =
    "lbDailyInt(data.wrongCount, \"wrongCount\", 0, 10)";
const leaderboardGuard = "\"dailyLeaderboard/\" + dateStr";

function sliceBetween(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `missing start marker: ${startMarker}`);

  const end = source.indexOf(endMarker, start + startMarker.length);
  if (end === -1) {
    return source.slice(start);
  }

  return source.slice(start, end);
}

test("API-Football key stays in Firebase Secret Manager", () => {
  const secretDeclaration = /defineSecret\(["']API_FOOTBALL_KEY["']\)/;
  const secretLiteral =
      /API_FOOTBALL_KEY\s*=\s*["'][A-Za-z0-9_-]{12,}["']/;

  assert.match(source, secretDeclaration);
  assert.doesNotMatch(source, secretLiteral);
});

test("Daily callable functions require authenticated users", () => {
  const startBlock = sliceBetween(
      "exports.startDailyScoreSession",
      "exports.submitDailyScore",
  );
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(startBlock.includes(authGuard));
  assert.ok(submitBlock.includes(authGuard));
});

test("Daily score primitives remain server bounded", () => {
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(submitBlock.includes(foundGuard));
  assert.ok(submitBlock.includes(targetGuard));
  assert.ok(submitBlock.includes(wrongGuard));
  assert.ok(submitBlock.includes("const score = foundCount * 10;"));
});

test("Daily leaderboard writes stay server validated", () => {
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(submitBlock.includes(leaderboardGuard));
  assert.ok(submitBlock.includes("serverValidated: true"));
  assert.ok(submitBlock.includes("validationVersion: 1"));
});
