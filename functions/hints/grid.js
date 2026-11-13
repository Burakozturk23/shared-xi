"use strict";
// İpucu v2 menus: Grid Klasik / Rastgele / Tersten, solo and bot (spec §4.3).
// Items target the selected cell (classic, random, "pending" pair) or axis (reverse);
// the once-per-board rule is per item, not per cell.
const POS = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", ATT: "Forvet"};
const TYPE = {club: "Kulüp", country: "Milliyet", position: "Mevki", coach: "Teknik direktör"};
const firstLetter = (s) => [...String(s)].find((c) => /\p{L}/u.test(c));

const CELL = [
  {id: "milliyet", label: "Milliyet", type: "milliyet", why: "Kutudaki bir adayın ülkesi."},
  {id: "mevki", label: "Mevki", type: "mevki", why: "Kutudaki bir adayın mevkisi."},
  {id: "lig", label: "Bir ligi", type: "kulup", why: "Adayın oynadığı bir lig."},
  {id: "baska_kulup", label: "Başka bir kulübü", type: "kulup", why: "Satır ve sütun dışında bir kulübü."},
  {id: "ilk_harf", label: "İlk harf", type: "isim", why: "Kutuyu neredeyse çözdürür."},
];
const AXIS = [
  {id: "kriter_turu", label: "Kriter türü", type: "kulup", why: "Kulüp, milliyet, mevki, yoksa teknik direktör mü?"},
  {id: "yanlis_kriter", label: "Bir yanlış kriteri ele", type: "ele", why: "İkisine uyup üçüncüye uymayan."},
  {id: "kriter_harf", label: "Kriterin ilk harfi", type: "isim", why: "Ortak kriterin baş harfi."},
];

function make({catalog, kind, answers, common, axisIds, matches, targetKey}) {
  const byLabel = (a, b) => a.label.localeCompare(b.label, "tr") || a.id.localeCompare(b.id);
  const clubOf = (id) => catalog.clubs[id];
  function candidate(r, target) {
    targetKey(r, target); // closed cell or axis: RewardError, nothing spent
    const ids = answers(r, target).sort((a, b) => catalog.players[a].rank - catalog.players[b].rank);
    return ids.length ? catalog.players[ids[0]] : null;
  }
  function criteriaOf(r, target) {
    if (target === "pending") return r.pending?.criteria || [];
    const i = Number(target); return [r.rows[i / 3 | 0], r.cols[i % 3]].filter(Boolean);
  }
  function otherClubs(r, target, p) {
    const shown = new Set(criteriaOf(r, target).filter((k) => k.startsWith("club:")).map((k) => k.slice(5)));
    return p.clubs.filter((c) => !shown.has(c) && clubOf(c))
        .sort((a, b) => (clubOf(a).rank ?? 999) - (clubOf(b).rank ?? 999) || a.localeCompare(b));
  }
  const cellText = {
    // Not sold when the row or column already is that criterion.
    milliyet: (r, t, p) => !criteriaOf(r, t).some((k) => k.startsWith("country:")) &&
      `Seçtiğin kutu için bir adayın milliyeti: ${p.countries.join(" / ")}`,
    mevki: (r, t, p) => !criteriaOf(r, t).some((k) => k.startsWith("position:")) && POS[p.position] &&
      `Seçtiğin kutu için bir adayın mevkisi: ${POS[p.position]}`,
    lig: (r, t, p) => {
      const c = otherClubs(r, t, p).find((id) => clubOf(id).league) || p.clubs.find((id) => clubOf(id)?.league);
      return c && `Seçtiğin kutu için bir aday ${clubOf(c).league} liginde oynadı`;
    },
    baska_kulup: (r, t, p) => {
      const c = otherClubs(r, t, p)[0];
      return c && `Seçtiğin kutu için bir adayın oynadığı başka bir kulüp: ${clubOf(c).name}`;
    },
    ilk_harf: (r, t, p) => firstLetter(p.name) &&
      `Seçtiğin kutu için bir adayın adının ilk harfi: ${firstLetter(p.name)}`,
  };
  function axisText(r, id, target) {
    targetKey(r, target);
    const i = Number(target); const valid = [...common(r, i)].sort(byLabel);
    if (!valid.length) return null;
    if (id === "kriter_turu") {
      return `Üçünü bağlayan geçerli kriter türlerinden biri: ${TYPE[valid[0].type]}. ` +
        "Diğer doğru ortak kriterler de kabul edilir.";
    }
    if (id === "kriter_harf") return `Ortak kriterlerden birinin ilk harfi: ${firstLetter(valid[0].label)}`;
    // A club or country two of the three share, but not the third.
    const ps = axisIds(r, i).map((x) => catalog.players[x]); const ok = new Set(valid.map((k) => k.id));
    const near = Object.values(catalog.criteria).filter((k) => ["club", "country"].includes(k.type) &&
      !ok.has(k.id) && ps.filter((p) => matches(p, k.id)).length === 2).sort(byLabel);
    return near.length ? `Bu eksenin ortak kriteri değil: ${near[0].label}` : null;
  }
  function reveal(r, id, ctx = {}) {
    const reverse = kind(r) === "reverse";
    if (!(reverse ? AXIS : CELL).some((x) => x.id === id)) throw new Error("not in this mode");
    let text;
    if (reverse) text = axisText(r, id, ctx.target);
    else {
      const p = candidate(r, ctx.target); text = p && cellText[id](r, ctx.target, p);
    }
    if (!text) throw new Error("unproducible");
    return {text, apply: (run) => {
      run.feedback = text;
    }};
  }
  return {
    modes: ["solo_grid_classic", "solo_grid_reverse", "solo_grid_random",
      "bot_grid_classic", "bot_grid_reverse", "bot_grid_random"],
    catalog: Object.fromEntries(["classic", "reverse", "random"].flatMap((k) =>
      ["solo", "bot"].map((w) => [`${w}_grid_${k}`, k === "reverse" ? AXIS : CELL]))),
    board: (r) => r.id,
    // Without a target (the menu view) every item is listed; with one, only what that target can produce.
    items(r, ctx = {}) {
      const list = kind(r) === "reverse" ? AXIS : CELL;
      if (ctx.target === undefined) return list;
      return list.filter((x) => {
        try {
          return !!reveal(r, x.id, ctx);
        } catch (_) {
          return false;
        }
      });
    },
    // Which items each open cell/axis can produce, so the panel shows only those for the selected one.
    // Random cells scan the whole catalog per cell, so they are left to the server's refusal.
    availability(r) {
      if (kind(r) === "random") return null;
      const targets = kind(r) === "reverse" ? [0, 1, 2, 3, 4, 5].filter((i) => !r.axes?.[i]) :
        [0, 1, 2, 3, 4, 5, 6, 7, 8].filter((i) => !r.cells?.[i]);
      return Object.fromEntries(targets.map((t) => [t, this.items(r, {target: t}).map((x) => x.id)]));
    },
    reveal,
  };
}

const CATALOG = Object.fromEntries(["classic", "reverse", "random"].flatMap((k) =>
  ["solo", "bot"].map((w) => [`${w}_grid_${k}`, k === "reverse" ? AXIS : CELL])));
module.exports = {make, CATALOG, TYPE};
