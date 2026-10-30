"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const B = require("../boosts");
const G = require("../grid_support");
const S = require("../bot_support");
// The 13 ranked/friend modes are read from the shipped Dart catalog, not copied.
const dart = fs.readFileSync(path.join(__dirname, "../../lib/online/online_mode_catalog.dart"), "utf8");
const getter = dart.slice(dart.indexOf("String get wireName"), dart.indexOf("static OnlinePlayMode? fromWire"));
const wireNames = [...getter.matchAll(/return '([a-z_]+)';/g)].map((m) => m[1]);

test("all 13 online wireNames stay outside every boost whitelist, offer and pinned policy", () => {
  assert.equal(new Set(wireNames).size, 13);
  const policy = {enabled: true, public: true, percent: 100,
    readyModes: Object.fromEntries([...wireNames, ...Object.keys(B.modes)].map((m) => [m, true]))};
  for (const mode of wireNames) {
    assert.equal(B.modes[mode], undefined, mode);
    assert.equal(B.offers.some((o) => o.modes.includes(mode)), false, mode);
    assert.equal(G.MODES.includes(mode) || S.MODES.includes(mode), false, mode);
    const run = {mode};
    B.pin(run, policy);
    assert.equal(B.paid(run), false, mode);
    assert.equal(B.view(run), null, mode);
  }
});

test("65-row coverage matrix matches the boost whitelist and cites existing tests", () => {
  const rows = JSON.parse(fs.readFileSync(path.join(__dirname, "../../docs/specs/mission-boosts/mode-coverage.json")));
  const scope = JSON.parse(fs.readFileSync(path.join(__dirname, "../../docs/specs/mission-boosts/mode-scope.json")));
  assert.equal(rows.length, 65);
  assert.deepEqual(rows.map((r) => r.grup + "/" + r.mod), scope.map((r) => r.grup + "/" + r.mod));
  for (const r of rows) {
    if (r.status === "server_paid") assert.ok(r.modeIds.length && r.modeIds.every((m) => B.modes[m]), r.mod);
    else assert.deepEqual(r.modeIds, [], r.mod);
    if (r.tests) assert.ok(fs.existsSync(path.join(__dirname, r.tests)), r.tests);
  }
  const listed = new Set(rows.flatMap((r) => r.modeIds));
  assert.deepEqual(Object.keys(B.modes).filter((m) => !listed.has(m)), []);
  assert.equal(rows.filter((r) => r.status === "online_cosmetic_only").length, wireNames.length);
});
