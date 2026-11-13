"use strict";
// İpucu v2 menus for Higher or Lower / Blind Ranking (training) and the eight story modes.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const E = require("../choice_engine");
const {definitions} = require("../mission_story_events");
const {content} = require("../story_support");
let seq = 105000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
const metricId = Object.values(E.catalog.metrics).find((m) => m.gatePassed).id;
const policy = {enabled: true, version: 2, betaUids: {alice: true}, readyModes: {higher_lower_training: true,
  blind_ranking_training: true, ...Object.fromEntries(definitions.map((d) => [d[1], true]))}};
const setup = (inventory = {}) => harness({runtimeConfig: {choice: {enabled: true, rewardsEnabled: true},
  boosts: policy}, economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(
    Object.entries(inventory).map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}},
{omitEmptyObjects: true});
const qty = (h, key) => h.read(`${root}/inventory/${key}/quantity`) || 0;
const result = (menu, itemId) => menu.items.find((i) => i.id === itemId)?.result;

async function startChoice(h, mode) {
  const r = (await h.call("prepareChoice", {mode, metricId, version: E.catalog.version, training: true, size: 5,
    requestId: id()})).session;
  return (await h.call("actChoice", {mode, sessionId: r.id, revision: r.revision, requestId: id(),
    action: "confirm"})).session;
}
const choiceHint = async (h, r, itemId) => (await h.call("actChoice", {mode: r.mode, sessionId: r.id,
  revision: r.revision, requestId: id(), action: "hint", itemId, questionId: r.question?.id || r.current?.id,
  paymentSource: "stock"})).session;

test("higher or lower: the value range", async () => {
  const h = setup({hint_donem: 1}); let r = await startChoice(h, "higher_lower");
  assert.deepEqual(r.hintMenu.items.map((i) => i.id), ["aralik"]);
  r = await choiceHint(h, r, "aralik");
  assert.match(result(r.hintMenu, "aralik"), /^Gizli değer .+–.+ aralığında\.$/);
  assert.equal(r.trainingHint, result(r.hintMenu, "aralik"));
  assert.equal(qty(h, "hint_donem"), 0);
});

test("blind ranking: half of the list, then the exact place", async () => {
  const h = setup({hint_donem: 1, hint_baglanti: 1}); let r = await startChoice(h, "blind_ranking");
  assert.deepEqual(r.hintMenu.items.map((i) => i.id), ["yari", "sira_dogrula"]);
  r = await choiceHint(h, r, "yari");
  assert.match(result(r.hintMenu, "yari"), /listenin (üst|alt) yarısında/);
  r = await choiceHint(h, r, "sira_dogrula");
  assert.match(result(r.hintMenu, "sira_dogrula"), /^İstatistikte \d+\. sırada\.$/);
});

const first = (mode) => Object.values(content(mode).targets)[0];
for (const [, mode] of definitions) {
  test(`${mode}: story menu from the task's own data`, async () => {
    const h = setup({hint_donem: 1, hint_ele: 1, hint_baglanti: 1});
    const t = first(mode);
    let v = await h.call("getStorySupport", {mode, targetId: t.task.id});
    assert.equal(v.legacy, false);
    const ids = v.session.hintMenu.items.map((i) => i.id);
    assert.ok(ids.length >= 1, mode);
    for (const x of ids) assert.ok(["gorev_ipucu", "bir_yanlis", "ilk_baglanti"].includes(x), x);
    if (ids.includes("gorev_ipucu")) {
      v = await h.call("useStorySupport", {mode, targetId: t.task.id, contentVersion: v.contentVersion,
        sessionId: v.session.id, revision: v.session.revision, requestId: id(), itemId: "gorev_ipucu",
        paymentSource: "stock"});
      assert.equal(result(v.session.hintMenu, "gorev_ipucu"), t.task.hint);
      assert.equal(qty(h, "hint_donem"), 0);
      await assert.rejects(h.call("useStorySupport", {mode, targetId: t.task.id, contentVersion: v.contentVersion,
        sessionId: v.session.id, revision: v.session.revision, requestId: id(), itemId: "gorev_ipucu",
        paymentSource: "stock"}), {code: "already-exists"});
    }
  });
}
