"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../nostalgia");
const proof = (t) => ({version: 1, taskId: t.id, answers: t.answerKeys});
test("Nostalji: all 24 tasks, 12 albums and final badge pay exactly 384 coins / 840 XP once", async () => {
  const h = harness();
  for (const t of catalog.tasks) await h.call("submitNostalgiaTask", proof(t));
  await Promise.all(catalog.tasks.map((t) => h.call("submitNostalgiaTask", proof(t))));
  const s = await h.call("getNostalgia");
  assert.equal(Object.keys(s.results).length, 24);
  assert.equal(Object.keys(s.albums).length, 12);
  assert.equal(s.badge, "nostalgia_archivist_v1");
  assert.equal(h.read("economyState/alice/balances/coins"), 384);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 840);
  for (const path of ["uclMomentsState", "whatIfState", "journeyRewardState"]) assert.equal(h.read(path), null);
});
test("Nostalji: answer secrecy, chapter order, auth, ID and version rejection", async () => {
  const h = harness();
  const s = await h.call("getNostalgia");
  assert.deepEqual(s.results, {}); assert.deepEqual(s.albums, {}); assert.deepEqual(s.hints, {});
  await assert.rejects(h.call("submitNostalgiaTask", proof(catalog.tasks[1])));
  await assert.rejects(h.call("submitNostalgiaTask", proof(catalog.tasks[0]), null));
  for (const taskId of ["constructor", "__proto__", "ucl_01"]) {
    await assert.rejects(h.call("submitNostalgiaTask", {...proof(catalog.tasks[0]), taskId}));
  }
  await assert.rejects(h.call("submitNostalgiaTask", {...proof(catalog.tasks[0]), version: 2}));
  for (const answers of [[], ["fake"], null, [catalog.tasks[0].answerKeys[0], "extra"]]) {
    assert.deepEqual(await h.call("submitNostalgiaTask", {...proof(catalog.tasks[0]), answers}), {correct: false});
  }
  assert.equal(h.read("economyState/alice"), null);
});
test("Nostalji: interrupted XP settlement repairs without duplicate money", async () => {
  const h = harness(); h.failNext("progressionState/alice");
  await assert.rejects(h.call("submitNostalgiaTask", proof(catalog.tasks[0])));
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  await h.call("getNostalgia"); await h.call("submitNostalgiaTask", proof(catalog.tasks[0]));
  assert.equal(h.read("economyState/alice/balances/coins"), 6);
  assert.equal(h.read("progressionState/alice/lifetimeXp"), 15);
});
test("Nostalji: guests solve offline-queued work; same UID Google link settles rewards", async () => {
  const h = harness(); const guest = {uid: "guest", token: {firebase: {sign_in_provider: "anonymous"}}};
  for (const t of catalog.tasks) await h.call("submitNostalgiaTask", proof(t), guest);
  assert.equal(h.read("economyState/guest"), null);
  const linked = {uid: "guest", token: {firebase: {identities: {"google.com": ["linked"]}}}};
  await h.call("getNostalgia", {}, linked); await h.call("getNostalgia", {}, linked);
  assert.equal(h.read("economyState/guest/balances/coins"), 384);
  const other = await h.call("getNostalgia", {}, {uid: "other", token: {}});
  assert.deepEqual(other.results, {});
});
test("Nostalji: coin hint charges once even when grant write fails; price must be confirmed", async () => {
  const h = harness({economyState: {alice: {balances: {coins: 30}}}});
  const input = {version: 1, taskId: catalog.tasks[0].id, maxPrice: 6};
  await assert.rejects(h.call("buyNostalgiaHint", {...input, maxPrice: 0}));
  h.failNext("nostalgiaState/alice");
  await assert.rejects(h.call("buyNostalgiaHint", input));
  assert.equal(h.read("economyState/alice/balances/coins"), 24);
  const responses = await Promise.all([h.call("buyNostalgiaHint", input), h.call("buyNostalgiaHint", input)]);
  assert.equal(h.read("economyState/alice/balances/coins"), 24);
  assert.equal(responses[0].hints[input.taskId], catalog.tasks[0].strongHint);
  assert.equal(Object.keys(responses[0].results).length, 0);
  assert.equal(Object.keys(responses[0].hints).length, 1);
});
test("Nostalji: Pro support is free; insufficient funds and anonymous support rejected", async () => {
  const h = harness({premiumState: {alice: {plan: "lifetime", verified: true, entitled: true}}});
  const input = {version: 1, taskId: catalog.tasks[0].id, maxPrice: 0};
  assert.equal((await h.call("getNostalgia")).hintPrice, 0);
  await h.call("buyNostalgiaHint", input);
  assert.equal(h.read("economyState/alice/balances/coins"), 0);
  await assert.rejects(harness().call("buyNostalgiaHint", {...input, maxPrice: 6}));
  await assert.rejects(harness().call("buyNostalgiaHint", {...input, maxPrice: 6}, {uid: "guest", token: {}}));
});
