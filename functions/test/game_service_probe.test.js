"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {groups, probe} = require("../../scripts/check-game-services");
test("service probe distinguishes callable auth, missing route, IAM and outages", async () => {
  for (const [status, body, expected] of [
    [401, "{\"error\":{\"status\":\"UNAUTHENTICATED\"}}", "PRESENT_AUTH_REQUIRED"],
    [404, "<html>404</html>", "MISSING"], [403, "Forbidden", "UNVERIFIED"],
    [500, "{\"error\":{\"status\":\"INTERNAL\"}}", "UNVERIFIED"],
    [200, "{}", "UNVERIFIED"],
  ]) {
    const result = await probe("getChoice", {fetchImpl: async (url, options) => {
      assert.equal(url, "https://europe-west1-sharedix.cloudfunctions.net/getChoice");
      assert.deepEqual(JSON.parse(options.body), {data: {}});
      assert.equal(options.headers.Authorization, undefined);
      return {status, text: async () => body};
    }});
    assert.equal(result.state, expected);
  }
  assert.equal((await probe("getChoice", {fetchImpl: async () => {
    throw Error("secret");
  }})).state, "NETWORK_ERROR");
});
test("deployment manifest names actual exports, including writes, search and replay", () => {
  const source = require("node:fs").readFileSync(require.resolve("../index.js"), "utf8");
  for (const name of Object.values(groups).flat()) assert.ok(source.includes(`exports.${name} =`), name);
  assert.ok(groups.arcade.includes("replayArcade"));
  assert.ok(groups.choice.includes("replayChoice"));
  assert.ok(groups.dailyWords.includes("getDailyWordsHistory"));
});
