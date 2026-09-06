"use strict";

// PHASE 15.1 — Realtime Database security source-contract tests.
//
// These tests are emulator-free. They verify that the checked-in production
// rules cannot regress to a public root read/write and that every RTDB path
// currently used by the Linkball client has an explicit policy.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const rulesPath = path.join(__dirname, "..", "..", "database.rules.json");
const doc = JSON.parse(fs.readFileSync(rulesPath, "utf8"));
const rules = doc.rules || {};

const authRule = "auth != null";
const selfRule = "auth != null && auth.uid == $uid";
const googleLinkedRule =
    "auth != null && auth.token.firebase.identities != null && " +
    "auth.token.firebase.identities[\"google.com\"] != null";

test("RTDB root is deny-by-default", () => {
  assert.equal(rules[".read"], false);
  assert.equal(rules[".write"], false);
});

test("daily public/server-owned paths are explicit", () => {
  assert.equal(rules.daily_fixtures[".read"], true);
  assert.equal(rules.daily_fixtures[".write"], false);

  assert.equal(rules.dailyLeaderboard[".read"], authRule);
  assert.equal(rules.dailyLeaderboard[".write"], false);

  assert.equal(rules.dailyScoreSessions[".read"], false);
  assert.equal(rules.dailyScoreSessions[".write"], false);
});

test("user profiles are self-only except authenticated Elo lookup", () => {
  const user = rules.users["$uid"];
  assert.equal(user[".read"], selfRule);
  assert.equal(user[".write"], selfRule);
  assert.equal(user.elo[".read"], authRule);
});

test("all active matchmaking queues require a Google-linked account", () => {
  const queues = [
    "queue",
    "gridQueue",
    "cinkoQueue",
    "fiveQueue",
    "lotoQueue",
  ];
  for (const queue of queues) {
    assert.equal(rules.matchmaking[queue][".read"], googleLinkedRule, queue);
    assert.equal(rules.matchmaking[queue][".write"], googleLinkedRule, queue);
  }
});

test("online records cannot be listed at collection root", () => {
  const collections = [
    ["matches", "$matchId"],
    ["rooms", "$roomCode"],
    ["gridMatches", "$matchId"],
    ["cinkoMatches", "$matchId"],
    ["fiveMatches", "$matchId"],
  ];

  for (const [name] of collections) {
    assert.equal(rules[name][".read"], undefined, name);
    assert.equal(rules[name][".write"], undefined, name);
  }

  assert.equal(rules.rooms["$roomCode"][".read"], googleLinkedRule);
  assert.equal(rules.rooms["$roomCode"][".write"], googleLinkedRule);
});

test("match records are participant-bound and ranked flag is immutable", () => {
  const collections = [
    ["matches", "$matchId"],
    ["gridMatches", "$matchId"],
    ["cinkoMatches", "$matchId"],
    ["fiveMatches", "$matchId"],
  ];

  for (const [name, child] of collections) {
    const readRule = rules[name][child][".read"];
    const writeRule = rules[name][child][".write"];

    assert.ok(readRule.includes(googleLinkedRule), name);
    assert.ok(
        readRule.includes("data.child(\"status\").val() == \"waiting\""),
        name,
    );
    assert.ok(
        readRule.includes("data.child(\"player1Uid\").val() == auth.uid"),
        name,
    );

    assert.ok(writeRule.includes(googleLinkedRule), name);
    assert.ok(
        writeRule.includes("data.child(\"player1Uid\").val() == auth.uid"),
        name,
    );
    assert.ok(
        writeRule.includes("newData.child(\"player2Uid\").val() == auth.uid"),
        name,
    );
    assert.ok(
        writeRule.includes(
            "newData.child(\"ranked\").val() == data.child(\"ranked\").val()",
        ),
        name,
    );
  }
});

test("guest/daily policies stay intentionally separate from Google-only Online", () => {
  assert.equal(rules.dailyLeaderboard[".read"], authRule);
  assert.equal(rules.users["$uid"][".write"], selfRule);
  assert.notEqual(rules.matchmaking.queue[".write"], authRule);
  assert.equal(rules.matchmaking.queue[".write"], googleLinkedRule);
});

test("nickname identity is server-authoritative", () => {
  const user = rules.users["$uid"];
  const usernames = rules.usernames;
  const nickname = usernames["$normalized"];

  assert.equal(usernames[".read"], false);
  assert.equal(nickname[".write"], false);
  assert.ok(nickname[".validate"].includes("^[a-z0-9_]{3,16}$"));

  assert.ok(
      user.displayName[".validate"].includes(
          "newData.val() == data.val()",
      ),
  );
  assert.ok(
      user.displayName[".validate"].includes(
          "^Oyuncu_[A-Za-z0-9]{1,12}$",
      ),
  );
  assert.ok(
      user.normalizedName[".validate"].includes(
          "newData.val() == data.val()",
      ),
  );
  assert.ok(
      user.nicknameNeedsSetup[".validate"].includes(
          "newData.val() == data.val()",
      ),
  );
});


