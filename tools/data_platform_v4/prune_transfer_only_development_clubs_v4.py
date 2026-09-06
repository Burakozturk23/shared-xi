#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB = ROOT / "assets" / "runtime" / "linkball_game_data_v4.sqlite"
DEFAULT_MANIFEST = ROOT / "assets" / "runtime" / "linkball_game_data_v4_manifest.json"

BAD_NAME_PREDICATE = """
(
  TRIM(c.name) = ''
  OR LOWER(TRIM(c.name)) LIKE 'club %'
  OR LOWER(c.name) LIKE '% u16%'
  OR LOWER(c.name) LIKE '% u17%'
  OR LOWER(c.name) LIKE '% u18%'
  OR LOWER(c.name) LIKE '% u19%'
  OR LOWER(c.name) LIKE '% u20%'
  OR LOWER(c.name) LIKE '% u21%'
  OR LOWER(c.name) LIKE '% u23%'
  OR LOWER(c.name) LIKE '%under 16%'
  OR LOWER(c.name) LIKE '%under 17%'
  OR LOWER(c.name) LIKE '%under 18%'
  OR LOWER(c.name) LIKE '%under 19%'
  OR LOWER(c.name) LIKE '%under 20%'
  OR LOWER(c.name) LIKE '%under 21%'
  OR LOWER(c.name) LIKE '%under 23%'
  OR LOWER(c.name) LIKE '%youth%'
  OR LOWER(c.name) LIKE '%academy%'
  OR LOWER(c.name) LIKE '%juvenil%'
  OR LOWER(c.name) LIKE '%primavera%'
  OR LOWER(c.name) LIKE '%next gen%'
  OR LOWER(c.name) LIKE '%reserve%'
  OR LOWER(c.name) LIKE '%reserves%'
  OR LOWER(c.name) LIKE '% b team%'
  OR LOWER(c.name) LIKE '% b-team%'
  OR LOWER(TRIM(c.name)) LIKE '% ii'
  OR LOWER(COALESCE(c.entity_type, '')) IN (
    'youth', 'academy', 'reserve', 'reserves', 'development'
  )
)
"""


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def qident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def table_names(con: sqlite3.Connection) -> set[str]:
    return {
        str(r[0])
        for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }


def row_count(con: sqlite3.Connection, table: str) -> int:
    if table not in table_names(con):
        return 0
    return int(con.execute(f"SELECT COUNT(*) FROM {qident(table)}").fetchone()[0])


def candidate_setup(con: sqlite3.Connection) -> None:
    con.execute("DROP TABLE IF EXISTS temp._v4_prune_clubs")
    con.execute("CREATE TEMP TABLE _v4_prune_clubs(id INTEGER PRIMARY KEY)")
    con.execute(
        f"""
        INSERT INTO _v4_prune_clubs(id)
        SELECT c.id
        FROM clubs c
        WHERE {BAD_NAME_PREDICATE}
          AND EXISTS (
            SELECT 1 FROM transfers t
            WHERE t.from_club_id = c.id OR t.to_club_id = c.id
          )
        """
    )


def remove_structural_references(con: sqlite3.Connection) -> list[tuple[str, str, int]]:
    """Protect any candidate referenced outside transfers.

    We intentionally scan all shipped tables for club-id-shaped columns rather
    than hard-code only the schema we know today. This makes the prune fail-safe
    if a future compiler adds a new relation table.
    """
    protected: list[tuple[str, str, int]] = []
    names = table_names(con)
    club_columns = {"club_id", "from_club_id", "to_club_id"}

    for table in sorted(names):
        if table in {"clubs", "transfers"}:
            continue
        cols = [str(r[1]) for r in con.execute(f"PRAGMA table_info({qident(table)})")]
        for col in cols:
            if col.lower() not in club_columns:
                continue
            before = int(con.execute("SELECT COUNT(*) FROM _v4_prune_clubs").fetchone()[0])
            con.execute(
                f"""
                DELETE FROM _v4_prune_clubs
                WHERE id IN (
                  SELECT DISTINCT {qident(col)}
                  FROM {qident(table)}
                  WHERE {qident(col)} IS NOT NULL
                )
                """
            )
            after = int(con.execute("SELECT COUNT(*) FROM _v4_prune_clubs").fetchone()[0])
            removed = before - after
            if removed:
                protected.append((table, col, removed))

    return protected


