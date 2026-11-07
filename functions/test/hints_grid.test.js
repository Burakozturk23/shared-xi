"use strict";
// İpucu v2 menus for the six Grid modes (solo and bot).
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const G = require("../grid_support");
let seq = 51000;
const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice/gridSupport";
const policy = {enabled: true, version: 2, betaUids: {alice: true},
  readyModes: Object.fromEntries(G.MODES.map((m) => [m, true]))};
const setup = (inventory = {}) => harness({runtimeConfig: {boosts: policy}, economyState: {alice: {
  balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
      .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
const load = async (h, mode) => h.call("getGridSupport", {mode});
const start = async (h, mode) => userTurn(h, (await h.call("actGridSupport", {mode, action: "start",
  requestId: id(), version: G.catalog.version})).session);
const act = async (h, r, action, extra) => (await h.call("actGridSupport", {mode: r.mode, sessionId: r.id,
  revision: r.revision, version: r.version, action, requestId: id(), ...extra})).session;
const hint = (h, r, itemId, target, extra = {}) => act(h, r, "hint", {itemId, target, paymentSource: "stock",
  ...extra});
const raw = (h, r) => ({cells: {}, used: {}, rows: {}, cols: {}, axes: {}, ...h.read(root + "/sessions/" + r.id)});
const qty = (h, key) => h.read(`economyState/alice/inventory/${key}/quantity`) || 0;
const result = (r, itemId) => r.hintMenu.items.find((i) => i.id === itemId)?.result;
async function userTurn(h, r) {
  if (r.turn !== "bot") return r;
  h.setTime(h.now + 2500); return (await load(h, r.mode)).session;
}
const openCell = (r) => [0, 1, 2, 3, 4, 5, 6, 7, 8].find((i) => !r.cells[i]);

test("classic and random: menu lists the spec items; reverse its own", async () => {
  const h = setup();
  for (const mode of ["solo_grid_classic", "bot_grid_random"]) {
    const r = await start(h, mode);
    assert.equal(r.hintMenu.version, 2);
    assert.equal(r.support, null);
    assert.deepEqual(r.hintMenu.items.map((i) => i.id), ["milliyet", "mevki", "lig", "baska_kulup", "ilk_harf"]);
    assert.deepEqual(r.hintMenu.suggested, ["milliyet", "ilk_harf"]);
  }
  const rev = await start(h, "solo_grid_reverse");
  assert.deepEqual(rev.hintMenu.items.map((i) => i.id), ["kriter_turu", "yanlis_kriter", "kriter_harf"]);
});

test("classic: each item describes one valid candidate of the selected cell", async () => {
  const h = setup({hint_milliyet: 1, hint_mevki: 1, hint_kulup: 2, hint_isim: 1});
  let r = await start(h, "solo_grid_classic");
  // A cell whose row/column is a country or position does not sell that item again.
  const cell = Number(Object.entries(r.hintMenu.byTarget).find(([, ids]) => ids.length === 5)?.[0] ?? openCell(r));
  const offered = r.hintMenu.byTarget[cell];
  const answers = G.answers(raw(h, r), cell).map((x) => G.catalog.players[x]);
  for (const item of offered) r = await hint(h, r, item, cell);
  if (offered.includes("milliyet")) {
    assert.ok(answers.some((p) => result(r, "milliyet").includes(p.countries.join(" / "))));
  }
  if (offered.includes("mevki")) assert.ok(/Kaleci|Defans|Orta saha|Forvet/.test(result(r, "mevki")));
  assert.ok(answers.some((p) => p.clubs.some((c) => result(r, "baska_kulup").includes(G.catalog.clubs[c].name))));
  assert.ok(answers.some((p) => p.clubs.some((c) => G.catalog.clubs[c].league &&
    result(r, "lig").includes(G.catalog.clubs[c].league))));
  assert.ok(answers.some((p) => result(r, "ilk_harf").endsWith(": " + [...p.name].find((c) => /\p{L}/u.test(c)))));
  const row = raw(h, r).rows[Math.floor(cell / 3)]; const col = raw(h, r).cols[cell % 3];
  for (const k of [row, col].filter((x) => x.startsWith("club:"))) {
    assert.ok(!result(r, "baska_kulup").includes(G.catalog.criteria[k].label));
  }
  assert.equal(qty(h, "hint_kulup"), 0);
});

test("byTarget lists what each open cell can produce", async () => {
  const h = setup({hint_kulup: 1}); const r = await start(h, "solo_grid_classic");
  const cell = openCell(r);
  assert.ok(r.hintMenu.byTarget[cell].includes("ilk_harf"));
  for (const [t, ids] of Object.entries(r.hintMenu.byTarget)) {
    if (!ids.includes("baska_kulup")) {
      await assert.rejects(hint(h, r, "baska_kulup", Number(t)), {code: "failed-precondition"});
      assert.equal(qty(h, "hint_kulup"), 1);
    }
  }
  assert.equal((await start(h, "solo_grid_random")).hintMenu.byTarget, null);
});

test("once per board, not per cell", async () => {
  const h = setup({hint_milliyet: 2}); let r = await start(h, "solo_grid_classic");
  const cells = Object.entries(r.hintMenu.byTarget).filter(([, ids]) => ids.includes("milliyet"))
      .map(([t]) => Number(t));
  if (cells.length < 2) return;
  r = await hint(h, r, "milliyet", cells[0]);
  const other = cells[1];
  await assert.rejects(hint(h, r, "milliyet", other), {code: "already-exists"});
  assert.equal(qty(h, "hint_milliyet"), 1);
});

test("reverse: criterion type, a wrong criterion and the first letter of a valid one", async () => {
  const h = setup({hint_kulup: 1, hint_ele: 1, hint_isim: 1}); let r = await start(h, "solo_grid_reverse");
  const axis = [0, 1, 2, 3, 4, 5].find((i) => !r.axes[i]);
  const valid = G.common(raw(h, r), axis);
  r = await hint(h, r, "kriter_turu", axis);
  assert.match(result(r, "kriter_turu"), /Kulüp|Milliyet|Mevki/);
  r = await hint(h, r, "kriter_harf", axis);
  assert.ok(valid.some((k) => result(r, "kriter_harf").endsWith(": " + [...k.label].find((c) => /\p{L}/u.test(c)))));
  assert.deepEqual(Object.keys(r.hintMenu.byTarget).map(Number).sort(), [0, 1, 2, 3, 4, 5].filter((i) => !r.axes[i]));
  if (r.hintMenu.byTarget[axis].includes("yanlis_kriter")) {
    r = await hint(h, r, "yanlis_kriter", axis);
    assert.ok(!valid.some((k) => result(r, "yanlis_kriter").includes(`: ${k.label}`)));
  }
});

test("bot turn: a hint is refused while the bot plays", async () => {
  const h = setup({hint_milliyet: 1}); let r = await start(h, "bot_grid_classic");
  r = await act(h, r, "guess", {target: openCell(r),
    playerId: G.answers(raw(h, r), openCell(r))[0]});
  if (r.turn !== "bot") return;
  await assert.rejects(hint(h, r, "milliyet", openCell(r)), {code: "failed-precondition"});
  assert.equal(qty(h, "hint_milliyet"), 1);
});

test("coins and ads go through the kernel", async () => {
  const h = setup(); let r = await start(h, "solo_grid_random");
  r = await act(h, r, "generate", {});
  r = await hint(h, r, "milliyet", "pending", {paymentSource: "coins", expectedPriceCoins: 25});
  assert.equal(h.read("economyState/alice/balances/coins"), 975);
  const service = h.context.lbGridSupportService();
  const benefit = await service.prepareHint("alice", "grid_support_hint", {sessionId: r.id, itemId: "mevki"});
  await service.settleHint("alice", {id: "e".repeat(48), context: benefit.context});
  r = (await load(h, r.mode)).session;
  r = await hint(h, r, "mevki", "pending", {paymentSource: "ad"});
  assert.ok(result(r, "mevki"));
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {boosts: {...policy, version: undefined}}}, {omitEmptyObjects: true});
  const r = await start(h, "solo_grid_classic");
  assert.equal(r.hintMenu, null);
  assert.equal(r.support.version, 1);
});
