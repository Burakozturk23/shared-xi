"use strict";
// İpucu sistemi v2 (docs/superpowers/specs/2026-11-07-ipucu-sistemi-design.md).
// Nine bag types plus the Pro-only Joker. Every menu item of every mode spends
// one bag type; the menus live in hints/<group>.js adapters.
const MAX_STOCK = 99;
const specs = [
  ["milliyet", "Milliyet", false], ["mevki", "Mevki", false], ["kulup", "Kulüp", false],
  ["donem", "Dönem", false], ["harf", "Harf", false], ["ele", "Ele", false],
  ["isim", "İsim", true], ["baglanti", "Bağlantı", true], ["aday", "Aday", true],
  ["joker", "Joker", false],
];
const TYPES = Object.freeze(Object.fromEntries(specs.map(([id, title, strong]) =>
  [id, Object.freeze({id, key: "hint_" + id, title, strong})])));
const DEFAULT_PRICES = Object.freeze({light: Object.freeze({single: 25, pack: 65}),
  strong: Object.freeze({single: 50, pack: 130})});

/** Coin price of one bag type: live (price_config.hintPrices) or the defaults. Joker is never sold. */
function priceOf(type, prices = null) {
  const t = TYPES[type];
  if (!t || type === "joker") throw new Error("Unsold hint type: " + type);
  const tier = t.strong ? "strong" : "light";
  return {...(prices?.[tier] || DEFAULT_PRICES[tier])};
}

module.exports = {MAX_STOCK, TYPES, DEFAULT_PRICES, priceOf};
