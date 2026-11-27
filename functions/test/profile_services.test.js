"use strict";
// Profile screens end to end: safety reports, community requests and account
// deletion (what it must leave behind for the other player).
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const E = require("../pvp_engine");

const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const boot = () => harness({
  users: {
    alice: {displayName: "Alice", normalizedName: "alice", createdAt: 1},
    bob: {displayName: "Bob", normalizedName: "bob", createdAt: 1},
  },
  usernames: {alice: "alice", bob: "bob"},
  runtimeConfig: {pvp: {friendEnabled: true}},
}, {omitEmptyObjects: true}); // RTDB keeps no empty nodes

test("a player can be reported and the report shows in the reporter's list", async () => {
  const h = boot();
  const r = await h.call("reportPlayer", {targetUid: "bob", category: "cheating", sourceContext: "profile",
    description: "Hileli görünüyor"}, auth("alice"));
  assert.equal(r.ok, true); assert.equal(r.report.category, "cheating"); assert.equal(r.report.status, "open");
  const list = await h.call("getMyPlayerReports", {}, auth("alice"));
  assert.equal(list.reports.length, 1); assert.equal(list.reports[0].reportId, r.report.reportId);
  // The same target again within the cooldown is refused; reporting oneself never works.
  await assert.rejects(h.call("reportPlayer", {targetUid: "bob", category: "spam", sourceContext: "profile"},
      auth("alice")), {code: "resource-exhausted"});
  await assert.rejects(h.call("reportPlayer", {targetUid: "alice", category: "spam", sourceContext: "profile"},
      auth("alice")), {code: "invalid-argument"});
});

test("a community request is stored and listed with its full message", async () => {
  const h = boot();
  const sent = await h.call("submitCommunityRequest", {category: "bug_report", subject: "Grid hatası",
    message: "Grid ekranında hücre seçilmiyor."}, auth("alice"));
  assert.equal(sent.ok, true); assert.equal(sent.submission.status, "open");
  const mine = await h.call("getMyCommunityRequests", {}, auth("alice"));
  assert.equal(mine.submissions.length, 1);
  assert.equal(mine.submissions[0].message, "Grid ekranında hücre seçilmiyor.");
  // Length is counted as the app counts it: an emoji is one character.
  const emoji = "⚽".repeat(1000) + "🏆".repeat(1000);
  h.setTime(h.now + 60000);
  const long = await h.call("submitCommunityRequest", {category: "feedback", subject: "Emoji 🏆🏆",
    message: emoji}, auth("alice"));
  assert.equal(long.ok, true);
});

test("deleting an account clears its friendships and online rooms for the other player", async () => {
  const h = boot();
  await h.call("sendFriendRequest", {targetUid: "bob"}, auth("alice"));
  await h.call("respondFriendRequest", {senderUid: "alice", accept: true}, auth("bob"));
  const room = (await h.call("enterPvp", {mode: "club_club", schemaVersion: 1, ruleVersion: E.RULE,
    dataRevision: E.catalog.version, action: "create", playKind: "friend", actionId: "b".repeat(32)},
  auth("alice"))).room;
  assert.ok(h.read(`pvpV1/club_club/rooms/${room.id}`));
  await h.call("deleteMyAccount", {}, auth("alice"));
  // Gone: missing, or an empty parent the real database would not keep.
  const gone = (path) => {
    const v = h.read(path);
    assert.ok(v == null || typeof v === "object" && !Object.keys(v).length, path);
  };
  gone("users/alice"); gone("usernames/alice"); gone("friends/bob/alice"); gone("socialState/pairs");
  // Rooms, the active pointer and requests that carry the deleted player's name are gone.
  gone(`pvpV1/club_club/rooms/${room.id}`); gone("pvpV1/club_club/active/alice");
  const requests = h.read("pvpV1/club_club/requests") || {};
  assert.ok(Object.keys(requests).every((k) => !k.startsWith("alice__")));
});

test("Pro status for a player who never bought: inactive, no Play call, sales off until launch", async () => {
  const h = boot();
  const s = await h.call("getMyPremiumStatus", {}, auth("alice"));
  assert.equal(s.ok, true); assert.equal(s.entitlement.active, false); assert.equal(s.entitlement.plan, "none");
  assert.equal(s.salesEnabled, false);
  const crate = await h.call("getProCrate", {}, auth("alice"));
  assert.equal(crate.pro, false); assert.equal(crate.canOpen, false);
});
