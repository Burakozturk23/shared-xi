from pathlib import Path
import re
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/07a4"
LOG = REPORT / "startup_logcat.txt"
AM = REPORT / "am_start_w.txt"
GFX = REPORT / "gfxinfo.txt"
OUT = REPORT / "startup_summary.txt"

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

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] startup_logcat.txt missing")

    lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    am = parse_am()

    runtime_ready = []
    runtime_lines = []
    skipped = []
    anr = []
    firebase_sessions = []
    telemetry = []
    sqlite = []
    displayed = []

    for line in lines:
        lower = line.lower()

        if "[runtimev3]" in lower:
            runtime_lines.append(line)
            if "ready" in lower:
                runtime_ready.append(line)

        if "skipped " in lower and "frames" in lower:
            skipped.append(line)

        if "anr in " in lower or "slow operations in main thread" in lower:
            anr.append(line)

        if "firebasesessions" in lower or "firebasesessionscomponent" in lower:
            firebase_sessions.append(line)

        if "[telemetry]" in lower:
            telemetry.append(line)

        if "sqlite" in lower or "database" in lower and "[runtimev3]" in lower:
            sqlite.append(line)

        if "displayed " in lower and PACKAGE in lower:
            displayed.append(line)

    # Find rough first relevant timestamp and RuntimeV3 READY delta.
    relevant_times = []
    for line in lines:
        if PACKAGE in line or "[RuntimeV3]" in line:
            t = parse_time(line)
            if t:
                relevant_times.append(t)

    first_time = min(relevant_times) if relevant_times else None
    ready_time = None
    if runtime_ready:
        ready_time = parse_time(runtime_ready[0])

    ready_delta = None
    if first_time and ready_time:
        delta = ready_time - first_time
        if delta.total_seconds() < 0:
            delta += timedelta(days=1)
        ready_delta = delta.total_seconds()

    severity = "PASS"
    reasons = []

    if am.get("TotalTime", 0) >= 5000:
        severity = "HIGH"
        reasons.append(f"Android activity TotalTime={am['TotalTime']}ms")

    if ready_delta is not None and ready_delta >= 10:
        severity = "HIGH"
        reasons.append(f"RuntimeV3 READY delta~{ready_delta:.1f}s")
    elif not runtime_ready:
        severity = "HIGH"
        reasons.append("RuntimeV3 READY marker not seen in capture window")

    if skipped:
        severity = "HIGH"
        reasons.append(f"Skipped-frame markers={len(skipped)}")

    if anr:
        severity = "HIGH"
        reasons.append(f"ANR/main-thread markers={len(anr)}")

    out = []
    out.append("==========================================================")
    out.append("LINKBALL STEP 07A.4 - STARTUP / ANR SUMMARY")
    out.append("==========================================================")
    out.append("")
    out.append(f"Overall: {severity}")
    out.append("")

    if am:
        out.append("Android am start -W:")
        for key in ("ThisTime", "TotalTime", "WaitTime"):
            if key in am:
                out.append(f"  {key}: {am[key]} ms")
    else:
        out.append("Android am start -W timings: unavailable")

    out.append("")
    if ready_delta is not None:
        out.append(f"Approx RuntimeV3 READY delta: {ready_delta:.1f} s")
    else:
        out.append("Approx RuntimeV3 READY delta: not measurable")

    out.append(f"RuntimeV3 log lines: {len(runtime_lines)}")
    out.append(f"Skipped-frame markers: {len(skipped)}")
    out.append(f"ANR/main-thread markers: {len(anr)}")
    out.append(f"FirebaseSessions markers: {len(firebase_sessions)}")
    out.append(f"Telemetry markers: {len(telemetry)}")
    out.append("")

    if reasons:
        out.append("Priority findings:")
        for reason in reasons:
            out.append("  - " + reason)
        out.append("")

    if runtime_ready:
        out.append("RuntimeV3 READY:")
        out.append("  " + runtime_ready[0])
        out.append("")

    if skipped:
        out.append("Skipped frames (last 8):")
        for line in skipped[-8:]:
            out.append("  " + line)
        out.append("")

    if anr:
        out.append("ANR/main-thread markers (last 8):")
        for line in anr[-8:]:
            out.append("  " + line)
        out.append("")

    if firebase_sessions:
        out.append("Firebase Sessions markers (last 8):")
        for line in firebase_sessions[-8:]:
            out.append("  " + line)
        out.append("")

    out.append("Next decision:")
    if not runtime_ready:
        out.append(
            "  Runtime V3 did not become ready in the capture window; "
            "profile data/bootstrap path first."
        )
    elif ready_delta is not None and ready_delta >= 10:
        out.append(
            "  Runtime V3/data bootstrap is the primary startup bottleneck."
        )
    elif skipped or anr:
        out.append(
            "  First-frame timing is acceptable, but main-isolate work "
            "causes frame/ANR pressure; move heavy work off the UI isolate."
        )
    else:
        out.append(
            "  No severe startup marker found in this run; compare with "
            "source scan and production Crashlytics."
        )

    text = "\n".join(out)
    OUT.write_text(text + "\n", encoding="utf-8", newline="\n")
    print(text)
    print()
    print("[INFO] Saved:", OUT.relative_to(ROOT))

if __name__ == "__main__":
    main()
