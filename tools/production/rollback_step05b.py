from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parents[2]
for rel in [
    'functions/index.js',
    'lib/services/daily_leaderboard_service.dart',
    'lib/controllers/daily_challenge_controller.dart',
    'firebase.json',
    'database.rules.json',
]:
    p = ROOT / rel
    bak = p.with_suffix(p.suffix + '.step05b.bak')
    if bak.exists():
        shutil.copy2(bak, p)
        print('[RESTORED]', rel)
    elif rel == 'database.rules.json' and p.exists():
        p.unlink()
        print('[REMOVED] database.rules.json')
