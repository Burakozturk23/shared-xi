from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/07a71/startup_phase_logcat.txt"
OUT = ROOT / "reports/production/07a71/startup_phase_summary.txt"

RX = re.compile(r"\[StartupPerf\]\s+([A-Za-z0-9_]+)=(\d+)ms")

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] startup_phase_logcat.txt missing")

    text = LOG.read_text(encoding="utf-8", errors="replace")
    rows = [(int(ms), phase) for phase, ms in RX.findall(text)]

    if not rows:
        print("[FAIL] No [StartupPerf] markers captured.")
        raise SystemExit(2)

    rows_sorted = sorted(rows, reverse=True)
    v3 = [(ms, p) for ms, p in rows if p.startswith("v3_")]
    js = [(ms, p) for ms, p in rows if p.startswith("json_")]

    print("=" * 58)
    print("LINKBALL STEP 07A.7.1 - BOOTSTRAP PHASE SUMMARY")
    print("=" * 58)
    print()
    print(f"Captured markers: {len(rows)}")
    print(f"V3 measured phase sum: {sum(ms for ms, _ in v3)} ms")
    print(f"JSON measured phase sum: {sum(ms for ms, _ in js)} ms")
    print()
    print("Slowest measured phases:")
    for ms, phase in rows_sorted[:16]:
        print(f"  {ms:>7} ms  {phase}")

    by_name = {}
    for ms, phase in rows:
        by_name.setdefault(phase, []).append(ms)

    def mx(name):
        vals = by_name.get(name, [])
        return max(vals) if vals else 0

    findings = []

    if mx("v3_sqlite_asset_load") >= 5000:
        findings.append("SQLite asset load/decompression is a primary blocker.")
    if mx("v3_sqlite_write_flush") >= 5000:
        findings.append("SQLite disk write + flush is a primary blocker.")
    if mx("v3_integrity_check") >= 3000:
        findings.append("PRAGMA integrity_check is too expensive for every startup.")
    if mx("v3_open_database") >= 3000:
        findings.append("openDatabase itself is slow.")
    if mx("json_parse_players") >= 3000:
        findings.append("Legacy players JSON parse remains a startup blocker.")

    if not findings:
        top_ms, top_phase = rows_sorted[0]
        findings.append(f"Top measured bottleneck: {top_phase} = {top_ms} ms.")

    print()
    print("Automated findings:")
    for item in findings:
        print("  -", item)

    report = [
        f"Captured markers: {len(rows)}",
        f"V3 measured phase sum: {sum(ms for ms, _ in v3)} ms",
        f"JSON measured phase sum: {sum(ms for ms, _ in js)} ms",
        "",
        "Slowest measured phases:",
    ]
    report.extend(f"{ms} ms | {phase}" for ms, phase in rows_sorted)
    report.append("")
    report.append("Findings:")
    report.extend("- " + item for item in findings)

    OUT.write_text("\n".join(report) + "\n", encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
