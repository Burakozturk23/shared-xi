from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
checks = {
    "lib/services/runtime_v3/runtime_v3_platform_io.dart": [
        "existingGameplayClubMetadata", "exposed_club_id", "competition",
    ],
    "lib/services/runtime_v3/hybrid_gameplay_data_service.dart": [
        "existingGameplayClubMetadata",
    ],
    "lib/controllers/build_xi_controller.dart": [
        "build_xi_preview", "_runtimeClubIdsByPlayer", "_runtimeFactsByPlayer",
        "_runtimeClubMetaById", "_buildRuntimePool", "_runtimeRankByPlayer[a.id]",
        "_detailedPositionFor(p)", "_clubIdsForPlayer(pi)",
        "[HybridV3] BuildXI SQLite",
    ],
}
errors=[]
for rel, markers in checks.items():
    p=ROOT/rel
    if not p.exists():
        errors.append(f"MISSING: {rel}")
        continue
    text=p.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text:
            errors.append(f"{rel}: missing {marker}")
if errors:
    print("[FAIL] Step 04.2H verification")
    for e in errors: print("  -",e)
    raise SystemExit(1)
print("[PASS] Step 04.2H static integration OK.")
print("[INFO] Android Build XI gameplay test is final verification.")
