"use strict";
const crypto = require("node:crypto");
const {dayKey, RewardError} = require("./rewarded_ads");
const VERSION = 3;
const hash = (s) => crypto.createHash("sha256").update(s).digest("hex");
const number = (v) => Number.isSafeInteger(v) && v >= 0 ? v : 0;
const onlineModes = ["club_club", "club_country", "grid_classic", "grid_random", "grid_reverse", "random_five",
  "cinko", "loto", "club_manager", "career_race", "transfer_duel", "mystery_duel", "fake_club_duel"];
const soloModes = [
  ["matching", "Matching", "puzzle"], ["pyramid", "Pyramid", "puzzle"],
  ["coach11", "Hoca 11", "squad"], ["vault", "Kadro Kasası", "squad"], ["letter11", "Harf 11", "squad"],
  ["career", "Kariyer Bulmacası", "puzzle"], ["transfer", "Transfer Dedektifi", "puzzle"],
  ["mystery", "Gizemli Futbolcu", "puzzle"], ["chain", "Kariyer Zinciri", "puzzle"],
  ["fake_endless", "Sahte Kulüp", "puzzle"], ["this_or_that", "This or That", "choice"],
  ["blind_ranking", "Blind Ranking", "choice"], ["higher_lower", "Higher or Lower", "choice"],
  ["burst_survival", "Burst Dayanıklılık", "arcade"], ["squad_challenge", "Kadro Mücadelesi", "squad"],
  ["daily_lingo", "Günün Lingo’su", "word"], ["passa_daily", "Mini Passaparola", "word"],
  ["daily_anagram", "Günün Anagramı", "word"], ["passa_weekly", "Haftalık Passaparola", "word"],
];
const dailyModes = new Set(["daily_lingo", "passa_daily", "daily_anagram"]);
const catalog = soloModes.map(([modeId, name, family]) => ({id: "complete_" + modeId, modeId, family,
  title: `${name} oyununu tamamla`, description: "Doğrulanmış bir oyunu tamamla.",
  metric: "mode__" + modeId, target: 1, routeKey: modeId, solo: true, once: dailyModes.has(modeId)}));
