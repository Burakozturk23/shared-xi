"use strict";
// İpucu v2 menus: Kadro Kasası, Harf 11 (three_modes.js) and Kadro Mücadelesi (squad_support.js), spec §4.3.
const item = (id, label, type, why) => ({id, label, type, why});
const VAULT = [item("bayrak", "Bir bayrak daha", "milliyet", "Kasadaki bir oyuncunun bayrağı."),
  item("lig", "Kasanın ligi", "kulup", "Gizli kulübün ligi."),
  item("oyuncu", "Bir oyuncunun adı", "aday", "Açık bir bayrağın sahibi.")];
const LETTER = [item("milliyet", "Milliyet", "milliyet", "Seçili mevkiye uyan bir futbolcunun ülkesi."),
  item("lig", "Ligi", "kulup", "Aynı futbolcunun oynadığı bir lig."),
  item("bir_kulup", "Bir kulübü", "kulup", "Aynı futbolcunun oynadığı bir kulüp."),
  item("ilk_iki_harf", "İlk iki harf", "isim", "Aynı futbolcunun adının şekli.")];
const CHALLENGE = [item("aday_listesi", "5 aday listesi", "aday", "Kriterlere uyan 5 aday; puandan 10 düşer."),
  item("tek_aday", "Tek aday", "aday", "En uygun tek aday; puandan 20 düşer.")];

/** Kadro Kasası and Harf 11. */
function three({catalog, clubs, players, puzzleOf, eligible, letterWord, targetOf}) {
  // Harf 11: one target player per slot, so every hint narrows the same footballer.
  function slotPlayer(run, slot) {
    if (!Number.isInteger(slot) || slot < 0 || slot >= 11 || run.picks?.[slot]) return null;
    const known = (p) => (p.clubs || []).some((id) => clubs.get(id)?.league);
    const options = eligible(run, catalog.formations[run.formation][slot])
        .sort((a, b) => Number(known(b)) - Number(known(a)) || a.rank - b.rank);
    return options[0] || null;
  }
  const lead = "Seçili mevkiye uygun, henüz bulunmamış bir futbolcu: ";
  function letterText(run, id, slot) {
    const p = slotPlayer(run, slot); if (!p) return null;
    if (id === "milliyet") return p.country && lead + p.country;
    const withLeague = p.clubs.map((c) => clubs.get(c)).find((c) => c?.league);
    if (id === "lig") return withLeague && `${lead}${withLeague.league} (kulübün veri sürümündeki ligi)`;
    if (id === "bir_kulup") {
      const c = p.clubs.map((x) => clubs.get(x)).find(Boolean); return c && lead + c.name;
    }
    const word = letterWord(p, targetOf(run).letter) || "";
    return word.length > 2 ? `${lead}"${word.slice(0, 2)}${"_".repeat(word.length - 2)}" (${word.length} harf)` : null;
  }
  function vault(run, id) {
    const puzzle = puzzleOf(run); const costs = catalog.policy.hintCosts;
    if (id === "bayrak") {
      const slot = puzzle.players.findIndex((_, i) => !run.revealed.includes(i));
      return slot < 0 ? null : {text: "Bir bayrak daha açıldı.", apply: (r) => {
        r.revealed.push(slot); r.penalty += costs.flag;
      }};
    }
    if (id === "lig") {
      return run.leagueShown ? null : {text: `Kasanın ligi: ${clubs.get(puzzle.clubId).league}`, apply: (r) => {
        r.leagueShown = true; r.penalty += costs.league;
      }};
    }
    const slot = run.revealed.find((i) => !(run.nameHints || []).includes(i));
    return slot == null ? null : {text: `Açık bir bayrağın sahibi: ${players.get(puzzle.players[slot]).name}`,
      apply: (r) => {
        (r.nameHints ||= []).push(slot); r.penalty += costs.player;
      }};
  }
  function reveal(run, id, ctx = {}) {
    let out;
    if (run.mode === "squad_vault") out = VAULT.some((x) => x.id === id) && vault(run, id);
    else {
      const text = LETTER.some((x) => x.id === id) && letterText(run, id, ctx.slot);
      out = text && {text};
    }
    if (!out) throw new Error("unproducible");
    const kind = {bayrak: "flag", lig: "league", oyuncu: "player", milliyet: "country", bir_kulup: "club",
      ilk_iki_harf: "shape"}[id];
    return {text: out.text, apply: (r) => {
      out.apply?.(r); r.hints.push({kind, text: out.text, itemId: id}); r.feedback = out.text;
    }};
  }
  return {
    modes: ["squad_vault", "letter11"],
    catalog: {squad_vault: VAULT, letter11: LETTER},
    board: (run) => run.id,
    items(run, ctx = {}) {
      const list = run.mode === "squad_vault" ? VAULT : LETTER;
      if (run.mode === "letter11" && ctx.slot === undefined) return list;
      return list.filter((x) => {
        try {
          return !!reveal(run, x.id, ctx);
        } catch (_) {
          return false;
        }
      });
    },
    reveal,
  };
}

/** Kadro Mücadelesi: the existing candidate advice, now as two Aday items. */
function challenge({recommendation}) {
  const COST = {aday_listesi: 10, tek_aday: 20};
  function reveal(run, id, ctx = {}) {
    if (!COST[id]) throw new Error("not in this mode");
    // recommendation() validates the draft and throws RewardError on a forged one.
    const advice = recommendation(run, {...ctx.input, boostId: id === "aday_listesi" ? "boost_basic" : "boost_strong"});
    const text = `${advice.slotLabel}: ${advice.candidates.map((c) => c.name).join(", ")}`;
    return {text, apply: (r) => {
      (r.supportHints ||= {})[id] = advice; r.supportPenalty = (r.supportPenalty || 0) + COST[id];
    }};
  }
  return {
    modes: ["squad_challenge"],
    catalog: {squad_challenge: CHALLENGE},
    board: (run) => run.id,
    items: () => CHALLENGE,
    reveal,
  };
}

module.exports = {three, challenge};
