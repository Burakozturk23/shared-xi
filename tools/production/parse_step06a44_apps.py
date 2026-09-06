from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/06a"
SOURCE = REPORT / "firebase_apps_android.json"
OUT = REPORT / "firebase_android_app_ids.txt"

def parse_json_maybe(text: str):
    text = text.strip()
    try:
        return json.loads(text)
    except Exception:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            return json.loads(text[start:end + 1])
        raise

def collect_ids(value):
    ids = []
    if isinstance(value, dict):
        app_id = value.get("appId") or value.get("app_id")
        platform = str(value.get("platform") or "").upper()
        if app_id and (not platform or platform == "ANDROID"):
            ids.append(str(app_id))
        for child in value.values():
            ids.extend(collect_ids(child))
    elif isinstance(value, list):
        for child in value:
            ids.extend(collect_ids(child))

    out = []
    seen = set()
    for item in ids:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out

def main():
    if not SOURCE.exists():
        raise SystemExit("[FAIL] firebase_apps_android.json missing")

    raw = SOURCE.read_text(encoding="utf-8", errors="replace")
    data = parse_json_maybe(raw)
    ids = collect_ids(data)

    if not ids:
        raise SystemExit("[FAIL] No Firebase Android app IDs found")

    OUT.write_text("\n".join(ids) + "\n", encoding="utf-8", newline="\n")
    print(f"[PASS] Android Firebase app IDs found: {len(ids)}")
    for app_id in ids:
        print(" ", app_id)

if __name__ == "__main__":
    main()
