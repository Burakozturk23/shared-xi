from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SERVICE = ROOT / "lib/services/telemetry_service.dart"

if not SERVICE.exists():
    raise SystemExit("[FAIL] telemetry_service.dart missing")

text = SERVICE.read_text(encoding="utf-8", errors="replace")

required = [
    "FirebaseCrashlytics.instance",
    "FirebaseAnalytics.instance",
    "LINKBALL_TELEMETRY_DEBUG",
    "LINKBALL_TELEMETRY_SMOKE",
    "telemetry_smoke",
    "STEP 07A telemetry smoke test",
]

missing = [m for m in required if m not in text]

if missing:
    print("[FAIL] 07A telemetry markers missing")
    for m in missing:
        print(" -", m)
    raise SystemExit(1)

print("[PASS] STEP 07A telemetry code present.")
