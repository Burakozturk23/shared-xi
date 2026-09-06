from pathlib import Path
import re, zipfile

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "lib"
APK = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
REPORT = ROOT / "reports/production/07a6"
REPORT.mkdir(parents=True, exist_ok=True)
OUT = REPORT / "runtime_bootstrap_forensics.txt"

HEAVY = {
    "rootBundle.load": r"\brootBundle\.load\s*\(",
    "rootBundle.loadString": r"\brootBundle\.loadString\s*\(",
    "jsonDecode": r"\bjsonDecode\s*\(",
    "openDatabase": r"\bopenDatabase\s*\(",
    "rawQuery": r"\brawQuery\s*\(",
    "query": r"\.query\s*\(",
    "File.copy": r"\.copy\s*\(",
    "writeAsBytes": r"\.writeAsBytes\s*\(",
    "compute": r"\bcompute\s*\(",
    "Isolate": r"\bIsolate\b",
}

def line_no(text, pos):
    return text.count("\n", 0, pos) + 1

def mb(n):
    return f"{n/(1024*1024):.1f} MB"

def main():
    ready = []
    runtime_files = []

    for path in LIB.rglob("*.dart"):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        for marker in ("[RuntimeV3] READY", "RuntimeV3] READY"):
            pos = text.find(marker)
            if pos >= 0:
                ready.append((path, text, line_no(text, pos)))
        if any(x in rel.lower() for x in ("runtime", "sqlite", "database", "bootstrap", "repository")) or "[RuntimeV3]" in text:
            hits, awaits = [], []
            for label, pat in HEAVY.items():
                for m in re.finditer(pat, text, re.I):
                    hits.append((line_no(text, m.start()), label))
            for i, line in enumerate(text.splitlines(), 1):
                if "await " in line:
                    awaits.append((i, line.strip()))
            if hits or awaits:
                runtime_files.append((path, hits, awaits))

    project_assets = []
    for base_name in ("assets", "data"):
        base = ROOT / base_name
        if base.exists():
            for p in base.rglob("*"):
                if p.is_file():
                    project_assets.append((p.stat().st_size, p))
    project_assets.sort(reverse=True, key=lambda x: x[0])

    apk_rows = []
    if APK.exists():
        with zipfile.ZipFile(APK, "r") as zf:
            for info in zf.infolist():
                low = info.filename.lower()
                if "assets/" in low or low.endswith((".db",".sqlite",".sqlite3",".json")):
                    apk_rows.append((info.file_size, info.compress_size, info.compress_type, info.filename))
        apk_rows.sort(reverse=True, key=lambda x: x[0])

    suspects = []
    for size, comp, method, name in apk_rows:
        low = name.lower()
        if low.endswith((".db",".sqlite",".sqlite3")):
            if size >= 50*1024*1024:
                suspects.append((100, f"Very large SQLite asset: {mb(size)} {name}"))
            elif size >= 20*1024*1024:
                suspects.append((80, f"Large SQLite asset: {mb(size)} {name}"))
            if method != 0 and size >= 20*1024*1024:
                suspects.append((95, f"Large SQLite asset is DEFLATED: {name}"))

    for path, hits, awaits in runtime_files:
        labels = [x[1] for x in hits]
        rel = str(path.relative_to(ROOT))
        if ("rootBundle.load" in labels or "rootBundle.loadString" in labels) and ("openDatabase" in labels or "File.copy" in labels or "writeAsBytes" in labels):
            suspects.append((95, f"Asset load/copy + DB open in same file: {rel}"))
        if labels.count("rawQuery") + labels.count("query") >= 5:
            suspects.append((75, f"Many DB queries in runtime file: {rel}"))
        if len(awaits) >= 10:
            suspects.append((60, f"Long sequential await chain: {rel} ({len(awaits)} awaits)"))

    suspects.sort(reverse=True)

    out = []
    out += ["="*58, "LINKBALL STEP 07A.6 - RUNTIME V3 BOOTSTRAP FORENSICS", "="*58, ""]
    out.append("A) READY marker source")
    if ready:
        for path, text, line in ready:
            out.append(f"  {path.relative_to(ROOT)}:{line}")
            lines = text.splitlines()
            start, end = max(1, line-50), min(len(lines), line+50)
            for idx in range(start, end+1):
                prefix = ">>" if idx == line else "  "
                out.append(f"  {prefix} L{idx}: {lines[idx-1]}")
    else:
        out.append("  [WARN] READY marker source not found")

    out += ["", "B) Runtime/SQLite heavy operations"]
    for path, hits, awaits in runtime_files:
        out.append(f"  FILE: {path.relative_to(ROOT)}")
        for ln, label in hits[:25]:
            out.append(f"    heavy L{ln}: {label}")
        for ln, line in awaits[:25]:
            out.append(f"    await L{ln}: {line}")

    out += ["", "C) Largest project assets"]
    for size, p in project_assets[:20]:
        out.append(f"  {mb(size):>10}  {p.relative_to(ROOT)}")

    out += ["", "D) Largest data-like files in release APK"]
    for size, comp, method, name in apk_rows[:30]:
        kind = "STORED" if method == 0 else "DEFLATED"
        ratio = comp/size if size else 0
        out.append(f"  {mb(size):>10} -> {mb(comp):>10} ratio={ratio:.2f} {kind:8} {name}")

    out += ["", "E) Top suspects"]
    if suspects:
        for score, reason in suspects[:10]:
            out.append(f"  [{score:03}] {reason}")
    else:
        out.append("  Static scan inconclusive; phase timing instrumentation required.")

    text = "\n".join(out)
    OUT.write_text(text + "\n", encoding="utf-8")

    print("="*58)
    print("LINKBALL STEP 07A.6 - FORENSICS SUMMARY")
    print("="*58)
    print(f"READY source locations: {len(ready)}")
    print(f"Runtime-heavy files:    {len(runtime_files)}")
    if project_assets:
        print(f"Largest project asset:  {mb(project_assets[0][0])} {project_assets[0][1].relative_to(ROOT)}")
    if apk_rows:
        print(f"Largest APK data asset: {mb(apk_rows[0][0])} {apk_rows[0][3]}")
    print()
    print("Top suspects:")
    if suspects:
        for score, reason in suspects[:8]:
            print(f"  [{score:03}] {reason}")
    else:
        print("  Static scan inconclusive; timing instrumentation needed.")
    print()
    print("[INFO] Full report:")
    print("  reports/production/07a6/runtime_bootstrap_forensics.txt")

if __name__ == "__main__":
    main()
