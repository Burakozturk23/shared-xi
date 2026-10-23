"use strict";
const {probe} = require("./check-game-services");
const callables = ["getPvp", "enterPvp", "actPvp", "searchPvp", "enterCareerTransferOnline",
  "actCareerTransferOnline", "getCareerTransfer", "getMysteryChain", "getFakeClub", "searchCareerTransfer"];
const scheduled = ["reconcilePvp", "reconcileCareerTransferOnline"];
async function main() {
  if (process.argv.includes("--deploy-targets")) {
    console.log([...callables, ...scheduled].map((n) => `functions:${n}`).join(",")); return;
  }
  let missing = false;
  for (let i = 0; i < callables.length; i += 4) {
    const results = await Promise.all(callables.slice(i, i + 4).map((n) => probe(n)));
    for (const r of results) {
      console.log(`${r.name}: ${r.state}${r.http ? ` (HTTP ${r.http})` : ""}`);
      missing ||= r.state !== "PRESENT_AUTH_REQUIRED";
    }
  }
  console.log("Routing check only. Verify App Check, linked accounts, runtime flags and two-device play separately.");
  process.exitCode = missing ? 1 : 0;
}
if (require.main === module) main().catch(() => { console.error("Online service check failed."); process.exitCode = 1; });
module.exports = {callables, scheduled};
