"use strict";
// İpucu v2 menus: Gizemli Futbolcu (mystery) and Kariyer Zinciri (mastermind), spec §4.3.
// Gizemli Futbolcu already shows nationality and position, so its menu is the
// puzzle's own verified clues (catalog `hints`) that are not on screen yet.
const {graphOf, remaining} = require("../mystery_chain_graph");

const MYSTERY = [
  {id: "sonraki_durak", label: "Bir başka kulübü", type: "kulup", why: "Kariyerinden bir durak daha."},
  {id: "donem", label: "Bir dönemi", type: "donem", why: "Bir kulüpteki yılları."},
  {id: "profil", label: "Profil", type: "mevki", why: "Boy, ayak ve milli maç."},
  {id: "ilk_harf", label: "İlk harf", type: "isim", why: "Neredeyse çözdürür."},
  {id: "takim_arkadasi", label: "Bir takım arkadaşı", type: "baglanti", why: "Aynı kadroda oynadığı biri."},
];
const CHAIN = [
  {id: "kopru_kulup", label: "Köprü kulübü", type: "kulup", why: "Sıradaki durağın kulübü."},
  {id: "kopru_milliyet", label: "Köprü oyuncunun ülkesi", type: "milliyet", why: "Köprü futbolcusunu daraltır."},
  {id: "kopru_ad", label: "Köprü oyuncunun adı", type: "baglanti", why: "Sıradaki hamleyi gösterir."},
];
const CLUE = {donem: "period", profil: "profile", takim_arkadasi: "teammate", ilk_harf: "letter"};
const graphs = new WeakMap();
const graphFor = (c) => {
  if (!graphs.has(c)) graphs.set(c, graphOf(c));
  return graphs.get(c);
};

function make({catalog}) {
  const shown = (r) => new Set([r.puzzle.hints[0]?.id, ...(r.hints || []).map((h) => h.id)].filter(Boolean));
  function clue(r, id) {
    const seen = shown(r);
    if (id === "sonraki_durak") {
      return r.puzzle.hints.slice(1).find((h) => h.id.startsWith("club_") && !seen.has(h.id)) || null;
    }
    const h = r.puzzle.hints.find((x) => x.id === CLUE[id]);
    return h && !seen.has(h.id) ? h : null;
  }
  function next(r, c) {
    const path = remaining(graphFor(c), {...r, path: r.path || []});
    if (!path?.length) return null;
    const step = path[0];
    return {step, player: c.graph.find((p) => p.id === step.playerId).player,
      club: c.clubs.find((x) => x.id === step.clubId)};
  }
  const chainText = {
    kopru_kulup: (n) => `Sıradaki köprü kulübü: ${n.club.name}`,
    kopru_milliyet: (n) => n.player.country && `Sıradaki köprü futbolcusunun ülkesi: ${n.player.country}`,
    kopru_ad: (n) => `Sıradaki köprü futbolcusu: ${n.player.name}`,
  };
  const reveal = (r, id, ctx = {}) => {
    if (r.mode === "mystery") {
      const h = MYSTERY.some((x) => x.id === id) && clue(r, id);
      if (!h) throw new Error("unproducible");
      return {text: h.text, apply: (run) => {
        run.hints.push({...h, itemId: id}); run.optionalHints = (run.optionalHints || 0) + 1; run.feedback = h.text;
      }};
    }
    const n = CHAIN.some((x) => x.id === id) && next(r, ctx.c || catalog);
    const text = n && chainText[id](n);
    if (!text) throw new Error("unproducible");
    const hint = {id: `${(r.path || []).map((x) => x.clubId).join("_")}__${id}`, playerId: n.step.playerId, text};
    return {text, apply: (run) => {
      run.hints.push(hint); run.optionalHints = (run.optionalHints || 0) + 1;
      if (id === "kopru_ad") run.bridgeHint = hint;
      run.feedback = text;
    }};
  };
  return {
    modes: ["mystery", "mastermind"],
    catalog: {mystery: MYSTERY, mastermind: CHAIN},
    board: (r) => r.mode === "mystery" ? r.id : r.puzzle.id,
    items: (r, ctx) => (r.mode === "mystery" ? MYSTERY : CHAIN).filter((i) => {
      try {
        return !!reveal(r, i.id, ctx);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

module.exports = {make, CATALOG: {mystery: MYSTERY, mastermind: CHAIN}};
