#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
E2_DIR = ROOT / "reports" / "data_platform_v3" / "03e2"
D2_DIR = ROOT / "reports" / "data_platform_v3" / "03d2"
CONTROLLERS_DIR = ROOT / "lib" / "controllers"
OUT_DIR = ROOT / "reports" / "data_platform_v3" / "03f"

def s(v: Any) -> str:
    return "" if v is None else str(v).strip()

def as_int(v: Any, default: int = 0) -> int:
    try:
        if s(v) == "":
            return default
        return int(float(v))
    except Exception:
        return default

def yes(v: Any) -> bool:
    return s(v).upper() == "YES"

def read_csv(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Eksik dosya: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def write_csv(name: str, rows: list[dict[str, Any]], fields: list[str] | None = None):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    p = OUT_DIR / name
    if fields is None:
        fields = list(rows[0].keys()) if rows else []
    with p.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

# Fields/tokens we care about in today's controller implementation.
DEPENDENCY_TOKENS = {
    "marketValue": "UNSAFE_VALUE_FIELD",
    "peakMarketValue": "UNSAFE_VALUE_FIELD",
    "careerGoals": "STATS_V3_REQUIRED",
    "careerTimeline": "CAREER_TIMELINE_V3_REQUIRED",
    "detailedPosition": "POSITION_V3_REQUIRED",
    "famousTransfers": "TRANSFER_V3_REQUIRED",
    "chainClubPool": "HARDCODED_POOL_TO_REPLACE",
    "PopularClubs": "HARDCODED_POOL_TO_REPLACE",
    "popularCountries": "HARDCODED_POOL_TO_REVIEW",
    ".clubs": "CORE_CLUB_RELATION",
    ".countries": "CORE_COUNTRY",
    ".position": "CORE_POSITION",
}

# Explicit gameplay contracts. These describe what the production version SHOULD use,
# not what the current controller happens to use.
CONTRACTS = {
    "shared_xi": {
        "sourceControllers": ["game_controller.dart", "vs_bot_controller.dart"],
        "status": "READY_FOR_POOL_INTEGRATION",
        "questionPool": "shared_xi_question_normal",
        "answerPool": "shared_xi_answer",
        "required": ["canonicalPlayerId", "cleanSeniorClubIds", "selectionTier"],
        "future": ["overlapYears"],
        "notes": "Keep broad answer validation; random prompts must come from curated pools."
    },
    "grid": {
        "sourceControllers": ["grid_controller.dart", "reverse_grid_controller.dart", "random_grid_controller.dart",
                              "online_grid_controller.dart", "vs_bot_grid_controller.dart",
                              "vs_bot_random_grid_controller.dart", "vs_bot_reverse_grid_controller.dart"],
        "status": "PARTIAL",
        "questionPool": "grid_question_normal",
        "answerPool": "grid_answer",
        "required": ["cleanSeniorClubIds", "countries", "position"],
        "blocked": ["career-goal criteria until Stats V3"],
        "migration": ["replace market-value rarity bonus with recognizability rarity"]
    },
    "odd_club": {
        "sourceControllers": ["odd_club_controller.dart"],
        "status": "READY_FOR_POOL_INTEGRATION",
        "questionPool": "odd_club_normal",
        "required": ["cleanSeniorClubIds>=3", "selectionTier"],
        "migration": ["replace peakMarketValue selection with V3 pool/rank"]
    },
    "mystery_player": {
        "sourceControllers": ["mystery_player_controller.dart"],
        "status": "PARTIAL",
        "questionPool": "mystery_normal",
        "required": ["countries", "position", "cleanSeniorClubIds>=2"],
        "blocked": ["career-goal hint until Stats V3", "market-value hint should be removed"],
        "migration": ["star teammate should use V3 popularity, not peakMarketValue"]
    },
    "career_puzzle": {
        "sourceControllers": ["career_puzzle_controller.dart", "player_journey_controller.dart", "story_journey_controller.dart"],
        "status": "BLOCKED_BY_TIMELINE_V3",
        "questionPool": "career_preview_normal",
        "required": ["orderedCareerSpells", "fromYear", "toYear", "clubId", "selectionTier"],
        "notes": "03F emits only candidate preview; do not migrate runtime yet."
    },
    "transfer_detective": {
        "sourceControllers": ["transfer_detective_controller.dart"],
        "status": "PARTIAL",
        "questionPool": "transfer_detective_normal",
        "required": ["validatedTransfer", "fromClubId", "toClubId", "year", "playerId"],
        "blocked": ["career-goal hint until Stats V3"],
        "migration": ["replace market-value popularity filters; fee can remain optional/curated"]
    },
    "chain": {
        "sourceControllers": ["chain_controller.dart", "match_pair_controller.dart"],
        "status": "READY_FOR_POOL_INTEGRATION",
        "questionPool": "chain_playable",
        "required": ["cleanSeniorClubIds>=2"],
        "migration": ["replace hard-coded elite/pool IDs with canonical club tier metadata"]
    },
    "guess_the_player": {
        "sourceControllers": ["guess_the_player_controller.dart"],
        "status": "READY_FOR_POOL_INTEGRATION",
        "questionPool": "guess_the_player_clubs",
        "answerPool": "shared_xi_answer",
        "required": ["club->players index", "cleanSeniorClubIds"]
    },
    "build_xi": {
        "sourceControllers": ["build_xi_controller.dart"],
        "status": "BLOCKED_BY_POSITION_V3",
        "questionPool": "build_xi_preview",
        "required": ["detailedPositionCanonical", "countries", "cleanSeniorClubIds"],
        "migration": ["replace peakMarketValue budget cost with percentile of gameplay quality/popularity"]
    },
    "higher_lower": {
        "sourceControllers": ["higher_lower_controller.dart"],
        "status": "BLOCKED_BY_STATS_V3",
        "required": ["complete comparable factual stat"],
        "migration": ["remove market-value criterion", "add appearances/goals/caps/UCL apps/height later"]
    },
    "blind_ranking": {
        "sourceControllers": ["blind_ranking_controller.dart"],
        "status": "BLOCKED_BY_STATS_V3",
        "required": ["complete ranking criterion"],
        "migration": ["replace marketValue ranking with factual stats"]
    },
    "build_or_quiz_core": {
        "sourceControllers": [
            "random_five_controller.dart", "online_five_controller.dart", "vs_bot_random_five_controller.dart",
            "streak_controller.dart", "endless_controller.dart", "guess_the_player_controller.dart",
            "harf11_controller.dart", "passaparola_controller.dart", "loto_controller.dart",
            "loto_versus_controller.dart", "this_or_that_controller.dart", "pyramid_controller.dart"
        ],
        "status": "AUDIT_CURRENT_IMPLEMENTATION",
        "questionPool": "normal_generic",
        "required": ["selectionTier"],
        "notes": "03F controller scan determines any extra legacy dependencies."
    }
}

def controller_audit():
    rows = []
    blockers = []
    if not CONTROLLERS_DIR.exists():
        return rows, blockers

    for p in sorted(CONTROLLERS_DIR.glob("*.dart")):
        text = p.read_text(encoding="utf-8", errors="replace")
        found = []
        risk_classes = set()
        for token, kind in DEPENDENCY_TOKENS.items():
            if token in text:
                found.append(token)
                risk_classes.add(kind)

        market_hits = len(re.findall(r"\b(?:peakMarketValue|marketValue)\b", text))
        goals_hits = len(re.findall(r"\bcareerGoals\b", text))
        timeline_hits = len(re.findall(r"\bcareerTimeline\b", text))
        detail_pos_hits = len(re.findall(r"\bdetailedPosition\b", text))

        if market_hits:
            status = "MIGRATION_REQUIRED"
        elif timeline_hits:
            status = "TIMELINE_REQUIRED"
        elif goals_hits:
            status = "STATS_REQUIRED"
        elif detail_pos_hits:
            status = "POSITION_REQUIRED"
        else:
            status = "CORE_COMPATIBLE_OR_REVIEW"

        row = {
            "controller": p.name,
            "status": status,
            "detectedTokens": "|".join(found),
            "riskClasses": "|".join(sorted(risk_classes)),
            "marketValueHits": market_hits,
            "careerGoalsHits": goals_hits,
            "careerTimelineHits": timeline_hits,
            "detailedPositionHits": detail_pos_hits,
        }
        rows.append(row)

        for token, kind in DEPENDENCY_TOKENS.items():
            if token in text and kind in {
                "UNSAFE_VALUE_FIELD", "STATS_V3_REQUIRED",
                "CAREER_TIMELINE_V3_REQUIRED", "POSITION_V3_REQUIRED",
                "TRANSFER_V3_REQUIRED", "HARDCODED_POOL_TO_REPLACE"
            }:
                blockers.append({
                    "controller": p.name,
                    "dependency": token,
                    "category": kind,
                    "severity": "P0" if kind == "UNSAFE_VALUE_FIELD" else "P1",
                    "recommendedAction": {
                        "UNSAFE_VALUE_FIELD": "Replace selection/scoring with Data Platform V3 pool or factual Stats V3.",
                        "STATS_V3_REQUIRED": "Do not trust legacy careerGoals; migrate after Stats V3.",
                        "CAREER_TIMELINE_V3_REQUIRED": "Use canonical ordered career spells after Timeline V3.",
                        "POSITION_V3_REQUIRED": "Use canonical detailed-position enrichment.",
                        "TRANSFER_V3_REQUIRED": "Use canonical validated transfer table.",
                        "HARDCODED_POOL_TO_REPLACE": "Replace hard-coded IDs with canonical club/player tier metadata."
                    }[kind]
                })
    return rows, blockers

def main():
    print("=" * 72)
    print("LINKBALL DATA PLATFORM V3 - STEP 03F")
    print("GAME MODE DATA CONTRACTS + POOL PREVIEW (READ-ONLY)")
    print("=" * 72)

    players = read_csv(E2_DIR / "player_selection_scores_v3.csv")
    clubs = read_csv(D2_DIR / "canonical_clubs_gameplay_guarded_v2.csv")
    careers = read_csv(D2_DIR / "canonical_careers_gameplay_guarded_v2.csv")

    print(f"[03F] Oyuncu: {len(players):,}")
    print(f"[03F] Kulup: {len(clubs):,}")
    print(f"[03F] Kariyer iliskisi: {len(careers):,}")

    player_by_id = {as_int(r.get("id"), -1): r for r in players}
    valid_player_ids = set(player_by_id)
    answer_ids = {pid for pid, r in player_by_id.items() if pid >= 0 and yes(r.get("answerEligible"))}
    playable_ids = {pid for pid, r in player_by_id.items() if pid >= 0 and yes(r.get("playableV3"))}
    hard_ids = {pid for pid, r in player_by_id.items() if pid >= 0 and yes(r.get("hardV3"))}
    normal_ids = {pid for pid, r in player_by_id.items() if pid >= 0 and yes(r.get("normalV3"))}
    casual_ids = {pid for pid, r in player_by_id.items() if pid >= 0 and yes(r.get("casualV3"))}

    clean_clubs = {
        s(r.get("canonicalKey")): r for r in clubs
        if yes(r.get("gameplayEligible03d1")) and s(r.get("entityType")).upper() == "SENIOR"
    }
    gameplay_pool_clubs = {
        key for key, r in clean_clubs.items() if yes(r.get("gameplayPool4000"))
    }

    # Unique clean player-club relations.
    player_clubs = defaultdict(set)
    club_players = defaultdict(set)
    transfer_players = set()
    for i, r in enumerate(careers, 1):
        if i % 150000 == 0:
            print(f"[03F] Kariyer index: {i:,}")
        if not yes(r.get("gameplayEligible03d1")):
            continue
        pid = as_int(r.get("canonicalPlayerId"), -1)
        key = s(r.get("canonicalClubKey"))
        if pid < 0 or pid not in valid_player_ids or key not in clean_clubs:
            continue
        player_clubs[pid].add(key)
        club_players[key].add(pid)
        if "TRANSFER_VALIDATED" in s(r.get("evidence")):
            transfer_players.add(pid)

    def filt(base_ids, pred=lambda pid, r: True):
        rows = []
        for pid in base_ids:
            r = player_by_id.get(pid)
            if r is not None and pred(pid, r):
                rows.append(r)
        rows.sort(key=lambda r: (as_int(r.get("selectionRankV3"), 10**9), s(r.get("name")).casefold()))
        return [as_int(r.get("id")) for r in rows]

    pools = {}
    pools["shared_xi_answer"] = filt(answer_ids)
    pools["shared_xi_question_casual"] = filt(casual_ids, lambda pid, r: len(player_clubs[pid]) >= 2)
    pools["shared_xi_question_normal"] = filt(normal_ids, lambda pid, r: len(player_clubs[pid]) >= 2)
    pools["shared_xi_question_hard"] = filt(hard_ids, lambda pid, r: len(player_clubs[pid]) >= 2)

    pools["grid_answer"] = filt(answer_ids, lambda pid, r: bool(s(r.get("countries"))) and bool(s(r.get("position"))))
    pools["grid_question_normal"] = filt(normal_ids, lambda pid, r: len(player_clubs[pid]) >= 1)

    pools["odd_club_normal"] = filt(normal_ids, lambda pid, r: len(player_clubs[pid]) >= 3)
    pools["mystery_normal"] = filt(normal_ids, lambda pid, r: len(player_clubs[pid]) >= 2)
    pools["chain_playable"] = filt(playable_ids, lambda pid, r: len(player_clubs[pid]) >= 2)

    pools["career_preview_beginner"] = filt(casual_ids, lambda pid, r: len(player_clubs[pid]) >= 3)
    pools["career_preview_normal"] = filt(normal_ids, lambda pid, r: len(player_clubs[pid]) >= 5)
    pools["career_preview_legend"] = filt(hard_ids, lambda pid, r: len(player_clubs[pid]) >= 8)

    pools["transfer_detective_normal"] = filt(
        normal_ids, lambda pid, r: pid in transfer_players and as_int(r.get("transferValidatedClubCount")) >= 1
    )
    pools["build_xi_preview"] = filt(
        playable_ids, lambda pid, r: bool(s(r.get("position")))
    )
    pools["normal_generic"] = filt(normal_ids)

    # Club prompt pool: senior gameplay clubs with enough answer depth.
    club_prompt_rows = []
    for key in gameplay_pool_clubs:
        c = clean_clubs[key]
        ans = club_players[key].intersection(answer_ids)
        mainstream = club_players[key].intersection(normal_ids)
        if len(ans) < 15:
            continue
        club_prompt_rows.append({
            "canonicalClubKey": key,
            "name": s(c.get("name")),
            "country": s(c.get("country")),
            "competition": s(c.get("competition")),
            "answerEligiblePlayerCount": len(ans),
            "normalPlayerCount": len(mainstream),
            "popularitySeed": as_int(c.get("popularitySeed")),
            "promptEligible": "YES",
        })
    club_prompt_rows.sort(
        key=lambda r: (-r["normalPlayerCount"], -r["answerEligiblePlayerCount"], -r["popularitySeed"], r["name"].casefold())
    )
    guess_club_keys = [r["canonicalClubKey"] for r in club_prompt_rows]
    pools["guess_the_player_clubs"] = guess_club_keys

    # Per-mode pool size / readiness.
    mode_rows = [
        {"mode":"Shared XI","status":"READY_FOR_POOL_INTEGRATION","pool":"shared_xi_question_normal","count":len(pools["shared_xi_question_normal"]),"blocker":""},
        {"mode":"Grid / Reverse / Random Grid","status":"PARTIAL","pool":"grid_question_normal","count":len(pools["grid_question_normal"]),"blocker":"Goal criteria + rarity still depend on legacy stats/value"},
        {"mode":"Odd Club / Find Imposter","status":"READY_FOR_POOL_INTEGRATION","pool":"odd_club_normal","count":len(pools["odd_club_normal"]),"blocker":""},
        {"mode":"Mystery Player","status":"PARTIAL","pool":"mystery_normal","count":len(pools["mystery_normal"]),"blocker":"careerGoals/value/star-teammate hint migration"},
        {"mode":"Career Puzzle","status":"BLOCKED_BY_TIMELINE_V3","pool":"career_preview_normal","count":len(pools["career_preview_normal"]),"blocker":"Trusted ordered career years/spells required"},
        {"mode":"Player/Story Journey","status":"BLOCKED_BY_TIMELINE_V3","pool":"career_preview_normal","count":len(pools["career_preview_normal"]),"blocker":"Trusted ordered career years/spells required"},
        {"mode":"Transfer Detective","status":"PARTIAL","pool":"transfer_detective_normal","count":len(pools["transfer_detective_normal"]),"blocker":"careerGoals hint; canonical transfer table still needed"},
        {"mode":"Chain / Match Pair","status":"READY_FOR_POOL_INTEGRATION","pool":"chain_playable","count":len(pools["chain_playable"]),"blocker":"Replace hard-coded club pools later"},
        {"mode":"Guess The Player (club)","status":"READY_FOR_POOL_INTEGRATION","pool":"guess_the_player_clubs","count":len(guess_club_keys),"blocker":""},
        {"mode":"Build XI","status":"BLOCKED_BY_POSITION_V3","pool":"build_xi_preview","count":len(pools["build_xi_preview"]),"blocker":"Detailed position + budget replacement"},
        {"mode":"Higher / Lower","status":"BLOCKED_BY_STATS_V3","pool":"","count":0,"blocker":"Remove market-value mode; compile complete comparable factual stats"},
        {"mode":"Blind Ranking","status":"BLOCKED_BY_STATS_V3","pool":"","count":0,"blocker":"Replace market-value ranking with factual stats"},
    ]

    audit_rows, blocker_rows = controller_audit()

    # Attach contract status to actual controller files.
    controller_contract = {}
    for contract_name, cfg in CONTRACTS.items():
        for filename in cfg.get("sourceControllers", []):
            controller_contract.setdefault(filename, []).append(contract_name)
    for r in audit_rows:
        r["contracts"] = "|".join(controller_contract.get(r["controller"], []))

    # Migration priorities from actual controller scan.
    blocker_rows.sort(key=lambda r: (0 if r["severity"] == "P0" else 1, r["controller"], r["dependency"]))

    # Contract JSON.
    contracts_json = {
        "schemaVersion": 1,
        "principles": [
            "DATABASE players are not automatically random-question candidates.",
            "Broad answer validation remains broader than prompt/question selection.",
            "No gameplay selection or scoring should depend on marketValue/peakMarketValue.",
            "careerGoals must be replaced by a complete Stats V3 source before launch use.",
            "careerTimeline consumers must migrate to canonical ordered career spells.",
            "Hard-coded club/player pools should become data metadata, not Dart source lists.",
            "Visual assets remain separate from football data."
        ],
        "contracts": CONTRACTS,
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "mode_data_contracts.json").write_text(
        json.dumps(contracts_json, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    (OUT_DIR / "mode_pool_ids.preview.json").write_text(
        json.dumps({"schemaVersion":1, "pools":pools}, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8"
    )

    write_csv("mode_pool_sizes.csv", mode_rows)
    write_csv("controller_dependency_audit.csv", audit_rows)
    write_csv("launch_data_blockers.csv", blocker_rows)
    write_csv("guess_the_player_club_pool.csv", club_prompt_rows)

    # Field migration plan: concise production roadmap.
    migration_plan = [
        {"priority":"P0","legacyField":"peakMarketValue / marketValue","usedFor":"selection, rarity, costs, ranking","replacement":"selectionRankV3 + Stats V3 factual criteria","targetStep":"03F integration + 03G stats"},
        {"priority":"P0","legacyField":"careerGoals","usedFor":"hints, goal grids, Higher/Lower","replacement":"Stats V3 complete career aggregates","targetStep":"03G"},
        {"priority":"P0","legacyField":"careerTimeline","usedFor":"Career Puzzle / journeys","replacement":"canonical ordered career_spells","targetStep":"03G"},
        {"priority":"P1","legacyField":"detailedPosition","usedFor":"Build XI slots","replacement":"canonical position/sub-position mapping","targetStep":"03G"},
        {"priority":"P1","legacyField":"famousTransfers","usedFor":"Transfer Detective","replacement":"validated canonical transfers","targetStep":"03G"},
        {"priority":"P1","legacyField":"chainClubPool / PopularClubs","usedFor":"question selection","replacement":"canonical club tier + gameplay-pool metadata","targetStep":"03F runtime integration"},
        {"priority":"P2","legacyField":"star teammate by peakMarketValue","usedFor":"Mystery hint","replacement":"teammate graph + selectionRankV3","targetStep":"later graph step"},
    ]
    write_csv("field_migration_plan.csv", migration_plan)

    controller_count = len(audit_rows)
    unsafe_value_controllers = sum(1 for r in audit_rows if as_int(r.get("marketValueHits")) > 0)
    timeline_controllers = sum(1 for r in audit_rows if as_int(r.get("careerTimelineHits")) > 0)
    stats_controllers = sum(1 for r in audit_rows if as_int(r.get("careerGoalsHits")) > 0)

    gates = [
        {"gate":"F-01","status":"PASS" if set(pools["shared_xi_question_normal"]).issubset(answer_ids) else "FAIL",
         "rule":"Shared XI prompt pool subset of answer-eligible players","detail":f"{len(pools['shared_xi_question_normal']):,}"},
        {"gate":"F-02","status":"PASS" if all(len(player_clubs[pid]) >= 3 for pid in pools["odd_club_normal"]) else "FAIL",
         "rule":"Odd Club pool players have >=3 clean senior clubs","detail":f"{len(pools['odd_club_normal']):,}"},
        {"gate":"F-03","status":"PASS" if all(pid in transfer_players for pid in pools["transfer_detective_normal"]) else "FAIL",
         "rule":"Transfer Detective preview players have validated transfer evidence","detail":f"{len(pools['transfer_detective_normal']):,}"},
        {"gate":"F-04","status":"PASS",
         "rule":"Market-value dependent controllers identified instead of silently migrated","detail":f"{unsafe_value_controllers:,} controller(s)"},
        {"gate":"F-05","status":"PASS",
         "rule":"Blocked timeline/stats modes remain explicit","detail":f"timeline={timeline_controllers}, careerGoals={stats_controllers}"},
        {"gate":"F-06","status":"PASS",
         "rule":"Runtime assets unchanged","detail":"Only reports/data_platform_v3/03f is written"},
    ]
    write_csv("migration_gates.csv", gates)

    summary = {
        "step":"03F",
        "runtimeChanged":False,
        "players":len(players),
        "answerEligiblePlayers":len(answer_ids),
        "playablePlayers":len(playable_ids),
        "normalPlayers":len(normal_ids),
        "hardPlayers":len(hard_ids),
        "cleanSeniorClubs":len(clean_clubs),
        "guessThePlayerPromptClubs":len(guess_club_keys),
        "controllersScanned":controller_count,
        "controllersUsingMarketValue":unsafe_value_controllers,
        "controllersUsingCareerGoals":stats_controllers,
        "controllersUsingCareerTimeline":timeline_controllers,
        "modePools":{r["mode"]:{"status":r["status"],"count":r["count"],"pool":r["pool"]} for r in mode_rows},
        "nextRecommendedStep":"03G_STATS_TIMELINE_POSITION_TRANSFER_ENRICHMENT"
    }
    (OUT_DIR / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    readme = f"""# Linkball Data Platform V3 — 03F

Game-mode data contracts and per-mode pool preview.

- Controllers scanned: {controller_count}
- Market-value dependent controllers: {unsafe_value_controllers}
- careerGoals dependent controllers: {stats_controllers}
- careerTimeline dependent controllers: {timeline_controllers}
- Shared XI normal prompt pool: {len(pools['shared_xi_question_normal']):,}
- Odd Club normal pool: {len(pools['odd_club_normal']):,}
- Mystery normal pool: {len(pools['mystery_normal']):,}
- Transfer Detective validated preview: {len(pools['transfer_detective_normal']):,}
- Guess-the-player club prompts: {len(guess_club_keys):,}

No runtime asset is modified.

Next data step: canonical Stats / Timeline / Detailed Position / Transfer enrichment.
"""
    (OUT_DIR / "README.md").write_text(readme, encoding="utf-8")

    print(f"[03F] Controller tarandi: {controller_count}")
    print(f"[03F] marketValue kullanan controller: {unsafe_value_controllers}")
    print(f"[03F] careerGoals kullanan controller: {stats_controllers}")
    print(f"[03F] careerTimeline kullanan controller: {timeline_controllers}")
    print(f"[03F] Shared XI normal: {len(pools['shared_xi_question_normal']):,}")
    print(f"[03F] Odd Club normal: {len(pools['odd_club_normal']):,}")
    print(f"[03F] Mystery normal: {len(pools['mystery_normal']):,}")
    print(f"[03F] Transfer Detective: {len(pools['transfer_detective_normal']):,}")
    print(f"[03F] Guess The Player club prompts: {len(guess_club_keys):,}")
    print(f"[03F] Rapor: {OUT_DIR}")
    print("[03F] TAMAMLANDI - assets/data degistirilmedi.")

if __name__ == "__main__":
    main()
