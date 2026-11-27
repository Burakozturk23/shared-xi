"use strict";
// İpucu v2 menus for Transfer Dedektifi and Kariyer Bulmacası.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog, players, cardsOf} = require("../career_transfer");
const clubs = new Map(require("../config/three_modes_catalog.json").clubs.map((c) => [c.id, c]));
const version = catalog.version;
let n = 0;
const id = () => (++n).toString(16).padStart(32, "a");
const policy = {enabled: true, version: 2, betaUids: {alice: true}, readyModes: {transfer: true, career: true}};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy},
  economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
      .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const start = async (h, mode) => (await h.call("startCareerTransfer", {mode, version, difficulty: "normal",
  requestId: id()})).session;
const hint = async (h, s, itemId, extra = {}) => (await h.call("actCareerTransfer", {mode: s.mode, version,
  sessionId: s.id, revision: s.revision, requestId: id(), action: "hint", itemId, paymentSource: "stock",
  ...extra})).session;
const raw = (h, s) => h.read(`economyState/alice/careerTransfer/sessions/${s.id}`);
const puzzle = (h, s) => (s.mode === "career" ? catalog.careers : catalog.transfers)
    .find((p) => p.id === raw(h, s).puzzle);
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;

test("transfer: menu lists the spec items in order, v2 only", async () => {
  const h = setup(); const s = await start(h, "transfer");
  assert.equal(s.hintMenu.version, 2);
  assert.equal(s.support, null);
  const ids = s.hintMenu.items.map((i) => i.id);
  assert.deepEqual(ids.filter((x) => x !== "baska_kulup"),
      ["milliyet", "mevki_yas", "kulup_sayisi", "ilk_harf", "isim_sekli"]);
  assert.deepEqual(s.hintMenu.suggested, ["milliyet", "ilk_harf"]);
  assert.deepEqual(s.hintMenu.items.map((i) => i.type).slice(0, 2), ["milliyet", "mevki"]);
});

test("transfer: İlk harf is usable first, before any other hint", async () => {
  const h = setup({hint_isim: 1}); let s = await start(h, "transfer");
  const p = puzzle(h, s); const name = players.get(p.playerId).name;
  s = await hint(h, s, "ilk_harf");
  assert.equal(s.hintMenu.items.find((i) => i.id === "ilk_harf").result, `İlk harf: ${name.match(/\p{L}/u)[0]}`);
  assert.equal(s.maskedName.replace(/ /g, "")[0], name.match(/\p{L}/u)[0]);
  assert.equal(qty(h, "hint_isim"), 0);
  assert.equal(s.hintMenu.assisted, true);
});

test("transfer: each item reveals text from catalog data", async () => {
  const h = setup({hint_milliyet: 1, hint_mevki: 1, hint_kulup: 2, hint_isim: 1}); let s = await start(h, "transfer");
  const p = puzzle(h, s); const player = players.get(p.playerId);
  s = await hint(h, s, "milliyet");
  s = await hint(h, s, "mevki_yas");
  s = await hint(h, s, "kulup_sayisi");
  s = await hint(h, s, "isim_sekli");
  const r = Object.fromEntries(s.hintMenu.items.map((i) => [i.id, i.result]));
  assert.equal(r.milliyet, player.country);
  assert.ok(r.mevki_yas.includes(`transferde ${p.age} yaşında`) || !p.age);
  assert.equal(r.kulup_sayisi, `Kariyerinde ${player.clubs.length} kulüp`);
  const letters = [...player.name].filter((c) => /\p{L}/u.test(c));
  assert.ok(r.isim_sekli.startsWith(letters[0]) && r.isim_sekli.includes(`(${letters.length} harf)`));
  const other = s.hintMenu.items.find((i) => i.id === "baska_kulup");
  if (other) {
    s = await hint(h, s, "baska_kulup");
    const text = s.hintMenu.items.find((i) => i.id === "baska_kulup").result;
    const shown = [p.fromClubId, p.toClubId];
    assert.ok(player.clubs.filter((c) => !shown.includes(c)).some((c) => text.includes(clubs.get(c).name)));
  }
});

