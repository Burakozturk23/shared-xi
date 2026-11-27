"use strict";
// İpucu v2 menus for Football Loto, Takım Yarışı, Futbol Çinko and Rastgele Beşler.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const S = require("../bot_support");
let seq = 61000;
const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice/botSupport";
const policy = {enabled: true, version: 2, betaUids: {alice: true},
  readyModes: Object.fromEntries(S.MODES.map((m) => [m, true]))};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy}, economyState: {alice: {
  balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
      .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const start = async (h, mode) => (await h.call("actBotSupport", {mode, action: "start", requestId: id(),
  version: S.VERSION, clubId: "club:141"})).session;
const act = async (h, r, action, extra) => (await h.call("actBotSupport", {mode: r.mode, sessionId: r.id,
  revision: r.revision, version: r.version, action, requestId: id(), ...extra})).session;
const hint = (h, r, itemId, target, extra = {}) => act(h, r, "hint", {itemId, target, paymentSource: "stock",
  ...extra});
const raw = (h, r) => h.read(root + "/sessions/" + r.id);
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;
const result = (r, itemId) => r.hintMenu.items.find((i) => i.id === itemId)?.result;
const player = (pid) => S.catalog.players[pid];

test("menus per mode, in spec order", async () => {
  const h = setup();
  const want = {bot_loto: ["milliyet", "mevki", "uygun_kutu"], bot_team_race: ["milliyet", "mevki", "ilk_harf"],
    bot_cinko: ["milliyet", "mevki", "ilk_harf"], bot_random_five: ["kulup_eslesme", "milliyet", "mevki", "ilk_harf"]};
  for (const [mode, ids] of Object.entries(want)) {
    const r = await start(h, mode);
    assert.equal(r.hintMenu.version, 2, mode);
    assert.equal(r.support, null);
    assert.deepEqual(r.hintMenu.items.map((i) => i.id), ids, mode);
    assert.equal(JSON.stringify(r).includes("countries"), false);
  }
});

test("loto: no ad source offered; the shown player's facts", async () => {
  const h = setup({hint_milliyet: 1, hint_aday: 1}); let r = await start(h, "bot_loto");
  assert.equal(r.hintMenu.ads.allowed, false);
  const service = h.context.lbBotSupportService();
  await assert.rejects(service.prepareHint("alice", "bot_support_hint", {sessionId: r.id, itemId: "milliyet",
    target: r.index}), {code: "permission-denied"});
  const pid = raw(h, r).board.queue[r.index];
  r = await hint(h, r, "milliyet", r.index);
  assert.equal(result(r, "milliyet"), `Bu oyuncunun milliyeti: ${player(pid).countries.join(" / ")}`);
  r = await hint(h, r, "uygun_kutu", r.index);
  const criteria = raw(h, r).board.criteria.map((k) => S.catalog.criteria[k]);
  assert.ok(criteria.some((k) => S.matches(pid, k.id) && result(r, "uygun_kutu").includes(k.label)));
});

test("team race: a remaining shared player; once per game", async () => {
  const h = setup({hint_isim: 2}); let r = await start(h, "bot_team_race");
  r = await hint(h, r, "ilk_harf", r.round);
  const race = raw(h, r).race;
  const rest = race.players.filter((x) => !race.found?.[x]);
  assert.ok(rest.some((x) => result(r, "ilk_harf").endsWith(": " + [...player(x).name].find((c) => /\p{L}/u.test(c)))));
  await assert.rejects(hint(h, r, "ilk_harf", r.round), {code: "already-exists"});
  assert.equal(qty(h, "hint_isim"), 1);
});

test("cinko: byTarget per playable cell; nationality is not offered on a country cell", async () => {
  const h = setup({hint_milliyet: 1}); const r = await start(h, "bot_cinko");
  const cells = raw(h, r).cells;
  for (const [t, ids] of Object.entries(r.hintMenu.byTarget)) {
    const k = S.catalog.criteria[cells[Number(t)]];
    assert.equal(ids.includes("milliyet"), k.type !== "country", k.id);
  }
});

test("random five: how many of the five clubs a candidate matches", async () => {
  const h = setup({hint_kulup: 1}); let r = await start(h, "bot_random_five");
  r = await hint(h, r, "kulup_eslesme", r.round);
  assert.match(result(r, "kulup_eslesme"), /beş kulübün \d tanesine uyuyor/);
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {boosts: {...policy, version: undefined}}}, {omitEmptyObjects: true});
  const r = await start(h, "bot_cinko");
  assert.equal(r.hintMenu, null);
  assert.equal(r.support.version, 1);
});
