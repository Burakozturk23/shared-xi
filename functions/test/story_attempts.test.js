"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {cooldownMs} = require("../story_attempts");
const catalog = require("../config/ucl_catalog.json");
const m = catalog.matches[0];
// A timeline task: the reversed order is a real, wrong guess.
const wrong = [...m.answerKeys].reverse();
const send = (h, answers) => h.call("submitUclMoment", {version: 1, matchId: m.id, answers});
test("story tasks: three real misses start a doubling cooldown; a correct answer records the misses", async () => {
  assert.deepEqual([0, 1, 2, 3, 4, 5, 9].map(cooldownMs), [0, 0, 0, 30000, 60000, 120000, 600000]);
  const h = harness();
  for (const answers of [null, [], 1]) assert.equal((await send(h, answers)).correct, false);
  assert.equal(h.read(`storyAttempts/alice/ucl_moments/${m.id}`), null);
  for (let i = 0; i < 3; i++) assert.equal((await send(h, wrong)).correct, false);
  await assert.rejects(send(h, m.answerKeys), {code: "resource-exhausted"});
  // Story services read the real clock: expire the stored cooldown instead.
  h.seed(`storyAttempts/alice/ucl_moments/${m.id}/until`, Date.now() - 1);
  const ok = await send(h, m.answerKeys);
  assert.notEqual(ok.correct, false);
  const row = h.read(`storyAttempts/alice/ucl_moments/${m.id}`);
  assert.equal(row.wrongBeforeSolve, 3); assert.equal(row.until, undefined);
});