catalog.push(
    {id: "discover_two", title: "İki farklı solo mod keşfet", description: "İki farklı modda oyun tamamla.",
      metric: "uniqueSoloModes", target: 2, routeKey: "solo_catalog", solo: true, family: "discovery"},
    {id: "ranked_play_two", title: "İki sıralamalı maç tamamla", description: "İki normal bitiş yap; kaçış sayılmaz.",
      metric: "rankedPlayed", target: 2, routeKey: "online_ranked", solo: false, family: "ranked"},
    {id: "daily_ranked_win_1", title: "Bir sıralamalı maç kazan", description: "Doğrulanmış bir galibiyet kazan.",
      metric: "rankedWins", target: 1, routeKey: "online_ranked", solo: false, family: "ranked"},
);
const weeklyCatalog = [
  {id: "weekly_explorer", title: "Linkball Kaşifi", description: "Beş farklı modda oyun tamamla.",
    metric: "uniqueModes", target: 5, routeKey: "solo_catalog"},
  {id: "weekly_puzzles", title: "Futbol Ansiklopedisi", description: "On doğrulanmış solo oyun tamamla.",
    metric: "soloCompleted", target: 10, routeKey: "solo_catalog"},
  {id: "weekly_words", title: "Kelime Avcısı", description: "Üç farklı kelime modunda oyun tamamla.",
    metric: "uniqueWordModes", target: 3, routeKey: "word_catalog"},
];
const extraChains = [
  {id: "solo_knowledge", metric: "soloCompleted", title: "Bilgi Ustası", targets: [10, 50, 100, 250]},
  {id: "mode_collector", metric: "uniqueModes", title: "Koleksiyoncu", targets: [3, 8, 12]},
];
function weekKey(time) {
  const d = new Date(dayKey(time) + "T12:00:00Z");
  d.setUTCDate(d.getUTCDate() - (d.getUTCDay() + 6) % 7);
  return d.toISOString().slice(0, 10);
}
const emptyMetrics = () => ({counters: {}, modes: {}, soloModes: {}, wordModes: {}, processed: {}});
function decorate(state, raw, now) {
  const sameDay = raw?.daily?.dateKey === state.daily.dateKey;
  const week = weekKey(now);
  state.schemaVersion = raw?.schemaVersion || 2;
  state.migrationDay = raw?.migrationDay || "";
  state.daily = {...state.daily, ...emptyMetrics(), ...state.daily,
    counters: {...(sameDay ? raw.daily.counters : {}), ...state.daily.counters},
    assigned: sameDay ? raw.daily.assigned || [] : [],
    modes: sameDay ? raw.daily.modes || {} : {}, soloModes: sameDay ? raw.daily.soloModes || {} : {},
    wordModes: sameDay ? raw.daily.wordModes || {} : {}};
  state.previousDailyIds = sameDay ? raw?.previousDailyIds || [] :
    (raw?.daily?.assigned || []).map((x) => x.definitionId || x.id);
  state.weekly = raw?.weekly?.weekKey === week ? {...emptyMetrics(), ...raw.weekly} :
    {...emptyMetrics(), weekKey: week, claims: {}, assigned: weeklyCatalog};
  state.general = {...emptyMetrics(), ...raw?.general};
  return state;
}
function value(bucket, definition) {
  const metric = definition.metric;
  if (metric === "uniqueModes") return Object.keys(bucket.modes || {}).length;
  if (metric === "uniqueSoloModes") return Object.keys(bucket.soloModes || {}).length;
  if (metric === "uniqueWordModes") return Object.keys(bucket.wordModes || {}).length;
  return number(bucket.counters?.[metric]);
}
function available(d, ready, state) {
  if (d.routeKey === "online_ranked") return ready.online === true;
  if (d.metric === "uniqueSoloModes") return soloModes.filter(([m]) => ready[m] === true).length >= 2;
  return ready[d.modeId] === true && (!d.once || !state.daily.modes[d.modeId]);
}
function assign(state, uid, ready, policy = {}, now = state.updatedAt) {
  if (policy.enabled !== true && state.schemaVersion !== VERSION) return state;
  const old = state.daily.assigned || [];
  // Preserve the current legacy day's earned/claimable rights during migration.
  if (!state.migrationDay) state.migrationDay = state.daily.dateKey;
  if (!old.length && state.schemaVersion !== VERSION && state.migrationDay === state.daily.dateKey &&
      (Object.keys(state.daily.claims).length || Object.values(state.daily.counters).some((n) => n > 0))) return state;
  const eligible = catalog.filter((d) => available(d, ready, state));
  // Never manufacture playable missions when rollout/data-health gates are not ready.
  const solo = eligible.filter((d) => d.solo);
  if (!old.length && (eligible.length < 5 || solo.length < 3)) {
    state.availabilityNotice = "Görev rotası hazırlanıyor. Doğrulanmış oyunlar açılınca yenile.";
    return state;
  }
  state.schemaVersion = VERSION;
  state.availabilityNotice = "";
  const seed = `${uid}|${state.daily.dateKey}|${VERSION}`;
  const ordered = [...eligible].sort((a, b) => hash(seed + a.id).localeCompare(hash(seed + b.id)));
  if (!old.length) {
    const picks = [];
    const take = (predicate) => {
      const d = ordered.find((x) => !picks.includes(x) && predicate(x)); if (d) picks.push(d);
    };
    take((x) => x.once); take((x) => x.solo && !x.once && x.id !== "discover_two");
    take((x) => x.id === "discover_two");
    while (picks.filter((x) => x.solo).length < 3) take((x) => x.solo);
    take((x) => !x.solo);
    while (picks.length < 5) take(() => true);
    const prior = [...state.previousDailyIds].sort().join("|");
    if (picks.map((x) => x.id).sort().join("|") === prior) {
      const i = picks.findIndex((x) => x.solo && !x.once);
      const alternate = ordered.find((x) => x.solo && !picks.includes(x));
      if (i >= 0 && alternate) picks[i] = alternate;
    }
    state.daily.assigned = picks.map((d, i) => ({...d, definitionId: d.id, id: "daily_v3_slot_" + (i + 1),
      assignedAt: now, baseline: 0}));
  } else {
    const used = new Set(old.map((x) => x.definitionId));
    state.daily.assigned = old.map((d) => {
      const progress = Math.max(0, value(state.daily, d) - number(d.baseline));
      if (state.daily.claims[d.id] || progress >= d.target) return d;
      if (available(d, ready, state)) {
        const rest = {...d}; delete rest.unavailable; return rest;
      }
      const replacement = ordered.find((x) => x.solo && !used.has(x.id));
      if (!replacement) return {...d, unavailable: true};
      used.add(replacement.id);
      const remaining = Math.max(1, d.target - progress);
      return {...replacement, definitionId: replacement.id, id: d.id, target: remaining,
        title: `${replacement.title} (${remaining})`, baseline: value(state.daily, replacement),
        replaced: [...d.replaced || [], {definitionId: d.definitionId, progress, target: d.target}],
        carriedProgress: number(d.carriedProgress) + progress};
    });
  }
  return state;
}
function record(state, event, now) {
  const mode = soloModes.find(([id]) => id === event.modeId);
  const ranked = event.source === "ranked_settlement";
  const friend = event.source === "friend_settlement";
  const time = event.serverFinishedAtMs;
  if (event.serverValidated !== true || event.verificationVersion !== 1 ||
      typeof event.eventId !== "string" || !event.eventId || !event.uid || typeof event.uid !== "string" ||
      !Number.isSafeInteger(time) || time <= 0 || time > now || event.cancelled || event.forfeit ||
      event.participated === false || event.assisted && (ranked || friend) ||
      (ranked || friend ? !onlineModes.includes(event.modeId) : !mode || event.source !== "solo_verified") ||
      (ranked || friend ? !["win", "draw", "loss"].includes(event.result) : event.result !== "completed")) return false;
  const key = hash(`${event.source}|${event.modeId}|${event.eventId}`);
  let changed = false;
  for (const [bucket, allowed] of [[state.daily, dayKey(time) === state.daily.dateKey],
    [state.weekly, weekKey(time) === state.weekly.weekKey], [state.general, true]]) {
    if (!allowed || bucket.processed[key]) continue;
    bucket.processed[key] = true; changed = true;
    bucket.modes[event.modeId] = true;
    const add = (name) => bucket.counters[name] = number(bucket.counters[name]) + 1;
    if (ranked) {
      add("rankedPlayed"); if (event.result === "win") add("rankedWins");
    } else if (friend) add("friendPlayed");
    else {
      bucket.soloModes[event.modeId] = true;
      if (mode[2] === "word") bucket.wordModes[event.modeId] = true;
      add("soloCompleted"); add("mode__" + event.modeId);
      if (!event.assisted) add("unassistedCompleted");
    }
  }
  return changed;
}
function items(state, policy = {}) {
  const project = (d, kind) => {
    const bucket = kind === "daily" ? state.daily : kind === "weekly" ? state.weekly : state.general;
    const claim = (kind === "general" ? state.generalClaims : bucket.claims)?.[d.id];
    const progress = Math.max(0, value(bucket, d) - number(d.baseline));
    const limit = kind === "daily" ? 3 : 2;
    const enabled = !d.unavailable && (kind === "daily" ? policy.enabled === true :
      kind === "weekly" ? policy.weeklyEnabled === true : policy.careerEnabled === true && number(d.rewardCoins) > 0);
    const limitReached = kind !== "general" && !claim && Object.keys(bucket.claims || {}).length >= limit;
    return {...d, kind, periodKey: kind === "daily" ? state.daily.dateKey :
      kind === "weekly" ? "weekly__" + state.weekly.weekKey : "general",
    progress: Math.min(progress, d.target), rawProgress: progress,
    rewardCoins: claim?.rewardCoins ?? (kind === "daily" ? 20 : kind === "weekly" ? 25 : number(d.rewardCoins)),
    rewardSp: kind === "daily" ? 30 : 0, rewardXp: 0, enabled, limitReached,
    claimed: !!claim, claimedAt: claim?.claimedAt || 0,
    claimable: enabled && !claim && !limitReached && progress >= d.target};
  };
  const general = extraChains.map((chain) => {
    const i = chain.targets.findIndex((n) => !state.generalClaims[chain.id + "_" + n]);
    const index = i < 0 ? chain.targets.length - 1 : i;
    const target = chain.targets[index];
    return project({id: chain.id + "_" + target, metric: chain.metric, title: `${chain.title}: ${target}`,
      description: "Doğrulanmış oyunlarla gelişim yolunu ilerlet.", target, routeKey: "solo_catalog",
      chainId: chain.id, stage: index + 1, stageCount: chain.targets.length,
      rewardCoins: number(policy.careerRewards?.[chain.id + "_" + target])}, "general");
  });
  return {daily: state.daily.assigned.map((d) => project(d, "daily")),
    weekly: weeklyCatalog.map((d) => project(d, "weekly")), general,
    weekKey: state.weekly.weekKey, weeklyClaimLimit: 2,
    weeklyCompletedCount: Object.keys(state.weekly.claims || {}).length,
    weeklyEnabled: policy.weeklyEnabled === true, availabilityNotice: state.availabilityNotice || ""};
}
function claim(state, missionId, policy, now, nonce) {
  const p = items(state, policy);
  let item = [...p.daily, ...p.weekly, ...p.general].find((x) => x.id === missionId);
  if (!item && state.generalClaims[missionId] && extraChains.some((c) =>
    c.targets.some((n) => c.id + "_" + n === missionId))) item = {id: missionId, kind: "general"};
  if (!item) return null;
  const bucket = item.kind === "daily" ? state.daily.claims :
    item.kind === "weekly" ? state.weekly.claims : state.generalClaims;
  const periodKey = item.kind === "daily" ? state.daily.dateKey :
    item.kind === "weekly" ? "weekly__" + state.weekly.weekKey : "general";
  if (!bucket[missionId] && !item.claimable) {
    throw new RewardError("failed-precondition",
        "Görev tamamlanmadı, ödül kapalı veya dönem limiti doldu.");
  }
  const sourceId = periodKey + "__" + missionId;
  bucket[missionId] ||= {claimedAt: now, rewardCoins: item.rewardCoins, nonce, economyConfigId: "missions-v3"};
  return {item, claim: bucket[missionId], periodKey, sourceId};
}
module.exports = {VERSION, onlineModes, soloModes, catalog, weeklyCatalog, extraChains,
  weekKey, decorate, assign, record, value, items, claim};
