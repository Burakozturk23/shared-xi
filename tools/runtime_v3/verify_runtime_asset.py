from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "assets/runtime/linkball_runtime_v3.sqlite"
MANIFEST = ROOT / "assets/runtime/runtime_manifest_v3.json"

REQUIRED = {
    "players", "clubs", "player_clubs", "profiles", "player_stats",
    "career_spells", "transfers", "player_pools", "club_pools",
    "event_pools", "metadata",
}

def main():
    print("=" * 68)
    print("LINKBALL STEP 04.1 - SQLITE ASSET VERIFY")
    print("=" * 68)

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expected = manifest["database"]
    data = DB.read_bytes()
    sha = hashlib.sha256(data).hexdigest()

    assert len(data) == int(expected["bytes"]), "asset byte-size mismatch"
    assert sha == expected["sha256"], "asset sha256 mismatch"

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    try:
        integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
        assert integrity == "ok", f"integrity={integrity}"

        tables = {
            x[0] for x in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        assert not (REQUIRED - tables), f"missing tables={REQUIRED - tables}"

        fk = list(con.execute("PRAGMA foreign_key_check"))
        assert not fk, f"foreign key errors={len(fk)}"

        meta = dict(con.execute("SELECT key,value FROM metadata"))
        assert meta.get("schema_version") == "3-preview", meta

        keys = [
            x[0] for x in con.execute(
                "SELECT canonical_key FROM clubs "
                "WHERE canonical_key LIKE 'existing:%'"
            )
        ]
        ids = [int(k.split(":", 1)[1]) for k in keys]
        assert len(ids) == len(set(ids)), "duplicate existing:* club id"

        print(f"[PASS] sha256={sha}")
        print(f"[PASS] bytes={len(data):,}")
        print(f"[PASS] existing club bridge={len(ids):,}")
        print("[PASS] SQLite contract OK")
    finally:
        con.close()

if __name__ == "__main__":
    main()
