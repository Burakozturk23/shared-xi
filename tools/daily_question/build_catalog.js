"use strict";
// Reproducible import of already sourced, editor-reviewed story facts.
// Never pad the bank with generated/unreviewed trivia to meet a numerical target.
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "../..");
const load = (name) => require(path.join(root, "functions", name));
const questions = [];
function add(category, task, prefix, sources, sourceId) {
  if (task.answerKeys?.length !== 1 || task.options?.length < 3) return;
  const correct = task.options.find((o) => (o.id || o.key) === task.answerKeys[0]);
  if (!correct) return;
  const wrong = task.options.filter((o) => o !== correct).slice(0, 2);
  const options = [correct, ...wrong].map((o) => o.label);
  if (new Set(options).size !== 3) return;
  const links = (sources || []).map((s) => typeof s === "string" ? {url: s} : s).filter((s) => /^https:\/\//.test(s.url));
  if (!links.length) return;
  questions.push({id: `q_${category}_${sourceId}`, category,
    prompt: prefix + (task.prompt || task.question), options, answer: 0,
    explanation: task.explanation || task.result?.story || task.result?.evidence || correct.label,
    sources: links, sourceId, provenance: "existing_story_catalog", review: "inherited"});
}
const journeys = Object.values(load("player_journey").journeys);
for (const j of journeys) {
  for (const t of j.tasks) add("career", t, `${j.name} · `, j.sources, t.id);
  const timeline = j.tasks.find((t) => t.type === "timeline" && t.answerKeys?.length >= 3);
  if (timeline) {
    const route = timeline.answerKeys.map((key) => timeline.options.find((o) => o.key === key)?.label);
    if (!route.every(Boolean) || !j.sources?.length) continue;
    questions.push({id: "q_player_" + j.id, category: "player",
      prompt: `A takım kariyerinde bu kulüplerde bu sırayla oynayan futbolcu kim? ${route.join(" → ")}`,
      options: [j.name, ...journeys.filter((x) => x.id !== j.id).slice(0, 2).map((x) => x.name)], answer: 0,
      explanation: `${j.name}. ${timeline.explanation}`, sources: j.sources.map((s) => typeof s === "string" ? {url: s} : s),
      sourceId: timeline.id, provenance: "existing_story_catalog", review: "inherited"});
  }
}
for (const s of Object.values(load("what_if").scenarios)) {
  // Only the historical route. Fictional endings must never become quiz facts.
  const route = s.routes.find((r) => r.kind === "history");
  // Teammate-only facts belong to other days, not the transfer category.
  if (route && !["gerrard", "rooney", "baresi", "ronaldo_nazario", "makelele"].includes(s.id)) {
    add("transfer", route.task, "", s.sources, route.task.id);
  }
}
for (const [module, category] of [["ucl_moments", "ucl"], ["international_glory", "international"]]) {
  for (const m of Object.values(load(module).matches)) add(category, m,
      `${m.date} · ${m.home.name} – ${m.away.name} · `, m.result?.sources, m.id);
}
for (const t of Object.values(load("nostalgia").tasks)) add("turkey", t, "", t.sources, t.id);
for (const t of Object.values(load("derby_day").tasks)) add("derby", t,
    `${t.clubs.join(" – ")} · `, t.result?.sources, t.id);
// Remove dependencies on the story's preceding task without revealing its answer.
const standalonePrompts = {
  tn2_c01_t2: "1968–69 Fuar Şehirleri Kupası yarı finalinde Göztepe’nin rakibi hangi Macar kulübüydü?",
  tn2_c02_t2: "Trabzonspor’u 1975–76 sezonundaki ilk lig şampiyonluğuna taşıyan teknik direktör kimdi?",
  tn2_c03_t2: "1988–89 sezonunda 29 golle ligin gol kralı olan Fenerbahçeli futbolcu kimdi?",
  tn2_c07_t1: "2002 Dünya Kupası’nda Türkiye’yi Senegal karşısında altın golle yarı finale taşıyan kimdi?",
  tn2_c08_t1: "Fenerbahçe’yi 2007–08 sezonunda Şampiyonlar Ligi çeyrek finaline taşıyan teknik direktör kimdi?",
  tn2_c09_t2: "EURO 2008 çeyrek finalinde Türkiye’nin Hırvatistan karşısındaki uzatma beraberliğini sağlayan kimdi?",
  tn2_c10_t2: "Bursaspor’u 2009–10 sezonunda lig şampiyonluğuna taşıyan teknik direktör kimdi?",
  tn2_c12_t1: "Beşiktaş, 2017–18 Şampiyonlar Ligi grubunu kaç puanla lider bitirdi?",
};
for (const q of questions) if (standalonePrompts[q.sourceId]) q.prompt = standalonePrompts[q.sourceId];
// Keep the correct option in a stable, balanced position. No answers ship in Flutter assets.
for (const [i, q] of questions.entries()) {
  const pos = i % 3;
  [q.options[0], q.options[pos]] = [q.options[pos], q.options[0]]; q.answer = pos;
  // Difficulty remains editorial metadata, not a claim of empirically measured difficulty.
  q.difficulty = i % 20 < 10 ? "easy" : i % 20 < 17 ? "medium" : "hard";
}
const counts = Object.fromEntries(["career", "ucl", "turkey", "transfer", "player", "international", "derby"].map((c) => [c, questions.filter((q) => q.category === c).length]));
if (Object.values(counts).some((n) => n < 13)) throw new Error("At least 13 questions per weekday required: " + JSON.stringify(counts));
const bank = {version: 1, targetCount: 700, reviewPolicy: "Inherited sourced catalog; new entries require editorial review before import", questions};
fs.writeFileSync(path.join(root, "functions/config/daily_question_catalog.json"), JSON.stringify(bank, null, 2) + "\n");
console.log(JSON.stringify({count: questions.length, counts}));
