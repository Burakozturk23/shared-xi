"use strict";
// İpucu v2 menus for Gizemli Futbolcu and Kariyer Zinciri.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {catalog} = require("../mystery_chain");
const {graphOf, remaining} = require("../mystery_chain_graph");
const version = catalog.version;
const graph = graphOf(catalog);
let seq = 0;
const id = () => (++seq).toString(16).padStart(32, "c");
const policy = {enabled: true, version: 2, betaUids: {alice: true}, readyModes: {mystery: true, mastermind: true}};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy,
  mysteryChain: {soloEnabled: true, dataEnabled: true}},
economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
    .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const start = async (h, mode) => (await h.call("startMysteryChain", {mode, version, requestId: id()})).session;
const act = async (h, s, extra) => (await h.call("actMysteryChain", {mode: s.mode, version, requestId: id(),
  sessionId: s.id, revision: s.revision, ...extra})).session;
const hint = (h, s, itemId, extra = {}) => act(h, s, {action: "hint", itemId, paymentSource: "stock", ...extra});
const raw = (h, s) => h.read(`economyState/alice/mysteryChain/sessions/${s.id}`);
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;
const result = (s, itemId) => s.hintMenu.items.find((i) => i.id === itemId)?.result;

test("mystery: menu lists the catalog clues not yet on screen", async () => {
  const h = setup(); const s = await start(h, "mystery");
  assert.equal(s.hintMenu.version, 2);
  assert.equal(s.support, null);
  const ids = s.hintMenu.items.map((i) => i.id);
  assert.ok(ids.length >= 3, ids.join());
  for (const x of ids) assert.ok(["sonraki_durak", "donem", "takim_arkadasi", "profil", "ilk_harf"].includes(x));
  assert.equal(s.hintMenu.suggested[1], "ilk_harf");
});

test("mystery: each item reveals the puzzle's own clue and costs score like an optional hint", async () => {
  const h = setup({hint_kulup: 1, hint_donem: 1, hint_baglanti: 1, hint_mevki: 1, hint_isim: 1});
  let s = await start(h, "mystery");
  const p = raw(h, s).puzzle;
  for (const item of s.hintMenu.items.map((i) => i.id)) s = await hint(h, s, item);
  const byId = Object.fromEntries(p.hints.map((x) => [x.id, x.text]));
  if (result(s, "takim_arkadasi")) assert.equal(result(s, "takim_arkadasi"), byId.teammate);
  if (result(s, "profil")) assert.equal(result(s, "profil"), byId.profile);
  if (result(s, "ilk_harf")) assert.equal(result(s, "ilk_harf"), byId.letter);
  if (result(s, "donem")) assert.equal(result(s, "donem"), byId.period);
  assert.ok(p.hints.some((x) => x.text === result(s, "sonraki_durak")));
  assert.equal(raw(h, s).optionalHints, s.hintMenu.items.length);
  s = await act(h, s, {action: "guess", playerId: p.playerId});
  assert.equal(s.score, Math.max(0, 100 - 10 * s.hintMenu.items.length));
});

test("mystery: a wrong guess never repeats a clue a hint already showed", async () => {
  const h = setup({hint_donem: 1}); let s = await start(h, "mystery");
  if (!s.hintMenu.items.some((i) => i.id === "donem")) return;
  s = await hint(h, s, "donem");
  const p = raw(h, s).puzzle;
  s = await act(h, s, {action: "guess", playerId: p.options.find((x) => x !== p.playerId)});
  const ids = raw(h, s).hints.map((x) => x.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("mystery: once per board", async () => {
  const h = setup({hint_isim: 2}); let s = await start(h, "mystery");
  s = await hint(h, s, "ilk_harf");
  await assert.rejects(hint(h, s, "ilk_harf"), {code: "already-exists"});
  assert.equal(qty(h, "hint_isim"), 1);
});

test("chain: bridge club, bridge nationality and bridge name from the shortest route", async () => {
  const h = setup({hint_kulup: 1, hint_milliyet: 1, hint_baglanti: 1}); let s = await start(h, "mastermind");
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["kopru_kulup", "kopru_milliyet", "kopru_ad"]);
  const r = raw(h, s); const next = remaining(graph, {...r, path: r.path || []})[0];
  const player = catalog.graph.find((x) => x.id === next.playerId).player;
  const club = catalog.clubs.find((x) => x.id === next.clubId);
  s = await hint(h, s, "kopru_kulup");
  s = await hint(h, s, "kopru_milliyet");
  s = await hint(h, s, "kopru_ad");
  assert.equal(result(s, "kopru_kulup"), `Sıradaki köprü kulübü: ${club.name}`);
  assert.equal(result(s, "kopru_milliyet"), `Sıradaki köprü futbolcusunun ülkesi: ${player.country}`);
  assert.equal(result(s, "kopru_ad"), `Sıradaki köprü futbolcusu: ${player.name}`);
  assert.equal(s.bridgeHint.text, `Sıradaki köprü futbolcusu: ${player.name}`);
  await assert.rejects(hint(h, s, "kopru_ad"), {code: "already-exists"});
});

test("chain: ad credit pays a light bridge hint", async () => {
  const h = setup(); let s = await start(h, "mastermind");
  const service = h.context.lbMysteryChainService();
  const benefit = await service.prepareHint("alice", "chain_hint", {sessionId: s.id, itemId: "kopru_kulup"});
  await service.settleHint("alice", {id: "d".repeat(48), context: benefit.context});
  s = (await h.call("getMysteryChain", {mode: "mastermind"})).session;
  s = await hint(h, s, "kopru_kulup", {paymentSource: "ad"});
  assert.ok(result(s, "kopru_kulup"));
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {boosts: {...policy, version: undefined},
    mysteryChain: {soloEnabled: true, dataEnabled: true}}}, {omitEmptyObjects: true});
  const s = await start(h, "mystery");
  assert.equal(s.hintMenu, null);
  assert.equal(s.support.version, 1);
});
