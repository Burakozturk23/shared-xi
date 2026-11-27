"use strict";
// İpucu v2 menus for Burst Dayanıklılık, Pyramid, Matching and Sahte Kulüp Sonsuz.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const arcade = require("../arcade_engine").catalog;
const fc = require("../fake_club").catalog;
let seq = 97000; const id = () => (++seq).toString(16).padStart(32, "0");
const policy = {enabled: true, version: 2, betaUids: {alice: true},
  readyModes: {burst_survival: true, pyramid: true, matching: true, fake_endless: true}};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy, arcade: {enabled: true},
  fakeClub: {dataEnabled: true, soloEnabled: true}},
economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
    .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;
const result = (s, itemId) => s.hintMenu.items.find((i) => i.id === itemId)?.result;
async function startArcade(h, mode) {
  let s = (await h.call("prepareArcade", {mode, version: arcade.version, style: "survival", difficulty: "easy",
    requestId: id()})).session;
  s = (await h.call("actArcade", {mode, sessionId: s.id, revision: s.revision, requestId: id(),
    action: "confirm"})).session;
  return s;
}
const actArcade = async (h, s, extra) => (await h.call("actArcade", {mode: s.mode, sessionId: s.id,
  revision: s.revision, requestId: id(), ...extra})).session;
const raw = (h, s) => h.read(`economyState/alice/arcade/sessions/${s.id}`);

test("burst: Bir cevabın milliyeti and Baş harfler, in either order", async () => {
  const h = setup({hint_isim: 1, hint_milliyet: 1}); let s = await startArcade(h, "burst");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["milliyet", "bas_harfler"]);
  s = await actArcade(h, s, {action: "hint", itemId: "bas_harfler", questionId: s.question.id,
    paymentSource: "stock"});
  assert.match(result(s, "bas_harfler"), /^(\S\. )+· /);
  s = await actArcade(h, s, {action: "hint", itemId: "milliyet", questionId: s.question.id, paymentSource: "stock"});
  assert.match(result(s, "milliyet"), /^Bir cevabın milliyeti: /);
  assert.equal(qty(h, "hint_isim"), 0);
  assert.equal(s.hintMenu.ads.allowed, true);
});

test("pyramid: candidate type then link for a ready slot; no ad", async () => {
  const h = setup({hint_kulup: 1, hint_baglanti: 1}); let s = await startArcade(h, "pyramid");
  assert.equal(s.hintMenu.ads.allowed, false);
  const r = raw(h, s);
  const slot = r.board.slots.find((x) => !r.filled?.[x.id] && x.supports.every((sid) => r.filled?.[sid]));
  s = await actArcade(h, s, {action: "hint", itemId: "aday_turu", slotId: slot.id, paymentSource: "stock"});
  assert.match(result(s, "aday_turu"), /^Aday türü: (Oyuncu|Kulüp|Ülke)\.$/);
  s = await actArcade(h, s, {action: "hint", itemId: "baglanti", slotId: slot.id, paymentSource: "stock"});
  assert.ok(result(s, "baglanti").startsWith("Aday türü: "));
  assert.ok(result(s, "baglanti").length > result(s, "aday_turu").length);
});

test("matching: a verified wrong pair and a correct pair", async () => {
  const h = setup({hint_ele: 1, hint_baglanti: 1}); let s = await startArcade(h, "matching");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["yanlis_eslesme", "dogru_cift"]);
  s = await actArcade(h, s, {action: "hint", itemId: "yanlis_eslesme", paymentSource: "stock"});
  const m = result(s, "yanlis_eslesme").match(/^(\d+)\. kart ile (\d+)\. kart eşleşmez$/);
  const cards = raw(h, s).board.cards; const a = cards[m[1] - 1]; const b = cards[m[2] - 1];
  assert.notEqual(a.pair, b.pair);
  s = await actArcade(h, s, {action: "hint", itemId: "dogru_cift", paymentSource: "stock"});
  assert.match(result(s, "dogru_cift"), /kart: .+ · \d+\. kart: /);
});

test("fake club: eliminate one real club, confirm another; per question", async () => {
  const h = setup({hint_ele: 2, hint_baglanti: 1});
  let s = (await h.call("startFakeClub", {mode: "fake_endless", version: fc.version, requestId: id()})).session;
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["gercek_ele", "dogrula"]);
  const act = async (extra) => (await h.call("actFakeClub", {mode: s.mode, version: fc.version, sessionId: s.id,
    questionId: s.question.questionId, revision: s.revision, requestId: id(), ...extra})).session;
  s = await act({action: "hint", itemId: "gercek_ele", paymentSource: "stock"});
  assert.equal(s.eliminated.length, 1);
  s = await act({action: "hint", itemId: "dogrula", paymentSource: "stock"});
  assert.equal(s.confirmed.length, 1);
  assert.notEqual(s.confirmed[0], s.eliminated[0]);
  await assert.rejects(act({action: "hint", itemId: "gercek_ele", paymentSource: "stock"}),
      {code: "already-exists"});
  assert.equal(qty(h, "hint_ele"), 1);
});
