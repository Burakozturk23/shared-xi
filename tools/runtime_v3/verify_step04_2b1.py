from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/services/runtime_v3/hybrid_chain_graph_service.dart"

if not p.exists():
    raise SystemExit("[FAIL] hybrid_chain_graph_service.dart yok")

text = p.read_text(encoding="utf-8")

required = [
    "List<Player>.unmodifiable(usablePlayers)",
    "Map<int, List<int>>.unmodifiable({",
    "List<int>.unmodifiable(e.value)",
    "Map<int, List<Player>>.unmodifiable({",
    "List<Player>.unmodifiable(e.value)",
    "List<Club>.unmodifiable(quizClubs)",
    "Set<int>.unmodifiable(graphClubIds)",
]

missing = [x for x in required if x not in text]
if missing:
    print("[FAIL] Typed collection fix eksik:")
    for x in missing:
        print("  -", x)
    raise SystemExit(1)

print("[PASS] 04.2B.1 typed collection fix mevcut.")
print("[INFO] Android Chain run final verification olacak.")