test("trusted ranked state is private and Global projection is server-owned", () => {
  assert.equal(rules.rankedState[".read"], false);
  assert.equal(rules.rankedState[".write"], false);

  assert.equal(rules.globalLeaderboard[".read"], authRule);
  assert.equal(rules.globalLeaderboard[".write"], false);
  assert.ok(rules.globalLeaderboard[".indexOn"].includes("elo"));
});


test("weekly leaderboard is authenticated-read and server-owned", () => {
  assert.equal(rules.leaderboardState[".read"], false);
  assert.equal(rules.leaderboardState[".write"], false);

  assert.equal(rules.weeklyLeaderboard[".read"], authRule);
  assert.equal(rules.weeklyLeaderboard[".write"], false);
  assert.ok(
      rules.weeklyLeaderboard["$weekKey"][".indexOn"].includes("score"),
  );
});


test("friend match invites are owner-readable and server-write-only", () => {
  assert.equal(rules.matchInvites[".read"], undefined);
  assert.equal(rules.matchInvites[".write"], undefined);
  assert.equal(
      rules.matchInvites["$uid"][".read"],
      googleLinkedRule + " && auth.uid == $uid",
  );
  assert.equal(rules.matchInvites["$uid"][".write"], false);
});

test("achievement projections are owner-readable and server-write-only", () => {
  assert.equal(rules.achievementState[".read"], false);
  assert.equal(rules.achievementState[".write"], false);

  for (const root of ["achievementProgress", "userAchievements"]) {
    assert.equal(rules[root][".read"], undefined, root);
    assert.equal(rules[root][".write"], undefined, root);
    assert.equal(
        rules[root]["$uid"][".read"],
        googleLinkedRule + " && auth.uid == $uid",
        root,
    );
    assert.equal(rules[root]["$uid"][".write"], false, root);
  }
});

test("economy state is private and all client projections are server-owned", () => {
  assert.equal(rules.economyState[".read"], false);
  assert.equal(rules.economyState[".write"], false);

  for (const root of [
    "walletBalances",
    "economyLedger",
    "rewardClaims",
    "inventory",
  ]) {
    assert.equal(rules[root][".read"], undefined, root);
    assert.equal(rules[root][".write"], undefined, root);
    assert.equal(
        rules[root]["$uid"][".read"],
        googleLinkedRule + " && auth.uid == $uid",
        root,
    );
    assert.equal(rules[root]["$uid"][".write"], false, root);
  }

  assert.ok(
      rules.economyLedger["$uid"][".indexOn"].includes("createdAt"),
  );
});

test("friends/social projections are private, server-owned and non-listable", () => {
  assert.equal(rules.publicProfiles[".read"], undefined);
  assert.equal(rules.publicProfiles[".write"], undefined);
  const publicProfileRead = String(
      rules.publicProfiles["$uid"][".read"],
  );
  assert.ok(publicProfileRead.includes(googleLinkedRule));
  assert.ok(publicProfileRead.includes("auth.uid == $uid"));
  assert.ok(publicProfileRead.includes("root.child(\"blocks\")"));
  assert.ok(publicProfileRead.includes("child(auth.uid)"));
  assert.equal(rules.publicProfiles["$uid"][".write"], false);

  const privateRoots = [
    "friendRequestsIncoming",
    "friendRequestsOutgoing",
    "friends",
    "blocks",
  ];

  for (const root of privateRoots) {
    assert.equal(rules[root][".read"], undefined, root);
    assert.equal(rules[root][".write"], undefined, root);
    assert.equal(
        rules[root]["$uid"][".read"],
        googleLinkedRule + " && auth.uid == $uid",
        root,
    );
    assert.equal(rules[root]["$uid"][".write"], false, root);
  }

  assert.equal(rules.socialState[".read"], false);
  assert.equal(rules.socialState[".write"], false);
});

test("known RTDB top-level client paths all have explicit policy", () => {
  const expected = [
    "daily_fixtures",
    "dailyLeaderboard",
    "dailyScoreSessions",
    "rankedState",
    "globalLeaderboard",
    "leaderboardState",
    "weeklyLeaderboard",
    "users",
    "usernames",
    "publicProfiles",
    "friendRequestsIncoming",
    "friendRequestsOutgoing",
    "friends",
    "blocks",
    "socialState",
    "matchInvites",
    "achievementState",
    "achievementProgress",
    "userAchievements",
    "economyState",
    "walletBalances",
    "economyLedger",
    "rewardClaims",
    "inventory",
    "matchmaking",
    "matches",
    "rooms",
    "gridMatches",
    "cinkoMatches",
    "fiveMatches",
  ];
  for (const key of expected) {
    assert.ok(Object.prototype.hasOwnProperty.call(rules, key), key);
  }
});
