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

function premiumBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_7F_PREMIUM_ENTITLEMENT_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_7F_PREMIUM_ENTITLEMENT_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

test("premium foundation has monthly yearly and lifetime plans", () => {
  const block = premiumBlock();

  for (const plan of ["monthly", "yearly", "lifetime"]) {
    assert.ok(block.includes(`"${plan}"`));
  }
});

test("premium is active only for trusted verified state", () => {
  const block = premiumBlock();

  assert.ok(block.includes("const verified = data.verified === true"));
  assert.ok(block.includes("const active = verified"));
  assert.ok(block.includes("expiresAt > currentTime"));
  assert.equal(block.includes("request.data.verified"), false);
  assert.equal(block.includes("(request.data || {}).plan"), false);
});

test("premium benefits are non-competitive", () => {
  const block = premiumBlock();

  assert.ok(block.includes("adFree: active"));
  assert.ok(block.includes("premiumCosmetics: active"));
  assert.ok(block.includes("dailyRewardMultiplier: active ? 2 : 1"));
  assert.ok(block.includes("streakProtection: active"));

  for (const forbidden of [
    "eloBoost",
    "matchPower",
    "answerReveal",
    "matchmakingPriority",
  ]) {
    assert.equal(block.includes(forbidden), false);
  }
});

test("premium status is server-backed and owner-readable only", () => {
  const block = premiumBlock();

  assert.ok(source.includes("exports.getMyPremiumStatus"));
  assert.ok(block.includes("premiumState/"));
  assert.ok(block.includes("premiumEntitlements/"));
  assert.equal(rules.rules.premiumState[".read"], false);
  assert.equal(rules.rules.premiumState[".write"], false);

  const owner = rules.rules.premiumEntitlements["$uid"];
  assert.equal(owner[".write"], false);
  assert.ok(String(owner[".read"]).includes("google.com"));
  assert.ok(String(owner[".read"]).includes("auth.uid == $uid"));
});

test("account deletion clears premium state and projection", () => {
  assert.ok(source.includes("updates[\"premiumState/\" + uid] = null"));
  assert.ok(
      source.includes(
          "updates[\"premiumEntitlements/\" + uid] = null",
      ),
  );
});
