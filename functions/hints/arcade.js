"use strict";
// İpucu v2 menus: Burst Dayanıklılık, Pyramid, Matching (arcade.js) and Sahte Kulüp Sonsuz (fake_club.js), spec §4.3.
// Arcade hints come from the engine's own hint step (arcade_engine.js), asked for one kind at a time:
// the reveal runs it on a copy and the apply runs it again on the run, so both see the same state.
const item = (id, label, type, why, kind) => ({id, label, type, why, ...(kind ? {kind} : {})});
const MENUS = {
  burst: [item("milliyet", "Bir cevabın milliyeti", "milliyet", "Bulunmamış bir cevabın ülkesi.", "country"),
    item("bas_harfler", "Baş harfler", "isim", "Bir cevabın baş harfleri ve ülkesi.", "initials")],
  pyramid: [item("aday_turu", "Aday türü", "kulup", "Seçili hücreye oyuncu mu, kulüp mü, ülke mi?", "type"),
    item("baglanti", "Bir bağlantı", "baglanti", "Adayın alt destekle bağı.", "link")],
  matching: [item("yanlis_eslesme", "Bir yanlış eşleşme", "ele", "Eşleşmeyen iki kart."),
    item("dogru_cift", "Doğru bir çift", "baglanti", "Kariyer kaynağıyla doğrulanmış bir çift.")],
};
const FAKE = [item("gercek_ele", "Bir gerçek kulübü ele", "ele", "Sahte olmayan bir kulübü eler."),
  item("dogrula", "Bir kulübü doğrula", "baglanti", "Gerçekten oynanmış bir kulübü gösterir.")];

function arcade({E}) {
  const menu = (r) => MENUS[r.mode];
  function wrongPair(r, c) {
    const cards = r.board.cards; const matched = new Set(r.matched || []);
    for (const p of cards.filter((x) => x.type === "player" && !matched.has(x.pair))) {
      const career = c.careers.find((x) => x.playerId === p.entityId);
      const club = cards.find((x) => x.type === "club" && !matched.has(x.pair) && x.pair !== p.pair &&
        career && !career.clubs.includes(x.entityId));
      if (club) return `${cards.indexOf(p) + 1}. kart ile ${cards.indexOf(club) + 1}. kart eşleşmez`;
    }
    return null;
  }
  function reveal(r, id, ctx = {}) {
    const it = menu(r)?.find((x) => x.id === id);
    if (!it || !ctx.c) throw new Error("not in this mode");
    if (id === "yanlis_eslesme") {
      const text = wrongPair(r, ctx.c); if (!text) throw new Error("unproducible");
      return {text};
    }
    const event = {...ctx.input, action: "hint", hintKind: it.kind};
    const copy = structuredClone(r);
    E.act(ctx.c, copy, event, ctx.eventTime); // throws RewardError when the engine has no hint here
    if (!copy.hint) throw new Error("unproducible");
    return {text: copy.hint, apply: (run) => E.act(ctx.c, run, event, ctx.eventTime)};
  }
  return {
    modes: ["burst_survival", "pyramid", "matching"],
    catalog: {burst_survival: MENUS.burst, pyramid: MENUS.pyramid, matching: MENUS.matching},
    board: (r) => r.mode === "burst" ? r.question?.id : r.id,
    // A view lists the menu; a hint request checks the one item against the engine.
    items: (r, ctx = {}) => !ctx.c ? menu(r) : menu(r).filter((x) => {
      try {
        return !!reveal(r, x.id, ctx);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

function fakeClub() {
  function pickReal(r) {
    return r.answered ? null :
      r.question.realClubIds.find((x) => !r.eliminated.includes(x) && !r.confirmed.includes(x)) ?? null;
  }
  const name = (r, cid) => r.question.options.find((o) => o.id === cid)?.name || "bir kulüp";
  function reveal(r, id, ctx = {}) {
    if (!FAKE.some((x) => x.id === id)) throw new Error("not in this mode");
    const cid = pickReal(r); if (cid == null) throw new Error("unproducible");
    const text = id === "gercek_ele" ? `Gerçek kulüp, elendi: ${name(r, cid)}` :
      `Gerçekten oynadığı kulüp: ${name(r, cid)}`;
    return {text, apply: (run) => {
      if (id === "gercek_ele") run.eliminated.push(cid); else run.confirmed.push(cid);
      run.hintsUsed++; run.questionHints++; run.cleanStreak = 0; ctx.onHint?.();
    }};
  }
  return {
    modes: ["fake_endless"],
    catalog: {fake_endless: FAKE},
    board: (r) => r.question.questionId,
    items: (r) => FAKE.filter((x) => {
      try {
        return !!reveal(r, x.id);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

module.exports = {arcade, fakeClub};
