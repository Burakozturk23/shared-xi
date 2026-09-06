from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOG = ROOT / "reports/production/07a/telemetry_logcat.txt"

def main():
    if not LOG.exists():
        raise SystemExit("[FAIL] telemetry_logcat.txt missing")

    lines = LOG.read_text(encoding="utf-8", errors="replace").splitlines()

    crash = []
    analytics = []

    for line in lines:
        lower = line.lower()

        if (
            "firebasecrashlytics" in lower
            and (
                "upload complete" in lower
                or "report" in lower
                or "204" in lower
            )
        ):
            crash.append(line)

        if (
            "telemetry_smoke" in lower
            or (
                ("analytics" in lower or " fa" in lower or "fa-" in lower)
                and ("logging event" in lower or "event" in lower)
            )
        ):
            analytics.append(line)

    print("==========================================================")
    print("STEP 07A.1 TELEMETRY TRANSPORT CHECK")
    print("==========================================================")

    if crash:
        print("[PASS] Crashlytics transport activity found.")
        for line in crash[-10:]:
            print(" ", line)
    else:
        print("[WARN] Crashlytics upload marker not found.")

    print()

    if analytics:
        print("[PASS] Analytics debug activity found.")
        for line in analytics[-10:]:
            print(" ", line)
    else:
        print("[WARN] Analytics telemetry_smoke log marker not found.")

    if not crash or not analytics:
        raise SystemExit(2)

    print()
    print("[OK] STEP 07A.1 LOCAL TRANSPORT PASS")

if __name__ == "__main__":
    main()
