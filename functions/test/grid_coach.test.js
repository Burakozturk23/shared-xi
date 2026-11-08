"use strict";
// Teknik direktör criterion (docs/superpowers/specs/2026-11-08-grid-teknik-direktor-design.md).
const {test} = require("node:test");
const assert = require("node:assert/strict");
const E = require("../pvp_engine");
const {harness} = require("./support/economy_harness");
const c = E.catalog;
const isCoach = (k) => k.startsWith("coach:");
const base = (mode) => ({mode, schemaVersion: 1, ruleVersion: E.RULE, dataRevision: c.version});
let serial = 0;
const id = () => (++serial).toString(16).padStart(32, "0");
const auth = (uid) => ({uid, token: {firebase: {identities: {"google.com": [uid]}}}});
const boot = () => harness({runtimeConfig: {pvp: {friendEnabled: true, rankedEnabled: true,
  rewardsEnabled: true, eloEnabled: true}}}, {omitEmptyObjects: true});
const enter = async (h, uid, mode, action, extra = {}) => (await h.call("enterPvp", {...base(mode),
  action, actionId: id(), playKind: "friend", ...extra}, auth(uid))).room;
const act = async (h, uid, r, action = "poll", extra = {}) => (await h.call("actPvp", {...base(r.mode),
  roomId: r.id, action, revision: r.revision, ...(action === "poll" ? {} : {actionId: id()}), ...extra},
auth(uid))).room;

test("coach criterion matches its members only", () => {
  const k = "coach:coach_269"; // Şenol Güneş
  const members = Object.values(c.players).filter((p) => p.coaches.includes("coach_269"));
  const other = Object.values(c.players).find((p) => !p.coaches.includes("coach_269"));
  assert(members.length >= 15);
  assert(members.every((p) => E.matches(c, p, k)));
  assert.equal(E.matches(c, other, k), false);
  // Catalogs from before coaches (no p.coaches) still answer false instead of throwing.
  const old = {criteria: {[k]: c.criteria[k]}};
  assert.equal(E.matches(old, {clubs: [], countryKeys: [], leagues: []}, k), false);
});

test("online grid_classic board with a coach validates a correct coach-cell answer", async () => {
  let seed = 0;
  while (!(() => {
    const g = E.puzzle(c, "grid_classic", "s" + seed); return [...g.rows, ...g.cols].some(isCoach);
  })()) seed++;
  const h = boot();
  let r = await enter(h, "alice", "grid_classic", "create");
  h.seed(`pvpV1/grid_classic/rooms/${r.id}/seed`, "s" + seed);
  r = await enter(h, "bob", "grid_classic", "join", {code: r.id});
  r = await act(h, "alice", r, "ready"); r = await act(h, "bob", r, "ready");
  h.setTime(new Date(r.startsAt + 100).toISOString());
  await act(h, "alice", r); r = await act(h, "bob", r);
  const g = h.read(`pvpV1/grid_classic/rooms/${r.id}`).puzzle;
  const cell = [...Array(9).keys()].find((i) => isCoach(g.rows[Math.floor(i / 3)]) || isCoach(g.cols[i % 3]));
  r = await act(h, r.turnUid, r, "answer", {targetId: cell, playerId: g.witness[cell]});
  assert(r.owners[cell], "coach cell owned after a correct answer");
});

test("club_club and club_country never draw coach pairs; friend options never offer a coach", () => {
  for (let s = 0; s < 150; s++) {
    for (const mode of ["club_club", "club_country"]) {
      assert(!E.puzzle(c, mode, "p" + s).rounds[0].criteria.some(isCoach));
    }
  }
  assert(!E.pairOptions(c, "club_club", "left", null).some(isCoach));
});

test("grid_random rounds carry at most 2 coach pairs and some boards have one", () => {
  const counts = [];
  for (let s = 0; s < 200; s++) {
    const q = E.puzzle(c, "grid_random", "r" + s);
    assert.equal(q.rounds.length, 5);
    counts.push(q.rounds.filter((p) => p.criteria.some(isCoach)).length);
  }
  assert(Math.max(...counts) <= 2);
  const share = counts.filter(Boolean).length / counts.length;
  assert(share > 0.6 && share < 0.9, String(share));
  // Catalogs without coach pairs still give five rounds.
  const old = {...c, pairs: c.pairs.filter((p) => !p.criteria.some(isCoach))};
  assert.equal(E.puzzle(old, "grid_random", "r1").rounds.length, 5);
});

test("grid_reverse accepted answers list a shared coach", () => {
  const g = c.grids.find((x) => x.rows.some(isCoach));
  const r = g.rows.findIndex(isCoach);
  const ids = g.witness.filter((_, i) => Math.floor(i / 3) === r);
  assert(E.acceptedFor(c, ids).includes(c.criteria[g.rows[r]].label));
});
