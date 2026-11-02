"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const report = require("../tools/economy_report");

const clone = (x) => JSON.parse(JSON.stringify(x));

test("budget registry matches the code: values, pinned constants, sources and band", () => {
  assert.deepEqual(report.problems(), []);
});

test("the report measures the declared totals and prints one Markdown document", () => {
  const m = report.measure();
  assert.equal(m.totals.routineAverage, 168.57);
  assert.equal(m.totals.routineAverageMissionsV3, 223.57);
  assert.equal(m.totals.oneTimeSupply, 6850);
  assert.equal(m.totals.cosmeticCatalog, 63400);
  const text = report.markdown(m);
  assert.match(text, /^# Linkball ekonomi raporu/);
  for (const section of ["## Kaynaklar", "## Harcamalar", "## Türetilmiş ölçüler", "## Fiyat ayarı (Faz 1c)"]) {
    assert.ok(text.includes(section), section);
  }
});

test("an unregistered coin source breaks the budget check", () => {
  const code = report.readCode();
  code["new_mode.js"] = "async function x() {\n  await grantCoins(uid, id, \"new_mode_reward\", key, 50, \"v1\");\n}\n";
  assert.ok(report.problems(report.measure(), code).some((p) => p.includes("kayıtsız coin kaynağı: new_mode_reward")));
  // A grant whose source type is a variable is counted too.
  code["new_mode.js"] = "async function x() {\n  await grantCoins(uid, id, receipt.type, key, 50, \"v1\");\n}\n";
  assert.ok(report.problems(report.measure(), code).some((p) => p.startsWith("değişken kaynaklı coin çağrıları")));
  // So is a new file writing to the wallet directly.
  code["new_mode.js"] = "state.lifetimeEarned += amount;\n";
  assert.ok(report.problems(report.measure(), code).some((p) => p.startsWith("lifetimeEarned yazan dosyalar")));
});

test("a routine total outside the band, a changed cap or a slow catalog breaks the check", () => {
  const m = report.measure();
  const high = clone(m); high.totals.routineAverage = 231;
  assert.ok(report.problems(high).some((p) => p.startsWith("rutin gelir 231")));
  // The v3 mission slots count against the same band.
  const v3 = clone(m); v3.totals.routineAverageMissionsV3 = 240;
  assert.ok(report.problems(v3).some((p) => p.startsWith("v3 rutin gelir 240")));
  const capped = clone(m); capped.measured.squad_challenge.average = 120;
  assert.ok(report.problems(capped).some((p) => p.startsWith("squad_challenge.average")));
  const slow = clone(m); slow.totals.catalogDays = 401;
  assert.ok(report.problems(slow).some((p) => p.startsWith("katalog 401")));
  const code = report.readCode();
  code["career_transfer.js"] = code["career_transfer.js"].replace("36 - d.coins", "48 - d.coins");
  assert.ok(report.problems(m, code).some((p) => p.startsWith("career_transfer: career_transfer.js")));
});

test("coin source summary: per player-day mean and median, paid packs excluded, window respected", () => {
  const {summarize} = require("../tools/coin_sources");
  const at = (day, h = 12) => Date.parse(`${day}T${String(h).padStart(2, "0")}:00:00+03:00`);
  const s = summarize({
    a: {claims: {
      x: {sourceType: "daily_reward", amount: 10, claimedAt: at("2026-11-29")},
      y: {sourceType: "mission_reward", amount: 50, claimedAt: at("2026-11-29")},
      z: {sourceType: "google_play_purchase", amount: 500, claimedAt: at("2026-11-29")},
      old: {sourceType: "daily_reward", amount: 99, claimedAt: at("2026-10-01")},
    }},
    b: {claims: {w: {sourceType: "daily_reward", amount: 30, claimedAt: at("2026-11-30")}}},
  }, {days: 14, until: "2026-11-30"});
  assert.equal(s.playerDays, 2);
  assert.equal(s.mean, 45); assert.equal(s.median, 45);
  assert.deepEqual(s.sources.map((r) => r.sourceType), ["mission_reward", "daily_reward"]);
  assert.equal(s.sources.find((r) => r.sourceType === "daily_reward").coins, 40);
});
