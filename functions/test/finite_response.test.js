"use strict";
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {finiteResponse} = require("../finite_response");

test("live-game replies: NaN and Infinity become null, the rest is untouched and logged once", () => {
  const ok = {room: {scores: {a: 2}, rounds: [{answers: {a: {second: 3}}}]}};
  assert.equal(finiteResponse(ok, "t"), ok);
  const logged = []; const error = console.error; console.error = (...x) => logged.push(x);
  try {
    const out = finiteResponse({room: {rounds: [{answers: {a: {second: NaN, name: "X"}}}], end: Infinity}}, "t");
    assert.deepEqual(out, {room: {rounds: [{answers: {a: {second: null, name: "X"}}}], end: null}});
  } finally {
    console.error = error;
  }
  assert.equal(logged.length, 1);
  assert.deepEqual(logged[0][1], [".room.rounds.0.answers.a.second", ".room.end"]);
});
