"use strict";
// İpucu v2 menus: Günün Sorusu, Günün Maçları, Günün Futbolcusu (spec §4.3). All three are daily runs (1 ad).
// Günün Sorusu has three options: eliminating two would give the answer away, so only one is offered.
const matchCatalog = require("../config/daily_catalog.json");
const item = (id, label, type, why) => ({id, label, type, why});
const MENUS = {
  daily_question: [item("bir_yanlis", "Bir yanlışı ele", "ele", "Üç şıktan birini eler.")],
  daily_match: [item("milliyet", "Milliyet", "milliyet", "Bulunmamış bir ortak oyuncunun ülkesi."),
    item("mevki", "Mevki", "mevki", "Aynı oyuncunun mevkisi."),
    item("soyad_harf", "Soyadının ilk harfi", "isim", "Aynı oyuncunun soyadı.")],
  daily_footballer: [item("milliyet", "Milliyet", "milliyet", "Günün futbolcusunun ülkesi."),
    item("lig", "Ligi", "kulup", "Oynadığı lig."),
    item("yas", "Yaşı", "donem", "Bugünkü yaşı."),
    item("isim_ipucu", "İsim ipucu", "isim", "Adının ve soyadının baş harfleri.")],
};
const age = (p, day) => {
  const [y, m, d] = day.split("-").map(Number); const [by, bm, bd] = p.birthDate.split("-").map(Number);
  return y - by - (m < bm || m === bm && d < bd ? 1 : 0);
};
const MATCH_POS = {Goalkeeper: "Kaleci", Defender: "Defans", Midfield: "Orta saha", Attack: "Hücum"};

function make() {
  function question(r, ctx) {
    const q = ctx.q;
    if (!q || r.questionId !== q.id || ctx.answered || ctx.eliminated != null) return null;
    const eliminated = (q.answer + 1) % 3;
    return {text: `Elenen şık: ${q.options[eliminated]}`, eliminated};
  }
  function match(r, id) {
    const pid = (r.answers || []).find((x) => !(r.found || []).includes(x)); const p = pid && matchCatalog.players[pid];
    if (!p || r.finished) return null;
    if (id === "milliyet") return `Bulunmamış bir ortak oyuncunun ülkesi: ${p.country}`;
    if (id === "mevki") return `Bulunmamış bir ortak oyuncunun mevkisi: ${MATCH_POS[p.position] || p.position}`;
    const surname = p.name.split(" ").at(-1);
    return `Ortak bir oyuncunun soyadı ${surname[0]} ile başlıyor`;
  }
  function footballer(r, id) {
    const t = r.target; if (!t || r.finished) return null;
    if (id === "milliyet") return t.country && `Ülkesi: ${t.country}`;
    if (id === "lig") return t.league && `Ligi: ${t.league}`;
    if (id === "yas") return t.birthDate && `Yaşı: ${age(t, r.day)}`;
    const words = t.name.trim().split(/\s+/);
    return `Adı ${words[0][0].toUpperCase()} harfiyle başlıyor` +
      (words.length > 1 ? `, son kelimesinin ilk harfi ${words.at(-1)[0].toUpperCase()}.` : ".");
  }
  function reveal(r, id, ctx = {}) {
    if (!MENUS[r.mode]?.some((x) => x.id === id)) throw new Error("not in this mode");
    if (r.mode === "daily_question") {
      const out = question(r, ctx); if (!out) throw new Error("unproducible");
      return {text: out.text, apply: () => ctx.onEliminate?.(out.eliminated)};
    }
    const text = r.mode === "daily_match" ? match(r, id) : footballer(r, id);
    if (!text) throw new Error("unproducible");
    return {text, apply: (run) => {
      if (run.mode === "daily_footballer" && id === "isim_ipucu") {
        run.hintUsed = true; run.hint = text;
      } else if (run.mode === "daily_match") run.hint = run.hint ? `${run.hint} · ${text}` : text;
    }};
  }
  return {
    modes: ["daily_question", "daily_match", "daily_footballer"],
    catalog: MENUS,
    board: (r) => r.mode === "daily_match" ? r.key : r.id,
    items: (r, ctx = {}) => MENUS[r.mode].filter((x) => {
      // The question menu needs the private question; without it (a view) list the item.
      if (r.mode === "daily_question" && !ctx.q) return true;
      try {
        return !!reveal(r, x.id, ctx);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

const adapter = require("../hints").register(make());
module.exports = {make, adapter, CATALOG: MENUS};
