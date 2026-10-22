"use strict";
// No token, App Check bypass, API key, game action or wallet write is used.
// A callable UNAUTHENTICATED response proves routing only, not playability.
const groups = {
  careerTransfer: ["getCareerTransfer", "startCareerTransfer", "actCareerTransfer", "searchCareerTransfer"],
  mysteryChain: ["getMysteryChain", "startMysteryChain", "actMysteryChain", "searchMysteryChain"],
  fakeClub: ["getFakeClub", "startFakeClub", "actFakeClub"],
  dailyWords: ["getDailyWords", "actDailyWords", "getDailyWordsHistory"],
  arcade: ["getArcade", "prepareArcade", "actArcade", "searchArcade", "replayArcade"],
  choice: ["getChoice", "prepareChoice", "actChoice", "replayChoice"],
  shared: ["getEnergyStatus", "getRewardedAdStatus", "prepareRewardedAd", "cancelRewardedAd"],
};
async function probe(name, {project = "sharedix", fetchImpl = fetch} = {}) {
  if (!/^[a-z][a-z0-9-]+$/.test(project)) throw Error("Invalid project ID");
  try {
    const response = await fetchImpl(`https://europe-west1-${project}.cloudfunctions.net/${name}`, {
      method: "POST", headers: {"Content-Type": "application/json"}, body: '{"data":{}}',
      signal: AbortSignal.timeout(20000),
    });
    const body = await response.text();
    let parsed; try { parsed = JSON.parse(body); } catch (_) { /* HTML 404 is not a callable. */ }
    const present = response.status === 401 && parsed?.error?.status === "UNAUTHENTICATED";
    return {name, http: response.status, state: present ? "PRESENT_AUTH_REQUIRED" :
      response.status === 404 ? "MISSING" : "UNVERIFIED"};
  } catch (_) { return {name, state: "NETWORK_ERROR"}; }
}
async function main() {
  if (process.argv.includes("--deploy-targets")) {
    console.log(Object.values(groups).flat().map((n) => `functions:${n}`).join(",")); return;
  }
  let failed = false;
  for (const [group, names] of Object.entries(groups)) {
    const results = await Promise.all(names.map((n) => probe(n, {project: process.env.FIREBASE_PROJECT_ID || "sharedix"})));
    for (const r of results) {
      console.log(`${r.state === "PRESENT_AUTH_REQUIRED" ? "PASS" : "FAIL"} ${group}/${r.name}: ${r.state}`);
      failed ||= r.state !== "PRESENT_AUTH_REQUIRED";
    }
  }
  console.log("Endpoint presence only. Auth/App Check, runtime flags, content gates and a real game still need verification.");
  process.exitCode = failed ? 1 : 0;
}
if (require.main === module) main().catch(() => { console.error("Service check failed."); process.exitCode = 1; });
module.exports = {groups, probe};
