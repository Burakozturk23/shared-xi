"use strict";
// Faz 1a: read-only economy report. `node tools/economy_report.js` prints one
// Markdown document (sources, sinks, derived measures). It reads config files,
// module constants and the budget registry; it never touches live data.
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const json = (file) => JSON.parse(read(file));
const round = (n, d = 2) => Math.round(n * 10 ** d) / 10 ** d;
const sum = (list) => list.reduce((a, b) => a + b, 0);

/** Every number the report and the budget test need, measured from the code. */
function measure() {
  const economy = require("../economy_config");
  const defaults = economy.defaults;
  const s = defaults.sources;
  const budget = json("config/economy_budget.json");
  const squad = require("../squad_challenge");
  const missions = require("../missions_v3").REWARDS;
  const streak = require("../daily_streak");
  const choice = json("config/choice_catalog.json").policy;
  const three = json("config/three_modes_catalog.json").policy;
  const store = json("config/store_collection.json").offers.filter((o) => o.enabled);
  const energy = json("config/energy_v1.json");
  const B = require("../boosts");
  const prices = require("../price_config");
  const coinPacks = require("../coin_purchases").PRODUCTS;

  const story = {};
  for (const [id, file, list] of [["derby_day", "derby_day", "tasks"], ["dynasties", "dynasties", "tasks"],
    ["football_docu", "football_docu", "tasks"], ["international_glory", "international", "matches"],
    ["ucl_moments", "ucl", "matches"]]) {
    const c = json(`config/${file}_catalog.json`);
    const each = (c.economy.task || c.economy.match).coins;
    story[id] = c[list].length * each + sum(c.economy.milestones.map((m) => m.coins));
  }
  const nostalgia = json("config/nostalgia_catalog.json");
  story.turkish_nostalgia = sum(nostalgia.chapters.map((c) => c.tasks.length)) * nostalgia.economy.task.coins +
    nostalgia.chapters.length * nostalgia.economy.chapter.coins + nostalgia.economy.final.coins;

  const measured = {
    daily_reward: {average: round(sum(s.daily_reward.coinsByDay) / s.daily_reward.coinsByDay.length),
      max: Math.max(...s.daily_reward.coinsByDay)},
    daily_mission: {average: s.daily_mission.amount * s.daily_mission.dailyLimit,
      max: s.daily_mission.amount * s.daily_mission.dailyLimit},
    squad_challenge: {average: sum(s.squad_challenge.rewards),
      max: sum(s.squad_challenge.rewards.map((r) => r + squad.STAR_BONUS[3]))},
    missions_v3_daily: {average: missions.slots.knowledge + missions.slots.discovery + missions.slots.rivalry +
      missions.dailyBonus.coins, max: missions.slots.knowledge + missions.slots.discovery + missions.slots.rivalry +
      missions.dailyBonus.coins},
    missions_v3_weekly: {
      average: round((missions.weekly.coins * missions.weeklyLimit + missions.weeklyBonus.coins) / 7),
      max: missions.weekly.coins * missions.weeklyLimit + missions.weeklyBonus.coins},
    daily_streak: {average: round(streak.FULL_DAY.coins + streak.MILESTONE.coins / 7),
      max: streak.FULL_DAY.coins + streak.MILESTONE.coins},
    choice_completion: {max: 2 * Math.max(...Object.values(choice.this_or_that)) + 6 +
      2 * Math.max(...Object.values(choice.blind_ranking))},
    three_modes: {max: sum(Object.values(three.daily).map((d) => d.coins))},
    rewarded_coin: {average: s.rewarded_coin.enabled ? s.rewarded_coin.amount * s.rewarded_coin.dailyLimit : 0,
      max: s.rewarded_coin.enabled ? s.rewarded_coin.amount * s.rewarded_coin.dailyLimit : 0},
    achievement: {total: sum(Object.values(economy.achievementRewards(economy.DEFAULT_CONFIG)))},
    general_mission: {total: sum(Object.values(s.general_mission.rewards))},
    missions_v3_career: {total: sum(Object.values(missions.career))},
    story_modes: {total: sum(Object.values(story))},
  };

  const byId = Object.fromEntries(budget.sources.map((x) => [x.id, x]));
  const value = (id, key) => measured[id]?.[key] ?? byId[id][key];
  const daily = budget.sources.filter((x) => x.cadence === "daily");
  const routine = daily.filter((x) => x.routine === true);
  const routineAverage = round(sum(routine.map((x) => value(x.id, "average"))));
  const legacyMissions = value("daily_mission", "average");
  const routineAverageMissionsV3 = round(routineAverage - legacyMissions + value("missions_v3_daily", "average"));
  // Every daily source at its busiest day; v3 slots replace the legacy missions, never both.
  const dailyModeCeiling = sum(daily.filter((x) => x.id !== "missions_v3_daily").map((x) => value(x.id, "max")));

  const avatars = store.filter((o) => o.itemType === "avatar");
  const kits = store.filter((o) => o.itemType === "kit");
  // Everything a player can buy once: store avatars and kits plus the four economy-config avatars.
  const legacyAvatars = Object.values(defaults.sinks.cosmetics.offers).filter((o) => o.enabled);
  const cosmeticCatalog = sum([...avatars, ...kits, ...legacyAvatars].map((o) => o.priceCoins));
  const oneTimeSupply = value("achievement", "total") + value("general_mission", "total");

  const sinks = [
    ...B.offers.map((o) => ({id: o.offerId, label: o.title, price: o.priceCoins, group: "Güçlendirme"})),
    ...store.filter((o) => o.itemType === "boost").map((o) => ({id: o.offerId, label: o.title + " (eski)",
      price: o.priceCoins, group: "Güçlendirme"})),
    {id: "avatars", label: `${avatars.length} avatar`, price: sum(avatars.map((o) => o.priceCoins)),
      group: "Kozmetik", count: avatars.length},
    {id: "kits", label: `${kits.length} forma`, price: sum(kits.map((o) => o.priceCoins)), group: "Kozmetik",
      count: kits.length},
    ...(legacyAvatars.length ? [{id: "legacy_avatars", label: `${legacyAvatars.length} eski avatar (ekonomi ayarı)`,
      price: sum(legacyAvatars.map((o) => o.priceCoins)), group: "Kozmetik", count: legacyAvatars.length}] : []),
    ...Object.entries(energy.packages).map(([id, p]) => ({id: "energy_" + id, label: `Enerji +${p.energy}`,
      price: p.coins, group: "Enerji"})),
    {id: "squad_extra", label: "Kadro Mücadelesi ek hakkı", price: defaults.sinks.squad_extra_attempt.priceCoins,
      group: "Hak"},
    ...["derby_day", "dynasties", "football_docu", "international"].map((c) => ({id: c + "_hint",
      label: `${c} ipucu`, price: json(`config/${c}_catalog.json`).economy.hintCoins, group: "Hikâye ipucu"})),
    {id: "nostalgia_hint", label: "nostalgia ipucu", price: nostalgia.economy.hintPrice, group: "Hikâye ipucu"},
  ];

  // Faz 2 supports, valued at their store price (coin equivalent, not coin income).
  const DR = require("../daily_return");
  const price = (id) => B.products[id].priceCoins;
  const loopWeek = Object.values(DR.LOOP_SUPPORTS).reduce((n, id) => n + price(id), 0);
  const bonusWeek = DR.BONUS_WEEKLY_LIMIT * price(DR.BONUS_ITEM);
  const supports = {
    daily_loop: {weeklyValue: loopWeek, monthlyValue: round(loopWeek * 30 / 7)},
    all_missions_bonus: {weeklyValue: bonusWeek, monthlyValue: round(bonusWeek * 30 / 7)},
    streak_first_week: {total: price("boost_basic")},
  };
  const monthlySupportValue = round(supports.daily_loop.monthlyValue + supports.all_missions_bonus.monthlyValue);

  // Release checklist items the code can answer (the live value may differ).
  const index = read("index.js");
  const release = [
    {label: "rewarded_coin kapalı", value: s.rewarded_coin.enabled ? "açık" : "kapalı",
      ok: s.rewarded_coin.enabled === false},
    {label: "Pro satış bayrağı (linkball_pro_sales_enabled) varsayılanı",
      value: index.includes("defaultConfig: {linkball_pro_sales_enabled: \"false\"}") ?
        "false (canlıda true yapılmalı)" : "bilinmiyor", ok: false},
    {label: "Enerji canlıda kapalı başlar", value: energy.rollout.enabled ? "açık" : "kapalı",
      ok: energy.rollout.enabled === false},
    {label: "Faz 2 bayrağı (runtimeConfig/dailyReturn) varsayılanı",
      value: require("../daily_return").OFF.enabled ? "açık" : "kapalı", ok: true},
    {label: "Fiyat ayarı (linkball_prices_v1) varsayılanı", value: prices.DEFAULT_PRICES.enabled ? "açık" : "kapalı",
      ok: prices.DEFAULT_PRICES.enabled === false},
    {label: "Satılan avatarlar iki kademede (300/450)",
      value: [...new Set(avatars.map((o) => o.priceCoins))].sort((a, b) => a - b).join(" / "),
      ok: avatars.every((o) => [300, 450].includes(o.priceCoins))},
  ];

  return {
    budget, measured, story, sinks, coinPacks, supports, release,
    totals: {routineAverage, routineAverageMissionsV3, dailyModeCeiling, oneTimeSupply, cosmeticCatalog,
      monthlySupportValue,
      catalogDays: round(cosmeticCatalog / routineAverage, 0)},
    prices: {parameter: prices.PARAMETER, enabled: prices.DEFAULT_PRICES.enabled,
      boosts: prices.DEFAULT_PRICES.boosts},
  };
}

