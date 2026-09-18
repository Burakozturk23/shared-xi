"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const engine = require("../squad_challenge");
const {wallet, solve} = require("./squad_fixture");
const now = Date.parse("2026-09-17T12:00:00Z");
const daily = engine.missions(engine.dayKey(now));
const ids = solve(daily[0]);
const request = (n, day = daily[0].day) => day + "__" + n.toString(16).padStart(32, "0");
const start = (state, n, premium = false, m = daily[0], time = now, payment = "free") =>
  engine.apply(state, "start", {missionId: m.id, requestId: request(n, m.day), payment}, time, premium);
const finish = (state, run, players = ids, time = now) =>
  engine.apply(state, "finish", {runId: run.id, playerIds: players}, time, false);
const abandon = (state, run) => engine.apply(state, "abandon", {runId: run.id}, now, false);

test("Canonical catalogs match byte-for-byte and every daily theme has a winning hard XI", () => {
  assert.equal(fs.readFileSync(path.join(__dirname, "../data/squad_challenge_catalog.json"), "utf8"),
      fs.readFileSync(path.join(__dirname, "../../assets/data/squad_challenge_catalog.json"), "utf8"));
  for (const theme of engine.catalog.themes.filter((t) => t.dailyEligible)) {
    const goal = {themeId: theme.id, formationId: "4-3-3", budget: 105, links: 8, countries: 5};
    const selected = solve(goal);
    const score = engine.evaluate(theme.id, goal.formationId, selected, goal.budget);
    assert.ok(score.links >= 8 && score.countries >= 5, theme.id);
  }
});

test("Three distinct daily missions rotate; reset is at midnight in Türkiye", () => {
  for (let i = 0; i < 62; i++) {
    const ms = engine.missions(engine.dayKey(now + i * 86400000));
    assert.equal(new Set(ms.map((m) => m.themeId)).size, 3);
    assert.equal(ms.reduce((n, m) => n + m.reward, 0), 90);
  }
  assert.equal(engine.dayKey(Date.parse("2026-09-17T20:59:59Z")), "2026-09-17");
  assert.equal(engine.dayKey(Date.parse("2026-09-17T21:00:00Z")), "2026-09-18");
  assert.throws(() => engine.missions("2026-99-88"), /geçersiz/);
});

test("Flutter scoring fixtures stay in agreement with the canonical server scorer", () => {
  const cases = JSON.parse(fs.readFileSync(
      path.join(__dirname, "../../test/support/squad_scoring_cases.json"), "utf8"));
  assert.equal(cases.length, 31);
  for (const row of cases) {
    const m = row.mission;
    assert.deepEqual(engine.evaluate(m.themeId, m.formationId, row.ids, m.budget), row.score);
  }
});

test("Free attempts exhaust at three; paid entry is explicit, atomic in state and capped", () => {
  const state = wallet(60);
  for (let i = 1; i <= 3; i++) abandon(state, start(state, i).run);
  assert.equal(state.balances.coins, 60);
  assert.throws(() => start(state, 4), /ücretsiz/);
  for (let i = 4; i <= 6; i++) {
    const run = start(state, i, false, daily[0], now, "coins").run;
    assert.equal(run.payment, "coins");
    abandon(state, run);
  }
  assert.equal(state.balances.coins, 0);
  assert.equal(state.lifetimeSpent, 60);
  assert.equal(Object.keys(state.purchases).length, 3);
  assert.throws(() => start(state, 7, false, daily[0], now, "coins"), /ek denemeni/);
});

test("Repeated starts resume one active run and never double-charge", () => {
  const state = wallet(20);
  for (let i = 1; i <= 3; i++) abandon(state, start(state, i).run);
  const first = start(state, 4, false, daily[0], now, "coins").run;
  assert.equal(start(state, 4, false, daily[0], now, "coins").run.id, first.id);
  assert.equal(start(state, 5, false, daily[0], now, "coins").run.id, first.id);
  assert.equal(state.balances.coins, 0);
  assert.equal(state.squadChallenge.paidUsed, 1);
  assert.throws(() => start(state, 6, false, daily[1], now, "coins"), /açık görevine/);
});

test("Win reward is server-computed once; retry returns the same result", () => {
  const state = wallet(0);
  const run = start(state, 1).run;
  const response = finish(state, run);
  assert.equal(response.run.result.reward, 20);
  assert.equal(state.balances.coins, 20);
  assert.equal(finish(state, run).run.result.reward, 20);
  assert.equal(state.balances.coins, 20);
  assert.equal(state.squadChallenge.completedTotal, 1);
  assert.equal(Object.keys(state.claims).length, 1);
  assert.throws(() => start(state, 2), /zaten aldın/);
  assert.equal(state.squadChallenge.freeUsed, 1);
  assert.throws(() => finish(state, run, [...ids].reverse()), /başka bir kadro/);
});

test("Forged player ids, duplicates, bad positions and over-budget XIs earn nothing", () => {
  const state = wallet();
  const run = start(state, 1).run;
  for (const players of [Array(11).fill(ids[0]), ids.slice(1), [-999, ...ids.slice(1)], [...ids].reverse()]) {
    assert.throws(() => finish(state, run, players));
    assert.equal(state.balances.coins, 200);
    assert.equal(state.squadChallenge.active.id, run.id);
  }
  assert.throws(() => engine.evaluate(daily[0].themeId, "4-3-3", ids, 1), /kredisi/);
  const other = wallet();
  assert.throws(() => finish(other, run), /bulunamadı/);
});

test("Premium gives attempts, not extra rewards or weaker goals; expiry restores limits", () => {
  const state = wallet(0);
  for (let i = 1; i <= 12; i++) abandon(state, start(state, i, true).run);
  assert.equal(state.squadChallenge.freeUsed, 0);
  assert.equal(state.balances.coins, 0);
  assert.equal(engine.status(state, now, true).dailyMaxCoins, 90);
  for (let i = 13; i <= 15; i++) abandon(state, start(state, i, false).run);
  assert.throws(() => start(state, 16), /ücretsiz/);
  assert.throws(() => start(state, 17, false, daily[0], now, "coins"), /20 coin/);
});

test("Rollover restores free entries and preserves an unfinished paid-for draft", () => {
  const state = wallet();
  const run = start(state, 1).run;
  const tomorrow = now + 86400000;
  const hub = engine.apply(state, "status", {}, tomorrow, false).hub;
  assert.equal(hub.freeRemaining, 3);
  assert.equal(hub.active.id, run.id);
  finish(state, run, ids, tomorrow);
  assert.equal(state.balances.coins, 220);
  assert.equal(state.squadChallenge.freeUsed, 0);
  assert.throws(() => start(state, 2, false, daily[0], tomorrow), /yenilendi/);
  const mission = engine.missions(engine.dayKey(tomorrow))[0];
  const next = start(state, 3, false, mission, tomorrow).run;
  assert.equal(next.payment, "free");
});

test("Abandon is idempotent and does not refund or allow a late reward", () => {
  const state = wallet();
  const run = start(state, 1).run;
  abandon(state, run);
  abandon(state, run);
  assert.equal(state.squadChallenge.freeUsed, 1);
  assert.throws(() => finish(state, run), /kapatılmış/);
  assert.equal(state.squadChallenge.active, null);
});
