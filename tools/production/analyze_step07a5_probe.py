from pathlib import Path
import re
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a5"
LOG = REPORT / "v3_release_logcat.txt"
AM = REPORT / "v3_release_am_start_w.txt"
OUT = REPORT / "v3_release_summary.txt"

PACKAGE = "com.burakozturk.linkball"

TIME_RE = re.compile(
    r"^(?P<month>\d{2})-(?P<day>\d{2}) "
    r"(?P<hour>\d{2}):(?P<minute>\d{2}):(?P<second>\d{2})\.(?P<millis>\d{3})"
)

def parse_time(line):
    m = TIME_RE.match(line)
    if not m:
        return None
    now = datetime.now()
    return datetime(
        now.year,
        int(m.group("month")),
        int(m.group("day")),
        int(m.group("hour")),
        int(m.group("minute")),
        int(m.group("second")),
        int(m.group("millis")) * 1000,
    )

def parse_am():
    vals = {}
    if not AM.exists():
        return vals
    for line in AM.read_text(encoding="utf-8", errors="replace").splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {"ThisTime", "TotalTime", "WaitTime"}:
            try:
                vals[key] = int(value)
            except ValueError:
                pass
    return vals

def max_skipped(lines):
    values = []
    rx = re.compile(r"Skipped\s+(\d+)\s+frames", re.I)
    for line in lines:
        m = rx.search(line)
        if m:
            values.append(int(m.group(1)))
    return max(values) if values else 0

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] v3_release_logcat.txt missing")

    lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    am = parse_am()

    runtime = [x for x in lines if "[RuntimeV3]" in x or "[HybridV3]" in x]
    ready = [x for x in runtime if "READY" in x]
    skipped = [x for x in lines if "Skipped " in x and "frames" in x]
    max_skip = max_skipped(skipped)

    relevant_times = []
    for line in lines:
        if PACKAGE in line or "[RuntimeV3]" in line:
            t = parse_time(line)
            if t:
                relevant_times.append(t)

    first = min(relevant_times) if relevant_times else None
    ready_time = parse_time(ready[0]) if ready else None
    ready_delta = None

    if first and ready_time:
        delta = ready_time - first
        if delta.total_seconds() < 0:
            delta += timedelta(days=1)
        ready_delta = delta.total_seconds()

    prior_path = ROOT / "reports/production/07a4/startup_summary.txt"
    prior = prior_path.read_text(
        encoding="utf-8",
        errors="replace",
    ) if prior_path.exists() else ""

    status = "PASS"
    reasons = []

    if not runtime:
        status = "FAIL"
        reasons.append(
            "No RuntimeV3/HybridV3 marker found even with explicit production defines"
        )
    elif not ready:
        status = "HIGH"
        reasons.append(
            "RuntimeV3 markers exist but READY was not reached in 60 seconds"
        )

    if ready_delta is not None and ready_delta > 15:
        status = "HIGH"
        reasons.append(f"RuntimeV3 READY delta is still high: {ready_delta:.1f}s")

    if max_skip >= 120:
        status = "HIGH"
        reasons.append(f"Large main-thread frame stall remains: max skipped={max_skip}")

    out = []
    out.append("==========================================================")
    out.append("LINKBALL STEP 07A.5 - V3 RELEASE PROBE SUMMARY")
    out.append("==========================================================")
    out.append("")
    out.append(f"Overall: {status}")
    out.append("")
    out.append("Build defines:")
    out.append("  LINKBALL_SQLITE_V3=true")
    out.append("  LINKBALL_SQLITE_GAMEPLAY_V3=true")
    out.append("  LINKBALL_SQLITE_PARITY=false")
    out.append("")

    if am:
        out.append("Android am start -W:")
        for key in ("ThisTime", "TotalTime", "WaitTime"):
            if key in am:
                out.append(f"  {key}: {am[key]} ms")
        out.append("")

    out.append(f"RuntimeV3/HybridV3 markers: {len(runtime)}")
    out.append(f"RuntimeV3 READY markers: {len(ready)}")
    if ready_delta is not None:
        out.append(f"Approx READY delta: {ready_delta:.1f} s")
    else:
        out.append("Approx READY delta: not measurable")
    out.append(f"Skipped-frame markers: {len(skipped)}")
    out.append(f"Maximum skipped frames in one marker: {max_skip}")
    out.append("")

    if runtime:
        out.append("First V3 markers:")
        for line in runtime[:10]:
            out.append("  " + line)
        out.append("")

    if skipped:
        out.append("Skipped-frame markers (last 8):")
        for line in skipped[-8:]:
            out.append("  " + line)
        out.append("")

    if prior:
        out.append("Previous 07A.4 comparison:")
        if "RuntimeV3 log lines: 0" in prior:
            out.append(
                "  Previous release audit had RuntimeV3 log lines = 0."
            )
        m = re.search(r"WaitTime:\s*(\d+)\s*ms", prior)
        if m:
            old_wait = int(m.group(1))
            new_wait = am.get("WaitTime")
            out.append(f"  Old WaitTime: {old_wait} ms")
            if new_wait is not None:
                out.append(f"  V3 WaitTime:  {new_wait} ms")
                out.append(f"  Delta:        {new_wait - old_wait:+d} ms")
        out.append("")

    if reasons:
        out.append("Findings:")
        for reason in reasons:
            out.append("  - " + reason)
        out.append("")

    out.append("Decision:")
    if status == "PASS":
        out.append(
            "  Explicit Runtime V3 release path is healthy enough to make "
            "V3 the production default / release gate."
        )
    elif runtime and not ready:
        out.append(
            "  V3 is active, but its bootstrap still needs targeted profiling."
        )
    elif not runtime:
        out.append(
            "  Dart-defines are not reaching the Runtime V3 switch; inspect the "
            "flag implementation before changing performance code."
        )
    else:
        out.append(
            "  V3 is active but main-thread stalls remain; optimize only the "
            "measured bootstrap phase next."
        )

    text = "\n".join(out)
    OUT.write_text(text + "\n", encoding="utf-8", newline="\n")
    print(text)

if __name__ == "__main__":
    main()
