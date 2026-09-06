#!/usr/bin/env python3
"""Linkball Data Platform v3 - Step 03A data audit.

Read-only audit for the current Flutter assets/data package. It never mutates game data.
Outputs reports under reports/data_audit/latest by default.

Usage from repository root:
    python tools/data_audit/audit.py
    python tools/data_audit/audit.py --deep
    python tools/data_audit/audit.py --data-dir assets/data --out reports/data_audit/latest
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

CANONICAL_POSITIONS = {"Goalkeeper", "Defender", "Midfield", "Attack"}
CURRENT_YEAR = datetime.now().year
PLAYER_FUTURE_FIELDS = [
    "birthYear", "foot", "height", "popularity", "quality", "difficulty", "eras"
]
PLAYER_CURRENT_FIELDS = [
    "id", "name", "countries", "position", "clubIds", "aliases", "avatarKey",
    "rating", "marketValue", "peakMarketValue", "careerGoals", "careerTimeline",
    "detailedPosition", "nationalTeams", "primaryNationalTeamId",
]
CLUB_CURRENT_FIELDS = ["id", "name", "country", "league", "badgeKey", "color"]


def norm_text(value: Any) -> str:
    s = str(value or "").strip().lower()
    s = re.sub(r"\s+", " ", s)
    return s


def as_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return None


def as_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def json_load(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def human_bytes(n: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    x = float(n)
    for unit in units:
        if x < 1024 or unit == units[-1]:
            return f"{x:.2f} {unit}"
        x /= 1024
    return f"{n} B"


def pct(num: int, den: int) -> float:
    return (num / den * 100.0) if den else 0.0


def write_csv(path: Path, rows: Iterable[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    rows = list(rows)
    if fieldnames is None:
        fieldnames = []
        seen = set()
        for r in rows:
            for k in r.keys():
                if k not in seen:
                    seen.add(k)
                    fieldnames.append(k)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in rows:
            writer.writerow(r)


@dataclass
class SeverityCount:
    error: int = 0
    warning: int = 0
    info: int = 0

    def add(self, severity: str) -> None:
        if severity == "error":
            self.error += 1
        elif severity == "warning":
            self.warning += 1
        else:
            self.info += 1


class Audit:
    def __init__(self, root: Path, data_dir: Path, out_dir: Path, deep: bool = False):
        self.root = root
        self.data_dir = data_dir
        self.out_dir = out_dir
        self.deep = deep
        self.now = datetime.now(timezone.utc)
        self.issues: list[dict[str, Any]] = []
        self.severity = SeverityCount()
        self.summary: dict[str, Any] = {}
        self.file_inventory: list[dict[str, Any]] = []
        self.field_coverage: list[dict[str, Any]] = []
        self.player_issues: list[dict[str, Any]] = []
        self.club_issues: list[dict[str, Any]] = []
        self.timeline_issues: list[dict[str, Any]] = []
        self.orphan_refs: list[dict[str, Any]] = []
        self.transfer_issues: list[dict[str, Any]] = []
        self.duplicate_names: list[dict[str, Any]] = []
        self.game_readiness: list[dict[str, Any]] = []
        self.full_min_diff: list[dict[str, Any]] = []

    def issue(self, severity: str, code: str, message: str, **context: Any) -> None:
        row = {"severity": severity, "code": code, "message": message, **context}
        self.issues.append(row)
        self.severity.add(severity)

    def inventory(self) -> None:
        expected = [
            "meta.json", "players_min.json", "clubs_min.json", "coaches_min.json",
            "famous_transfers.json", "players.json", "clubs.json"
        ]
        total = 0
        for name in expected:
            p = self.data_dir / name
            exists = p.exists()
            size = p.stat().st_size if exists else 0
            total += size
            self.file_inventory.append({
                "file": name,
                "exists": exists,
                "bytes": size,
                "size": human_bytes(size) if exists else "",
            })
        self.summary["knownAssetBytes"] = total
        self.summary["knownAssetSize"] = human_bytes(total)

        pubspec = self.root / "pubspec.yaml"
        bundles_data_dir = False
        if pubspec.exists():
            text = pubspec.read_text(encoding="utf-8", errors="replace")
            bundles_data_dir = bool(re.search(r"(?m)^\s*-\s+assets/data/\s*$", text))
        self.summary["pubspecBundlesWholeDataDir"] = bundles_data_dir
        if bundles_data_dir and (self.data_dir / "players.json").exists() and (self.data_dir / "players_min.json").exists():
            full_size = (self.data_dir / "players.json").stat().st_size
            self.issue(
                "warning", "BUNDLE_FULL_AND_MIN_PLAYERS",
                "pubspec assets/data/ klasörünün tamamını paketliyor; players.json ve players_min.json birlikte AAB'ye girebilir.",
                fullPlayersSize=human_bytes(full_size),
            )

    def field_stats(self, rows: list[dict[str, Any]], entity: str, fields: list[str]) -> None:
        n = len(rows)
        for field in fields:
            present = 0
            useful = 0
            for r in rows:
                if field in r:
                    present += 1
                    v = r.get(field)
                    if v not in (None, "", [], {}, 0, 0.0):
                        useful += 1
            self.field_coverage.append({
                "entity": entity,
                "field": field,
                "present": present,
                "presentPct": round(pct(present, n), 2),
                "useful": useful,
                "usefulPct": round(pct(useful, n), 2),
                "total": n,
            })

    def audit_clubs(self, clubs: list[dict[str, Any]]) -> tuple[dict[int, dict[str, Any]], Counter]:
        ids: dict[int, dict[str, Any]] = {}
        duplicate_ids = Counter()
        names: dict[str, list[int]] = defaultdict(list)
        unresolved = 0
        partial = 0
        empty_country = 0
        empty_league = 0

        for idx, c in enumerate(clubs):
            cid = as_int(c.get("id"))
            name = str(c.get("name") or "").strip()
            country = str(c.get("country") or "").strip()
            league = str(c.get("league") or "").strip()
            badge = str(c.get("badgeKey") or "").strip()
            issues = []

            if cid is None or cid <= 0:
                issues.append("invalid_id")
            else:
                if cid in ids:
                    duplicate_ids[cid] += 1
                else:
                    ids[cid] = c

            placeholder = bool(cid is not None and re.fullmatch(rf"Club\s+{cid}", name, flags=re.I))
            if not name:
                issues.append("empty_name")
            if placeholder:
                issues.append("placeholder_name")
                unresolved += 1
            if not country:
                issues.append("empty_country")
                empty_country += 1
            if not league:
                issues.append("empty_league")
                empty_league += 1
            if badge and cid is not None and badge != f"c_{cid}":
                issues.append("badge_key_mismatch")
            if (not placeholder) and name and (not country or not league):
                partial += 1

            if name:
                names[norm_text(name)].append(cid if cid is not None else -1)
            if issues:
                self.club_issues.append({
                    "row": idx,
                    "clubId": cid,
                    "name": name,
                    "country": country,
                    "league": league,
                    "issues": ";".join(issues),
                })

        for cid, count in duplicate_ids.items():
            self.issue("error", "DUPLICATE_CLUB_ID", "Aynı club ID birden fazla kez bulunuyor.", clubId=cid, duplicates=count + 1)

        dup_names = [(name, vals) for name, vals in names.items() if name and len(set(vals)) > 1]
        for name, vals in sorted(dup_names, key=lambda x: -len(x[1]))[:1000]:
            self.duplicate_names.append({"entity": "club", "normalizedName": name, "ids": ",".join(map(str, sorted(set(vals)))), "count": len(set(vals))})

        self.summary.update({
            "clubCount": len(clubs),
            "clubUniqueIdCount": len(ids),
            "clubPlaceholderCount": unresolved,
            "clubPartialCount": partial,
            "clubEmptyCountryCount": empty_country,
            "clubEmptyLeagueCount": empty_league,
            "duplicateClubIdCount": len(duplicate_ids),
            "duplicateClubNameGroups": len(dup_names),
        })
        return ids, Counter()

    def audit_players(self, players: list[dict[str, Any]], clubs_by_id: dict[int, dict[str, Any]]) -> tuple[dict[int, dict[str, Any]], Counter]:
        ids: dict[int, dict[str, Any]] = {}
        duplicate_ids = Counter()
        names: dict[str, list[int]] = defaultdict(list)
        club_usage = Counter()
        no_clubs = no_country = no_position = 0
        timeline_any = timeline3 = goals_any = peak_any = 0
        national_any = 0

        for idx, p in enumerate(players):
            pid = as_int(p.get("id"))
            name = str(p.get("name") or "").strip()
            countries = p.get("countries") if isinstance(p.get("countries"), list) else []
            position = str(p.get("position") or "").strip()
            clubs = p.get("clubIds") if isinstance(p.get("clubIds"), list) else p.get("clubs") if isinstance(p.get("clubs"), list) else []
            timeline = p.get("careerTimeline") if isinstance(p.get("careerTimeline"), list) else []
            issues = []

            if pid is None or pid <= 0:
                issues.append("invalid_id")
            else:
                if pid in ids:
                    duplicate_ids[pid] += 1
                else:
                    ids[pid] = p

            if not name:
                issues.append("empty_name")
            else:
                names[norm_text(name)].append(pid if pid is not None else -1)
            if not countries:
                issues.append("empty_countries")
                no_country += 1
            if not position:
                issues.append("empty_position")
                no_position += 1
            elif position not in CANONICAL_POSITIONS:
                issues.append("noncanonical_position")

            club_ids: list[int] = []
            invalid_club_values = 0
            for raw in clubs:
                cid = as_int(raw)
                if cid is None or cid <= 0:
                    invalid_club_values += 1
                    continue
                club_ids.append(cid)
                club_usage[cid] += 1
                if cid not in clubs_by_id:
                    self.orphan_refs.append({
                        "source": "player.clubIds", "playerId": pid, "playerName": name,
                        "clubId": cid, "detail": "club not found in clubs_min.json"
                    })
            if invalid_club_values:
                issues.append("invalid_club_id_value")
            if not club_ids:
                no_clubs += 1
                issues.append("no_clubs")
            if len(club_ids) != len(set(club_ids)):
                issues.append("duplicate_club_ids")
            if club_ids and club_ids != sorted(club_ids):
                issues.append("club_ids_not_sorted")

            if timeline:
                timeline_any += 1
            if len(timeline) >= 3:
                timeline3 += 1
            timeline_clubs: set[int] = set()
            prev_start = None
            prev_club = None
            for order, stop in enumerate(timeline):
                if not isinstance(stop, dict):
                    self.timeline_issues.append({"playerId": pid, "playerName": name, "stop": order, "clubId": "", "startYear": "", "endYear": "", "issue": "stop_not_object"})
                    continue
                cid = as_int(stop.get("clubId"))
                start = as_int(stop.get("startYear"))
                end = as_int(stop.get("endYear"))
                t_issues = []
                if cid is None or cid <= 0:
                    t_issues.append("invalid_club_id")
                else:
                    timeline_clubs.add(cid)
                    if cid not in clubs_by_id:
                        t_issues.append("orphan_club")
                        self.orphan_refs.append({
                            "source": "player.careerTimeline", "playerId": pid, "playerName": name,
                            "clubId": cid, "detail": f"timeline stop {order} club not found"
                        })
                    if cid not in set(club_ids):
                        t_issues.append("timeline_club_missing_from_clubIds")
                if start is None:
                    t_issues.append("missing_start_year")
                elif start < 1880 or start > CURRENT_YEAR + 2:
                    t_issues.append("implausible_start_year")
                if end is not None:
                    if end < 1880 or end > CURRENT_YEAR + 3:
                        t_issues.append("implausible_end_year")
                    if start is not None and end < start:
                        t_issues.append("end_before_start")
                if start is not None and prev_start is not None and start < prev_start:
                    t_issues.append("timeline_not_chronological")
                if cid is not None and prev_club == cid:
                    t_issues.append("consecutive_duplicate_club")
                if start is not None:
                    prev_start = start
                if cid is not None:
                    prev_club = cid
                if t_issues:
                    self.timeline_issues.append({
                        "playerId": pid, "playerName": name, "stop": order, "clubId": cid,
                        "startYear": start, "endYear": end, "issue": ";".join(t_issues)
                    })

            market = as_float(p.get("marketValue")) or 0.0
            peak = as_float(p.get("peakMarketValue")) or 0.0
            goals = as_int(p.get("careerGoals")) or 0
            if market < 0 or peak < 0:
                issues.append("negative_market_value")
            if peak > 0:
                peak_any += 1
            if goals > 0:
                goals_any += 1
            if goals < 0:
                issues.append("negative_career_goals")
            if market > 0 and peak > 0 and market > peak:
                issues.append("market_value_above_peak")
            national_teams = p.get("nationalTeams")
            if isinstance(national_teams, list) and national_teams:
                national_any += 1

            if issues:
                self.player_issues.append({
                    "row": idx,
                    "playerId": pid,
                    "name": name,
                    "countryCount": len(countries),
                    "position": position,
                    "clubCount": len(club_ids),
                    "timelineStops": len(timeline),
                    "issues": ";".join(issues),
                })

        for pid, count in duplicate_ids.items():
            self.issue("error", "DUPLICATE_PLAYER_ID", "Aynı player ID birden fazla kez bulunuyor.", playerId=pid, duplicates=count + 1)

        dup_names = [(name, vals) for name, vals in names.items() if name and len(set(vals)) > 1]
        for name, vals in sorted(dup_names, key=lambda x: -len(x[1]))[:5000]:
            self.duplicate_names.append({"entity": "player", "normalizedName": name, "ids": ",".join(map(str, sorted(set(vals))[:40])), "count": len(set(vals))})

        self.summary.update({
            "playerCount": len(players),
            "playerUniqueIdCount": len(ids),
            "duplicatePlayerIdCount": len(duplicate_ids),
            "duplicatePlayerNameGroups": len(dup_names),
            "playersWithoutClubs": no_clubs,
            "playersWithoutCountries": no_country,
            "playersWithoutPosition": no_position,
            "playersWithTimeline": timeline_any,
            "playersWithTimeline3Plus": timeline3,
            "playersWithCareerGoals": goals_any,
            "playersWithPeakMarketValue": peak_any,
            "playersWithNationalTeams": national_any,
            "uniqueReferencedClubCount": len(club_usage),
        })
        return ids, club_usage

    def audit_transfers(self, transfers: list[dict[str, Any]], players_by_id: dict[int, dict[str, Any]], clubs_by_id: dict[int, dict[str, Any]]) -> None:
        seen = set()
        valid = 0
        for idx, t in enumerate(transfers):
            pid = as_int(t.get("playerId"))
            frm = as_int(t.get("fromClubId"))
            to = as_int(t.get("toClubId"))
            year = as_int(t.get("year"))
            fee = as_float(t.get("fee"))
            issues = []
            if pid is None or pid not in players_by_id:
                issues.append("missing_player")
            if frm is None or frm not in clubs_by_id:
                issues.append("missing_from_club")
            if to is None or to not in clubs_by_id:
                issues.append("missing_to_club")
            if frm is not None and to is not None and frm == to:
                issues.append("same_from_to_club")
            if year is None or year < 1880 or year > CURRENT_YEAR + 2:
                issues.append("invalid_year")
            if fee is not None and fee < 0:
                issues.append("negative_fee")
            key = (pid, frm, to, year)
            if key in seen:
                issues.append("duplicate_transfer")
            seen.add(key)
            if issues:
                self.transfer_issues.append({
                    "row": idx, "playerId": pid, "fromClubId": frm, "toClubId": to,
                    "year": year, "fee": fee, "issues": ";".join(issues)
                })
            else:
                valid += 1
        self.summary["famousTransferCount"] = len(transfers)
        self.summary["validFamousTransferCount"] = valid

    def classify_clubs(self, clubs_by_id: dict[int, dict[str, Any]], club_usage: Counter) -> None:
        unresolved_used = 0
        partial_used = 0
        unused = 0
        high_impact = []
        for cid, c in clubs_by_id.items():
            name = str(c.get("name") or "").strip()
            country = str(c.get("country") or "").strip()
            league = str(c.get("league") or "").strip()
            usage = club_usage.get(cid, 0)
            placeholder = bool(re.fullmatch(rf"Club\s+{cid}", name, flags=re.I))
            if usage == 0:
                unused += 1
            if usage and placeholder:
                unresolved_used += 1
                high_impact.append((usage, cid, name, country, league, "unresolved_used"))
            elif usage and (not country or not league):
                partial_used += 1
                high_impact.append((usage, cid, name, country, league, "partial_used"))
        self.summary["unusedClubCount"] = unused
        self.summary["usedUnresolvedClubCount"] = unresolved_used
        self.summary["usedPartialClubCount"] = partial_used
        for usage, cid, name, country, league, issue in sorted(high_impact, reverse=True)[:1000]:
            self.club_issues.append({
                "row": "", "clubId": cid, "name": name, "country": country,
                "league": league, "issues": issue, "playerUsage": usage
            })

    def readiness(self, players: list[dict[str, Any]], transfers: list[dict[str, Any]]) -> None:
        def count(pred) -> int:
            return sum(1 for p in players if pred(p))

        n = len(players)
        with_club2 = count(lambda p: len(p.get("clubIds") or p.get("clubs") or []) >= 2)
        with_country_club = count(lambda p: bool(p.get("countries")) and bool(p.get("clubIds") or p.get("clubs")))
        with_pos = count(lambda p: p.get("position") in CANONICAL_POSITIONS and bool(p.get("clubIds") or p.get("clubs")))
        career3 = count(lambda p: len(p.get("careerTimeline") or []) >= 3)
        higher_goals = count(lambda p: (as_int(p.get("careerGoals")) or 0) > 0)
        higher_value = count(lambda p: (as_float(p.get("peakMarketValue")) or 0) > 0)
        national = count(lambda p: bool(p.get("nationalTeams")))
        future_popularity = count(lambda p: (as_float(p.get("popularity")) or 0) > 0)
        birth = count(lambda p: as_int(p.get("birthYear")) is not None)
        foot = count(lambda p: bool(p.get("foot")))
        height = count(lambda p: as_int(p.get("height")) is not None)

        def add(game: str, requirement: str, eligible: int, status: str, note: str = ""):
            self.game_readiness.append({
                "game": game, "requirement": requirement, "eligiblePlayers": eligible,
                "coveragePct": round(pct(eligible, n), 2), "status": status, "note": note
            })

        add("Shared XI / Club×Club", ">=2 clubIds", with_club2, "GOOD" if with_club2 >= 5000 else "REVIEW")
        add("Grid / Reverse Grid", "country + club", with_country_club, "GOOD" if with_country_club >= 5000 else "REVIEW")
        add("Build XI", "canonical position + club", with_pos, "GOOD" if with_pos >= 5000 else "REVIEW")
        add("Career Puzzle / Journey", ">=3 careerTimeline stops", career3, "GOOD" if career3 >= 3000 else "WEAK")
        add("Higher/Lower: Goals", "careerGoals > 0", higher_goals, "GOOD" if higher_goals >= 2000 else "WEAK")
        add("Higher/Lower: Peak value", "peakMarketValue > 0", higher_value, "GOOD" if higher_value >= 2000 else "WEAK", "Hak/lisans yaklaşımında bu kriteri ileride kaldırmayı planlıyoruz.")
        add("Transfer Detective", "valid famous transfers", len(transfers), "GOOD" if len(transfers) >= 500 else "WEAK")
        add("International modes", "nationalTeams present", national, "GOOD" if national >= 2000 else "WEAK")
        add("Difficulty / Daily pools", "popularity > 0", future_popularity, "GOOD" if future_popularity >= 5000 else "MISSING")
        add("Mystery: birth year", "birthYear present", birth, "GOOD" if birth >= 5000 else "MISSING")
        add("Mystery: preferred foot", "foot present", foot, "GOOD" if foot >= 5000 else "MISSING")
        add("Mystery / Higher-Lower: height", "height present", height, "GOOD" if height >= 5000 else "MISSING")

    def meta_check(self, meta: dict[str, Any], players: list[Any], clubs: list[Any], coaches: list[Any], transfers: list[Any]) -> None:
        checks = [
            ("playerCount", len(players)),
            ("clubCount", len(clubs)),
            ("coachCount", len(coaches)),
            ("famousTransferCount", len(transfers)),
        ]
        for key, actual in checks:
            declared = as_int(meta.get(key))
            if declared is not None and declared != actual:
                self.issue("error", "META_COUNT_MISMATCH", f"meta.json {key} gerçek dosya sayısıyla uyuşmuyor.", field=key, declared=declared, actual=actual)
        self.summary["schemaVersion"] = meta.get("schemaVersion")
        self.summary["dataVersion"] = meta.get("dataVersion")
        self.summary["preferMin"] = bool(meta.get("preferMin"))

    def deep_compare(self, min_players: list[dict[str, Any]], min_clubs: list[dict[str, Any]]) -> None:
        full_players_path = self.data_dir / "players.json"
        full_clubs_path = self.data_dir / "clubs.json"
        if not full_players_path.exists():
            self.issue("info", "DEEP_NO_FULL_PLAYERS", "--deep istendi ama players.json bulunamadı.")
            return
        try:
            full_players = json_load(full_players_path)
        except Exception as e:
            self.issue("warning", "DEEP_FULL_PLAYERS_LOAD_FAILED", "players.json deep audit için yüklenemedi.", error=str(e))
            return
        if not isinstance(full_players, list):
            self.issue("warning", "DEEP_FULL_PLAYERS_NOT_LIST", "players.json JSON list değil.")
            return

        min_by_id = {as_int(p.get("id")): p for p in min_players if as_int(p.get("id")) is not None}
        full_by_id = {as_int(p.get("id")): p for p in full_players if as_int(p.get("id")) is not None}
        all_ids = set(min_by_id) | set(full_by_id)
        only_min = sum(1 for x in all_ids if x in min_by_id and x not in full_by_id)
        only_full = sum(1 for x in all_ids if x in full_by_id and x not in min_by_id)
        self.summary["deepFullPlayerCount"] = len(full_players)
        self.summary["deepPlayersOnlyInMin"] = only_min
        self.summary["deepPlayersOnlyInFull"] = only_full

        compare_fields = ["name", "countries", "position", "clubIds", "careerTimeline", "careerGoals", "marketValue", "peakMarketValue", "nationalTeams", "detailedPosition"]
        for field in compare_fields:
            min_useful = sum(1 for p in min_players if p.get(field) not in (None, "", [], {}, 0, 0.0))
            full_useful = sum(1 for p in full_players if p.get(field) not in (None, "", [], {}, 0, 0.0))
            self.full_min_diff.append({
                "field": field,
                "minUseful": min_useful,
                "minPct": round(pct(min_useful, len(min_players)), 2),
                "fullUseful": full_useful,
                "fullPct": round(pct(full_useful, len(full_players)), 2),
                "delta": full_useful - min_useful,
            })

        # Sample structural mismatches for shared ids (limit output; count all).
        mismatch_counts = Counter()
        examples = defaultdict(list)
        for pid in set(min_by_id) & set(full_by_id):
            a, b = min_by_id[pid], full_by_id[pid]
            for field in compare_fields:
                av = a.get(field)
                bv = b.get(field)
                if field == "clubIds":
                    av = sorted(set(av or a.get("clubs") or []))
                    bv = sorted(set(bv or b.get("clubs") or []))
                if av != bv:
                    mismatch_counts[field] += 1
                    if len(examples[field]) < 20:
                        examples[field].append(pid)
        for field, cnt in mismatch_counts.items():
            self.full_min_diff.append({
                "field": f"VALUE_MISMATCH:{field}", "minUseful": "", "minPct": "",
                "fullUseful": "", "fullPct": "", "delta": cnt,
                "examples": ",".join(map(str, examples[field]))
            })

        if full_clubs_path.exists():
            try:
                full_clubs = json_load(full_clubs_path)
                self.summary["deepFullClubCount"] = len(full_clubs) if isinstance(full_clubs, list) else None
            except Exception as e:
                self.issue("warning", "DEEP_FULL_CLUBS_LOAD_FAILED", "clubs.json deep audit için yüklenemedi.", error=str(e))

    def generate_recommendations(self) -> list[dict[str, str]]:
        recs: list[dict[str, str]] = []
        def add(priority: str, title: str, reason: str):
            recs.append({"priority": priority, "title": title, "reason": reason})

        if self.summary.get("duplicatePlayerIdCount", 0):
            add("P0", "Duplicate player ID'leri çöz", "Canonical player tablosunda ID tekil olmalı.")
        if self.summary.get("duplicateClubIdCount", 0):
            add("P0", "Duplicate club ID'leri çöz", "Player→club referansları güvenilir kalamaz.")
        if self.orphan_refs:
            add("P0", "Orphan club referanslarını sıfıra indir", f"{len(self.orphan_refs)} player/timeline/transfer referansı clubs tablosunda karşılık bulmuyor.")
        if self.summary.get("clubPlaceholderCount", 0):
            add("P1", "Club {id} kayıtlarını resolve et", f"{self.summary['clubPlaceholderCount']} placeholder kulüp var; kullanılanlar soru havuzundan çıkarılmalı.")
        if self.summary.get("playersWithTimeline3Plus", 0) < 3000:
            add("P1", "Career spell katmanını zenginleştir", "Career Puzzle/Journey için güvenilir zaman çizelgesi havuzu düşük.")
        if self.summary.get("playersWithCareerGoals", 0) < 2000:
            add("P1", "Aggregate player stats üret", "Higher/Lower ve stat tabanlı modlar için careerGoals kapsamı düşük.")
        if self.summary.get("playersWithNationalTeams", 0) < 2000:
            add("P1", "National stats/team mapping ekle", "International modlar ve grid kriterleri genişler.")
        if self.summary.get("pubspecBundlesWholeDataDir") and (self.data_dir / "players.json").exists():
            add("P1", "Full JSON'ları production bundle'dan çıkar", "Runtime min veri kullansa bile assets/data/ klasörü topluca paketleniyor olabilir.")
        add("P1", "Popularity/quality katmanını oluştur", "Database player, playable player ve question candidate ayrımı için gerekli.")
        add("P2", "Competition tablosunu canonical hale getir", "League string'lerini normalize ederek Grid/Daily/Manager içeriklerini güvenilir üret.")
        return recs

    def write_report(self, recommendations: list[dict[str, str]]) -> None:
        self.out_dir.mkdir(parents=True, exist_ok=True)
        write_csv(self.out_dir / "file_inventory.csv", self.file_inventory)
        write_csv(self.out_dir / "field_coverage.csv", self.field_coverage)
        write_csv(self.out_dir / "player_issues.csv", self.player_issues)
        write_csv(self.out_dir / "club_issues.csv", self.club_issues)
        write_csv(self.out_dir / "timeline_issues.csv", self.timeline_issues)
        write_csv(self.out_dir / "orphan_club_references.csv", self.orphan_refs)
        write_csv(self.out_dir / "transfer_issues.csv", self.transfer_issues)
        write_csv(self.out_dir / "duplicate_names.csv", self.duplicate_names)
        write_csv(self.out_dir / "game_readiness.csv", self.game_readiness)
        if self.full_min_diff:
            write_csv(self.out_dir / "full_min_diff.csv", self.full_min_diff)
        write_csv(self.out_dir / "issues.csv", self.issues)
        write_csv(self.out_dir / "recommendations.csv", recommendations)

        payload = {
            "auditVersion": "03A-1.0",
            "generatedAtUtc": self.now.isoformat(),
            "repoRoot": str(self.root),
            "dataDir": str(self.data_dir),
            "deep": self.deep,
            "severity": asdict(self.severity),
            "summary": self.summary,
            "recommendations": recommendations,
        }
        (self.out_dir / "report.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        s = self.summary
        sev = self.severity
        md = []
        md.append("# Linkball Data Audit — Step 03A")
        md.append("")
        md.append(f"Generated: `{self.now.isoformat()}`  ")
        md.append(f"Mode: `{'deep' if self.deep else 'standard'}`")
        md.append("")
        md.append("## Executive summary")
        md.append("")
        md.append(f"- Players: **{s.get('playerCount', 0):,}**")
        md.append(f"- Clubs: **{s.get('clubCount', 0):,}**")
        md.append(f"- Famous transfers: **{s.get('famousTransferCount', 0):,}**")
        md.append(f"- Unique referenced clubs: **{s.get('uniqueReferencedClubCount', 0):,}**")
        md.append(f"- Orphan club references: **{len(self.orphan_refs):,}**")
        md.append(f"- Placeholder clubs (`Club {{id}}`): **{s.get('clubPlaceholderCount', 0):,}**")
        md.append(f"- Players without clubs: **{s.get('playersWithoutClubs', 0):,}**")
        md.append(f"- Players with 3+ timeline stops: **{s.get('playersWithTimeline3Plus', 0):,}**")
        md.append(f"- Players with career goals: **{s.get('playersWithCareerGoals', 0):,}**")
        md.append(f"- Players with nationalTeams: **{s.get('playersWithNationalTeams', 0):,}**")
        md.append(f"- Known data asset size: **{s.get('knownAssetSize', '—')}**")
        md.append("")
        md.append(f"Audit issues: **{sev.error} error / {sev.warning} warning / {sev.info} info**")
        md.append("")
        md.append("## Club health")
        md.append("")
        md.append(f"- Duplicate club IDs: **{s.get('duplicateClubIdCount', 0):,}**")
        md.append(f"- Empty country: **{s.get('clubEmptyCountryCount', 0):,}**")
        md.append(f"- Empty league: **{s.get('clubEmptyLeagueCount', 0):,}**")
        md.append(f"- Used unresolved clubs: **{s.get('usedUnresolvedClubCount', 0):,}**")
        md.append(f"- Used partial clubs: **{s.get('usedPartialClubCount', 0):,}**")
        md.append(f"- Unused clubs: **{s.get('unusedClubCount', 0):,}**")
        md.append("")
        md.append("## Player health")
        md.append("")
        md.append(f"- Duplicate player IDs: **{s.get('duplicatePlayerIdCount', 0):,}**")
        md.append(f"- Duplicate normalized-name groups: **{s.get('duplicatePlayerNameGroups', 0):,}**")
        md.append(f"- Missing countries: **{s.get('playersWithoutCountries', 0):,}**")
        md.append(f"- Missing positions: **{s.get('playersWithoutPosition', 0):,}**")
        md.append(f"- Timeline present: **{s.get('playersWithTimeline', 0):,}**")
        md.append(f"- Timeline 3+ stops: **{s.get('playersWithTimeline3Plus', 0):,}**")
        md.append("")
        md.append("## Game readiness")
        md.append("")
        md.append("| Game/data capability | Eligible | Coverage | Status |")
        md.append("|---|---:|---:|---|")
        for r in self.game_readiness:
            md.append(f"| {r['game']} | {r['eligiblePlayers']:,} | {r['coveragePct']:.2f}% | **{r['status']}** |")
        md.append("")
        md.append("## Recommended next actions")
        md.append("")
        for r in recommendations:
            md.append(f"- **{r['priority']} — {r['title']}**: {r['reason']}")
        md.append("")
        md.append("## Files to send back for Step 03B")
        md.append("")
        md.append("Send these files from `reports/data_audit/latest/`:")
        md.append("")
        md.append("- `report.md`")
        md.append("- `report.json`")
        md.append("- `orphan_club_references.csv`")
        md.append("- `club_issues.csv`")
        md.append("- `field_coverage.csv`")
        md.append("- `game_readiness.csv`")
        md.append("- `full_min_diff.csv` if deep mode was used")
        md.append("")
        md.append("> This audit is read-only. It does not modify assets/data files.")
        (self.out_dir / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")

    def run(self) -> int:
        required = ["meta.json", "players_min.json", "clubs_min.json"]
        missing = [name for name in required if not (self.data_dir / name).exists()]
        if missing:
            print("ERROR: Required data files missing:", ", ".join(missing), file=sys.stderr)
            print(f"Expected data directory: {self.data_dir}", file=sys.stderr)
            return 2

        print("=== Linkball Data Audit 03A ===")
        print(f"Repo: {self.root}")
        print(f"Data: {self.data_dir}")
        print(f"Mode: {'deep' if self.deep else 'standard'}")
        print("Loading data...")

        self.inventory()
        meta = json_load(self.data_dir / "meta.json")
        players = json_load(self.data_dir / "players_min.json")
        clubs = json_load(self.data_dir / "clubs_min.json")
        coaches_path = self.data_dir / "coaches_min.json"
        transfers_path = self.data_dir / "famous_transfers.json"
        coaches = json_load(coaches_path) if coaches_path.exists() else []
        transfers = json_load(transfers_path) if transfers_path.exists() else []

        if not isinstance(meta, dict) or not isinstance(players, list) or not isinstance(clubs, list):
            print("ERROR: meta/players/clubs JSON top-level schema is invalid.", file=sys.stderr)
            return 3
        if not isinstance(coaches, list):
            coaches = []
        if not isinstance(transfers, list):
            transfers = []

        print("Auditing schemas and references...")
        self.field_stats(players, "player", PLAYER_CURRENT_FIELDS + PLAYER_FUTURE_FIELDS)
        self.field_stats(clubs, "club", CLUB_CURRENT_FIELDS)
        clubs_by_id, _ = self.audit_clubs(clubs)
        players_by_id, club_usage = self.audit_players(players, clubs_by_id)
        self.audit_transfers(transfers, players_by_id, clubs_by_id)
        self.classify_clubs(clubs_by_id, club_usage)
        self.meta_check(meta, players, clubs, coaches, transfers)
        self.readiness(players, transfers)

        if self.orphan_refs:
            self.issue("error", "ORPHAN_CLUB_REFERENCES", "Player/timeline kayıtlarında clubs tablosunda olmayan club ID referansları var.", count=len(self.orphan_refs))
        if self.timeline_issues:
            self.issue("warning", "TIMELINE_ISSUES", "Career timeline kayıtlarında yapısal/tarihsel sorunlar var.", count=len(self.timeline_issues))
        if self.summary.get("clubPlaceholderCount", 0):
            self.issue("warning", "PLACEHOLDER_CLUBS", "Club {id} placeholder kayıtları mevcut.", count=self.summary["clubPlaceholderCount"])
        if self.summary.get("playersWithoutClubs", 0):
            self.issue("warning", "PLAYERS_WITHOUT_CLUBS", "clubIds bulunmayan oyuncular var.", count=self.summary["playersWithoutClubs"])

        if self.deep:
            print("Deep comparing full/min datasets (can use extra memory)...")
            self.deep_compare(players, clubs)

        recommendations = self.generate_recommendations()
        self.write_report(recommendations)

        print("")
        print("DONE")
        print(f"Report: {self.out_dir / 'report.md'}")
        print(f"Errors: {self.severity.error} | Warnings: {self.severity.warning} | Info: {self.severity.info}")
        print("This audit did not modify your data files.")
        return 0


def resolve_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    # Script lives under repo/tools/data_audit/audit.py after installation.
    candidate = Path(__file__).resolve().parents[2]
    if (candidate / "pubspec.yaml").exists():
        return candidate
    return Path.cwd().resolve()


def main() -> int:
    parser = argparse.ArgumentParser(description="Linkball Data Platform v3 Step 03A read-only audit")
    parser.add_argument("--root", help="Repository root; auto-detected by default")
    parser.add_argument("--data-dir", help="Data directory; default <root>/assets/data")
    parser.add_argument("--out", help="Output directory; default <root>/reports/data_audit/latest")
    parser.add_argument("--deep", action="store_true", help="Also load/compare players.json and clubs.json if present")
    args = parser.parse_args()

    root = resolve_root(args.root)
    data_dir = Path(args.data_dir).expanduser().resolve() if args.data_dir else root / "assets" / "data"
    out_dir = Path(args.out).expanduser().resolve() if args.out else root / "reports" / "data_audit" / "latest"
    return Audit(root, data_dir, out_dir, deep=args.deep).run()


if __name__ == "__main__":
    raise SystemExit(main())
