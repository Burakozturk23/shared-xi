"use strict";
// Hikâye Modu: one completion reward for the full (base + Ekim 2026 expansion)
// content of five stories. A new receipt key, so the existing milestone_*,
// album and final receipts (earned on the base size) never change or repay.
const KEY = "expansion_final";
const FINALS = Object.freeze({
  ucl_moments: Object.freeze({coins: 20, xp: 50}),
  international_glory: Object.freeze({coins: 20, xp: 50}),
  dynasties: Object.freeze({coins: 20, xp: 50}),
  turkish_nostalgia: Object.freeze({coins: 20, xp: 50}),
  player_journey: Object.freeze({coins: 40, xp: 100}),
});

/** Status field a client can show: the reward and whether it is already earned. */
function view(story, rewards) {
  return {...FINALS[story], earned: !!rewards?.[KEY]};
}

module.exports = {KEY, FINALS, view};
