from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/harf11_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] harf11_controller.dart yok")

text = p.read_text(encoding="utf-8")

markers = [
    "_runtimePlayers",
    "_runtimeFactsByPlayer",
    "playersInPool('build_xi_preview')",
    "playerFactsForPool('build_xi_preview')",
    "_runtimePlayableLetters",
    "_fitsPosition",
    "[HybridV3] Harf11 SQLite",
]

missing = [m for m in markers if m not in text]

if missing:
    print("[FAIL] Step 04.2P verification")
    for m in missing:
        print("  -", m)
    raise SystemExit(1)

print("[PASS] Step 04.2P Harf11 static integration OK.")
print("[INFO] flutter analyze + Android gameplay are final verification.")
