from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
files = [
    ROOT / "lib/controllers/game_controller.dart",
    ROOT / "lib/controllers/odd_club_controller.dart",
    ROOT / "lib/controllers/guess_the_player_controller.dart",
]
for p in files:
    bak = p.with_suffix(p.suffix + ".step04_2a.bak")
    if bak.exists():
        shutil.copy2(bak, p)
        print(f"[RESTORED] {p.relative_to(ROOT)}")
    else:
        print(f"[SKIP] backup yok: {p.relative_to(ROOT)}")

print(
    "runtime_v3 04.2A dosyalari silinmedi. "
    "Gameplay flag OFF iken mevcut JSON davranisi kullanilir."
)
