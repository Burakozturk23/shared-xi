"use strict";
// Read-only: real coin income per source from an RTDB export of /economyState
// (Firebase console > Realtime Database > Export JSON, or `firebase database:get
// /economyState > economy.json`). No live access and no user ids in the output.
//   node tools/coin_sources.js economy.json [--days 14] [--until 2026-11-30]
// Prints, for the last N Istanbul days: active player-days, mean and median
// daily income per active player, and each sourceType's share. This checks the
// budget registry's "rutin" and "tam oyuncu" bands against live data.
const fs = require("node:fs");

const dayKey = (ms) => new Intl.DateTimeFormat("en-CA", {timeZone: "Europe/Istanbul", year: "numeric",
  month: "2-digit", day: "2-digit"}).format(new Date(ms));

/** Paid coin packs are money, not gameplay income. */
const PAID = new Set(["google_play_purchase", "google_play_refund"]);

function summarize(economyState, {days = 14, until = dayKey(Date.now())} = {}) {
  const end = Date.parse(until + "T23:59:59+03:00");
  const start = end - days * 86400000;
  const perPlayerDay = new Map(); const bySource = {};
  for (const [uid, state] of Object.entries(economyState || {})) {
    for (const claim of Object.values(state?.claims || {})) {
      const at = Number(claim?.claimedAt); const amount = Number(claim?.amount);
      if (!Number.isFinite(at) || at < start || at > end || !(amount > 0) || PAID.has(claim.sourceType)) continue;
      const key = uid + "|" + dayKey(at);
      perPlayerDay.set(key, (perPlayerDay.get(key) || 0) + amount);
      const type = String(claim.sourceType || "unknown");
      bySource[type] = (bySource[type] || 0) + amount;
    }
  }
  const daily = [...perPlayerDay.values()].sort((a, b) => a - b);
  const total = daily.reduce((n, v) => n + v, 0);
  const median = daily.length ? (daily.length % 2 ? daily[(daily.length - 1) / 2] :
    (daily[daily.length / 2 - 1] + daily[daily.length / 2]) / 2) : 0;
  const round = (n) => Math.round(n * 100) / 100;
  return {days, until, playerDays: daily.length, mean: round(daily.length ? total / daily.length : 0),
    median: round(median), p90: daily.length ? daily[Math.floor(daily.length * 0.9)] : 0,
    sources: Object.entries(bySource).sort((a, b) => b[1] - a[1])
        .map(([sourceType, coins]) => ({sourceType, coins, share: round(total ? coins / total : 0),
          perPlayerDay: round(daily.length ? coins / daily.length : 0)}))};
}

function markdown(s, band) {
  return [`# Canlı coin geliri (${s.days} gün, ${s.until} dahil)`, "",
    `Aktif oyuncu-gün: ${s.playerDays}. Günlük gelir: ortalama **${s.mean}**, medyan **${s.median}**, ` +
      `%90'lık dilim ${s.p90} coin.`,
    band ? `Bütçe bantları: rutin ${band.routineMin}–${band.routineMax}, tam oyuncu en çok ${band.fullPlayerMax}.` : "",
    "", "| Kaynak | Coin | Pay | Oyuncu-gün başına |", "| --- | --- | --- | --- |",
    ...s.sources.map((r) => `| ${r.sourceType} | ${r.coins} | %${Math.round(r.share * 100)} | ${r.perPlayerDay} |`),
    ""].join("\n");
}

if (require.main === module) {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith("--") && !/^\d/.test(a));
  if (!file) {
    process.stderr.write("Kullanım: node tools/coin_sources.js economy.json [--days 14] [--until YYYY-MM-DD]\n");
    process.exitCode = 1;
  } else {
    const opt = (name) => args[args.indexOf("--" + name) + 1];
    const raw = JSON.parse(fs.readFileSync(file, "utf8"));
    const s = summarize(raw.economyState || raw, {days: args.includes("--days") ? Number(opt("days")) : 14,
      until: args.includes("--until") ? opt("until") : undefined});
    process.stdout.write(markdown(s, require("../config/economy_budget.json").band));
  }
}

module.exports = {summarize, markdown, dayKey};
