"use strict";
// İpucu v2 menus: Football Loto, Takım Yarışı, Futbol Çinko, Rastgele Beşler (spec §4.3).
// Loto shows the player's name, so its menu helps placing them instead of naming them.
const POS = {GK: "Kaleci", DEF: "Defans", MID: "Orta saha", ATT: "Forvet"};
const firstLetter = (s) => [...String(s)].find((c) => /\p{L}/u.test(c));
const item = (id, label, type, why) => ({id, label, type, why});
const MENUS = {
  loto: [item("milliyet", "Milliyet", "milliyet", "Ülkesi hangi kutuya uyar?"),
    item("mevki", "Mevki", "mevki", "Mevki grubu."),
    item("uygun_kutu", "Uygun bir kutu", "aday", "Bu oyuncunun gidebileceği bir kutu.")],
  team_race: [item("milliyet", "Milliyet", "milliyet", "Kalan ortak oyunculardan birinin ülkesi."),
    item("mevki", "Mevki", "mevki", "Kalan bir ortak oyuncunun mevkisi."),
    item("ilk_harf", "İlk harf", "isim", "Kalan bir ortak oyuncunun baş harfi.")],
  cinko: [item("milliyet", "Milliyet", "milliyet", "Kutuya uyan bir adayın ülkesi."),
    item("mevki", "Mevki", "mevki", "Kutuya uyan bir adayın mevkisi."),
    item("ilk_harf", "İlk harf", "isim", "Kutuya uyan bir adayın baş harfi.")],
  random_five: [item("kulup_eslesme", "Kaç kulübe uyuyor", "kulup", "En iyi adayın kaç kulübe uyduğu."),
    item("milliyet", "Milliyet", "milliyet", "En iyi adayın ülkesi."),
    item("mevki", "Mevki", "mevki", "En iyi adayın mevkisi."),
    item("ilk_harf", "İlk harf", "isim", "En iyi adayın baş harfi.")],
};

function make({catalog, kind, targetKey, answers, matches, remaining, matched, byRank, playable}) {
  // The player each hint is about, for this target (throws RewardError when the target is closed).
  function subject(r, target) {
    targetKey(r, target);
    const k = kind(r);
    if (k === "loto") return r.board.queue[r.humanIndex];
    if (k === "team_race") return [...remaining(r)].sort(byRank)[0];
    if (k === "cinko") return [...answers(r.cells[Number(target)])].filter((x) => !r.used[x]).sort(byRank)[0];
    const pool = new Set();
    for (const club of r.rounds[r.round]) for (const x of answers(club)) if (!r.used[x]) pool.add(x);
    return [...pool].sort((a, b) => matched(r, b).length - matched(r, a).length || byRank(a, b))[0];
  }
  const who = {loto: "Bu oyuncunun", team_race: "Kalan ortak oyunculardan birinin",
    cinko: "Bu kutuya uyan bir adayın", random_five: "Kalan adaylardan birinin"};
  function text(r, id, target) {
    const pid = subject(r, target); const p = pid && catalog.players[pid]; if (!p) return null;
    const k = kind(r); const lead = who[k];
    if (id === "milliyet") {
      if (k === "cinko" && catalog.criteria[r.cells[Number(target)]]?.type === "country") return null;
      return `${lead} milliyeti: ${p.countries.join(" / ")}`;
    }
    if (id === "mevki") return POS[p.position] && `${lead} mevkisi: ${POS[p.position]}`;
    if (id === "ilk_harf") return firstLetter(p.name) && `${lead} adının ilk harfi: ${firstLetter(p.name)}`;
    if (id === "uygun_kutu") {
      const open = r.board.criteria.map((c, i) => ({c, i})).filter(({c, i}) => !r.human?.[i] && matches(pid, c));
      return open.length ? `Bu oyuncu şu kutuya uyar: ${catalog.criteria[open[0].c].label}` : null;
    }
    if (id === "kulup_eslesme") return `Kalan adaylardan biri beş kulübün ${matched(r, pid).length} tanesine uyuyor`;
    return null;
  }
  function reveal(r, id, ctx = {}) {
    if (!MENUS[kind(r)].some((x) => x.id === id)) throw new Error("not in this mode");
    const t = text(r, id, ctx.target);
    if (!t) throw new Error("unproducible");
    return {text: t, apply: (run) => {
      run.feedback = t;
    }};
  }
  return {
    modes: ["bot_loto", "bot_team_race", "bot_cinko", "bot_random_five"],
    catalog: {bot_loto: MENUS.loto, bot_team_race: MENUS.team_race, bot_cinko: MENUS.cinko,
      bot_random_five: MENUS.random_five},
    board: (r) => kind(r) === "random_five" ? `${r.id}:${r.round}` : r.id,
    items(r, ctx = {}) {
      const list = MENUS[kind(r)];
      if (ctx.target === undefined) return list;
      return list.filter((x) => {
        try {
          return !!reveal(r, x.id, ctx);
        } catch (_) {
          return false;
        }
      });
    },
    // Çinko: what each playable cell can produce (nationality is no help on a country cell).
    availability(r) {
      if (kind(r) !== "cinko") return null;
      return Object.fromEntries(playable(r).map((i) => [i, this.items(r, {target: i}).map((x) => x.id)]));
    },
    reveal,
  };
}

module.exports = {make, CATALOG: {bot_loto: MENUS.loto, bot_team_race: MENUS.team_race,
  bot_cinko: MENUS.cinko, bot_random_five: MENUS.random_five}};
