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

test("Google Play verifier uses subscriptions v2 as source of truth", () => {
  const block = verificationBlock();

  assert.ok(block.includes("purchases/subscriptionsv2/tokens/"));
  assert.equal(block.includes("/purchases/products/"), false);
  assert.ok(block.includes("https://www.googleapis.com/auth/androidpublisher"));
  assert.equal(block.includes("request.data.verified"), false);
});

test("only canonical Linkball Pro launch product ids are accepted", () => {
  const block = verificationBlock();

  for (const productId of [
    "linkball_pro_monthly",
    "linkball_pro_yearly",
  ]) {
    assert.ok(block.includes(productId));
  }

  assert.equal(block.includes("linkball_premium_monthly"), false);
  assert.equal(block.includes("linkball_premium_yearly"), false);
  assert.equal(block.includes("linkball_premium_lifetime"), false);
  assert.ok(block.includes("LB_PLAY_PREMIUM_PRODUCTS"));
  assert.ok(block.includes("lbPlayPremiumPlan(productId)"));
});

test("subscription lifecycle state is verified server-side", () => {
  const block = verificationBlock();

  assert.ok(block.includes("SUBSCRIPTION_STATE_ACTIVE"));
  assert.ok(block.includes("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"));
  assert.ok(block.includes("SUBSCRIPTION_STATE_CANCELED"));
  assert.ok(block.includes("expiresAt > currentTime"));
  assert.ok(block.includes("SUBSCRIPTION_STATE_CANCELED"));
  assert.ok(block.includes("externalAccountIdentifiers"));
  assert.ok(block.includes("obfuscatedExternalAccountId"));
  assert.ok(block.includes("entitled: verified.result.entitled === true"));
});

test("purchase is cryptographically bound to the Linkball account", () => {
  const block = verificationBlock();

  assert.ok(block.includes("\"linkball-play:\" + uid"));
  assert.ok(block.includes("lbPlayAccountId(uid)"));
  assert.ok(block.includes("verified.result.accountId !== expectedAccountId"));
  assert.ok(block.includes("\"permission-denied\""));
});

test("subscription renewals and cancellations are reconciled from Play", () => {
  const block = verificationBlock();

  assert.ok(block.includes("exports.reconcilePremiumSubscriptions"));
  assert.ok(block.includes("schedule: \"every 30 minutes\""));
  assert.ok(block.includes("lbPremiumRefreshFromPlay"));
  assert.ok(block.includes("purchaseToken: purchaseToken"));
  assert.ok(block.includes("premiumPurchaseOwners"));
});

test("new Pro subscriptions are acknowledged on the trusted backend", () => {
  const block = verificationBlock();

  assert.ok(block.includes("lbPlayAcknowledgeSubscription"));
  assert.ok(block.includes("/purchases/subscriptions/"));
  assert.ok(block.includes(":acknowledge"));
  assert.ok(block.includes("ACKNOWLEDGEMENT_STATE_PENDING"));
  assert.ok(block.includes("ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"));
  assert.ok(block.includes("externalAccountIds"));
  assert.ok(block.includes("obfuscatedAccountId"));
  assert.ok(block.includes("lbPremiumApplyAndAcknowledge"));
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
  assert.ok(block.includes("lbPremiumWriteProjection"));
  assert.ok(source.includes("premiumEntitlements/"));
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
