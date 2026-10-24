"use strict";
// Inputs are exclusively Admin-owned snapshots, never callable request.data.
const families = ["threeModes", "careerTransfer", "mysteryChain", "fakeClub", "arcade", "choice", "squadChallenge"];
function fromRun(uid, family, id, r) {
  if (!r || r.cancelled || r.forfeit || r.abandoned || r.status === "abandoned") return null;
  let modeId; let valid = false;
  switch (family) {
    case "threeModes":
      modeId = {coach_xi: "coach11", squad_vault: "vault", letter11: "letter11"}[r.mode];
      valid = r.finished === true && (r.mode === "squad_vault" ? r.won === true :
        Object.values(r.picks || {}).filter(Number.isSafeInteger).length === 11); break;
    case "careerTransfer":
      modeId = r.mode; valid = r.finished === true && r.phase === "result" && r.found === true; break;
    case "mysteryChain":
      modeId = {mystery: "mystery", mastermind: "chain"}[r.mode];
      valid = r.finished === true && r.found === true; break;
    case "fakeClub":
      modeId = r.mode;
      valid = r.finished === true && r.mode === "fake_endless" && r.lives <= 0 && r.answers > 0; break;
    case "arcade":
      modeId = r.mode === "burst" && r.style === "survival" ? "burst_survival" : r.mode;
      valid = r.finished === true && r.recorded === true && r.phase === "active" &&
        (r.mode === "burst" ? r.rounds >= 3 : r.won === true); break;
    case "choice":
      modeId = r.mode;
      valid = r.finished === true && r.recorded === true && r.phase === "active" &&
        (r.mode === "higher_lower" ? r.streak >= 5 : r.completed === true); break;
    case "squadChallenge":
      modeId = "squad_challenge"; valid = r.status === "finished" && r.result?.won === true; break;
    case "dailyWords":
      modeId = r.mode; valid = r.finished === true && r.eligible === true; break;
  }
  if (!valid || !modeId) return null;
  const hints = Array.isArray(r.hints) ? r.hints.filter((h) => !h.automatic).length : Number(r.hints) || 0;
  return {uid, eventId: family + ":" + id, modeId, source: "solo_verified", result: "completed",
    serverValidated: true, verificationVersion: 1,
    serverFinishedAtMs: r.finishedAt || r.completedAt || r.result?.finishedAt,
    assisted: r.assisted === true || hints > 0 || r.optionalHints > 0 || r.hintsUsed > 0 || r.hint === true ||
      (r.rounds || []).some?.((x) => x.bio || x.first) === true};
}
function changedRuns(uid, family, before, after) {
  if (!families.includes(family)) return [];
  const key = family === "squadChallenge" ? "runs" : "sessions";
  return Object.entries(after?.[key] || {}).flatMap(([id, r]) => {
    if (fromRun(uid, family, id, before?.[key]?.[id])) return [];
    const e = fromRun(uid, family, id, r); return e ? [e] : [];
  });
}
function changedWords(uid, before, after) {
  const events = [];
  for (const bucket of ["days", "weeks"]) {
    for (const [period, modes] of Object.entries(after?.[bucket] || {})) {
      for (const [mode, r] of Object.entries(bucket === "weeks" ? {passa_weekly: modes} : modes || {})) {
        const id = period + ":" + mode;
        const prior = bucket === "weeks" ? before?.weeks?.[period] : before?.days?.[period]?.[mode];
        if (fromRun(uid, "dailyWords", id, prior)) continue;
        const event = fromRun(uid, "dailyWords", id, r); if (event) events.push(event);
      }
    }
  }
  return events;
}
module.exports = {families, fromRun, changedRuns, changedWords};
