"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {createCatalog, loadBundledCatalog} = require("../lib/duel_data");
const bundled = require("../config/duel_runtime.json");
const condition = {kind: "country", key: "Test country"};

// Fictional test identities only. Never included in the production package.
function fixture() {
  const data = structuredClone(bundled);
  data.players = [];
  data.verifiedMetrics = [];
  data.conditions = [];
  data.sources = {fixture: {provider: "test-only"}};
  data.acceptance = {conditionPathsApproved: true, gameplayApproved: true};
  const criterion = data.criteria.find((c) => c.id === "F12");
  criterion.enabled = true;
  criterion.blockers = [];
  for (let i = 1; i <= 120; i++) {
    const position = ["GK", "DEF", "MID", "FWD"][Math.floor((i - 1) / 30)];
    data.players.push({id: i, name: `Test ${i}`, aliases: [], position});
    data.verifiedMetrics.push({playerId: i, criterionId: "F12", value: position === "GK" ? 0 : i,
      scopeId: criterion.scopeId, unit: "count", cutoff: data.cutoff,
      status: "verified", coverage: "complete", sources: ["fixture"]});
    data.conditions.push({...condition, playerId: i, cutoff: data.cutoff, status: "verified",
      meaning: "senior_national_team", sources: ["fixture"]});
    if ((i - 1) % 30 < 6) {
      data.conditions.push({kind: "club", key: "Test club", playerId: i,
        cutoff: data.cutoff, status: "verified", meaning: "official_senior_appearance", sources: ["fixture"]});
    }
  }
  return data;
}

test("bundled data exposes reviewed corrections but no playable criteria", () => {
  const catalog = loadBundledCatalog();
  assert.deepEqual(catalog.availableCriteria(), []);
  assert.equal(catalog.verifiedMetric("F15", 5023).value, 176);
  assert.equal(catalog.verifiedMetric("F12", 5023), null);
  assert.equal(catalog.verifiedMetric("F18", 4000000056).value, 56);
  assert.throws(() => catalog.score("F15", [], []));
});

test("zero is valid, complete player pool is not capped at 24", () => {
  const catalog = createCatalog(fixture());
  assert.deepEqual(catalog.availableCriteria(), ["F12"]);
  assert.equal(catalog.verifiedMetric("F12", 1).value, 0);
  assert.equal(catalog.eligiblePlayerIds("F12", "GK", condition).length, 30);
  assert.equal(catalog.eligiblePlayerIds("F12", "DEF", condition).length, 30);
});

test("country and career club are alternative filters; both players' exclusions apply", () => {
  const catalog = createCatalog(fixture());
  const club = {kind: "club", key: "Test club"};
  assert.equal(catalog.eligiblePlayerIds("F12", "DEF", club).length, 6);
  assert.equal(catalog.eligiblePlayerIds("F12", "DEF", condition, new Set([31, 32])).length, 28);
  assert.equal(catalog.candidateConditions("F12", "DEF", new Set([31])).length, 1);
  assert.deepEqual(catalog.eligiblePlayerIds("F12", "DEF", {kind: "club", key: "unknown"}), []);
});

test("minimum total, position coverage and acceptance gates all fail closed", () => {
  const variants = [
    (d) => d.verifiedMetrics.pop(),
    (d) => d.players.filter((p) => p.position === "GK").forEach((p) => {
      p.position = "DEF";
    }),
    (d) => {
      d.acceptance.gameplayApproved = false;
    },
    (d) => {
      d.acceptance.conditionPathsApproved = false;
    },
    (d) => {
      d.criteria.find((c) => c.id === "F12").enabled = false;
    },
    (d) => {
      d.criteria.find((c) => c.id === "F12").blockers.push("unreviewed");
    },
  ];
  for (const change of variants) {
    const data = fixture(); change(data);
    assert.deepEqual(createCatalog(data).availableCriteria(), []);
  }
});

