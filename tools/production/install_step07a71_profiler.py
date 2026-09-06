from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart"
DBSERVICE = ROOT / "lib/services/database_service.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".step07a71.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    else:
        print("[PASS] Backup already exists:", bak.relative_to(ROOT))
    return bak

def write_lf(path: Path, text: str):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def var_name(label: str) -> str:
    return "__perf_" + re.sub(r"[^A-Za-z0-9_]", "_", label)

def wrap_single_line_statement(text: str, needle: str, label: str):
    """Instrument only when the whole Dart statement ends on the same line."""
    if f"[StartupPerf] {label}=" in text:
        return text, True

    lines = text.splitlines()
    for i, line in enumerate(lines):
        if needle not in line:
            continue

        # Safety: never patch a multiline statement here.
        if ";" not in line:
            return text, False

        indent = line[:len(line) - len(line.lstrip())]
        var = var_name(label)
        replacement = [
            f"{indent}final {var} = Stopwatch()..start();",
            line,
            f"{indent}print('[StartupPerf] {label}=${{{var}.elapsedMilliseconds}}ms');",
        ]
        lines[i:i+1] = replacement
        return "\n".join(lines) + "\n", True

    return text, False

def wrap_multiline_call_from_start(text: str, needle: str, label: str):
    """
    Instrument a multiline call ONLY when the matching line is the actual
    statement start (e.g. `_db = await openDatabase(`).
    """
    if f"[StartupPerf] {label}=" in text:
        return text, True

    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if needle in line:
            start = i
            break
    if start is None:
        return text, False

    stripped = lines[start].strip()
    # Safety: this helper is used only for an explicit assignment start.
    if not stripped.startswith("_db = await openDatabase("):
        return text, False

    indent = lines[start][:len(lines[start]) - len(lines[start].lstrip())]
    depth = 0
    seen = False
    end = None

    for i in range(start, len(lines)):
        for ch in lines[i]:
            if ch == "(":
                depth += 1
                seen = True
            elif ch == ")":
                depth -= 1
        if seen and depth <= 0 and ";" in lines[i]:
            end = i
            break

    if end is None:
        return text, False

    var = var_name(label)
    lines.insert(start, f"{indent}final {var} = Stopwatch()..start();")
    end += 1
    lines.insert(
        end + 1,
        f"{indent}print('[StartupPerf] {label}=${{{var}.elapsedMilliseconds}}ms');",
    )

    return "\n".join(lines) + "\n", True

def patch_runtime():
    if not RUNTIME.exists():
        raise RuntimeError("runtime_v3_platform_io.dart missing")

    backup(RUNTIME)
    text = RUNTIME.read_text(encoding="utf-8", errors="replace")

    # All of these anchors are known single-line statements from the 07A.6 report.
    targets = [
        ("final manifestRaw = await rootBundle.loadString(_manifestAsset);", "v3_manifest_load"),
        ("final databasesPath = await getDatabasesPath();", "v3_get_db_path"),
        ("var mustCopy = !await target.exists();", "v3_target_exists"),
        ("mustCopy = (await target.stat()).size != expectedBytes;", "v3_target_stat"),
        ("final data = await rootBundle.load(_dbAsset);", "v3_sqlite_asset_load"),
        ("if (await temp.exists()) await temp.delete();", "v3_temp_cleanup"),
        ("await temp.writeAsBytes(bytes, flush: true);", "v3_sqlite_write_flush"),
        ("if (await target.exists()) await target.delete();", "v3_old_target_delete"),
        ("await temp.rename(target.path);", "v3_temp_rename"),
        ("final integrity = await _database.rawQuery('PRAGMA integrity_check');", "v3_integrity_check"),
        ("final meta = await metadata();", "v3_metadata"),
    ]

    required_missing = []

    for needle, label in targets:
        text, ok = wrap_single_line_statement(text, needle, label)
        if not ok:
            required_missing.append(label)

    text, ok = wrap_multiline_call_from_start(
        text,
        "_db = await openDatabase(",
        "v3_open_database",
    )
    if not ok:
        required_missing.append("v3_open_database")

    if required_missing:
        raise RuntimeError(
            "Required safe profiler anchors missing: "
            + ", ".join(required_missing)
        )

    write_lf(RUNTIME, text)
    print("[PATCH] Runtime V3 critical phase timers added safely.")

def patch_players_parse():
    if not DBSERVICE.exists():
        raise RuntimeError("database_service.dart missing")

    backup(DBSERVICE)
    text = DBSERVICE.read_text(encoding="utf-8", errors="replace")

    # Only this known one-line statement is touched.
    text, ok = wrap_single_line_statement(
        text,
        "_playersCache = await compute(_parsePlayers, raw);",
        "json_parse_players",
    )

    if not ok:
        print(
            "[WARN] players JSON parse anchor not found; "
            "continuing with Runtime V3-only profiling."
        )

    write_lf(DBSERVICE, text)
    print("[PATCH] database_service.dart safe players-parse timer handled.")

def main():
    patch_runtime()
    patch_players_parse()

    print()
    print("[SAFE] No multiline rootBundle.loadString statements are modified.")
    print("[SAFE] Profiling only; application behavior is otherwise unchanged.")
    print("[SAFE] Source backups use .step07a71.bak.")

if __name__ == "__main__":
    main()
