"use strict";
// İpucu v2 menus: Higher or Lower / Blind Ranking training (choice.js) and the eight story modes
// (story_support.js), spec §4.3.
const item = (id, label, type, why) => ({id, label, type, why});
const CHOICE = {
  higher_lower: [item("aralik", "Değer aralığı", "donem", "Gizli değerin hangi aralıkta olduğu.")],
  blind_ranking: [item("yari", "Üst / alt yarı", "donem", "Listenin hangi yarısında."),
    item("sira_dogrula", "Sırasını göster", "baglanti", "İstatistikteki tam yeri.")],
};
const STORY = [item("gorev_ipucu", "Görevin ipucu", "donem", "Görevin kendi ipucu."),
  item("bir_yanlis", "Bir yanlışı ele", "ele", "Doğru olmayan bir seçeneği eler."),
  item("ilk_baglanti", "İlk bağlantı", "baglanti", "Cevabın ilk adımı.")];
const STORY_MODES = ["player_journey", "what_if", "ucl_moments", "nostalgia", "international_glory", "dynasties",
  "football_docu", "derby_day"];

/** Training choice games: `clue` is choice.js's verified range/half helper. */
function choice({clue, catalog}) {
  // The screen shows trainingHints[target]; two hints on one question read as one line.
  const note = (run, t, text) => {
    (run.trainingHints ||= {})[t] = run.trainingHints[t] ? `${run.trainingHints[t]} ${text}` : text;
  };
  const targetOf = (r) => r.mode === "higher_lower" ? r.question?.id : r.orderedCandidateIds?.[r.placements.length];
  function reveal(r, id, ctx = {}) {
    if (!CHOICE[r.mode]?.some((x) => x.id === id)) throw new Error("not in this mode");
    const c = ctx.c || catalog;
    if (id === "sira_dogrula") {
      const target = targetOf(r); const value = r.values?.[target];
      if (r.type !== "objective" || !Number.isFinite(value) || r.answered) throw new Error("unproducible");
      const rank = Object.values(r.values).filter((v) => v > value).length + 1;
      const text = `İstatistikte ${rank}. sırada.`;
      return {text, apply: (run) => note(run, targetOf(run), text)};
    }
    const info = clue(r, c);
    return {text: info.text, apply: (run) => note(run, info.target, info.text)};
  }
  return {
    modes: ["higher_lower_training", "blind_ranking_training"],
    catalog: {higher_lower_training: CHOICE.higher_lower, blind_ranking_training: CHOICE.blind_ranking},
    board: (r) => String(targetOf(r) ?? ""),
    items: (r, ctx) => (CHOICE[r.mode] || []).filter((x) => {
      try {
        return !!reveal(r, x.id, ctx);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

/** Story modes: one run per story section; the board is the task the player is on (run.hintTarget). */
function story() {
  function text(task, id) {
    const options = task.options || []; const keys = task.answerKeys || [];
    const label = (key) => options.find((o) => (o.id || o.key) === key)?.label;
    if (id === "gorev_ipucu") return typeof task.hint === "string" && task.hint.trim() ? task.hint : null;
    if (id === "bir_yanlis") {
      const excluded = options.length > 2 && options.find((o) => !keys.includes(o.id || o.key));
      return excluded ? "Bu seçenek elenir: " + excluded.label : null;
    }
    if (typeof task.strongHint === "string" && task.strongHint.trim()) return task.strongHint;
    return keys.length > 1 && label(keys[0]) ? "İlk bağlantı: " + (task.slots?.[0] ? task.slots[0] + " → " : "") +
      label(keys[0]) : null;
  }
  function reveal(r, id, ctx = {}) {
    if (!STORY.some((x) => x.id === id) || !ctx.task) throw new Error("not in this mode");
    const t = text(ctx.task, id); if (!t) throw new Error("unproducible");
    return {text: t, apply: (run) => {
      (run.reveals ||= {})[ctx.task.id + ":" + id] = t;
    }};
  }
  return {
    modes: STORY_MODES,
    catalog: Object.fromEntries(STORY_MODES.map((m) => [m, STORY])),
    board: (r) => r.hintTarget || "",
    items: (r, ctx = {}) => STORY.filter((x) => {
      try {
        return !!reveal(r, x.id, ctx);
      } catch (_) {
        return false;
      }
    }),
    reveal,
  };
}

module.exports = {choice, story, CATALOG: {higher_lower_training: CHOICE.higher_lower,
  blind_ranking_training: CHOICE.blind_ranking, ...Object.fromEntries(STORY_MODES.map((m) => [m, STORY]))}};
