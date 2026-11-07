"use strict";
// İpucu v2 menus: Günün Lingo'su, Mini/Haftalık Passaparola, Günün Anagramı, Sekizli Anagram (spec §4.3).
// Lingo already shows the word length, so its menu starts with the category clue.
const tm = require("../config/three_modes_catalog.json");
const tmPlayers = new Map(tm.players.map((p) => [p.id, p]));
const tmClubs = new Map(tm.clubs.map((c) => [c.id, c]));
const POS = {Goalkeeper: "Kaleci", Defender: "Defans", Midfield: "Orta saha", Attack: "Forvet"};
const item = (id, label, type, why) => ({id, label, type, why});
const LINGO = [item("ipucu", "Kategori ipucu", "milliyet", "Kelimenin kategorisinden bir bilgi."),
  item("harf_yeri", "Bir harfin yeri", "harf", "Henüz bulmadığın bir harf."),
  item("son_harf", "Son harf", "harf", "Kelimenin son harfi."),
  item("ilk_harf", "İlk harf", "isim", "Neredeyse çözdürür.")];
const PASSA = [item("harf_sayisi", "Harf sayısı", "harf", "Cevabın uzunluğu."),
  item("harf_yeri", "Bir harfin yeri", "harf", "Cevaptan bir harf."),
  item("son_harf", "Son harf", "harf", "Cevabın son harfi."),
  item("ilk_harf", "İlk harf", "isim", "Harfi içeren sorularda baş harf.")];
const ANAGRAM = [item("milliyet", "Milliyet", "milliyet", "Futbolcunun ülkesi."),
  item("mevki", "Mevki", "mevki", "Futbolcunun mevkisi."),
  item("son_harf", "Son harf", "harf", "Cevabın son harfi."),
  item("bir_kulup", "Bir kulübü", "kulup", "Oynadığı bir kulüp."),
  item("ilk_harf", "İlk harf", "isim", "Neredeyse çözdürür.")];
const LIGHT_POINTS = 10;

function make({normalize, isAnagram}) {
  const menuOf = (r) => r.mode === "daily_lingo" ? LINGO : isAnagram(r.mode) ? ANAGRAM : PASSA;
  const questionOf = (r) => r.puzzle || r.questions[r.index];
  // A middle letter the player has not placed yet (Lingo: not marked exact in any guess).
  function middle(answer, known = () => false) {
    for (let i = 1; i < answer.length - 1; i++) if (!known(i)) return i;
    return null;
  }
  function lingo(r, id) {
    const q = r.puzzle; const a = q.answer;
    if (id === "ipucu") return r.hint ? null : q.hint;
    if (id === "ilk_harf") return `İlk harf: ${a[0]}`;
    if (id === "son_harf") return `Son harf: ${a.at(-1)}`;
    const i = middle(a, (n) => (r.guesses || []).some((g) => g.marks?.[n] === "exact"));
    return i == null ? null : `${i + 1}. harf: ${a[i]}`;
  }
  function passa(r, id) {
    const q = questionOf(r); const round = r.rounds[r.index]; const a = normalize(q.answer);
    if (round.status !== "pending" || !a) return null;
    if (id === "harf_sayisi") return `Cevap ${a.length} harften oluşur.`;
    if (id === "son_harf") return `Son harf: ${a.at(-1)}`;
    if (id === "ilk_harf") return q.rule === "contains" ? `İlk harf: ${a[0]}` : null;
    const i = middle(a); return i == null ? null : `${i + 1}. harf: ${a[i]}`;
  }
  function anagram(r, id) {
    const q = questionOf(r); const round = r.rounds[r.index];
    if (round.status !== "pending") return null;
    if (id === "milliyet") return q.countryLabel || q.country || null;
    if (id === "mevki") return POS[q.position] || null;
    if (id === "son_harf") return `Son harf: ${q.answer.at(-1)}`;
    if (id === "ilk_harf") return round.first ? null : `İlk harf: ${q.answer[0]}`;
    const club = (tmPlayers.get(q.id)?.clubs || []).map((c) => tmClubs.get(c)).filter(Boolean)
        .sort((a, b) => (b.popularity || 0) - (a.popularity || 0))[0];
    return club ? `Oynadığı bir kulüp: ${club.name}` : null;
  }
  function reveal(r, id) {
    if (!menuOf(r).some((x) => x.id === id)) throw new Error("not in this mode");
    const text = r.mode === "daily_lingo" ? lingo(r, id) : isAnagram(r.mode) ? anagram(r, id) : passa(r, id);
    if (!text) throw new Error("unproducible");
    return {text, apply: (run) => {
      if (run.mode === "daily_lingo") {
        if (id === "ipucu") run.hint = true;
      } else if (isAnagram(run.mode)) {
        const round = run.rounds[run.index];
        if (id === "ilk_harf") round.first = true; else round.extra = (round.extra || 0) + LIGHT_POINTS;
      } else {
        const round = run.rounds[run.index]; round.hint = round.hint ? `${round.hint} · ${text}` : text;
      }
    }};
  }
  return {
    modes: ["daily_lingo", "passa_daily", "passa_weekly", "daily_anagram", "anagram_practice"],
    catalog: {daily_lingo: LINGO, passa_daily: PASSA, passa_weekly: PASSA, daily_anagram: ANAGRAM,
      anagram_practice: ANAGRAM},
    board: (r) => {
      const q = questionOf(r); return r.mode === "daily_lingo" ? r.id : q.questionId || q.id;
    },
    items: (r) => menuOf(r).filter((x) => {
      try {
        return !!reveal(r, x.id);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

module.exports = {make, LIGHT_POINTS};
