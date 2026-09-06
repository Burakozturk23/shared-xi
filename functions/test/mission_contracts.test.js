"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);
const rules = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "..", "database.rules.json"),
    "utf8",
));

function missionBlock() {
  const start = source.indexOf(
      "// LINKBALL_16_10C_MISSION_ENGINE_START",
  );
  const end = source.indexOf(
      "// LINKBALL_16_10C_MISSION_ENGINE_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  assert.ok(end > start);

  return source.slice(start, end);
}

function deletionBlock() {
  const start = source.indexOf(
      "// LINKBALL_08B_ACCOUNT_DELETION_START",
  );
  const end = source.indexOf(
      "// LINKBALL_08B_ACCOUNT_DELETION_END",
  );

  assert.notEqual(start, -1);
  assert.notEqual(end, -1);

  return source.slice(start, end);
}

test("mission engine exposes trusted callables and triggers", () => {
  const block = missionBlock();

  assert.ok(block.includes("exports.getMyMissions"));
  assert.ok(block.includes("exports.claimMissionReward"));
  assert.ok(block.includes("exports.syncRankedMissions"));
  assert.ok(block.includes("exports.syncDailyMissions"));
  assert.ok(block.includes("lbRequireGoogleLinked(request)"));
});

test("daily missions use only trusted ranked and daily sources", () => {
  const block = missionBlock();

  assert.ok(block.includes(
      "ref: \"/rankedState/settlements/{mode}/{matchId}\"",
  ));
  assert.ok(block.includes(
      "ref: \"/dailyLeaderboard/{dateKey}/{uid}\"",
  ));
  assert.ok(block.includes("settlement.serverValidated !== true"));
  assert.ok(block.includes("row.serverValidated !== true"));
  assert.equal(block.includes("recordSoloMission"), false);
});

test("daily catalog is three canonical ten-coin tasks", () => {
  const block = missionBlock();

  for (const id of [
    "daily_ranked_play_3",
    "daily_ranked_win_1",
    "daily_challenge_1",
  ]) {
    assert.ok(block.includes(id), id);
  }

  const dailySection = block.slice(
      block.indexOf("LB_MISSION_DAILY_DEFINITIONS"),
      block.indexOf("LB_MISSION_GENERAL_CHAINS"),
  );

  assert.equal(
      (dailySection.match(/rewardCoins: 10/g) || []).length,
      3,
  );
});

test("general missions form ordered trusted progression chains", () => {
  const block = missionBlock();

  for (const id of [
    "general_ranked_play_5",
    "general_ranked_play_250",
    "general_ranked_wins_3",
    "general_ranked_wins_100",
    "general_daily_days_3",
    "general_daily_days_100",
  ]) {
    assert.ok(block.includes(id), id);
  }

  assert.ok(block.includes("lbMissionRequirePreviousStages"));
  assert.ok(block.includes("Complete the previous mission stage first."));
});

test("mission reward claims are server-defined and idempotent", () => {
  const block = missionBlock();

  assert.ok(block.includes("lbProgressionGrantCoins("));
  assert.ok(block.includes("\"mission_reward__\" + periodKey"));
  assert.ok(block.includes("resolved.definition.rewardCoins"));
  assert.equal(block.includes("(request.data || {}).amount"), false);
  assert.equal(block.includes("(request.data || {}).progress"), false);
});

test("mission daily state resets by server Istanbul day", () => {
  const block = missionBlock();

  assert.ok(block.includes("lbProgressionDateKey(currentTime)"));
  assert.ok(block.includes("sameDay"));
  assert.ok(block.includes("eventDay !== currentDay"));
  assert.equal(block.includes("(request.data || {}).dateKey"), false);
});

test("mission state is private and projection is owner read-only", () => {
  assert.equal(rules.rules.missionState[".read"], false);
  assert.equal(rules.rules.missionState[".write"], false);

  const owner = rules.rules.missionProfiles["$uid"];

  assert.equal(owner[".write"], false);
  assert.ok(String(owner[".read"]).includes("google.com"));
  assert.ok(String(owner[".read"]).includes("auth.uid == $uid"));
});

test("account deletion clears mission state and projection", () => {
  const block = deletionBlock();

  assert.ok(block.includes("missionState/"));
  assert.ok(block.includes("missionProfiles/"));
});

test("mission engine does not add mode-specific solo tasks", () => {
  const block = missionBlock();

  for (const mode of [
    "7a0",
    "box2box",
    "pyramid",
    "career_puzzle",
    "player_journey",
  ]) {
    assert.equal(block.includes(mode), false, mode);
  }
});
