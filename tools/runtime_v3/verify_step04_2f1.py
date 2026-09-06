from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
p = ROOT / "lib/controllers/random_grid_controller.dart"

if not p.exists():
    raise SystemExit("[FAIL] random_grid_controller.dart yok")

text = p.read_text(encoding="utf-8")

errors = []

if "players: source," in text:
    errors.append("SearchService.suggestions hala Iterable aliyor")

if "players: source.toList()" not in text:
    errors.append("source.toList() marker yok")

for bad in [
    "{required Club rowClub, required Club colClub}) {",
    "{ required Club rowClub, required Club colClub}) {",
]:
    if bad in text:
        errors.append("bozuk _placeAtAnchorLegacy signature mevcut")

required = [
    "void _placeAtAnchorLegacy(",
    "_generatePairRuntime",
    "_pairAnswerIds",
    "playerPool: 'grid_answer'",
    "_primePairCache(newRows, newCols)",
    "_cachedPairContains(row, col, player.id)",
]
for marker in required:
    if marker not in text:
        errors.append(f"eksik marker: {marker}")

if errors:
    print("[FAIL] 04.2F.1 verification")
    for e in errors:
        print("  -", e)
    raise SystemExit(1)

print("[PASS] Step 04.2F.1 static repair verification OK.")
print("[INFO] flutter analyze final compile verification olacak.")
