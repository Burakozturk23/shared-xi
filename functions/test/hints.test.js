"use strict";
// İpucu sistemi v2: kernel (hints.js). Spec: docs/superpowers/specs/2026-11-07-ipucu-sistemi-design.md
const test = require("node:test");
const assert = require("node:assert/strict");
const H = require("../hints");
const P = require("../price_config");

test("hint types: nine sellable types, strong ones, Joker unsold", () => {
  const sellable = Object.values(H.TYPES).filter((t) => t.id !== "joker");
  assert.deepEqual(sellable.map((t) => [t.key, t.title]), [
    ["hint_milliyet", "Milliyet"], ["hint_mevki", "Mevki"], ["hint_kulup", "Kulüp"], ["hint_donem", "Dönem"],
    ["hint_harf", "Harf"], ["hint_ele", "Ele"], ["hint_isim", "İsim"], ["hint_baglanti", "Bağlantı"],
    ["hint_aday", "Aday"]]);
  assert.deepEqual(sellable.filter((t) => t.strong).map((t) => t.id), ["isim", "baglanti", "aday"]);
  assert.equal(H.TYPES.joker.key, "hint_joker");
  assert.equal(H.TYPES.joker.title, "Joker");
  assert.deepEqual(H.priceOf("milliyet"), {single: 25, pack: 65});
  assert.deepEqual(H.priceOf("isim"), {single: 50, pack: 130});
  assert.throws(() => H.priceOf("joker"));
  assert.equal(H.MAX_STOCK, 99);
});

test("hint prices come from linkball_prices_v1 when set", () => {
  const on = P.validatePrices({...JSON.parse(JSON.stringify(P.defaults)), enabled: true,
    hints: {light: {single: 30, pack: 80}, strong: {single: 50, pack: 130}}});
  assert.deepEqual(P.hintPrices(on), {light: {single: 30, pack: 80}, strong: {single: 50, pack: 130}});
  assert.deepEqual(H.priceOf("kulup", P.hintPrices(on)), {single: 30, pack: 80});
  assert.deepEqual(H.priceOf("aday", P.hintPrices(on)), {single: 50, pack: 130});
  // No hints section (today's published value) still validates; defaults apply.
  assert.equal(P.hintPrices(P.validatePrices({...P.defaults, enabled: true})), null);
  assert.equal(P.hintPrices(P.DEFAULT_PRICES), null);
  assert.throws(() => P.validatePrices({...P.defaults, hints: {light: {single: 30, pack: 100}}}));
});
