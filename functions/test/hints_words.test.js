"use strict";
// İpucu v2 menus for Lingo, Mini/Haftalık Passaparola, Günün Anagramı and Sekizli Anagram.
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {harness} = require("./support/economy_harness");
const A = require("../anagram_practice");
const {normalize} = require("../daily_words");
let seq = 81000; const id = () => (++seq).toString(16).padStart(32, "0");
const root = "economyState/alice";
const policy = {enabled: true, version: 2, betaUids: {alice: true}, readyModes: {daily_lingo: true,
  daily_anagram: true, passa_daily: true, passa_weekly: true, anagram_practice: true}};
function setup(inventory = {}) {
  const h = harness({runtimeConfig: {dailyWords: {enabled: true, rewardsEnabled: true}, boosts: policy},
    economyState: {alice: {balances: {coins: 1000}, inventory: Object.fromEntries(Object.entries(inventory)
        .map(([k, q]) => [k, {itemId: k, itemType: "boost", quantity: q}]))}}}, {omitEmptyObjects: true});
  h.setTime(Date.parse("2026-10-19T10:00:00+03:00")); return h;
}
const bucket = (s) => s.mode === "passa_weekly" ? `weeks/${s.period}` : `days/${s.period}/${s.mode}`;
const raw = (h, s) => h.read(`${root}/dailyWords/${bucket(s)}`);
const load = async (h, mode) => (await h.call("getDailyWords", {mode})).session;
const act = async (h, s, extra) => (await h.call("actDailyWords", {mode: s.mode, period: s.period,
  packId: s.packId, contentVersion: s.contentVersion, revision: s.revision, questionId: s.questionId,
  requestId: id(), ...extra})).session;
const hint = (h, s, itemId, extra = {}) => act(h, s, {action: "hint", itemId, paymentSource: "stock", ...extra});
const qty = (h, key) => h.read(`${root}/inventory/${key}/quantity`) || 0;
const result = (s, itemId) => s.hintMenu.items.find((i) => i.id === itemId)?.result;

test("lingo: four items, usable before any guess", async () => {
  const h = setup({hint_milliyet: 1, hint_harf: 2, hint_isim: 1}); let s = await load(h, "daily_lingo");
  assert.equal(s.support, undefined);
  assert.deepEqual(s.hintMenu.items.map((i) => i.id), ["ipucu", "harf_yeri", "son_harf", "ilk_harf"]);
  const q = raw(h, s).puzzle;
  s = await hint(h, s, "ilk_harf");
  assert.equal(result(s, "ilk_harf"), `İlk harf: ${q.answer[0]}`);
  s = await hint(h, s, "son_harf");
  assert.equal(result(s, "son_harf"), `Son harf: ${q.answer.at(-1)}`);
  s = await hint(h, s, "harf_yeri");
  const m = result(s, "harf_yeri").match(/^(\d+)\. harf: (.)$/);
  assert.equal(q.answer[Number(m[1]) - 1], m[2]);
  s = await hint(h, s, "ipucu");
  assert.equal(result(s, "ipucu"), q.hint);
  assert.equal(s.hint, q.hint);
  await assert.rejects(hint(h, s, "ipucu"), {code: "already-exists"});
});

test("passa: per question; the next question resets the board", async () => {
  const h = setup({hint_harf: 3}); let s = await load(h, "passa_daily");
  const ids = s.hintMenu.items.map((i) => i.id);
  assert.ok(ids.includes("harf_sayisi") && ids.includes("harf_yeri") && ids.includes("son_harf"), ids.join());
  const q = raw(h, s).questions[s.index];
  s = await hint(h, s, "harf_sayisi");
  assert.equal(result(s, "harf_sayisi"), `Cevap ${normalize(q.answer).length} harften oluşur.`);
  assert.equal(s.question.hint, result(s, "harf_sayisi"));
  await assert.rejects(hint(h, s, "harf_sayisi"), {code: "already-exists"});
  s = await act(h, s, {action: "skip"});
  s = await hint(h, s, "harf_sayisi");
  assert.equal(qty(h, "hint_harf"), 1);
});

test("passa: İlk harf only where the rule does not give it", async () => {
  const h = setup(); const s = await load(h, "passa_daily");
  const q = raw(h, s).questions[s.index];
  assert.equal(s.hintMenu.items.some((i) => i.id === "ilk_harf"), q.rule === "contains");
});

test("daily anagram: five items; light ones cost 10 points, İlk harf 25", async () => {
  const h = setup({hint_milliyet: 1, hint_isim: 1}); let s = await load(h, "daily_anagram");
  const ids = s.hintMenu.items.map((i) => i.id);
  for (const x of ["milliyet", "mevki", "son_harf", "ilk_harf"]) assert.ok(ids.includes(x), x);
  const q = raw(h, s).questions[0];
  s = await hint(h, s, "milliyet");
  assert.equal(result(s, "milliyet"), q.countryLabel);
  s = await hint(h, s, "ilk_harf");
  assert.equal(s.rounds[0].firstLetter, q.answer[0]);
  s = await act(h, s, {action: "guess", answer: q.answer});
  assert.equal(s.rounds[0].score, 100 - 10 - 25);
});

test("practice anagram shares the menu and pays through the kernel", async () => {
  const h = setup({hint_mevki: 1});
  let r = (await h.call("actAnagramPractice", {requestId: id(), action: "start", contentVersion: A.version,
    expectedEnergyCost: 0})).session;
  assert.equal(r.hintMenu.version, 2);
  r = (await h.call("actAnagramPractice", {requestId: id(), action: "hint", itemId: "mevki", paymentSource: "stock",
    packId: r.packId, contentVersion: r.contentVersion, revision: r.revision, questionId: r.questionId})).session;
  assert.match(result(r, "mevki"), /Kaleci|Defans|Orta saha|Forvet/);
  assert.equal(qty(h, "hint_mevki"), 0);
});

test("v1 policy keeps today's supports", async () => {
  const h = harness({runtimeConfig: {dailyWords: {enabled: true}, boosts: {...policy, version: undefined}}},
      {omitEmptyObjects: true});
  h.setTime(Date.parse("2026-10-19T10:00:00+03:00"));
  const s = await load(h, "daily_lingo");
  assert.equal(s.hintMenu, undefined);
  assert.equal(s.support.version, 1);
});
