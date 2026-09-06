from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/07a/analytics_07a3_logcat.txt"

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] analytics_07a3_logcat.txt missing")

    lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()

    groups = {
        "debug_mode": [],
        "initialized": [],
        "event": [],
        "upload": [],
        "errors": [],
    }

    for line in lines:
        lower = line.lower()

        if (
            "debug mode" in lower
            or "debug-level message logging enabled" in lower
            or "faster debug mode" in lower
        ):
            groups["debug_mode"].append(line)

        if (
            "app measurement initialized" in lower
            or "measurement initialized" in lower
            or "firebase analytics" in lower and "initialized" in lower
        ):
            groups["initialized"].append(line)

        if "telemetry_smoke" in lower:
            groups["event"].append(line)

        if any(x in lower for x in [
            "uploading data",
            "successful upload",
            "uploading events",
            "batching events",
            "network upload",
        ]):
            groups["upload"].append(line)

        if any(x in lower for x in [
            "analytics collection disabled",
            "missing google_app_id",
            "google app id is missing",
            "failed to send",
            "network error",
            "upload failed",
            "measurement disabled",
        ]):
            groups["errors"].append(line)

    print("==========================================================")
    print("STEP 07A.3 NATIVE ANALYTICS DIAGNOSTIC")
    print("==========================================================")

    for key, label in [
        ("debug_mode", "Debug mode markers"),
        ("initialized", "Analytics initialization markers"),
        ("event", "telemetry_smoke markers"),
        ("upload", "Upload/activity markers"),
        ("errors", "Error/disabled markers"),
    ]:
        values = groups[key]
        status = "PASS" if values and key != "errors" else "INFO"
        if key == "errors" and values:
            status = "FAIL"
        print(f"[{status}] {label}: {len(values)}")
        for line in values[-10:]:
            print(" ", line)
        print()

    if groups["errors"]:
        raise SystemExit(3)

    if not groups["event"]:
        raise SystemExit(2)

    print("[PASS] Native Analytics SDK logged telemetry_smoke.")
    if not groups["debug_mode"]:
        print("[WARN] No native 'debug mode enabled' marker found.")
    if not groups["upload"]:
        print("[WARN] No explicit upload marker found in captured window.")

if __name__ == "__main__":
    main()
