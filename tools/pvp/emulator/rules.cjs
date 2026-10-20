"use strict";
const fs = require("node:fs");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {ref, get, set, update} = require("firebase/database");
(async () => {
  const env = await initializeTestEnvironment({projectId: "demo-pvp", database: {host: "127.0.0.1", port: 9009,
    rules: fs.readFileSync("../../../database.rules.json", "utf8")}});
  try {
    await env.withSecurityRulesDisabled(async (context) => {
      await set(ref(context.database(), "pvpV1/club_club/rooms/ABCD1234"),
          {host: "alice", guest: "bob", scores: {alice: 0, bob: 0}, status: "playing"});
      await set(ref(context.database(), "pvpCatalogs/private"), {answers: ["secret"]});
    });
    let assertions = 0;
    for (const uid of [null, "anonymous", "alice", "bob", "mallory"]) {
      const context = uid == null ? env.unauthenticatedContext() : env.authenticatedContext(uid,
          uid === "anonymous" ? {firebase: {sign_in_provider: "anonymous"}} :
            {firebase: {sign_in_provider: "google.com", identities: {"google.com": [uid]}}});
      const db = context.database();
      for (const path of ["pvpV1", "pvpV1/club_club/rooms/ABCD1234", "pvpCatalogs/private", "rankedState"]) {
        await assertFails(get(ref(db, path))); assertions++;
        await assertFails(set(ref(db, path), {scores: {alice: 999}, winnerUid: uid, status: "finished"})); assertions++;
      }
      for (const path of ["matches/old", "rooms/old", "gridMatches/old", "cinkoMatches/old", "fiveMatches/old",
        "matchmaking/queue/alice", "economyLedger/alice/forged", "walletBalances/alice", "users/alice/elo"]) {
        await assertFails(set(ref(db, path), 999)); assertions++;
      }
      await assertFails(update(ref(db), {"pvpV1/club_club/rooms/ABCD1234/scores/alice": 999,
        "pvpV1/club_club/rooms/ABCD1234/winnerUid": uid || "alice"})); assertions++;
      await assertSucceeds(get(ref(db, "daily_fixtures"))); assertions++;
    }
    const alice = env.authenticatedContext("alice", {firebase: {
      sign_in_provider: "google.com", identities: {"google.com": ["alice"]}}}).database();
    await assertSucceeds(set(ref(alice, "users/alice"), {
      displayName: "Oyuncu_alice", elo: 1000, wins: 0, losses: 0, draws: 0})); assertions++;
    await assertSucceeds(update(ref(alice, "users/alice"), {accountType: "google"})); assertions++;
    await assertFails(set(ref(alice, "users/alice/elo"), null)); assertions++;
    await assertFails(update(ref(alice, "users/alice"), {elo: 1500, wins: 20})); assertions++;
    await assertFails(set(ref(alice, "users/alice"), null)); assertions++;
    console.log(`PASS: ${assertions} actual RTDB emulator permission assertions.`);
  } finally {await env.cleanup();}
})().catch((error) => {console.error(error); process.exitCode = 1;});
