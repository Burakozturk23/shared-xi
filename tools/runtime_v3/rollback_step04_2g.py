from pathlib import Path
import shutil
ROOT=Path(__file__).resolve().parents[2]
for rel in [
 'lib/services/runtime_v3/runtime_v3_platform_base.dart',
 'lib/services/runtime_v3/runtime_v3_platform_stub.dart',
 'lib/services/runtime_v3/runtime_v3_platform_io.dart',
 'lib/services/runtime_v3/runtime_v3_database.dart',
 'lib/services/runtime_v3/hybrid_gameplay_data_service.dart',
 'lib/controllers/career_puzzle_controller.dart',
 'lib/controllers/transfer_detective_controller.dart',
]:
    p=ROOT/rel; bak=p.with_suffix(p.suffix+'.step04_2g.bak')
    if bak.exists(): shutil.copy2(bak,p); print('[RESTORED]',rel)
    else: print('[SKIP]',rel)
