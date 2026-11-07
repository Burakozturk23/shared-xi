"use strict";
// İpucu v2: the static menus of every mode, for the store (game lists, game guide) and rewards.
// Only the adapters' constant menus are loaded here, never the game modules (some load 100+ MB).
const H = require("../hints");
const parts = [require("./career_transfer").CATALOG, require("./mystery_chain").CATALOG, require("./grid").CATALOG,
  require("./bot").CATALOG, require("./squad").CATALOG, require("./words").CATALOG, require("./daily").CATALOG,
  require("./arcade").CATALOG, require("./story_choice").CATALOG];
const MENUS = Object.freeze(Object.assign({}, ...parts));
const EXAMPLES = {milliyet: "Ör. Transfer Dedektifi'nde futbolcunun ülkesi.",
  mevki: "Ör. Grid'de bir adayın mevkisi.", kulup: "Ör. Gizemli Futbolcu'da bir başka kulübü.",
  donem: "Ör. Hikâyelerde görevin kendi ipucu.", harf: "Ör. Lingo'da bir harfin yeri.",
  ele: "Ör. Günün Sorusu'nda bir yanlış şık.", isim: "Ör. Transfer Dedektifi'nde ilk harf.",
  baglanti: "Ör. Kariyer Zinciri'nde köprü futbolcusu.", aday: "Ör. Kadro Mücadelesi'nde tek aday."};

const menus = () => MENUS;
/** Modes whose menu has at least one item of this bag type (Joker: every mode). */
const modesFor = (type) => Object.keys(MENUS).filter((m) => type === "joker" || MENUS[m].some((i) => i.type === type));

/** The 18 hint offers (9 types × single and 3-pack) for the games this policy has open. */
function offers(policy, prices = null) {
  const ready = (m) => policy?.readyModes?.[m] === true;
  return Object.values(H.TYPES).filter((t) => t.id !== "joker").flatMap((t, i) => [1, 3].map((units) => {
    const price = H.priceOf(t.id, prices);
    return {offerId: `hint_${t.id}_${units}`, itemId: t.key, itemType: "boost",
      title: units === 3 ? `${t.title} · 3 kullanım` : t.title,
      subtitle: `${EXAMPLES[t.id]} Sonuç Yardımlı olarak kaydedilir.`,
      badge: units === 3 ? "3’LÜ PAKET" : "TEK KULLANIM", units, priceCoins: units === 1 ? price.single : price.pack,
      enabled: true, oneTime: false, category: t.strong ? "Güçlü" : "Hafif", sortOrder: 300 + i * 2 + (units === 3),
      modes: modesFor(t.id).filter(ready)};
  })).filter((o) => o.modes.length);
}
const offerOf = (offerId) => offers({readyModes: Object.fromEntries(Object.keys(MENUS).map((m) => [m, true]))})
    .find((o) => o.offerId === offerId) || null;

/** Store game guide: what each open game's items are, by bag type. */
function guide(readyModes) {
  const names = require("../boost_guide").guide;
  return Object.entries(MENUS).filter(([m]) => readyModes?.[m] === true && names[m]).map(([modeId, items]) => ({
    modeId, name: names[modeId][0], group: names[modeId][1],
    supports: items.map((i) => ({itemId: H.TYPES[i.type].key, title: H.TYPES[i.type].title, effect: i.label}))}));
}

/** Season Pro lane supports: on v2 every unit is a Joker (spec §5.1). */
function seasonSupports(items, live) {
  if (!live) return items;
  const n = Object.values(items || {}).reduce((sum, x) => sum + x, 0);
  return n ? {hint_joker: n} : {};
}

module.exports = {menus, modesFor, offers, offerOf, guide, seasonSupports};
