from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/07a/analytics_native_logcat.txt"

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] analytics_native_logcat.txt missing")

    lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    event_hits = []
    activity_hits = []

    for line in lines:
        lower = line.lower()
        if "telemetry_smoke" in lower:
            event_hits.append(line)
        if any(marker in lower for marker in (
            "logging event",
            "uploading data",
            "successful upload",
            "event recorded",
            "batching events",
        )):
            activity_hits.append(line)

    print("==========================================================")
    print("STEP 07A.2 NATIVE ANALYTICS CHECK")
    print("==========================================================")

    if event_hits:
        print("[PASS] Native Analytics log contains telemetry_smoke.")
        for line in event_hits[-10:]:
            print(" ", line)
    else:
        print("[FAIL] Native Analytics log does NOT contain telemetry_smoke.")

    print()

    if activity_hits:
        print("[INFO] Analytics activity markers:")
        for line in activity_hits[-10:]:
            print(" ", line)
    else:
        print("[WARN] No obvious Analytics activity marker found.")

    if not event_hits:
        raise SystemExit(2)

    print()
    print("[OK] Native Analytics SDK accepted telemetry_smoke.")

if __name__ == "__main__":
    main()
