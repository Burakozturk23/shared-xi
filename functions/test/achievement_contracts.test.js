"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

function achievementBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  return source.slice(start, end);
}

test("first canonical achievement catalog has stable unique ids", () => {
  const block = achievementBlock();
  const ids = [...block.matchAll(/id: "([a-z0-9_]+)"/g)]
      .map((match) => match[1]);

  assert.equal(ids.length, 28);
  assert.equal(new Set(ids).size, ids.length);
});

test("achievement definitions have positive targets", () => {
  const block = achievementBlock();
  const targets = [...block.matchAll(/target: ([0-9]+)/g)]
      .map((match) => Number(match[1]));

  assert.equal(targets.length, 28);
  assert.ok(targets.every((value) => value > 0));
});

test("achievement engine keeps unlocks in private canonical state", () => {
  const block = achievementBlock();

  assert.ok(block.includes("state.unlocks[definition.id]"));
  assert.ok(block.includes("achievementState/"));
  assert.ok(block.includes("achievementProgress/"));
  assert.ok(block.includes("userAchievements/"));
});