test("transfer: once per board; next file resets", async () => {
  const h = setup({hint_milliyet: 3}); let s = await start(h, "transfer");
  s = await hint(h, s, "milliyet");
  await assert.rejects(hint(h, s, "milliyet"), {code: "already-exists"});
  assert.equal(qty(h, "hint_milliyet"), 2);
  s = (await h.call("actCareerTransfer", {mode: "transfer", version, sessionId: s.id, revision: s.revision,
    requestId: id(), action: "skip"})).session;
  const next = await start(h, "transfer");
  assert.equal(next.hintMenu.items.find((i) => i.id === "milliyet").used, false);
  await hint(h, next, "milliyet");
  assert.equal(qty(h, "hint_milliyet"), 1);
});

test("career: guess phase and order phase have their own menus", async () => {
  const h = setup({hint_donem: 2, hint_kulup: 1, hint_baglanti: 1}); let s = await start(h, "career");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["milliyet", "mevki", "kariyer_yillari", "ilk_harf"]);
  const p = puzzle(h, s); const cards = cardsOf(p);
  s = await hint(h, s, "kariyer_yillari");
  assert.equal(s.hintMenu.items.find((i) => i.id === "kariyer_yillari").result,
      `Kariyer: ${cards[0].start.slice(0, 4)}–${cards.at(-1).end?.slice(0, 4) || "devam ediyor"}`);
  s = (await h.call("actCareerTransfer", {mode: "career", version, sessionId: s.id, revision: s.revision,
    requestId: id(), action: "guess", playerId: p.playerId})).session;
  assert.equal(s.phase, "order");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["yillar", "durak", "art_arda"]);
  s = await hint(h, s, "yillar");
  s = await hint(h, s, "durak");
  s = await hint(h, s, "art_arda");
  const r = s.hintMenu.items.map((i) => i.result);
  assert.ok(r.every((t) => typeof t === "string" && t.length > 3), JSON.stringify(r));
  assert.equal(qty(h, "hint_baglanti"), 0);
});

test("transfer: omits an unproducible item and refuses it without charging", async () => {
  const h = setup({hint_kulup: 1});
  // A player whose every club is already on screen has no other club to show.
  const p = catalog.transfers.find((x) => players.get(x.playerId).clubs
      .every((c) => [x.fromClubId, x.toClubId].includes(c)));
  if (!p) return; // catalog has no such file
  let s = await start(h, "transfer");
  h.seed(`economyState/alice/careerTransfer/sessions/${s.id}/puzzle`, p.id);
  s = (await h.call("getCareerTransfer", {mode: "transfer"})).session;
  assert.equal(s.hintMenu.items.some((i) => i.id === "baska_kulup"), false);
  await assert.rejects(hint(h, s, "baska_kulup"), {code: "failed-precondition"});
  assert.equal(qty(h, "hint_kulup"), 1);
});

test("transfer: Coin and ad payments go through the kernel", async () => {
  const h = setup(); let s = await start(h, "transfer");
  s = await hint(h, s, "milliyet", {paymentSource: "coins", expectedPriceCoins: 25});
  assert.equal(h.read("economyState/alice/balances/coins"), 975);
  const service = h.context.lbCareerTransferService();
  const benefit = await service.prepareHint("alice", "transfer_hint", {sessionId: s.id, itemId: "mevki_yas"});
  assert.equal(benefit.context.itemId, "mevki_yas");
  await service.settleHint("alice", {id: "b".repeat(48), context: benefit.context});
  s = (await h.call("getCareerTransfer", {mode: "transfer"})).session;
  s = await hint(h, s, "mevki_yas", {paymentSource: "ad"});
  assert.ok(s.hintMenu.items.find((i) => i.id === "mevki_yas").used);
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {boosts: {...policy, version: undefined}}}, {omitEmptyObjects: true});
  const s = await start(h, "transfer");
  assert.equal(s.hintMenu, null);
  assert.equal(s.support.version, 1);
});
