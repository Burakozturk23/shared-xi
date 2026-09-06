"use strict";

// STEP 07B.3.1
//
// Fast, emulator-free security contract tests.
// These protect the server-authoritative Daily and secret-management contract.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const sourcePath = path.join(__dirname, "..", "index.js");
const source = fs.readFileSync(sourcePath, "utf8");

const authGuard = "if (!request.auth || !request.auth.uid) {";
const foundGuard =
    "lbDailyInt(data.foundCount, \"foundCount\", 0, 80)";
const targetGuard =
    "lbDailyInt(data.targetCount, \"targetCount\", 1, 80)";
const wrongGuard =
    "lbDailyInt(data.wrongCount, \"wrongCount\", 0, 10)";
const leaderboardGuard = "\"dailyLeaderboard/\" + dateStr";

function sliceBetween(startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `missing start marker: ${startMarker}`);

  const end = source.indexOf(endMarker, start + startMarker.length);
  if (end === -1) {
    return source.slice(start);
  }

  return source.slice(start, end);
}

test("API-Football key stays in Firebase Secret Manager", () => {
  const secretDeclaration = /defineSecret\(["']API_FOOTBALL_KEY["']\)/;
  const secretLiteral =
      /API_FOOTBALL_KEY\s*=\s*["'][A-Za-z0-9_-]{12,}["']/;

  assert.match(source, secretDeclaration);
  assert.doesNotMatch(source, secretLiteral);
});

test("Daily callable functions require authenticated users", () => {
  const startBlock = sliceBetween(
      "exports.startDailyScoreSession",
      "exports.submitDailyScore",
  );
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(startBlock.includes(authGuard));
  assert.ok(submitBlock.includes(authGuard));
});

test("Daily score primitives remain server bounded", () => {
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(submitBlock.includes(foundGuard));
  assert.ok(submitBlock.includes(targetGuard));
  assert.ok(submitBlock.includes(wrongGuard));
  assert.ok(submitBlock.includes("const score = foundCount * 10;"));
});

test("Daily leaderboard writes stay server validated", () => {
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(submitBlock.includes(leaderboardGuard));
  assert.ok(submitBlock.includes("serverValidated: true"));
  assert.ok(submitBlock.includes("validationVersion: 1"));
});


test("Daily trusted submission maintains weekly server aggregation", () => {
  const submitBlock = sliceBetween(
      "exports.submitDailyScore",
      "// LINKBALL_05B_DAILY_AUTHORITY_END",
  );

  assert.ok(submitBlock.includes("lbDailyWeekKey(dateStr)"));
  assert.ok(submitBlock.includes("weeklyLeaderboard/"));
  assert.ok(submitBlock.includes("leaderboardState/weeklyUserIndex/"));
  assert.ok(submitBlock.includes("serverValidated: true"));
  assert.ok(submitBlock.includes("validationVersion: 1"));
});

test("Ranked settlement is authenticated and Google-linked", () => {
  const callableBlock = sliceBetween(
      "exports.submitRankedResult",
      "// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_END",
  );
  const authHelper = sliceBetween(
      "function lbRequireGoogleLinked",
      "function lbRankedExpectedScore",
  );

  assert.ok(callableBlock.includes("lbRequireGoogleLinked(request)"));
  assert.ok(callableBlock.includes("request.auth.uid"));
  assert.ok(authHelper.includes("request.auth.token.firebase"));
  assert.ok(authHelper.includes("identities[\"google.com\"]"));
});

test("Ranked settlement requires an explicitly ranked finished match", () => {
  const callableBlock = sliceBetween(
      "exports.submitRankedResult",
      "// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_END",
  );
  const factsHelper = sliceBetween(
      "function lbRankedMatchFacts",
      "function lbRankedResultName",
  );

  assert.ok(callableBlock.includes("lbRankedMatchFacts(mode, match)"));
  assert.ok(factsHelper.includes("match.ranked !== true"));
  assert.ok(factsHelper.includes("match.status !== \"finished\""));
  assert.ok(factsHelper.includes("game.gameOver !== true"));
  assert.ok(!callableBlock.includes("data.elo"));
});

test("Trusted ranked state and Global projection are server-written", () => {
  const block = sliceBetween(
      "exports.submitRankedResult",
      "// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_END",
  );

  assert.ok(block.includes("rankedState"));
  assert.ok(block.includes("globalLeaderboard/"));
  assert.ok(block.includes("serverValidated: true"));
  assert.ok(block.includes("validationVersion"));
});

test("Ranked caller observation is verified against stored match facts", () => {
  const helper = sliceBetween(
      "function lbRankedObservation",
      "function lbRankedUserMirror",
  );

  assert.ok(helper.includes("result !== expectedResult"));
  assert.ok(helper.includes("myScore !== expectedMyScore"));
  assert.ok(helper.includes("opponentScore !== expectedOpponentScore"));
  assert.ok(helper.includes("opponentUid !== expectedOpponent"));
});

test("Ranked Elo settlement requires matching attestations from both players", () => {
  const block = sliceBetween(
      "exports.submitRankedResult",
      "// LINKBALL_16_3C_TRUSTED_RANKED_AUTHORITY_END",
  );

  assert.ok(block.includes("rankedState/attestations/"));
  assert.ok(block.includes("pendingOpponent: true"));
  assert.ok(block.includes("peer.stateSignature !== observation.stateSignature"));
  assert.ok(block.includes("lbRankedStateSignature(finalFacts)"));
  assert.ok(block.includes("pendingOpponent: false"));
});

test("friend/social callables require Google-linked Linkball accounts", () => {
  const block = sliceBetween(
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_START",
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_END",
  );

  const callableNames = [
    "syncMyPublicProfile",
    "searchFriendByNickname",
    "sendFriendRequest",
    "respondFriendRequest",
    "cancelFriendRequest",
    "removeFriend",
    "blockUser",
    "unblockUser",
  ];

  for (const name of callableNames) {
    assert.ok(block.includes("exports." + name), name);
  }

  const googleGuards =
    block.match(/lbRequireGoogleLinked\(request\)/g) || [];
  assert.ok(googleGuards.length >= callableNames.length);
});

test("public social profile is sanitized and server-projected", () => {
  const block = sliceBetween(
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_START",
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_END",
  );

  assert.ok(block.includes("exports.syncPublicProfileProjection"));
  assert.ok(block.includes("lbSocialHasGoogleProvider(uid)"));
  assert.ok(block.includes("\"usernames/\" + normalizedName"));
  assert.ok(block.includes("\"rankedState/profiles/\" + uid"));
  assert.ok(block.includes("\"publicProfiles/\" + uid"));
  assert.ok(!block.includes("photoURL"));
  assert.ok(!block.includes("email:"));
});

test("friend transitions use private canonical pair state and projections", () => {
  const block = sliceBetween(
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_START",
      "// LINKBALL_16_4B_FRIENDS_FOUNDATION_END",
  );

  assert.ok(block.includes("\"socialState/pairs/\" + pairKey"));
  assert.ok(block.includes("friendRequestsIncoming/"));
  assert.ok(block.includes("friendRequestsOutgoing/"));
  assert.ok(block.includes("\"friends/\" +"));
  assert.ok(block.includes("\"blocks/\" +"));
  assert.ok(block.includes("LB_SOCIAL_MAX_FRIENDS"));
  assert.ok(block.includes("LB_SOCIAL_MAX_OUTGOING_REQUESTS"));
});

test("friend match invites are friendship-gated and room-validated", () => {
  const block = sliceBetween(
      "// LINKBALL_16_4D_FRIEND_MATCH_INVITES_START",
      "// LINKBALL_16_4D_FRIEND_MATCH_INVITES_END",
  );

  assert.ok(block.includes("exports.sendFriendMatchInvite"));
  assert.ok(block.includes("exports.acceptFriendMatchInvite"));
  assert.ok(block.includes("exports.declineFriendMatchInvite"));
  assert.ok(block.includes("lbSocialRequireFriends("));
  assert.ok(block.includes("lbSocialValidateInviteRoom("));
  assert.ok(block.includes("LB_SOCIAL_INVITE_TTL_MS"));
  assert.ok(block.includes("LB_SOCIAL_MAX_INCOMING_MATCH_INVITES"));
  assert.ok(block.includes("\"socialState/userInvites/\" + uid"));
});

test("friend match invite validation binds sender to waiting room", () => {
  const block = sliceBetween(
      "async function lbSocialValidateInviteRoom",
      "async function lbSocialLoadInvite",
  );

  assert.ok(block.includes("room.status !== \"waiting\""));
  assert.ok(block.includes("room.hostUid === uid"));
  assert.ok(block.includes("match.status !== \"waiting\""));
  assert.ok(block.includes("match.player1Uid !== uid"));
  assert.ok(block.includes("match.player2Uid != null"));
});

test("friend invites support Loto and Club Manager room adapters", () => {
  const block = sliceBetween(
      "// LINKBALL_16_4D_FRIEND_MATCH_INVITES_START",
      "// LINKBALL_16_4D_FRIEND_MATCH_INVITES_END",
  );

  assert.ok(block.includes("\"loto\""));
  assert.ok(block.includes("\"club_manager\""));
  assert.ok(block.includes("room.matchType !== mode"));
  assert.ok(block.includes("room.mode !== \"clubManager\""));
  assert.ok(block.includes("room.status === \"squad\""));
  assert.ok(block.includes("Object.keys(players).length >= 2"));
});

test("achievement unlocks are server-owned and source-derived", () => {
  const block = sliceBetween(
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_START",
      "// LINKBALL_16_5B_ACHIEVEMENTS_FOUNDATION_END",
  );

  assert.ok(block.includes("exports.syncRankedAchievements"));
  assert.ok(block.includes("exports.syncDailyAchievements"));
  assert.ok(block.includes("exports.syncWeeklyAchievements"));
  assert.ok(block.includes("exports.syncFriendAchievements"));
  assert.ok(block.includes("exports.syncMyAchievements"));
  assert.ok(block.includes("\"achievementState/\" + uid"));
  assert.ok(block.includes("\"achievementProgress/\" + uid"));
  assert.ok(block.includes("\"userAchievements/\" + uid"));
  assert.ok(block.includes("LB_ACHIEVEMENT_CATALOG_VERSION"));
});

test("achievement ranked signals come from trusted ranked profiles", () => {
  const block = sliceBetween(
      "function lbAchievementRankedSignals",
      "exports.syncRankedAchievements",
  );

  assert.ok(block.includes("lbRankedProfile(profile)"));
  assert.ok(block.includes("ranked_played"));
  assert.ok(block.includes("ranked_wins"));
  assert.ok(block.includes("best_win_streak"));
  assert.ok(block.includes("peak_elo"));
  assert.ok(block.includes("ranked_shared_xi_wins"));
  assert.ok(block.includes("ranked_grid_wins"));
  assert.ok(block.includes("ranked_cinko_wins"));
  assert.ok(block.includes("ranked_five_wins"));
});

test("trusted ranked profile preserves streak and per-mode statistics", () => {
  const block = sliceBetween(
      "function lbRankedModeStat",
      "function lbRankedMatchFacts",
  );

  assert.ok(block.includes("currentWinStreak"));
  assert.ok(block.includes("bestWinStreak"));
  assert.ok(block.includes("modeStats"));
  assert.ok(block.includes("shared_xi"));
  assert.ok(block.includes("grid"));
  assert.ok(block.includes("cinko"));
  assert.ok(block.includes("five"));
});

