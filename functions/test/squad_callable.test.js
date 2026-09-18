"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const engine = require("../squad_challenge");
const {wallet, solve} = require("./squad_fixture");

const source = fs.readFileSync(path.join(__dirname, "../index.js"), "utf8");
function definition(name) {
  const start = source.indexOf("function " + name + "(");
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf("\n}", start) + 2);
}
const now = Date.parse("2026-09-18T10:00:00Z");
const day = engine.dayKey(now);
const mission = engine.missions(day)[0];
const requestId = (n) => day + "__" + n.toString(16).padStart(32, "0");
const clone = (value) => JSON.parse(JSON.stringify(value));

// Execute the actual exported callable factory and canonical normalizers.
// The fake RTDB deliberately invokes each update first with a cold null cache,
// then retries it on the serialized current server value (including conflicts).
function harness(initial = wallet()) {
  let state = clone(initial);
  let premium = {};
  let queue = Promise.resolve();
  let projectionFails = false;
  let commits = 0;
  const db = {
    ref: (key) => ({
      get: async () => ({val: () => clone(premium)}),
      transaction: (update) => {
        assert.equal(key, "economyState/alice");
        update(null);
        const pending = queue.then(async () => {
          const next = update(clone(state));
          state = clone(next);
          commits++;
          return {committed: true, snapshot: {val: () => clone(state)}};
        });
        queue = pending.catch(() => {});
        return pending;
      },
    }),
  };
  class HttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }
  const context = vm.createContext({
    squadChallenge: engine,
    httpsV2: {HttpsError, onCall: (options, handler) => ({options, handler})},
    admin: {database: () => db},
    Date: {now: () => now},
    LB_ECONOMY_VERSION: 1,
    LB_PREMIUM_VERSION: 1,
    LB_PREMIUM_PLANS: new Set(["monthly", "yearly", "lifetime"]),
    lbEconomyProject: async () => {
      if (projectionFails) {
        projectionFails = false;
        throw new Error("Lost response after committed wallet transaction");
      }
    },
  });
  vm.runInContext([
    "lbRequireGoogleLinked", "lbPremiumNumber", "lbPremiumText",
    "lbPremiumState", "lbEconomyNumber", "lbEconomyState", "squadCallable",
  ].map(definition).join("\n"), context);
  const callables = Object.fromEntries(["status", "start", "finish", "abandon"]
      .map((action) => [action, context.squadCallable(action)]));
  return {
    call: (action, data = {}, auth = {
      uid: "alice", token: {firebase: {identities: {"google.com": ["alice-google"]}}},
    }) => callables[action].handler({auth, data: {catalogVersion: engine.catalog.version, ...data}}),
    get state() {
      return state;
    },
    get commits() {
      return commits;
    },
    callables,
    normalize: (s) => context.lbEconomyState(clone(s)),
    setPremium: (p) => premium = p,
    failProjection: () => projectionFails = true,
  };
}

test("callables enforce App Check, Google identity and catalog version before wallet writes", async () => {
  const h = harness();
  for (const callable of Object.values(h.callables)) assert.equal(callable.options.enforceAppCheck, true);
  await assert.rejects(h.call("status", {}, null), {code: "unauthenticated"});
  await assert.rejects(h.call("status", {}, {uid: "alice", token: {}}), {code: "failed-precondition"});
  await assert.rejects(h.call("status", {catalogVersion: "obsolete"}), {code: "failed-precondition"});
  assert.equal(h.commits, 0);
});

test("concurrent paid starts and duplicate finishes commit one charge and one reward despite cold cache", async () => {
  const initial = wallet(100);
  engine.apply(initial, "status", {}, now, false);
  initial.squadChallenge.freeUsed = 3;
  const h = harness(initial);
  const starts = await Promise.all([1, 2].map((n) => h.call("start", {
    missionId: mission.id, requestId: requestId(n), payment: "coins",
  })));
  assert.equal(starts[0].run.id, starts[1].run.id);
  assert.equal(h.state.balances.coins, 80);
  assert.equal(h.state.squadChallenge.paidUsed, 1);
  const ids = solve(mission);
  const data = {runId: starts[0].run.id, playerIds: ids};
  const results = await Promise.all([h.call("finish", data), h.call("finish", data)]);
  assert.deepEqual(results[0].run.result, results[1].run.result);
  assert.equal(h.state.balances.coins, 100);
  assert.equal(Object.keys(h.state.claims).length, 1);
  assert.equal(Object.keys(h.state.purchases).length, 1);
  assert.equal(h.state.squadChallenge.completedTotal, 1);
  // Other wallet handlers use this same normalizer; they must not erase progress.
  assert.deepEqual(clone(h.normalize(h.state).squadChallenge), h.state.squadChallenge);
});

test("failed response after commit recovers the exact receipt without charging or rewarding again", async () => {
  const initial = wallet(100);
  engine.apply(initial, "status", {}, now, false);
  initial.squadChallenge.freeUsed = 3;
  const h = harness(initial);
  const data = {missionId: mission.id, requestId: requestId(1), payment: "coins"};
  h.failProjection();
  await assert.rejects(h.call("start", data), /Lost response/);
  const start = await h.call("start", data);
  assert.equal(h.state.balances.coins, 80);
  const finish = {runId: start.run.id, playerIds: solve(mission)};
  h.failProjection();
  await assert.rejects(h.call("finish", finish), /Lost response/);
  const result = await h.call("finish", finish);
  assert.equal(result.run.result.reward, 20);
  assert.equal(h.state.balances.coins, 100);
  assert.equal(h.state.lifetimeSpent, 20);
  assert.equal(h.state.squadChallenge.completedTotal, 1);
});

test("Premium requires verified unexpired server state, ignoring client flags", async () => {
  const h = harness();
  const forged = await h.call("status", {premium: true, coins: 99999, freeRemaining: 999});
  assert.equal(forged.hub.premium, false);
  assert.equal(forged.hub.coins, 200);
  for (const record of [
    {plan: "monthly", verified: false, expiresAt: now + 10000},
    {plan: "monthly", verified: true, expiresAt: now - 1},
    {plan: "lifetime", verified: false},
  ]) {
    h.setPremium(record);
    assert.equal((await h.call("status")).hub.premium, false);
  }
  for (const record of [
    {plan: "monthly", verified: true, expiresAt: now + 10000},
    {plan: "lifetime", verified: true},
  ]) {
    h.setPremium(record);
    const status = await h.call("status");
    assert.equal(status.hub.premium, true);
    assert.equal(status.hub.dailyMaxCoins, 90);
  }
});

test("a rejected submission leaves the canonical wallet and active run unchanged", async () => {
  const h = harness();
  const start = await h.call("start", {missionId: mission.id, requestId: requestId(1)});
  const before = clone(h.state);
  await assert.rejects(h.call("finish", {runId: start.run.id, playerIds: [99999]}),
      {code: "invalid-argument"});
  assert.deepEqual(h.state, before);
});
