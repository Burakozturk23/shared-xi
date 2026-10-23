"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {callables, scheduled} = require("../../scripts/check-online-services");
test("online deployment manifest covers the actual exported services without changing economy gates", () => {
  const root = path.join(__dirname, "../..");
  const source = fs.readFileSync(path.join(root, "functions/index.js"), "utf8");
  for (const name of [...callables, ...scheduled]) assert(source.includes(`exports.${name} =`), name);
  assert.equal(new Set([...callables, ...scheduled]).size, 12);
  const script = fs.readFileSync(path.join(root, "scripts/deploy-online-games.ps1"), "utf8");
  assert(!/"(?:rewardsEnabled|eloEnabled|managerRankedVerified)"\s*:/.test(script));
  assert(script.includes("if ($LASTEXITCODE -ne 0)"));
  assert(script.indexOf("node scripts/check-online-services.js\n  if") < script.indexOf("if ($EnableOnlineModes)"));
});
