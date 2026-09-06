from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "reports/production/06a"
SOURCE = REPORT / "firebase_create_production_android.json"
OUT = REPORT / "firebase_created_app_id.txt"

def parse_json_maybe(text: str):
    text = text.lstrip("\ufeff").strip()

    try:
        return json.loads(text)
    except Exception:
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

def find_app_ids(value):
    ids = []

    if isinstance(value, dict):
        for key in ("appId", "app_id", "appIdValue"):
            app_id = value.get(key)
            if app_id:
                ids.append(str(app_id))

        for child in value.values():
            ids.extend(find_app_ids(child))

    elif isinstance(value, list):
        for child in value:
            ids.extend(find_app_ids(child))

    out = []
    seen = set()
    for item in ids:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out

def main():
    if not SOURCE.exists():
        raise SystemExit("[FAIL] Firebase create JSON missing")

    raw = SOURCE.read_text(encoding="utf-8", errors="replace")

    try:
        data = parse_json_maybe(raw)
    except Exception as exc:
        print("[FAIL] Could not parse Firebase create JSON:", exc)
        print("[INFO] First 800 chars:")
        print(raw[:800])
        raise SystemExit(1)

    ids = find_app_ids(data)

    if not ids:
        print("[FAIL] Firebase appId not found in create output.")
        print("[INFO] Parsed JSON:")
        print(json.dumps(data, indent=2)[:2000])
        raise SystemExit(1)

    # The create command should describe one app. If wrappers duplicate the
    # same appId, de-duplication above still yields one.
    if len(ids) != 1:
        print("[FAIL] Ambiguous appIds:", ids)
        raise SystemExit(1)

    OUT.write_text(ids[0] + "\n", encoding="utf-8", newline="\n")

    print("[PASS] Created Firebase Android appId:")
    print(" ", ids[0])

if __name__ == "__main__":
    main()
