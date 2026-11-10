"use strict";
// Friend requests end to end. The harness, like the RTDB SDK, first runs a
// transaction with a cold (null) value: handlers must not abort on it.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");

const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
// Two Google-linked players with a claimed nickname (what the public profile needs).
const boot = () => harness({
  users: {
    alice: {displayName: "Alice", normalizedName: "alice", createdAt: 1},
    bob: {displayName: "Bob", normalizedName: "bob", createdAt: 1},
  },
  usernames: {alice: "alice", bob: "bob"},
});
const relation = (h, a, b) => {
  const pairs = h.read("socialState/pairs") || {};
  return Object.values(pairs).find((p) => [p.uidA, p.uidB].sort().join() === [a, b].sort().join()) || null;
};

test("a friend request can be accepted", async () => {
  const h = boot();
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  assert.equal(relation(h, "alice", "bob").status, "pending");
  const r = await h.call("respondFriendRequest", {senderUid: "alice", accept: true}, auth("bob"));
  assert.equal(r.ok, true); assert.equal(r.relationship, "friends");
  assert.equal(relation(h, "alice", "bob").status, "friends");
});

test("a friend request can be declined or cancelled", async () => {
  const h = boot();
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  const r = await h.call("respondFriendRequest", {senderUid: "alice", accept: false}, auth("bob"));
  assert.equal(r.ok, true); assert.equal(r.relationship, "none");
  assert.equal(relation(h, "alice", "bob"), null);
  h.setTime(h.now + 120000); // past the repeat-action cooldown
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  await h.call("cancelFriendRequest", {targetUid: "bob"}, auth("alice"));
  assert.equal(relation(h, "alice", "bob"), null);
});

test("a friend can be removed; a block can be lifted", async () => {
  const h = boot();
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  await h.call("respondFriendRequest", {senderUid: "alice", accept: true}, auth("bob"));
  await h.call("removeFriend", {friendUid: "bob"}, auth("alice"));
  assert.notEqual(relation(h, "alice", "bob")?.status, "friends");
  await h.call("blockUser", {targetUid: "bob"}, auth("alice"));
  assert.equal(relation(h, "alice", "bob").blocks.alice, true);
  await h.call("unblockUser", {targetUid: "bob"}, auth("alice"));
  assert.notEqual(relation(h, "alice", "bob")?.blocks?.alice, true);
});

test("answering a request that is gone still fails clearly", async () => {
  const h = boot();
  await assert.rejects(h.call("respondFriendRequest", {senderUid: "alice", accept: true}, auth("bob")),
      {code: "failed-precondition"});
});

test("friends can invite each other to an open friend room, accept and decline", async () => {
  const E = require("../pvp_engine");
  const h = harness({
    users: {
      alice: {displayName: "Alice", normalizedName: "alice", createdAt: 1},
      bob: {displayName: "Bob", normalizedName: "bob", createdAt: 1},
    },
    usernames: {alice: "alice", bob: "bob"},
    runtimeConfig: {pvp: {friendEnabled: true}},
  });
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  await h.call("respondFriendRequest", {senderUid: "alice", accept: true}, auth("bob"));
  const room = (await h.call("enterPvp", {mode: "club_club", schemaVersion: 1, ruleVersion: E.RULE,
    dataRevision: E.catalog.version, action: "create", playKind: "friend",
    actionId: "a".repeat(32)}, auth("alice"))).room;
  const sent = await h.call("sendFriendMatchInvite", {targetUid: "bob", mode: "club_club", roomCode: room.id},
      auth("alice"));
  assert.equal(sent.ok, true);
  assert.equal(h.read(`matchInvites/bob/${sent.inviteId}`).roomCode, room.id);
  const accepted = await h.call("acceptFriendMatchInvite", {inviteId: sent.inviteId}, auth("bob"));
  assert.equal(accepted.invite.roomCode, room.id); assert.equal(accepted.invite.mode, "club_club");
  assert.equal(h.read(`matchInvites/bob/${sent.inviteId}`), null);
  h.setTime(h.now + 120000); // past the invite cooldown for the pair
  const again = await h.call("sendFriendMatchInvite", {targetUid: "bob", mode: "club_club", roomCode: room.id},
      auth("alice"));
  await h.call("declineFriendMatchInvite", {inviteId: again.inviteId}, auth("bob"));
  assert.equal(h.read(`matchInvites/bob/${again.inviteId}`), null);
});
