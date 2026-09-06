"use strict";

// STEP 08B.2.1 - source-contract checks for account deletion.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
    path.join(__dirname, "..", "index.js"),
    "utf8",
);

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

test("deleteMyAccount requires Firebase authentication", () => {
  const block = deletionBlock();

  assert.ok(block.includes("exports.deleteMyAccount"));
  assert.ok(
      block.includes("if (!request.auth || !request.auth.uid)"),
  );
});

test("deleteMyAccount removes direct Linkball account data", () => {
  const block = deletionBlock();

  assert.ok(block.includes("updates[\"users/\" + uid] = null"));
  assert.ok(
      block.includes(
          "updates[\"dailyScoreSessions/\" + uid] = null",
      ),
  );
  assert.ok(
      block.includes(
          "\"dailyLeaderboard/\" + dateKey + \"/\" + uid",
      ),
  );
  assert.ok(block.includes("LB_ACCOUNT_QUEUE_PATHS"));
});

test("deleteMyAccount releases the owned unique nickname", () => {
  const block = deletionBlock();

  assert.ok(block.includes("profile.normalizedName"));
  assert.ok(block.includes("\"usernames/\" + normalizedName"));
  assert.ok(block.includes("nicknameSnap.val() === uid"));
});


test("deleteMyAccount removes trusted weekly leaderboard rows", () => {
  const block = deletionBlock();

  assert.ok(
      block.includes("leaderboardState/weeklyUserIndex/"),
  );
  assert.ok(block.includes("weeklyLeaderboard/"));
  assert.ok(block.includes("leaderboardEntriesRemoved += 1"));
});

test("deleteMyAccount removes Global ranking and trusted player profile", () => {
  const block = deletionBlock();

  assert.ok(block.includes("\"globalLeaderboard/\" + uid"));
  assert.ok(block.includes("\"rankedState/profiles/\" + uid"));
  assert.ok(block.includes("rankedState/settlements"));
  assert.ok(block.includes("settlement.player1Uid = null"));
  assert.ok(block.includes("settlement.player2Uid = null"));
});


test("deleteMyAccount removes private ranked attestations", () => {
  const block = deletionBlock();

  assert.ok(block.includes("rankedState/attestations"));
  assert.ok(
      block.includes(
          "\"rankedState/attestations/\" + mode + \"/\" + matchId + \"/\" + uid",
      ),
  );
});


test("deleteMyAccount removes achievement state and projections", () => {
  const block = deletionBlock();

  assert.ok(block.includes("\"achievementState/\" + uid"));
  assert.ok(block.includes("\"achievementProgress/\" + uid"));
  assert.ok(block.includes("\"userAchievements/\" + uid"));
});

test("deleteMyAccount removes canonical economy and projections", () => {
  const block = deletionBlock();

  assert.ok(block.includes("\"economyState/\" + uid"));
  assert.ok(block.includes("\"walletBalances/\" + uid"));
  assert.ok(block.includes("\"economyLedger/\" + uid"));
  assert.ok(block.includes("\"rewardClaims/\" + uid"));
  assert.ok(block.includes("\"inventory/\" + uid"));
});

test("deleteMyAccount removes incoming and sent friend match invites", () => {
  const block = deletionBlock();

  assert.ok(block.includes("\"matchInvites/\" + uid"));
  assert.ok(block.includes("\"socialState/userInvites/\" + uid"));
  assert.ok(
      block.includes(
          "\"matchInvites/\" + targetUid + \"/\" + inviteId",
      ),
  );
});

test("deleteMyAccount removes all social projections and canonical pair state", () => {
  const block = deletionBlock();

  assert.ok(block.includes("\"publicProfiles/\" + uid"));
  assert.ok(block.includes("\"friendRequestsIncoming/\" + uid"));
  assert.ok(block.includes("\"friendRequestsOutgoing/\" + uid"));
  assert.ok(block.includes("\"friends/\" + uid"));
  assert.ok(block.includes("\"blocks/\" + uid"));
  assert.ok(block.includes("\"socialState/userPairs/\" + uid"));
  assert.ok(block.includes("\"socialState/pairs/\" + pairKey"));
  assert.ok(
      block.includes(
          "\"friendRequestsIncoming/\" + otherUid + \"/\" + uid",
      ),
  );
  assert.ok(block.includes("\"friends/\" + otherUid + \"/\" + uid"));
});

test("deleteMyAccount de-identifies shared match records", () => {
  const block = deletionBlock();

  assert.ok(block.includes("LB_ACCOUNT_SHARED_COLLECTIONS"));
  assert.ok(block.includes("lbAccountScrubUid"));
  assert.ok(block.includes("\"Silinmiş oyuncu\""));
  assert.ok(block.includes("\"/opponentName\""));
});

test("deleteMyAccount deletes the Firebase Auth user", () => {
  const block = deletionBlock();

  assert.ok(block.includes("admin.auth().deleteUser(uid)"));
  assert.ok(block.includes("auth/user-not-found"));
});
