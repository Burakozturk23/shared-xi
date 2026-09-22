"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const vm = require("node:vm");
const crypto = require("node:crypto");
const {harness} = require("./support/economy_harness");

function setup() {
  const h = harness();
  const apply = vm.runInContext("lbPremiumApplyPlayVerification", h.context);
  const accountId = vm.runInContext("lbPlayAccountId", h.context)("alice");
  const verified = (active, days = 30, plan = "monthly") => ({
    plan,
    result: {
      accountId, entitled: active, startedAt: h.now - 1000,
      expiresAt: h.now + days * 86400000, autoRenewing: active,
      purchaseState: active ? "SUBSCRIPTION_STATE_ACTIVE" : "SUBSCRIPTION_STATE_EXPIRED",
      orderId: "test-order", acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      testPurchase: true,
    },
  });
  return {h, verified, apply: (token, value) =>
    apply(h.db, "alice", "linkball_pro_" + value.plan, token, value)};
}

test("expired old subscription never revokes a different active token, in either receipt order", async () => {
  for (const reverse of [false, true]) {
    const {h, verified, apply} = setup();
    const entries = [["old", verified(false, -1)], ["new", verified(true)]];
    if (reverse) entries.reverse();
    for (const [token, value] of entries) await apply(token, value);
    assert.equal(h.read("premiumState/alice/purchaseTokenHash"), "new");
    assert.equal(h.read("premiumEntitlements/alice/active"), true);
  }
});

test("concurrent old/new verifications preserve the longest active coverage", async () => {
  for (const reverse of [false, true]) {
    const {h, verified, apply} = setup();
    const entries = [["expired", verified(false, -1)], ["month", verified(true)],
      ["year", verified(true, 365, "yearly")]];
    if (reverse) entries.reverse();
    await Promise.all(entries.map(([token, value]) => apply(token, value)));
    assert.equal(h.read("premiumState/alice/purchaseTokenHash"), "year");
    assert.equal(h.read("premiumEntitlements/alice/plan"), "yearly");
  }
});

test("the selected token still revokes on expiry/hold, and can renew again", async () => {
  const {h, verified, apply} = setup();
  await apply("current", verified(true));
  const held = verified(false);
  held.result.purchaseState = "SUBSCRIPTION_STATE_ON_HOLD";
  await apply("current", held);
  assert.equal(h.read("premiumEntitlements/alice/active"), false);
  await apply("current", verified(true, 60));
  assert.equal(h.read("premiumEntitlements/alice/active"), true);
  await apply("current", verified(false, -1));
  assert.equal(h.read("premiumEntitlements/alice/active"), false);
});

test("foreign-account receipt cannot revoke another token, but the selected mismatched token is revoked", async () => {
  const {h, verified, apply} = setup();
  await apply("current", verified(true));
  const foreign = verified(true);
  foreign.result.accountId = "another-account";
  await assert.rejects(apply("old", foreign), {code: "permission-denied"});
  assert.equal(h.read("premiumEntitlements/alice/active"), true);
  await assert.rejects(apply("current", foreign), {code: "permission-denied"});
  assert.equal(h.read("premiumEntitlements/alice/active"), false);
});

test("a delayed earlier projection cannot replace a newer canonical verification", async () => {
  const {h, verified, apply} = setup();
  await apply("old", verified(false, -1));
  const stale = h.read("premiumEntitlements/alice");
  await apply("new", verified(true));
  const write = vm.runInContext("lbPremiumWriteProjection", h.context);
  const result = await write(h.db, "alice", stale);
  assert.equal(result.active, true);
  assert.equal(h.read("premiumEntitlements/alice/active"), true);
});

function schedulerSetup(count) {
  const h = harness();
  const owners = {};
  for (let i = 0; i < count; i++) {
    const token = "review-regression-token-" + i;
    const hash = crypto.createHash("sha256").update(token).digest("hex");
    owners[hash] = {uid: "user-" + i, productId: "linkball_pro_monthly", purchaseToken: token};
  }
  h.seed("premiumPurchaseOwners", owners);
  const originalRef = h.db.ref;
  const queries = [];
  h.db.ref = (key) => {
    const ref = originalRef(key);
    if (key !== "premiumPurchaseOwners") return ref;
    ref.orderByKey = () => {
      let after = "";
      let limit = Infinity;
      const query = {
        startAfter: (cursor) => {
          after = cursor;
          return query;
        },
        limitToFirst: (n) => {
          limit = n;
          return query;
        },
        get: async () => {
          assert.equal(limit, 500, "must not load the full token collection");
          const rows = Object.entries(h.read(key) || {}).sort(([a], [b]) => a.localeCompare(b))
              .filter(([k]) => k > after).slice(0, limit);
          queries.push({after, size: rows.length});
          return {exists: () => rows.length > 0, val: () => Object.fromEntries(rows)};
        },
      };
      return query;
    };
    return ref;
  };
  const checked = [];
  h.context.reviewVerify = async (product, token) => {
    checked.push(token);
    return {};
  };
  vm.runInContext("lbPlayVerifyWithGoogle = (p, t) => reviewVerify(p, t); " +
    "lbPremiumApplyAndAcknowledge = async () => {};", h.context);
  return {h, owners, queries, checked, scan: () => h.context.exports.reconcilePremiumSubscriptions()};
}

test("501 subscriptions are all reached across pages and a new sweep starts at the beginning", async () => {
  const {h, owners, queries, checked, scan} = schedulerSetup(501);
  await scan();
  assert.equal(checked.length, 500);
  const cursor = h.read("premiumReconciliation/cursor");
  assert.equal(cursor, Object.keys(owners).sort()[499]);
  await scan();
  assert.equal(checked.length, 501);
  assert.equal(new Set(checked).size, 501);
  assert.equal(h.read("premiumReconciliation/cursor"), "");
  await scan();
  assert.equal(checked.length, 1001);
  assert.deepEqual(queries.map((q) => q.size), [500, 1, 500]);
});

test("failed and malformed receipts cannot trap the cursor; failed receipts are retried next sweep", async () => {
  const {h, owners, checked, scan} = schedulerSetup(501);
  const keys = Object.keys(owners).sort();
  const badToken = owners[keys[0]].purchaseToken;
  h.seed("premiumPurchaseOwners/" + keys[1], {uid: "missing-token"});
  h.context.reviewVerify = async (product, token) => {
    checked.push(token);
    if (token === badToken) throw new Error("temporary Play failure");
    return {};
  };
  await scan();
  await scan();
  assert.ok(checked.includes(owners[keys[500]].purchaseToken));
  assert.equal(h.read("premiumReconciliation/cursor"), "");
  await scan();
  assert.equal(checked.filter((t) => t === badToken).length, 2);
});

test("time-bounded scans checkpoint the last processed token instead of restarting the same page", async () => {
  const {h, checked, scan} = schedulerSetup(20);
  h.context.reviewVerify = async (product, token) => {
    checked.push(token);
    h.setTime(h.now + 60000);
    return {};
  };
  await scan();
  assert.equal(checked.length, 8);
  assert.ok(h.read("premiumReconciliation/cursor"));
  await scan();
  await scan();
  assert.equal(new Set(checked).size, 20);
  assert.equal(checked.length, 20);
  assert.equal(h.read("premiumReconciliation/cursor"), "");
});
