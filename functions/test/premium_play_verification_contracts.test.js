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
const packageJson = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "package.json"),
    "utf8",
));

function verificationBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_7I_PLAY_PURCHASE_VERIFICATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_7I_PLAY_PURCHASE_VERIFICATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

test("Google Play verifier uses official Android Publisher endpoints", () => {
  const block = verificationBlock();

  assert.ok(block.includes("purchases/subscriptionsv2/tokens/"));
  assert.ok(block.includes("purchases/products/"));
  assert.ok(block.includes("https://www.googleapis.com/auth/androidpublisher"));
  assert.equal(block.includes("request.data.verified"), false);
});

test("only canonical Linkball Premium product ids are accepted", () => {
  const block = verificationBlock();

  for (const productId of [
    "linkball_premium_monthly",
    "linkball_premium_yearly",
    "linkball_premium_lifetime",
  ]) {
    assert.ok(block.includes(productId));
  }

  assert.ok(block.includes("LB_PLAY_PREMIUM_PRODUCTS"));
  assert.ok(block.includes("lbPlayPremiumPlan(productId)"));
});

test("subscription and lifetime state are verified server-side", () => {
  const block = verificationBlock();

  assert.ok(block.includes("SUBSCRIPTION_STATE_ACTIVE"));
  assert.ok(block.includes("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"));
  assert.ok(block.includes("SUBSCRIPTION_STATE_CANCELED"));
  assert.ok(block.includes("expiresAt > currentTime"));
  assert.ok(block.includes("const entitled = purchaseState === 0"));
});

test("purchase token replay uses a private hash claim", () => {
  const block = verificationBlock();

  assert.ok(block.includes("crypto.createHash(\"sha256\")"));
  assert.ok(block.includes("premiumPurchaseOwners/"));
  assert.ok(block.includes("premiumPurchaseClaimsByUser/"));
  assert.equal(rules.rules.premiumPurchaseOwners[".read"], false);
  assert.equal(rules.rules.premiumPurchaseOwners[".write"], false);
  assert.equal(rules.rules.premiumPurchaseClaimsByUser[".read"], false);
  assert.equal(rules.rules.premiumPurchaseClaimsByUser[".write"], false);
});

test("verified Play purchase is the only source of premium activation", () => {
  const block = verificationBlock();

  assert.ok(block.includes("exports.verifyPremiumPurchase"));
  assert.ok(block.includes("verified: true"));
  assert.ok(block.includes("premiumState/"));
  assert.ok(block.includes("premiumEntitlements/"));
  assert.ok(block.includes("lbRequireGoogleLinked(request)"));
});

test("Google auth dependency is declared", () => {
  assert.equal(
      packageJson.dependencies["google-auth-library"],
      "^11.0.2",
  );
});

test("account deletion removes Play purchase ownership claims", () => {
  assert.ok(
      source.includes(
          "premiumPurchaseClaimsByUser/\" + uid",
      ),
  );
  assert.ok(
      source.includes(
          "updates[\"premiumPurchaseOwners/\" + tokenHash] = null",
      ),
  );
});
