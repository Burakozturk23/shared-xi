from pathlib import Path
import shutil
import re

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart"
DBSERVICE = ROOT / "lib/services/database_service.dart"

def backup(path: Path):
    bak = path.with_suffix(path.suffix + ".step07a7.bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print("[BACKUP]", bak.relative_to(ROOT))
    return bak

def write(path: Path, text: str):
    with path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def wrap_single_line(text, needle, label):
    if f"[StartupPerf] {label}=" in text:
        return text, True
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if needle not in line:
            continue
        indent = line[:len(line)-len(line.lstrip())]
        var = "__perf_" + re.sub(r"[^A-Za-z0-9_]", "_", label)
        new = [
            f"{indent}final {var} = Stopwatch()..start();",
            line,
            f"{indent}print('[StartupPerf] {label}=${{{var}.elapsedMilliseconds}}ms');",
        ]
        lines[i:i+1] = new
        return "\n".join(lines) + "\n", True
    return text, False

def wrap_multiline_call(text, start_needle, label):
    if f"[StartupPerf] {label}=" in text:
        return text, True

    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if start_needle in line:
            start = i
            break
    if start is None:
        return text, False

    indent = lines[start][:len(lines[start])-len(lines[start].lstrip())]
    depth = 0
    seen_paren = False
    end = None

    for i in range(start, len(lines)):
        line = lines[i]
        for ch in line:
            if ch == "(":
                depth += 1
                seen_paren = True
            elif ch == ")":
                depth -= 1
        if seen_paren and depth <= 0 and ";" in line:
            end = i
            break

    if end is None:
        return text, False

    var = "__perf_" + re.sub(r"[^A-Za-z0-9_]", "_", label)
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

    targets = [
        ("final manifestRaw = await rootBundle.loadString(_manifestAsset);", "v3_manifest_load"),
        ("final databasesPath = await getDatabasesPath();", "v3_get_db_path"),
        ("var mustCopy = !await target.exists();", "v3_target_exists"),
        ("mustCopy = (await target.stat()).size != expectedBytes;", "v3_target_stat"),
        ("final data = await rootBundle.load(_dbAsset);", "v3_sqlite_asset_load"),
        ("await temp.writeAsBytes(bytes, flush: true);", "v3_sqlite_write_flush"),
        ("if (await temp.exists()) await temp.delete();", "v3_temp_cleanup"),
        ("if (await target.exists()) await target.delete();", "v3_old_target_delete"),
        ("await temp.rename(target.path);", "v3_temp_rename"),
        ("final integrity = await _database.rawQuery('PRAGMA integrity_check');", "v3_integrity_check"),
        ("final meta = await metadata();", "v3_metadata"),
    ]

    misses = []
    for needle, label in targets:
        text, ok = wrap_single_line(text, needle, label)
        if not ok:
            misses.append(label)

    text, ok = wrap_multiline_call(
        text,
        "_db = await openDatabase(",
        "v3_open_database",
    )
    if not ok:
        misses.append("v3_open_database")

    write(RUNTIME, text)

    print("[PATCH] runtime_v3_platform_io.dart phase timers added.")
    if misses:
        print("[WARN] Runtime timer anchors not found:", ", ".join(misses))
    return misses

def patch_database_service():
    if not DBSERVICE.exists():
        raise RuntimeError("database_service.dart missing")
    backup(DBSERVICE)
    text = DBSERVICE.read_text(encoding="utf-8", errors="replace")

    # Instrument each asset loadString line independently.
    lines = text.splitlines()
    out = []
    asset_idx = 0
    for line in lines:
        if "await rootBundle.loadString(" in line and "[StartupPerf]" not in line:
            asset_idx += 1
            indent = line[:len(line)-len(line.lstrip())]
            var = f"__perf_json_asset_{asset_idx}"
            label = f"json_asset_load_{asset_idx}"
            out.append(f"{indent}final {var} = Stopwatch()..start();")
            out.append(line)
            out.append(
                f"{indent}print('[StartupPerf] {label}=${{{var}.elapsedMilliseconds}}ms');"
            )
        else:
            out.append(line)
    text = "\n".join(out) + "\n"

    parse_targets = [
        ("_clubsCache = await compute(_parseClubs, raw);", "json_parse_clubs"),
        ("_playersCache = await compute(_parsePlayers, raw);", "json_parse_players"),
        ("_coachesCache = await compute(_parseCoaches, raw);", "json_parse_coaches"),
        ("_famousTransfersCache = await compute(_parseFamous, raw);", "json_parse_famous"),
    ]

    misses = []
    for needle, label in parse_targets:
        text, ok = wrap_single_line(text, needle, label)
        if not ok:
            misses.append(label)

    write(DBSERVICE, text)
    print(f"[PATCH] database_service.dart asset timers added: {asset_idx}")
    if misses:
        print("[WARN] JSON parser anchors not found:", ", ".join(misses))
    return misses

def main():
    runtime_misses = patch_runtime()
    db_misses = patch_database_service()

    print()
    print("[SAFE] Profiling only. No runtime behavior intentionally changed.")
    print("[SAFE] Backups created with .step07a7.bak suffix.")
    print("[INFO] Missing optional anchors:", len(runtime_misses) + len(db_misses))

if __name__ == "__main__":
    main()
