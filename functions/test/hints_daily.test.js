"use strict";
// İpucu v2 menus for Günün Sorusu, Günün Maçları and Günün Futbolcusu.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const {dayKey} = require("../rewarded_ads");
const catalog = require("../config/daily_catalog.json");
let seq = 91000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
const policy = {enabled: true, version: 2, betaUids: {alice: true},
  readyModes: {daily_question: true, daily_match: true, daily_footballer: true}};
function setup(inventory = {}) {
  const h = harness({runtimeConfig: {dailyQuestion: {enabled: true}, boosts: policy},
    economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
        .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
  const day = dayKey(h.now);
  h.seed("daily_fixtures/" + day, {updatedAt: h.now, matches: [1, 2].map((fixtureId) => ({fixtureId,
    homeName: "Fenerbahce", awayName: "Besiktas", kickoff: day + "T20:00:00+03:00", leagueId: 203,
    isDerby: true, leagueName: "Süper Lig", status: "NS"}))});
  return h;
}
const qty = (h, key) => h.read(`${root}/inventory/${key}/quantity`) || 0;
const result = (menu, itemId) => menu.items.find((i) => i.id === itemId)?.result;

test("daily question: one wrong option is eliminated; the answer is never given away", async () => {
  const h = setup({hint_ele: 1}); let v = await h.call("getDailyQuestion");
  assert.equal(v.session.hintMenu.version, 2);
  assert.deepEqual(v.session.hintMenu.items.map((i) => i.id), ["bir_yanlis"]);
  assert.equal(v.session.hintMenu.ads.remaining, 1);
  v = await h.call("useDailyQuestionHint", {sessionId: v.session.id, revision: v.session.revision,
    day: v.question.day, questionId: v.question.id, requestId: id(), itemId: "bir_yanlis", paymentSource: "stock"});
  const answer = h.read("dailyQuestionPrivate/" + v.question.day).answer;
  assert.notEqual(v.eliminated, answer);
  assert.equal(result(v.session.hintMenu, "bir_yanlis"), `Elenen şık: ${v.question.options[v.eliminated]}`);
  assert.equal(qty(h, "hint_ele"), 0);
});

test("daily match: a shared player not found yet", async () => {
  const h = setup({hint_milliyet: 1, hint_mevki: 1, hint_isim: 1});
  let r = (await h.call("startDailyMatch", {fixtureId: 1})).session;
  assert.deepEqual(r.hintMenu.items.map((i) => i.id), ["milliyet", "mevki", "soyad_harf"]);
  for (const item of ["milliyet", "mevki", "soyad_harf"]) {
    r = (await h.call("playDailyMatch", {key: r.key, action: "hint", revision: r.revision, requestId: id(),
      itemId: item, paymentSource: "stock"})).session;
  }
  const answers = h.read(`${root}/dailyMatches/sessions/${r.key}/answers`) ||
    h.read(`dailyMatchState/alice/sessions/${r.key}/answers`);
  const players = (answers || []).map((x) => catalog.players[x]);
  assert.ok(players.some((p) => result(r.hintMenu, "milliyet").endsWith(p.country)));
  assert.match(result(r.hintMenu, "soyad_harf"), /^Ortak bir oyuncunun soyadı .+ ile başlıyor$/);
  await assert.rejects(h.call("playDailyMatch", {key: r.key, action: "hint", revision: r.revision,
    requestId: id(), itemId: "milliyet", paymentSource: "stock"}), {code: "already-exists"});
});

test("daily footballer: four items about today's target, before the first guess", async () => {
  const h = setup({hint_milliyet: 1, hint_kulup: 1, hint_donem: 1, hint_isim: 1});
  let r = (await h.call("getDailyFootballer")).session;
  assert.deepEqual(r.hintMenu.items.map((i) => i.id), ["milliyet", "lig", "yas", "isim_ipucu"]);
  const target = h.read(`${root}/dailyFootballer/days/${r.dayKey}/target`);
  for (const item of ["milliyet", "lig", "yas", "isim_ipucu"]) {
    r = (await h.call("actDailyFootballer", {requestId: id(), day: r.dayKey, sessionId: r.id, revision: r.revision,
      action: "hint", itemId: item, paymentSource: "stock"})).session;
  }
  assert.equal(result(r.hintMenu, "milliyet"), `Ülkesi: ${target.country}`);
  assert.equal(result(r.hintMenu, "lig"), `Ligi: ${target.league}`);
  assert.match(result(r.hintMenu, "yas"), /^Yaşı: \d+$/);
  assert.match(result(r.hintMenu, "isim_ipucu"), /^Adı . harfiyle başlıyor/);
  assert.equal(r.hint, result(r.hintMenu, "isim_ipucu"));
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {dailyQuestion: {enabled: true}, boosts: {...policy, version: undefined}}},
      {omitEmptyObjects: true});
  const v = await h.call("getDailyQuestion");
  assert.equal(v.session.hintMenu, null);
  assert.equal(v.session.support.version, 1);
});
