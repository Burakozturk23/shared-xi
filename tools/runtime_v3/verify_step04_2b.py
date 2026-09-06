from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
chain = ROOT / "lib/controllers/chain_controller.dart"
service = ROOT / "lib/services/runtime_v3/hybrid_chain_graph_service.dart"

checks = {
    service: [
        "class HybridChainGraphSnapshot",
        "playersInPool('chain_playable')",
        "playerClubIdsForPool('chain_playable')",
        "topGameplayClubs(limit: 80)",
        "topGameplayClubs(limit: 400)",
    ],
    chain: [
        "HybridChainGraphSnapshot? _runtimeGraph;",
        "_initializeHybridGraph",
        "_clubIdsForPlayer",
        "_graphFamousClubIds",
        "Chain SQLite enabled",
        "for (final next in _clubIdsForPlayer(p))",
        "options = _clubIdsForPlayer(player)",
    ],
}

errors = []
for path, markers in checks.items():
    if not path.exists():
        errors.append(f"MISSING: {path.relative_to(ROOT)}")
        continue
    text = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            errors.append(
                f"{path.relative_to(ROOT)} missing marker: {marker}"
            )

if errors:
    print("[FAIL] 04.2B verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Step 04.2B static integration markers OK.")
print("[INFO] Android compile + Chain gameplay test is final verification.")
