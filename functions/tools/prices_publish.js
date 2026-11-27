"use strict";
// Faz 1c: the one way to change linkball_prices_v1 in Remote Config.
//   node tools/prices_publish.js <file.json>             validate + show the change (no write)
//   node tools/prices_publish.js <file.json> --publish   also publish it (needs Google credentials)
// The file is a whole price snapshot (same shape as config/linkball_prices.defaults.json).
// A new `revision` is required for every publish; the Remote Config version history,
// with the revision in the parameter description, is the change record.
const fs = require("node:fs");
const path = require("node:path");
const P = require("../price_config");

/** What publishing `next` over `current` would change, or why it must not. */
function plan(current, nextRaw) {
  const errors = [];
  let next = null;
  try {
    next = P.validatePrices(nextRaw);
  } catch (error) {
    errors.push("Geçersiz fiyat dosyası: " + error.message);
    return {errors, changes: [], next};
  }
  const base = current || P.DEFAULT_PRICES;
  if (next.revision === base.revision) errors.push(`revision değişmeli (şu an "${base.revision}").`);
  const changes = [];
  const flag = (on) => on ? "açık" : "kapalı";
  if (base.enabled !== next.enabled) changes.push(`bayrak: ${flag(base.enabled)} → ${flag(next.enabled)}`);
  for (const [id, p] of Object.entries(next.boosts)) {
    const old = base.boosts[id];
    for (const key of ["single", "pack"]) {
      if (old[key] !== p[key]) changes.push(`${id} ${key === "single" ? "tek" : "3'lü"}: ${old[key]} → ${p[key]}`);
    }
  }
  if (!changes.length) errors.push("Değişiklik yok.");
  return {errors, changes, next};
}

async function main(argv) {
  const file = argv.find((a) => !a.startsWith("--"));
  if (!file) throw new Error("Kullanım: node tools/prices_publish.js <dosya.json> [--publish]");
  const nextRaw = JSON.parse(fs.readFileSync(path.resolve(file), "utf8"));
  const publish = argv.includes("--publish");
  let current = null; let rc = null; let template = null;
  if (publish || argv.includes("--remote")) {
    const {initializeApp} = require("firebase-admin/app");
    const {getRemoteConfig} = require("firebase-admin/remote-config");
    const project = JSON.parse(fs.readFileSync(path.join(__dirname, "../../.firebaserc"), "utf8")).projects.default;
    initializeApp({projectId: project});
    rc = getRemoteConfig();
    template = await rc.getTemplate();
    const raw = template.parameters[P.PARAMETER]?.defaultValue?.value;
    current = raw ? P.validatePrices(raw) : null;
  }
  const result = plan(current, nextRaw);
  process.stdout.write(`Karşılaştırılan: ${current ? "Remote Config (" + current.revision + ")" :
    "varsayılan dosya"}\n`);
  for (const line of result.changes) process.stdout.write("  " + line + "\n");
  if (result.errors.length) {
    for (const line of result.errors) process.stdout.write("HATA: " + line + "\n");
    process.exitCode = 1;
    return;
  }
  if (!publish) {
    process.stdout.write("Kontrol tamam. Yayınlamak için --publish ekle.\n");
    return;
  }
  const {configId, ...snapshot} = result.next;
  template.parameters[P.PARAMETER] = {
    defaultValue: {value: JSON.stringify(snapshot)},
    description: `Linkball fiyatları · ${snapshot.revision} · ${configId}`,
    valueType: "JSON",
  };
  const validated = await rc.validateTemplate(template);
  const published = await rc.publishTemplate(validated);
  process.stdout.write(`Yayınlandı: Remote Config sürümü ${published.version?.versionNumber}.\n`);
}

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(error.message + "\n");
    process.exitCode = 1;
  });
}

module.exports = {plan};