function markdown(m = measure()) {
  const b = m.budget;
  const v = (x, key) => m.measured[x.id]?.[key] ?? x[key];
  const cell = (n) => n == null ? "ölçülmedi" : String(n);
  const days = (price) => round(price / m.totals.routineAverage, 1);
  const lines = [
    "# Linkball ekonomi raporu", "",
    `Kayıt sürümü ${b.version}. Rutin bant ${b.band.routineMin}–${b.band.routineMax} coin/gün ` +
      `(${b.band.decidedBy})`, "",
    "## Kaynaklar", "",
    "| Kaynak | Sıklık | Ortalama gün | En dolu gün | Tek seferlik | Rutin | Açılma koşulu |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    ...b.sources.map((x) => `| ${x.label} | ${x.cadence} | ${cell(v(x, "average"))} | ${cell(v(x, "max"))} | ` +
      `${x.cadence === "oneTime" || x.cadence === "season" ? cell(v(x, "total")) : ""} | ` +
      `${x.routine === true ? "evet" : x.routine === "missions_v3" ? "v3 açıkken" : ""} | ${x.gate || ""} |`),
    "", "## Harcamalar", "",
    "| Kalem | Grup | Fiyat (coin) | Kaç günlük rutin gelir |", "| --- | --- | --- | --- |",
    ...m.sinks.map((x) => `| ${x.label} | ${x.group} | ${x.price} | ${days(x.price)} |`),
    "", "Coin paketleri (gerçek para): " +
      Object.entries(m.coinPacks).map(([id, n]) => `${id} = ${n}`).join(", ") + ".",
    "", "## Türetilmiş ölçüler", "",
    `- Rutin günlük gelir (ortalama): **${m.totals.routineAverage}** coin.`,
    `- Görevler v3 açıkken rutin gelir: **${m.totals.routineAverageMissionsV3}** coin (+ haftalık ortalama ` +
      `${m.measured.missions_v3_weekly.average}).`,
    `- Tüm günlük kaynakların en dolu günü toplamı: **${m.totals.dailyModeCeiling}** coin.`,
    `- Tek seferlik arz (başarı + genel görev): **${m.totals.oneTimeSupply}** coin.`,
    `- Hikâye modları tek seferlik: ${Object.entries(m.story).map(([k, n]) => `${k} ${n}`).join(", ")} ` +
      `(toplam ${m.measured.story_modes.total}).`,
    `- Kozmetik katalog: **${m.totals.cosmeticCatalog}** coin; rutin gelirle bitirme süresi ` +
      `**${m.totals.catalogDays}** gün (sınır ${b.band.maxCatalogDays}).`,
    "", "## Güçlendirme kaynakları (Faz 2, coin eşdeğeri)", "",
    "| Kaynak | Haftalık | Aylık | Tek seferlik | Açılma koşulu |", "| --- | --- | --- | --- | --- |",
    ...b.supports.map((x) => `| ${x.label} | ${cell(m.supports[x.id]?.weeklyValue ?? x.weeklyValue)} | ` +
      `${cell(m.supports[x.id]?.monthlyValue ?? x.monthlyValue)} | ${x.cadence === "oneTime" ? cell(x.total) : ""} | ` +
      `${x.gate || ""} |`),
    "", `Ücretsiz oyuncunun aylık güçlendirme değeri (hepsi açıkken): **${m.totals.monthlySupportValue}** coin.`,
    "", "## Yayın kontrol listesi (koddaki varsayılanlar)", "",
    "Canlı değerler Remote Config ve runtimeConfig'tedir; bu liste yalnız kodun varsayılanını gösterir.", "",
    ...m.release.map((r) => `- ${r.ok ? "[x]" : "[ ]"} ${r.label}: ${r.value}`),
    "", "## Fiyat ayarı (Faz 1c)", "",
    `Remote Config parametresi \`${m.prices.parameter}\`, varsayılan bayrak: ${m.prices.enabled ? "açık" : "kapalı"}.`,
    ...Object.entries(m.prices.boosts).map(([id, p]) => `- ${id}: tek ${p.single}, 3'lü ${p.pack}`),
    "",
  ];
  return lines.join("\n");
}

