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

test("expanded server and Flutter catalog retain all legacy IDs and agree on targets", () => {
  const additions = require("../config/achievement_expansion.json");
  const old = [...achievementBlock().matchAll(/id: "([a-z0-9_]+)",\s*signal: "([a-z0-9_]+)",\s*target: (\d+)/g)]
      .map((m) => ({id: m[1], signal: m[2], target: Number(m[3])}));
  const all = [...old, ...additions];
  assert.equal(all.length, 88);
  assert.equal(new Set(all.map((r) => r.id)).size, 88);
  const dart = fs.readFileSync(path.join(__dirname, "../../lib/models/achievement_catalog.dart"), "utf8");
  for (const d of all) {
    const block = dart.slice(dart.indexOf("id: '" + d.id + "'"));
    const definition = block.slice(0, block.indexOf("    ),"));
    assert.ok(definition.includes("signal: '" + d.signal + "'"), d.id);
    assert.ok(definition.includes("target: " + d.target + ","), d.id);
    assert.ok(d.target > 0);
  }
});

test("new badge reward requires server unlock and is idempotent", async () => {
  const {harness} = require("./support/economy_harness");
  const h = harness();
  await assert.rejects(h.call("claimAchievementReward", {achievementId: "winner_750"}),
      {code: "failed-precondition"});
  h.seed("userAchievements/alice/winner_750", {unlockedAt: h.now});
  const a = await h.call("claimAchievementReward", {achievementId: "winner_750"});
  const b = await h.call("claimAchievementReward", {achievementId: "winner_750"});
  assert.equal(a.amount, 250);
  assert.equal(b.alreadyClaimed, true);
  assert.equal(h.read("economyState/alice/balances/coins"), 250);
});

// Every definition with its reward and Flutter tier, server and app together.
function catalog() {
  const additions = require("../config/achievement_expansion.json");
  const economy = require("../economy_config");
  const rewards = economy.achievementRewards(economy.defaults);
  const old = [...achievementBlock().matchAll(/id: "([a-z0-9_]+)",\s*signal: "([a-z0-9_]+)",\s*target: (\d+)/g)]
      .map((m) => ({id: m[1], signal: m[2], target: Number(m[3])}));
  const dart = fs.readFileSync(path.join(__dirname, "../../lib/models/achievement_catalog.dart"), "utf8");
  return [...old, ...additions].map((d) => {
    const block = dart.slice(dart.indexOf("id: '" + d.id + "'"));
    const tier = block.slice(0, block.indexOf("    ),")).match(/AchievementTier\.(\w+)/)[1];
    return {...d, tier, reward: rewards[d.id] ?? 0};
  });
}

test("within a signal a harder badge never pays less or sits in a lower tier", () => {
  const order = ["bronze", "silver", "gold", "platinum"];
  const bySignal = {};
  for (const d of catalog()) (bySignal[d.signal] ||= []).push(d);
  for (const [signal, rows] of Object.entries(bySignal)) {
    rows.sort((a, b) => a.target - b.target);
    for (let i = 1; i < rows.length; i++) {
      assert.ok(rows[i].reward >= rows[i - 1].reward, signal + ": " + rows[i].id);
      assert.ok(order.indexOf(rows[i].tier) >= order.indexOf(rows[i - 1].tier), signal + ": " + rows[i].id);
    }
  }
  assert.ok(catalog().every((d) => d.reward > 0), "every badge pays a reward");
});

test("every badge signal has a server producer", () => {
  const sources = fs.readdirSync(path.join(__dirname, "..")).filter((f) => f.endsWith(".js"))
      .map((f) => fs.readFileSync(path.join(__dirname, "..", f), "utf8")).join("\n");
  const families = source.match(/LB_ACHIEVEMENT_MODE_FAMILIES = \{([\s\S]*?)\n\};/)[1];
  for (const {id, signal} of catalog()) {
    const family = signal.match(/^ranked_(\w+)_wins$/)?.[1];
    // Numbered signals may be built from a prefix ("journey_chapter_" + n).
    const prefix = "\"" + signal.replace(/\d+$/, "") + "\" +";
    const produced = sources.includes(signal + ":") || sources.includes("\"" + signal + "\"") ||
      /\d$/.test(signal) && sources.includes(prefix) ||
      signal === "ranked_modes_won" || !!family && new RegExp("\\b" + family + ": \\[").test(families);
    assert.ok(produced, id + " -> " + signal);
  }
});

test("today's PvP mode ids count toward the older badge families and new ladders", () => {
  const block = achievementBlock();
  const start = block.indexOf("// Badge families of ranked modes");
  const end = block.indexOf("exports.syncRankedAchievements");
  const signals = new Function("lbRankedProfile", "lbRankedModeStats", block.slice(start, end) +
    "\nreturn lbAchievementRankedSignals;")((p) => p, (m) => m);
  const row = (wins) => ({wins, losses: 0, draws: 0});
  const s = signals({wins: 9, losses: 0, draws: 0, bestWinStreak: 2, peakElo: 1000, modeStats: {
    club_club: row(2), shared_xi: row(1), grid_classic: row(1), grid_reverse: row(1), random_five: row(3),
    loto: row(1), fake_club_duel: row(0)}});
  assert.equal(s.ranked_shared_xi_wins, 3); assert.equal(s.ranked_grid_wins, 2);
  assert.equal(s.ranked_five_wins, 3); assert.equal(s.ranked_loto_wins, 1);
  assert.equal(s.ranked_fake_club_duel_wins, 0); assert.equal(s.ranked_modes_won, 4);
});
