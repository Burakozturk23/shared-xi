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

function communityBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_8B_COMMUNITY_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_8B_COMMUNITY_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
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

test("community callables require Firebase authentication", () => {
  const block = communityBlock();

  assert.ok(block.includes("exports.submitCommunityRequest"));
  assert.ok(block.includes("exports.getMyCommunityRequests"));
  assert.ok(block.includes("lbCommunityRequireAuth(request)"));
  assert.ok(block.includes("if (!request.auth || !request.auth.uid)"));
});

test("community categories stay separate from user moderation reports", () => {
  const block = communityBlock();

  for (const category of [
    "suggestion",
    "bug_report",
    "help",
    "matchmaking_issue",
    "feedback",
  ]) {
    assert.ok(block.includes(`"${category}"`), category);
  }

  assert.ok(!block.includes("\"user_report\""));
  assert.ok(!block.includes("\"abuse_report\""));
});

test("community text is bounded and rate limited", () => {
  const block = communityBlock();

  assert.ok(block.includes("LB_COMMUNITY_WINDOW_LIMIT = 5"));
  assert.ok(block.includes("LB_COMMUNITY_DAILY_LIMIT = 20"));
  assert.ok(block.includes("\"subject\","));
  assert.ok(block.includes("\"message\","));
  assert.ok(block.includes("2000"));
  assert.ok(block.includes("communityState/rateLimits/"));
});

test("community submissions are canonical server writes with owner index", () => {
  const block = communityBlock();

  assert.ok(block.includes("communitySubmissions/"));
  assert.ok(block.includes("communitySubmissionIndex/"));
  assert.ok(block.includes("status: \"open\""));
  assert.ok(block.includes("schemaVersion: 1"));
  assert.ok(!block.includes("email:"));
  assert.ok(!block.includes("photoURL"));
});

test("community RTDB nodes are entirely client private", () => {
  for (const node of [
    "communitySubmissions",
    "communitySubmissionIndex",
    "communityState",
  ]) {
    assert.equal(rules.rules[node][".read"], false, node);
    assert.equal(rules.rules[node][".write"], false, node);
  }
});

test("account deletion removes community submissions and rate state", () => {
  const block = deletionBlock();

  assert.ok(block.includes("communitySubmissionIndex/"));
  assert.ok(block.includes("communitySubmissions/"));
  assert.ok(block.includes("communityState/rateLimits/"));
});

test("community list only returns records owned by the caller", () => {
  const block = communityBlock();

  assert.ok(block.includes("if (record.uid !== uid) continue"));
  assert.ok(block.includes("LB_COMMUNITY_LIST_LIMIT"));
});
