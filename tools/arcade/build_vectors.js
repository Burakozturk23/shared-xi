"use strict";
const fs = require("node:fs");
const E = require("../../functions/arcade_engine");
const fields = ["activeMs", "score", "correct", "wrong", "lives", "rounds", "streak", "bestStreak", "passes", "hints",
  "freeUsed", "adCredits", "finished", "won", "penaltyMs", "roundAt", "roundIds", "hintedIds", "found",
  "totalRemainingMs", "roundRemainingMs", "revision", "paused"];
const scenarios = [];
for (const style of ["speed", "survival"]) {
  const r = E.create(E.catalog, {mode: "burst", style, pairType: "clubClub", requestId: style.padEnd(32, "0")}, 100000);
  r.phase = "active"; r.paused = false; r.adCredits = 2; r.adGranted = 2;
  const scenario = {style, initial: E.publicRun(E.catalog, structuredClone(r), 100000), steps: []};
  function step(action, extra = {}, elapsedMs = 250) {
    const event = {mode: "burst", sessionId: r.id, revision: r.revision, action, questionId: r.question.id, elapsedMs, ...extra};
    const time = r.lastAt + elapsedMs; E.tick(E.catalog, r, time);
    if (!r.finished) E.act(E.catalog, r, event, time); r.revision++;
    const view = E.publicRun(E.catalog, structuredClone(r), time);
    scenario.steps.push({event, expected: Object.fromEntries(fields.filter((k) => view[k] != null).map((k) => [k, view[k]])), questionId: view.question.id});
  }
  step("answer", {query: "Definitely unknown xyz"});
  const first = r.question.answers[0]; step("answer", {entityId: first}); step("answer", {entityId: first});
  const wrong = Object.keys(E.catalog.players).find((id) => !r.question.answers.includes(id));
  step("answer", {entityId: wrong});
  step("pause"); step("resume", {}, 0);
  if (style === "survival") {step("hint"); step("hint"); step("hint");}
  step("pass"); step("pass");
  const count = style === "survival" ? 36 : 12;
  for (let i = 0; i < count; i++) step("answer", {entityId: r.question.answers.find((id) => !r.found.includes(id))});
  if (style === "speed") {step("tick", {}, 31000); step("tick", {}, 120000);}
  scenarios.push(scenario);
}
const path = "test/fixtures/burst_offline_vectors.json";
const content = JSON.stringify({version: E.catalog.version, scenarios}, null, 2) + "\n";
if (process.argv.includes("--check")) {
  if (fs.readFileSync(path, "utf8") !== content) throw new Error("Burst server/client vectors drifted");
} else fs.writeFileSync(path, content);
