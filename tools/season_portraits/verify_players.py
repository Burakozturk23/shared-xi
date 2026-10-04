#!/usr/bin/env python3
from __future__ import annotations

import json
import sqlite3
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("manifest.json")
DB = ROOT / "assets" / "runtime" / "linkball_game_data_v4.sqlite"


def norm(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(c for c in value if not unicodedata.combining(c))
    return "".join(c.lower() for c in value if c.isalnum())


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    aliases = manifest.get("aliases", {})
    requested = []
    seen = set()
    for season in ("2012_13", "2013_14"):
        for row in manifest["seasons"][season]:
            for name in row:
                if name not in seen:
                    seen.add(name)
                    requested.append(name)

    requested.extend(p['name'] for p in manifest.get('additionalPortraits', []))

    with sqlite3.connect(DB) as con:
        player_names = {row[0]: norm(row[1]) for row in con.execute("SELECT id, name FROM players")}
        search_terms = {}
        for player_id, term in con.execute("SELECT player_id, compact_term FROM player_search_terms"):
            if term:
                search_terms.setdefault(player_id, set()).add(norm(term))

    missing = []
    for name in requested:
        candidates = [name, *aliases.get(name, [])]
        player_id = manifest['playerIds'].get(name)
        terms = search_terms.get(player_id, set()) | {player_names.get(player_id, '')}
        if player_id is None or not any(norm(candidate) in terms for candidate in candidates):
            missing.append(name)

    print(f"Season portrait players: {len(requested)} unique across source sheets and additional portraits")
    if missing:
        print("Missing from bundled V4 data:")
        for name in missing:
            print(f"  - {name}")
        return 1

    print("[PASS] Every season portrait player resolves in bundled V4 data.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
