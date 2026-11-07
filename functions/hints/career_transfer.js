"use strict";
// İpucu v2 menus: Transfer Dedektifi and Kariyer Bulmacası (spec §4.3).
// The module passes its own data helpers in, so there is no require cycle.
let clubCache = null; // three_modes clubs (league, popularity), loaded on first use
const allClubs = {get: (id) => (clubCache ||= new Map(require("../config/three_modes_catalog.json").clubs
    .map((c) => [c.id, c]))).get(id)};
const POSITIONS = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", FWD: "Forvet"};
const letters = (name) => [...name].filter((c) => /\p{L}/u.test(c));
const shape = (name) => {
  const chars = [...name]; const idx = chars.map((c, i) => /\p{L}/u.test(c) ? i : -1).filter((i) => i >= 0);
  const show = new Set([idx[0], idx.at(-1)]);
  return chars.map((c, i) => /\p{L}/u.test(c) ? show.has(i) ? c : "_" : " ").join(" ").replace(/ {3,}/g, "   ");
};

const catalog = {
  transfer: [
    {id: "milliyet", label: "Milliyet", type: "milliyet", why: "Aday listesini en çok bu daraltır."},
    {id: "mevki_yas", label: "Mevki ve yaş", type: "mevki", why: "Transferdeki rolü ve yaşı."},
    {id: "baska_kulup", label: "Başka bir kulübü", type: "kulup", why: "Ekranda olmayan bir kulübü."},
    {id: "kulup_sayisi", label: "Kulüp sayısı", type: "kulup", why: "Kariyerinin uzunluğunu gösterir."},
    {id: "ilk_harf", label: "İlk harf", type: "isim", why: "Neredeyse çözdürür."},
    {id: "isim_sekli", label: "İsim şekli", type: "isim", why: "İlk ve son harf, harf sayısı."},
  ],
  career: [
    {id: "milliyet", label: "Milliyet", type: "milliyet", why: "Aday listesini en çok bu daraltır."},
    {id: "mevki", label: "Mevki", type: "mevki", why: "Sahadaki rolü."},
    {id: "kariyer_yillari", label: "Kariyer yılları", type: "donem", why: "Hangi dönemin oyuncusu?"},
    {id: "ilk_harf", label: "İlk harf", type: "isim", why: "Neredeyse çözdürür."},
  ],
  career_order: [
    {id: "yillar", label: "Bir kulübün yılları", type: "donem", why: "Yanlış yerdeki bir kulübün yılları."},
    {id: "durak", label: "Kaçıncı durak", type: "kulup", why: "Bir kulübün kariyerdeki sırası."},
    {id: "art_arda", label: "Art arda iki kulüp", type: "baglanti", why: "İki kartı birden yerine oturtur."},
  ],
};
const CATALOG = {transfer: catalog.transfer, career: [...catalog.career, ...catalog.career_order]};

function make({puzzleOf, players, cardsOf, orderOf, clubOfCard, clubName, yearsOf, detailedPositions}) {
  const menuOf = (run) => run.mode === "career" && run.phase === "order" ? "career_order" : run.mode;
  const playerOf = (run) => players.get(puzzleOf(run).playerId);
  const otherClubs = (run) => {
    const p = puzzleOf(run);
    return (playerOf(run).clubs || []).filter((c) => c !== p.fromClubId && c !== p.toClubId && allClubs.get(c))
        .sort((a, b) => (allClubs.get(b).popularity || 0) - (allClubs.get(a).popularity || 0) || a - b);
  };
  // Order phase: the first career card the hints have not told yet (misplaced first).
  function orderPick(run, needNext) {
    const p = puzzleOf(run); const cards = cardsOf(p); const order = orderOf(run, cards);
    const told = new Set((run.hints || []).map((h) => h.card).filter(Boolean));
    const all = cards.map((c, i) => ({c, i}))
        .filter(({c, i}) => !told.has(c.id) && (!needNext || i + 1 < cards.length));
    return all.find(({c, i}) => clubOfCard(cards, order[i]) !== c.clubId) || all[0] || null;
  }
  const texts = {
    milliyet: (run) => playerOf(run).country,
    mevki_yas: (run) => {
      const p = puzzleOf(run);
      const text = detailedPositions[p.detailedPosition] || POSITIONS[playerOf(run).position];
      return text && (p.age ? `${text} · transferde ${p.age} yaşında` : text);
    },
    mevki: (run) => POSITIONS[playerOf(run).position],
    baska_kulup: (run) => {
      const c = otherClubs(run)[0]; return c ? `Oynadığı bir kulüp: ${allClubs.get(c).name}` : null;
    },
    kulup_sayisi: (run) => playerOf(run).clubs?.length ? `Kariyerinde ${playerOf(run).clubs.length} kulüp` : null,
    ilk_harf: (run) => letters(playerOf(run).name)[0] ? `İlk harf: ${letters(playerOf(run).name)[0]}` : null,
    isim_sekli: (run) => `${shape(playerOf(run).name)} (${letters(playerOf(run).name).length} harf)`,
    kariyer_yillari: (run) => {
      const cards = cardsOf(puzzleOf(run));
      return `Kariyer: ${cards[0].start.slice(0, 4)}–${cards.at(-1).end?.slice(0, 4) || "devam ediyor"}`;
    },
    yillar: (run) => {
      const pick = orderPick(run); return pick && `${clubName(pick.c.clubId)}: ${yearsOf(pick.c)}`;
    },
    durak: (run) => {
      const pick = orderPick(run); return pick && `${clubName(pick.c.clubId)} kariyerin ${pick.i + 1}. durağı`;
    },
    art_arda: (run) => {
      const pick = orderPick(run, true); if (!pick) return null;
      const next = cardsOf(puzzleOf(run))[pick.i + 1];
      return `${clubName(pick.c.clubId)} → ${clubName(next.clubId)} art arda`;
    },
  };
  // What the module's existing screen state needs after a reveal.
  const kinds = {ilk_harf: "letter", isim_sekli: "shape", yillar: "years", durak: "short", art_arda: "connection"};
  return {
    modes: ["transfer", "career"],
    catalog: CATALOG,
    board: (run) => run.mode === "career" ? `${run.id}:${run.phase}` : run.id,
    items: (run) => catalog[menuOf(run)].filter((i) => texts[i.id](run)),
    reveal(run, id) {
      if (!catalog[menuOf(run)].some((i) => i.id === id)) throw new Error("not in this phase");
      const text = texts[id](run);
      if (!text) throw new Error("unproducible");
      const card = ["yillar", "durak"].includes(id) ? orderPick(run)?.c.id :
        id === "art_arda" ? orderPick(run, true)?.c.id : undefined;
      return {text, apply: (r) => {
        r.hints.push({kind: kinds[id] || id, text, ...(card ? {card} : {}), itemId: id});
        r.feedback = text;
      }};
    },
  };
}

module.exports = {make, shape, CATALOG};
