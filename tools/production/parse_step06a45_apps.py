from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/06a"
SOURCE = REPORT / "firebase_apps_android.json"
OUT = REPORT / "firebase_android_app_ids.txt"

def parse_json_maybe(text: str):
    text = text.lstrip("\ufeff").strip()
    try:
        return json.loads(text)
    except Exception:
        # Be tolerant if CLI adds non-JSON text around the JSON payload.
        starts = [i for i, c in enumerate(text) if c in "[{"]
        for start in starts:
            for end in range(len(text), start, -1):
                if text[end - 1] not in "]}":
                    continue
                try:
                    return json.loads(text[start:end])
                except Exception:
                    continue
        raise

def collect_ids(value):
    ids = []

    if isinstance(value, dict):
        app_id = (
            value.get("appId")
            or value.get("app_id")
            or value.get("appIdValue")
        )
        platform = str(
            value.get("platform")
            or value.get("platformId")
            or ""
        ).upper()

        if app_id and (not platform or platform == "ANDROID"):
            ids.append(str(app_id))

        for child in value.values():
            ids.extend(collect_ids(child))

    elif isinstance(value, list):
        for child in value:
            ids.extend(collect_ids(child))

    result = []
    seen = set()
    for app_id in ids:
        if app_id not in seen:
            seen.add(app_id)
            result.append(app_id)

    return result

def main():
    if not SOURCE.exists():
        raise SystemExit("[FAIL] firebase_apps_android.json missing")

    raw = SOURCE.read_text(encoding="utf-8", errors="replace")

    try:
        data = parse_json_maybe(raw)
    except Exception as exc:
        print("[FAIL] Firebase apps JSON parse failed:", exc)
        print("[INFO] First 500 chars:")
        print(raw[:500])
        raise SystemExit(1)

    ids = collect_ids(data)

    if not ids:
        raise SystemExit("[FAIL] No Firebase Android app IDs found")

    OUT.write_text(
        "\n".join(ids) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print(f"[PASS] Android Firebase app IDs: {len(ids)}")
    for app_id in ids:
        print(" ", app_id)

if __name__ == "__main__":
    main()
