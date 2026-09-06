from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
MAIN = LIB / "main.dart"
REPORT = ROOT / "reports/production/07a4"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "startup_source_scan.txt"

SYNC_PATTERNS = {
    "readAsStringSync": r"\breadAsStringSync\s*\(",
    "readAsBytesSync": r"\breadAsBytesSync\s*\(",
    "FileSync": r"\b(?:existsSync|lengthSync|statSync)\s*\(",
    "jsonDecode": r"\bjsonDecode\s*\(",
    "rootBundle.loadString": r"\brootBundle\.loadString\s*\(",
    "openDatabase": r"\bopenDatabase\s*\(",
    "sqflite": r"package:sqflite",
    "compute": r"\bcompute\s*\(",
    "Isolate": r"\bIsolate\b",
}

def line_number(text, pos):
    return text.count("\n", 0, pos) + 1

def main():
    if not MAIN.exists():
        raise SystemExit("[FAIL] lib/main.dart missing")

    text = MAIN.read_text(encoding="utf-8", errors="replace")
    run_pos = text.find("runApp(")

    if run_pos < 0:
        raise SystemExit("[FAIL] runApp() not found in main.dart")

    before = text[:run_pos]
    lines = before.splitlines()

    awaits = []
    for idx, line in enumerate(lines, start=1):
        if "await " in line:
            awaits.append((idx, line.strip()))

    # Find simple Foo.bar(...) awaited calls and search where class/file lives.
    call_targets = []
    call_re = re.compile(
        r"await\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)\s*\("
    )
    for idx, line in awaits:
        m = call_re.search(line)
        if m:
            call_targets.append((idx, m.group(1)))

    files = list(LIB.rglob("*.dart"))
    risky = []

    for path in files:
        try:
            content = path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        hits = []
        for name, pattern in SYNC_PATTERNS.items():
            for m in re.finditer(pattern, content):
                hits.append((line_number(content, m.start()), name))
        if hits:
            risky.append((path.relative_to(ROOT), hits))

    out = []
    out.append("==========================================================")
    out.append("LINKBALL STEP 07A.4 - STARTUP SOURCE SCAN")
    out.append("==========================================================")
    out.append("")
    out.append("Await calls before runApp():")
    if awaits:
        for idx, line in awaits:
            out.append(f"  L{idx}: {line}")
    else:
        out.append("  (none)")
    out.append("")

    out.append("Simple awaited call targets:")
    if call_targets:
        for idx, target in call_targets:
            out.append(f"  L{idx}: {target}")
    else:
        out.append("  (none)")
    out.append("")

    out.append("Potential heavy-I/O / decode markers under lib/:")
    for rel, hits in risky:
        shown = ", ".join(f"{name}@L{line}" for line, name in hits[:12])
        extra = "" if len(hits) <= 12 else f" (+{len(hits)-12} more)"
        out.append(f"  {rel}: {shown}{extra}")

    out.append("")
    out.append("Interpretation:")
    out.append("- pre-runApp awaits delay the first Flutter frame")
    out.append("- rootBundle/jsonDecode/openDatabase may be fine when async,")
    out.append("  but large work on the UI isolate can still cause skipped frames")
    out.append("- Sync file APIs are higher priority findings")
    out.append("")

    text_out = "\n".join(out)
    OUT.write_text(text_out + "\n", encoding="utf-8", newline="\n")
    print(text_out)
    print()
    print("[INFO] Saved:", OUT.relative_to(ROOT))

if __name__ == "__main__":
    main()
