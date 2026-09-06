from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/07a7/startup_phase_logcat.txt"
OUT = ROOT / "reports/production/07a7/startup_phase_summary.txt"

RX = re.compile(r"\[StartupPerf\]\s+([A-Za-z0-9_]+)=(\d+)ms")

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] startup_phase_logcat.txt missing")

    text = LOG.read_text(encoding="utf-8", errors="replace")
    rows = []

    for phase, ms in RX.findall(text):
        rows.append((int(ms), phase))

    if not rows:
        print("[FAIL] No [StartupPerf] markers captured.")
        raise SystemExit(2)

    rows_sorted = sorted(rows, reverse=True)

    runtime_rows = [(ms, p) for ms, p in rows if p.startswith("v3_")]
    json_rows = [(ms, p) for ms, p in rows if p.startswith("json_")]

    runtime_total = sum(ms for ms, _ in runtime_rows)
    json_total = sum(ms for ms, _ in json_rows)

    print("==========================================================")
    print("LINKBALL STEP 07A.7 - BOOTSTRAP PHASE SUMMARY")
    print("==========================================================")
    print()
    print(f"Captured phase markers: {len(rows)}")
    print(f"V3 measured phase sum:  {runtime_total} ms")
    print(f"JSON measured phase sum:{json_total:>8} ms")
    print()
    print("Slowest measured phases:")
    for ms, phase in rows_sorted[:15]:
        print(f"  {ms:>7} ms  {phase}")

    print()
    print("V3 phases:")
    for ms, phase in sorted(runtime_rows, reverse=True):
        print(f"  {ms:>7} ms  {phase}")

    print()
    print("Legacy JSON phases:")
    for ms, phase in sorted(json_rows, reverse=True):
        print(f"  {ms:>7} ms  {phase}")

    # Decision rules.
    by_name = {}
    for ms, phase in rows:
        by_name.setdefault(phase, []).append(ms)

    def max_phase(name):
        vals = by_name.get(name, [])
        return max(vals) if vals else 0

    findings = []

    asset_load = max_phase("v3_sqlite_asset_load")
    write_flush = max_phase("v3_sqlite_write_flush")
    open_db = max_phase("v3_open_database")
    integrity = max_phase("v3_integrity_check")
    parse_players = max_phase("json_parse_players")

    if asset_load >= 5000:
        findings.append(
            "SQLite asset decompression/load is a primary blocker."
        )
    if write_flush >= 5000:
        findings.append(
            "SQLite copy + flush is a primary blocker; remove forced flush / change install strategy."
        )
    if open_db >= 3000:
        findings.append(
            "SQLite openDatabase is slow; inspect journal/open pragmas and copied DB state."
        )
    if integrity >= 3000:
        findings.append(
            "PRAGMA integrity_check is too expensive for every startup; move it to install/version verification."
        )
    if parse_players >= 3000:
        findings.append(
            "Legacy players JSON parsing remains a user-visible startup blocker."
        )

    if not findings:
        top_ms, top_phase = rows_sorted[0]
        findings.append(
            f"Top measured bottleneck is {top_phase} at {top_ms} ms."
        )

    print()
    print("Automated findings:")
    for f in findings:
        print("  -", f)

    summary = []
    summary.append("Captured phase markers: " + str(len(rows)))
    summary.append(f"V3 measured phase sum: {runtime_total} ms")
    summary.append(f"JSON measured phase sum: {json_total} ms")
    summary.append("")
    summary.append("Slowest phases:")
    for ms, phase in rows_sorted:
        summary.append(f"{ms} ms | {phase}")
    summary.append("")
    summary.append("Findings:")
    summary.extend("- " + f for f in findings)

    OUT.write_text("\n".join(summary) + "\n", encoding="utf-8", newline="\n")

if __name__ == "__main__":
    main()
