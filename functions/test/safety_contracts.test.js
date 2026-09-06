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

function safetyBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_11B_SOCIAL_SAFETY_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_11B_SOCIAL_SAFETY_FOUNDATION_END",
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

test("player reports require Google-linked authentication", () => {
  const block = safetyBlock();

  assert.ok(block.includes("exports.reportPlayer"));
  assert.ok(block.includes("exports.getMyPlayerReports"));

  const guards = block.match(/lbRequireGoogleLinked\(request\)/g) || [];
  assert.ok(guards.length >= 2);
  assert.ok(block.includes("You cannot report yourself."));
});

test("player report categories remain separate from Community Center", () => {
  const block = safetyBlock();

  for (const category of [
    "harassment",
    "hate_speech",
    "cheating",
    "inappropriate_name",
    "spam",
    "other",
  ]) {
    assert.ok(block.includes(`"${category}"`), category);
  }

  assert.equal(block.includes("\"bug_report\""), false);
  assert.equal(block.includes("\"suggestion\""), false);
});

test("player reports are bounded and rate limited", () => {
  const block = safetyBlock();

  assert.ok(block.includes("LB_SAFETY_REPORT_WINDOW_LIMIT = 5"));
  assert.ok(block.includes("LB_SAFETY_REPORT_DAILY_LIMIT = 15"));
  assert.ok(block.includes("LB_SAFETY_REPORT_TARGET_COOLDOWN_MS"));
  assert.ok(block.includes("\"description\","));
  assert.ok(block.includes("500"));
});

test("player reports use private canonical state and owner projection", () => {
  const block = safetyBlock();

  assert.ok(block.includes("safetyReports/"));
  assert.ok(block.includes("safetyReportIndex/"));
  assert.ok(block.includes("safetyReportsByTarget/"));
  assert.ok(block.includes("status: \"open\""));
  assert.ok(block.includes("schemaVersion: 1"));
  assert.equal(block.includes("email:"), false);
  assert.equal(block.includes("photoURL"), false);
});

test("safety RTDB state is server-owned", () => {
  for (const node of [
    "safetyReports",
    "safetyReportsByTarget",
    "safetyState",
  ]) {
    assert.equal(rules.rules[node][".read"], false, node);
    assert.equal(rules.rules[node][".write"], false, node);
  }

  const owner = rules.rules.safetyReportIndex["$uid"];
  assert.equal(owner[".write"], false);
  assert.ok(String(owner[".read"]).includes("auth.uid == $uid"));
  assert.ok(String(owner[".read"]).includes("google.com"));
});

test("friend requests have server-side anti-spam limits", () => {
  const start = source.indexOf("exports.sendFriendRequest");
  const end = source.indexOf("exports.respondFriendRequest", start);
  const block = source.slice(start, end);

  assert.ok(block.includes("lbSafetyConsumeActionLimit("));
  assert.ok(block.includes("lbSafetyConsumePairCooldown("));
  assert.ok(block.includes("\"friend_request\""));
  assert.ok(block.includes("LB_SAFETY_FRIEND_REQUEST_WINDOW_LIMIT"));
});

test("friend match invites have sender and pair cooldown limits", () => {
  const start = source.indexOf("exports.sendFriendMatchInvite");
  const end = source.indexOf("exports.acceptFriendMatchInvite", start);
  const block = source.slice(start, end);

  assert.ok(block.includes("lbSafetyConsumeActionLimit("));
  assert.ok(block.includes("lbSafetyConsumePairCooldown("));
  assert.ok(block.includes("\"match_invite\""));
  assert.ok(block.includes("LB_SAFETY_INVITE_WINDOW_LIMIT"));
});

test("blocking purges pending match invites between both players", () => {
  const start = source.indexOf("exports.blockUser");
  const end = source.indexOf("exports.unblockUser", start);
  const block = source.slice(start, end);
  const safety = safetyBlock();

  assert.ok(block.includes("lbSafetyPurgePairInvites("));
  assert.ok(safety.includes("[uid, targetUid]"));
  assert.ok(safety.includes("[targetUid, uid]"));
  assert.ok(safety.includes("matchInvites/"));
  assert.ok(safety.includes("socialState/userInvites/"));
});

test("blocked users cannot directly read blocker public profile", () => {
  const readRule = String(rules.rules.publicProfiles["$uid"][".read"]);

  assert.ok(readRule.includes("root.child(\"blocks\")"));
  assert.ok(readRule.includes("child($uid)"));
  assert.ok(readRule.includes("child(auth.uid)"));
});

test("account deletion removes player safety data", () => {
  const block = deletionBlock();

  assert.ok(block.includes("safetyReportIndex/"));
  assert.ok(block.includes("safetyReportsByTarget/"));
  assert.ok(block.includes("safetyReports/"));
  assert.ok(block.includes("safetyState/actionLimits/"));
  assert.ok(block.includes("safetyState/pairCooldowns/"));
  assert.ok(block.includes("safetyState/reportLimits/"));
});
