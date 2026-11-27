"use strict";
// Ranked fallback bot: a ranked search that finds nobody within 20 s gets a bot that
// plays every online mode by the engine's own rules, as a beatable opponent.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const E = require("../pvp_engine");
const BOT = require("../pvp_bot");
const c = E.catalog;

function botRoom(mode, seed) {
  const r = E.hydrate({id: "B0T" + seed.slice(0, 5).toUpperCase().padEnd(5, "0"), mode, host: "a", guest: null,
    playKind: "ranked", seed, dataRevision: c.version, names: {a: "Ayşe"}, status: "waiting", createdAt: 0,
    revision: 0});
  const uid = BOT.join(r, BOT.BOT_AFTER_MS);
  r.ready.a = true; E.start(r, c, BOT.BOT_AFTER_MS);
  return {r, uid};
}
// The person only polls (keeps presence); the bot plays on every poll.
function play(r, uid) {
  let moves = 0;
  for (let t = BOT.BOT_AFTER_MS; t < r.endsAt + 120000 && !E.terminal(r); t += 1000) {
    r.presence.a = t; E.advance(r, t);
    if (BOT.step(c, r, t)) moves++;
  }
  return moves;
}

for (const mode of E.MODES) {
  test(`bot plays ${mode} to the end by the rules`, () => {
    for (const seed of ["s1", "s2"]) {
      const {r, uid} = botRoom(mode, mode + seed);
      assert.equal(r.names[uid], "Linkball Botu"); assert.ok(BOT.isBot(uid));
      const moves = play(r, uid);
      assert.ok(E.terminal(r), mode + " ends");
      assert.notEqual(r.status, "forfeit", mode + ": the bot is never absent");
      assert.ok(moves > 0, mode + ": the bot moves");
      assert.equal(E.view(c, r, "a", r.finishedAt).bot.name, "Linkball Botu");
    }
  });
}

test("the bot is beatable: about six in ten answers right, never all", () => {
  let right = 0; let total = 0;
  for (let i = 0; i < 12; i++) {
    const {r, uid} = botRoom("random_five", "acc" + i); play(r, uid);
    for (const a of E.list(r.answers)) {
      if (!a?.[uid]) continue;
      total++; if (a[uid].points > 0) right++;
    }
  }
  assert.ok(total >= 30 && right / total > 0.4 && right / total < 0.95, `${right}/${total}`);
});

test("a replayed poll makes the same bot move", () => {
  const a = botRoom("grid_classic", "same").r; const b = botRoom("grid_classic", "same").r;
  for (let t = BOT.BOT_AFTER_MS; t < a.startsAt + 60000; t += 1000) {
    for (const r of [a, b]) {
      r.presence.a = t; E.advance(r, t); BOT.step(c, r, t);
    }
  }
  assert.deepEqual(a.owners, b.owners); assert.deepEqual(a.scores, b.scores);
});