/** Server source files (top level of functions/), by name. */
function readCode() {
  return Object.fromEntries(fs.readdirSync(root).filter((f) => f.endsWith(".js") && f !== ".eslintrc.js")
      .map((f) => [f, read(f)]));
}

/**
 * Where coins are granted: literal source types, grant calls whose source type
 * is a variable, and files that add to lifetimeEarned directly.
 */
function scanCode(code) {
  const literal = new Set(); const dynamic = {}; const writers = {};
  const call = /\b(?:grantCoins|lbProgressionGrantCoins)\((?!\.\.\.)([^;]*)/g;
  for (const [file, text] of Object.entries(code)) {
    for (const m of text.matchAll(call)) {
      if (/^\s*$/.test(m[1]) || /^\s*db,\s*$/.test(m[1])) continue;
      // Skip the function's own definition (named parameters, not a call).
      if (text.slice(Math.max(0, m.index - 9), m.index).includes("function")) continue;
      const args = m[1].replace(/^\s*db,\s*/, "").split(",").map((x) => x.trim());
      if (args[0].startsWith("...")) continue; // a pass-through wrapper, not a grant site
      const type = /^"([a-z_]+)"$/.exec(args[2] || "");
      if (type) literal.add(type[1]);
      else dynamic[file] = (dynamic[file] || 0) + 1;
    }
    for (const m of text.matchAll(/\blbPendingReward\(\s*"([a-z_]+)"/g)) literal.add(m[1]);
    const added = (text.match(/\blifetimeEarned \+= /g) || []).length;
    if (added) writers[file] = added;
  }
  return {literal, dynamic, writers};
}

/** Every budget rule that does not hold; empty when the economy matches the registry. */
function problems(m = measure(), code = readCode()) {
  const out = []; const b = m.budget; const t = m.totals;
  const near = (a, e) => Math.abs(a - e) < 0.01;
  for (const x of b.sources) {
    for (const key of ["average", "max", "total"]) {
      const got = m.measured[x.id]?.[key];
      if (got != null && !near(got, x[key])) out.push(`${x.id}.${key}: kayıt ${x[key]}, kod ${got}`);
    }
    for (const pin of x.pins || []) {
      if (!code[pin.file]?.includes(pin.text)) out.push(`${x.id}: ${pin.file} içinde sabit değişti: ${pin.text}`);
    }
  }
  // Both mission systems must fit: the legacy three missions and the v3 slots.
  for (const [label, value] of [["rutin gelir", t.routineAverage], ["v3 rutin gelir", t.routineAverageMissionsV3]]) {
    if (value < b.band.routineMin || value > b.band.routineMax) {
      out.push(`${label} ${value}, bant ${b.band.routineMin}–${b.band.routineMax}`);
    }
  }
  for (const x of b.supports || []) {
    for (const key of ["weeklyValue", "monthlyValue", "total"]) {
      const got = m.supports?.[x.id]?.[key];
      if (got != null && !near(got, x[key])) out.push(`${x.id}.${key}: kayıt ${x[key]}, kod ${got}`);
    }
  }
  for (const key of ["routineAverage", "routineAverageMissionsV3", "oneTimeSupply", "cosmeticCatalog",
    "dailyModeCeiling", "monthlySupportValue"]) {
    if (!near(t[key], b.expected[key])) out.push(`${key}: kayıt ${b.expected[key]}, ölçülen ${t[key]}`);
  }
  if (t.catalogDays > b.band.maxCatalogDays) {
    out.push(`katalog ${t.catalogDays} günde biter (> ${b.band.maxCatalogDays})`);
  }
  const registered = new Set(b.sources.flatMap((x) => x.sourceTypes));
  const scan = scanCode(code);
  for (const type of scan.literal) if (!registered.has(type)) out.push(`kayıtsız coin kaynağı: ${type}`);
  const all = Object.values(code).join("\n");
  for (const type of registered) {
    if (!all.includes(`"${type}"`)) out.push(`kayıttaki kaynak kodda yok: ${type}`);
  }
  for (const [label, got, want] of [["lifetimeEarned yazan dosyalar", scan.writers, b.walletWriters],
    ["değişken kaynaklı coin çağrıları", scan.dynamic, b.dynamicGrantCalls]]) {
    if (JSON.stringify(Object.entries(got).sort()) !== JSON.stringify(Object.entries(want).sort())) {
      out.push(`${label}: kayıt ${JSON.stringify(want)}, kod ${JSON.stringify(got)}`);
    }
  }
  return out;
}

if (require.main === module) {
  if (process.argv.includes("--check")) {
    const found = problems();
    process.stdout.write(found.length ? found.map((x) => "- " + x).join("\n") + "\n" : "Bütçe kaydı kodla uyumlu.\n");
    process.exitCode = found.length ? 1 : 0;
  } else {
    process.stdout.write(markdown());
  }
}

module.exports = {measure, markdown, readCode, scanCode, problems};
