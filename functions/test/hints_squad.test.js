"use strict";
// İpucu v2 menus for Kadro Kasası, Harf 11 and Kadro Mücadelesi.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const T = require("../three_modes");
const S = require("../squad_challenge");
let seq = 71000;
const id = () => (++seq).toString(16).padStart(32, "0");
const policy = {enabled: true, version: 2, betaUids: {alice: true},
  readyModes: {squad_vault: true, letter11: true, squad_challenge: true}};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy}, economyState: {alice: {
  balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
      .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const start = async (h, mode) => (await h.call("startThreeMode", {version: T.catalog.version, mode, entry: "random",
  requestId: id()})).session;
const act = async (h, s, extra) => (await h.call("actThreeMode", {version: T.catalog.version, mode: s.mode,
  sessionId: s.id, revision: s.revision, requestId: id(), ...extra})).session;
const hint = (h, s, itemId, extra = {}) => act(h, s, {action: "hint", itemId, paymentSource: "stock", ...extra});
const raw = (h, s) => h.read(`economyState/alice/threeModes/sessions/${s.id}`);
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;
const result = (s, itemId) => s.hintMenu.items.find((i) => i.id === itemId)?.result;

test("vault: Bir bayrak daha, Kasanın ligi, Bir oyuncunun adı; penalties stay", async () => {
  const h = setup({hint_milliyet: 1, hint_kulup: 1, hint_aday: 1}); let s = await start(h, "squad_vault");
  assert.equal(s.support, null);
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["bayrak", "lig", "oyuncu"]);
  const before = raw(h, s).revealed.length;
  s = await hint(h, s, "bayrak");
  assert.equal(raw(h, s).revealed.length, before + 1);
  s = await hint(h, s, "lig");
  assert.ok(s.league);
  s = await hint(h, s, "oyuncu");
  const r = raw(h, s); const puzzle = T.catalog.puzzles.find((p) => p.id === r.puzzle);
  assert.ok(puzzle.players.some((pid) => result(s, "oyuncu").includes(
      T.catalog.players.find((p) => p.id === pid).name)));
  const costs = T.catalog.policy.hintCosts;
  assert.equal(r.penalty, costs.flag + costs.league + costs.player);
  await assert.rejects(hint(h, s, "lig"), {code: "already-exists"});
});

test("letter 11: four items about one unfound player of the selected slot", async () => {
  const h = setup({hint_milliyet: 1, hint_kulup: 2, hint_isim: 1}); let s = await start(h, "letter11");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["milliyet", "lig", "bir_kulup", "ilk_iki_harf"]);
  for (const item of ["milliyet", "lig", "bir_kulup", "ilk_iki_harf"]) s = await hint(h, s, item, {slot: 0});
  assert.match(result(s, "ilk_iki_harf"), /"[^"_]{2}_*" \(\d+ harf\)/);
  assert.ok(s.hintMenu.items.every((i) => i.used));
  assert.equal(qty(h, "hint_kulup"), 0);
  await assert.rejects(hint(h, s, "milliyet", {slot: 1}), {code: "already-exists"});
});

test("letter 11: a filled slot gets nothing and is not charged", async () => {
  const h = setup({hint_milliyet: 1}); let s = await start(h, "letter11");
  const t = T.catalog.letters.find((x) => x.id === s.targetId);
  const p = T.catalog.players.find((x) => x.position === s.slots[0].position && x.letters.includes(t.letter));
  s = await act(h, s, {action: "place", slot: 0, playerId: p.id});
  await assert.rejects(hint(h, s, "milliyet", {slot: 0}), {code: "failed-precondition"});
  assert.equal(qty(h, "hint_milliyet"), 1);
});

async function openSquad(h) {
  const hub = (await h.call("getMySquadChallenge", {catalogVersion: S.catalog.version})).hub;
  const mission = hub.missions[0];
  const context = {catalogVersion: S.catalog.version, themeId: mission.themeId, formationId: mission.formationId};
  return {context, view: await h.call("getSquadSupport", context)};
}
const squadUse = (h, v, itemId, extra = {}) => h.call("useSquadSupport", {catalogVersion: S.catalog.version,
  sessionId: v.session.id, revision: v.session.revision, slot: 0, playerIds: Array(11).fill(null),
  requestId: id(), itemId, paymentSource: "stock", ...extra});

test("squad challenge: aday listesi −10 and tek aday −20, both Aday", async () => {
  const h = setup({hint_aday: 2}); const {view} = await openSquad(h);
  assert.equal(view.legacy, false);
  assert.deepEqual(view.session.hintMenu.items.map((i) => [i.id, i.type]), [["aday_listesi", "aday"],
    ["tek_aday", "aday"]]);
  let v = await squadUse(h, view, "aday_listesi");
  assert.equal(v.penalty, 10);
  assert.equal(v.hints.aday_listesi.candidates.length <= 5, true);
  v = await squadUse(h, v, "tek_aday");
  assert.equal(v.penalty, 30);
  assert.equal(v.hints.tek_aday.candidates.length, 1);
  assert.equal(qty(h, "hint_aday"), 0);
  await assert.rejects(squadUse(h, v, "tek_aday"), {code: "already-exists"});
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {boosts: {...policy, version: undefined}}}, {omitEmptyObjects: true});
  const s = await start(h, "letter11");
  assert.equal(s.hintMenu, null);
  assert.equal(s.support.version, 1);
});