test("partial, date-shifted, wrong-scope or source-free metrics are rejected", () => {
  for (const change of [{coverage: "partial"}, {value: null}, {value: -1}, {value: 0.1},
    {value: Number.MAX_SAFE_INTEGER + 1}, {cutoff: "2026-10-15"}, {scopeId: "with-qualifiers"},
    {unit: "inches"}, {status: "source_observed"}, {sources: []}, {sources: ["constructor"]}]) {
    const data = fixture(); Object.assign(data.verifiedMetrics[0], change);
    assert.throws(() => createCatalog(data));
  }
});

test("duplicate identities and metrics, unverified roster conditions are rejected", () => {
  const changes = [
    (d) => d.players.push(d.players[0]),
    (d) => d.verifiedMetrics.push(d.verifiedMetrics[0]),
    (d) => {
      d.conditions[0].meaning = "citizenship";
    },
    (d) => {
      d.conditions[1].meaning = "current_roster";
    },
    (d) => d.criteria.pop(),
  ];
  for (const change of changes) {
    const data = fixture(); change(data);
    assert.throws(() => createCatalog(data));
  }
});

test("six local choices cannot authorize a dead-end future round", () => {
  const data = fixture();
  data.conditions = data.conditions.filter((c) => c.playerId <= 36 || c.playerId > 60);
  const catalog = createCatalog(data);
  assert.equal(catalog.candidateConditions("F12", "DEF").length, 2);
  assert.deepEqual(catalog.safeConditions("F12", "DEF", ["MID", "DEF", "MID", "FWD"]), []);
  assert.equal(catalog.safeConditions("F12", "DEF", ["FWD"]).length, 2);
});

test("every possible first pair leaves safe paths under the reserve certificate", () => {
  const catalog = createCatalog(fixture());
  const choices = catalog.eligiblePlayerIds("F12", "DEF", condition);
  assert.ok(catalog.safeConditions("F12", "DEF", ["MID", "DEF", "MID", "FWD"]).length);
  for (let i = 0; i < choices.length; i++) {
    for (let j = i + 1; j < choices.length; j++) {
      assert.ok(catalog.safeConditions("F12", "MID", ["DEF", "MID", "FWD"],
          new Set([choices[i], choices[j]])).length);
    }
  }
});

test("scores use complete criterion total, legal positions, distinct players and actual zero", () => {
  const catalog = createCatalog(fixture());
  const lineup = [1, 31, 61, 32, 62, 91];
  const rounds = Array(6).fill({kind: "club", key: "Test club"});
  assert.equal(catalog.score("F12", lineup, rounds), 277);
  assert.throws(() => catalog.score("F12", [1, 31, 61, 31, 62, 91], rounds));
  assert.throws(() => catalog.score("F12", [31, 1, 61, 32, 62, 91], rounds));
  assert.throws(() => catalog.score("F12", [1, 31, 61, 32, 62, 120], rounds));
});

test("catalog takes immutable copies of authority fields", () => {
  const data = fixture(); const catalog = createCatalog(data);
  data.criteria.find((c) => c.id === "F12").blockers.push("changed");
  data.verifiedMetrics[0].value = 999;
  data.players[0].position = "FWD";
  assert.equal(catalog.isAvailable("F12"), true);
  assert.equal(catalog.verifiedMetric("F12", 1).value, 0);
  assert.equal(catalog.eligiblePlayerIds("F12", "GK", condition).length, 30);
});

test("tampered payload and manifest fail integrity verification", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "duel-test-"));
  try {
    const base = path.join(__dirname, "../config");
    for (const file of ["duel_manifest.json", "duel_runtime.json"]) {
      fs.copyFileSync(path.join(base, file), path.join(dir, file));
    }
    fs.appendFileSync(path.join(dir, "duel_runtime.json"), " ");
    assert.throws(() => loadBundledCatalog(dir), /integrity/);
    fs.copyFileSync(path.join(base, "duel_runtime.json"), path.join(dir, "duel_runtime.json"));
    const manifest = JSON.parse(fs.readFileSync(path.join(dir, "duel_manifest.json")));
    manifest.version = "wrong";
    fs.writeFileSync(path.join(dir, "duel_manifest.json"), JSON.stringify(manifest));
    assert.throws(() => loadBundledCatalog(dir), /version/);
  } finally {
    fs.rmSync(dir, {recursive: true, force: true});
  }
});
