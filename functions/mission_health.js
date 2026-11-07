"use strict";
const MAX_AGE_MS = 10 * 60 * 1000;
const groups = {
  pvp: ["getPvp", "enterPvp", "actPvp", "searchPvp"],
  duels: ["getCareerTransfer", "enterCareerTransferOnline", "actCareerTransferOnline", "searchCareerTransfer"],
};
// Routing probes deliberately carry no identity, App Check token or game action.
// Playability additionally requires the existing admin pilot and per-mode gates.
async function collect({fetchImpl = fetch, now = Date.now} = {}) {
  const endpoints = {};
  await Promise.all(Object.values(groups).flat().map(async (name) => {
    try {
      const response = await fetchImpl("https://europe-west1-sharedix.cloudfunctions.net/" + name, {
        method: "POST", headers: {"Content-Type": "application/json"}, body: "{\"data\":{}}",
        redirect: "error", signal: AbortSignal.timeout(8000),
      });
      const body = await response.json();
      endpoints[name] = response.status === 401 && body?.error?.status === "UNAUTHENTICATED";
    } catch (_) {
      endpoints[name] = false;
    }
  }));
  return {version: 1, checkedAt: now(), endpoints};
}
function availability(snapshot, runtime, time) {
  const fresh = snapshot?.version === 1 && Number.isSafeInteger(snapshot.checkedAt) &&
    snapshot.checkedAt <= time && time - snapshot.checkedAt <= MAX_AGE_MS;
  const healthy = (group) => fresh && groups[group].every((name) => snapshot.endpoints?.[name] === true);
  const pvp = runtime.pvp || {};
  const permits = (flag) => require("./missions_v3").onlineModes.slice(0, 9).some((mode) => {
    const policy = {...pvp, ...pvp.modes?.[mode]};
    return policy[flag] === true && (flag !== "rankedEnabled" || mode !== "club_manager" ||
      policy.managerRankedVerified === true);
  });
  // Career Race / Transfer Duel have server-authoritative entry without a
  // separate rollout gate. Mystery/Fake policy cannot disable those two modes.
  return {online: healthy("duels") || healthy("pvp") && permits("rankedEnabled"),
    friends: healthy("duels") || healthy("pvp") && permits("friendEnabled")};
}
module.exports = {MAX_AGE_MS, groups, collect, availability};