def update_metadata(con: sqlite3.Connection, before_clubs: int, after_clubs: int,
                    before_transfers: int, after_transfers: int, pruned_clubs: int,
                    pruned_transfers: int) -> None:
    if "metadata" not in table_names(con):
        return
    rows = {
        "compiler_step": "08D.7O",
        "club_prune_policy": "transfer_only_development_v1",
        "club_count_before_prune": str(before_clubs),
        "club_count_after_prune": str(after_clubs),
        "transfer_count_before_prune": str(before_transfers),
        "transfer_count_after_prune": str(after_transfers),
        "pruned_transfer_only_development_clubs": str(pruned_clubs),
        "pruned_transfer_rows": str(pruned_transfers),
    }
    for key, value in rows.items():
        con.execute(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)",
            (key, value),
        )


def update_manifest(path: Path, db_path: Path, *, clubs: int, transfers: int,
                    pruned_clubs: int, pruned_transfers: int) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    db_info = data.setdefault("database", {})
    db_info["bytes"] = db_path.stat().st_size
    db_info["sha256"] = sha256_file(db_path)

    # Preserve unknown manifest structure. Update common count containers only
    # when they already exist; add an explicit pruning report either way.
    for key in ("counts", "row_counts", "tables"):
        container = db_info.get(key)
        if isinstance(container, dict):
            if "clubs" in container and isinstance(container["clubs"], int):
                container["clubs"] = clubs
            if "transfers" in container and isinstance(container["transfers"], int):
                container["transfers"] = transfers
    top_counts = data.get("counts")
    if isinstance(top_counts, dict):
        if "clubs" in top_counts and isinstance(top_counts["clubs"], int):
            top_counts["clubs"] = clubs
        if "transfers" in top_counts and isinstance(top_counts["transfers"], int):
            top_counts["transfers"] = transfers

    data["pruning"] = {
        "step": "08D.7O",
        "policy": "transfer_only_development_v1",
        "clubs_removed": pruned_clubs,
        "transfer_rows_removed": pruned_transfers,
        "clubs_remaining": clubs,
        "transfers_remaining": transfers,
    }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Safely prune transfer-only youth/reserve/development clubs from V4 SQLite."
    )
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--apply", action="store_true", help="Apply changes. Default is preview only.")
    args = ap.parse_args()

    db_path = args.db.resolve()
    manifest_path = args.manifest.resolve()
    if not db_path.exists():
        print(f"[FAIL] DB not found: {db_path}")
        return 2
    if not manifest_path.exists():
        print(f"[FAIL] Manifest not found: {manifest_path}")
        return 2

    print("===== 08D.7O V4 TRANSFER-ONLY DEVELOPMENT PRUNE =====")
    print(f"DB       : {db_path}")
    print(f"Manifest : {manifest_path}")

    con = sqlite3.connect(str(db_path))
    try:
        con.execute("PRAGMA foreign_keys=ON")
        names = table_names(con)
        required = {"clubs", "transfers"}
        missing = required - names
        if missing:
            print(f"[FAIL] Required tables missing: {sorted(missing)}")
            return 3

        before_clubs = row_count(con, "clubs")
        before_transfers = row_count(con, "transfers")
        candidate_setup(con)
        initial_candidates = int(con.execute("SELECT COUNT(*) FROM _v4_prune_clubs").fetchone()[0])
        protected = remove_structural_references(con)
        final_candidates = int(con.execute("SELECT COUNT(*) FROM _v4_prune_clubs").fetchone()[0])
        transfer_rows = int(
            con.execute(
                """
                SELECT COUNT(*)
                FROM transfers t
                WHERE EXISTS (SELECT 1 FROM _v4_prune_clubs p WHERE p.id = t.from_club_id)
                   OR EXISTS (SELECT 1 FROM _v4_prune_clubs p WHERE p.id = t.to_club_id)
                """
            ).fetchone()[0]
        )

        print(f"Clubs before                  : {before_clubs:,}")
        print(f"Transfers before              : {before_transfers:,}")
        print(f"Development + transfer refs   : {initial_candidates:,}")
        print(f"Structurally protected        : {initial_candidates - final_candidates:,}")
        print(f"Safe transfer-only candidates : {final_candidates:,}")
        print(f"Transfer rows to remove       : {transfer_rows:,}")
        for table, col, count in protected:
            print(f"  protect via {table}.{col}: {count:,}")

        samples = con.execute(
            """
            SELECT c.id, c.name,
                   (SELECT COUNT(*) FROM transfers t
                    WHERE t.from_club_id=c.id OR t.to_club_id=c.id) AS transfer_rows
            FROM clubs c JOIN _v4_prune_clubs p ON p.id=c.id
            ORDER BY transfer_rows DESC, c.name COLLATE NOCASE
            LIMIT 12
            """
        ).fetchall()
        for cid, name, n in samples:
            print(f"  candidate {cid} | {name} | transferRows={n}")

        if final_candidates == 0:
            print("[PASS] Nothing to prune.")
            return 0
        if final_candidates > before_clubs // 2:
            print("[FAIL] Safety stop: candidate set is unexpectedly >50% of all clubs.")
            return 4

        projected = before_clubs - final_candidates
        if projected < 3000:
            print(f"[FAIL] Safety stop: projected club count too low ({projected:,}).")
            return 4

        if not args.apply:
            print(f"[PREVIEW] Projected clubs: {projected:,}")
            print("[PREVIEW] No files changed. Re-run with --apply to prune.")
            return 0

        con.close()
        con = None

        db_backup = db_path.with_suffix(db_path.suffix + ".step08d7o.bak")
        manifest_backup = manifest_path.with_suffix(manifest_path.suffix + ".step08d7o.bak")
        if not db_backup.exists():
            shutil.copy2(db_path, db_backup)
        if not manifest_backup.exists():
            shutil.copy2(manifest_path, manifest_backup)
        print(f"Backup DB       : {db_backup}")
        print(f"Backup manifest : {manifest_backup}")

        con = sqlite3.connect(str(db_path))
        con.execute("PRAGMA foreign_keys=ON")
        con.execute("BEGIN IMMEDIATE")
        try:
            candidate_setup(con)
            remove_structural_references(con)
            final_candidates2 = int(con.execute("SELECT COUNT(*) FROM _v4_prune_clubs").fetchone()[0])
            if final_candidates2 != final_candidates:
                raise RuntimeError(
                    f"Candidate set changed between preview/apply: {final_candidates} -> {final_candidates2}"
                )

            con.execute(
                """
                DELETE FROM transfers
                WHERE EXISTS (SELECT 1 FROM _v4_prune_clubs p WHERE p.id = transfers.from_club_id)
                   OR EXISTS (SELECT 1 FROM _v4_prune_clubs p WHERE p.id = transfers.to_club_id)
                """
            )
            con.execute(
                "DELETE FROM clubs WHERE id IN (SELECT id FROM _v4_prune_clubs)"
            )

            after_clubs = row_count(con, "clubs")
            after_transfers = row_count(con, "transfers")
            update_metadata(
                con,
                before_clubs,
                after_clubs,
                before_transfers,
                after_transfers,
                final_candidates,
                before_transfers - after_transfers,
            )
            con.commit()
        except Exception:
            con.rollback()
            raise

        fk = con.execute("PRAGMA foreign_key_check").fetchall()
        quick = con.execute("PRAGMA quick_check").fetchone()[0]
        if fk or quick != "ok":
            raise RuntimeError(f"Integrity failed: quick_check={quick!r} foreign_keys={fk[:5]!r}")

        con.execute("ANALYZE")
        con.execute("VACUUM")
        con.close()
        con = None

        # Re-open after VACUUM for final verification/counts.
        verify = sqlite3.connect(str(db_path))
        verify.execute("PRAGMA foreign_keys=ON")
        after_clubs = row_count(verify, "clubs")
        after_transfers = row_count(verify, "transfers")
        quick = verify.execute("PRAGMA quick_check").fetchone()[0]
        fk = verify.execute("PRAGMA foreign_key_check").fetchall()
        verify.close()
        if quick != "ok" or fk:
            raise RuntimeError(f"Post-VACUUM integrity failed: quick={quick!r} fk={fk[:5]!r}")

        update_manifest(
            manifest_path,
            db_path,
            clubs=after_clubs,
            transfers=after_transfers,
            pruned_clubs=before_clubs - after_clubs,
            pruned_transfers=before_transfers - after_transfers,
        )

        print("\n===== RESULT =====")
        print(f"Clubs      : {before_clubs:,} -> {after_clubs:,}  (-{before_clubs-after_clubs:,})")
        print(f"Transfers  : {before_transfers:,} -> {after_transfers:,}  (-{before_transfers-after_transfers:,})")
        print(f"DB size MB : {db_path.stat().st_size / 1024 / 1024:.2f}")
        print(f"SHA-256    : {sha256_file(db_path)}")
        print("Quick check: ok")
        print("Foreign keys: ok")
        print("[PASS] 08D.7O production V4 prune completed.")
        return 0
    except Exception as e:
        print(f"[FAIL] {type(e).__name__}: {e}")
        return 1
    finally:
        if con is not None:
            con.close()


if __name__ == "__main__":
    sys.exit(main())
