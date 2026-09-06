from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
checks = {
  'lib/services/runtime_v3/runtime_v3_platform_io.dart': ['transfer_detective_normal_v3','END AS exposed_club_id','transferDetectiveEvents'],
  'lib/services/runtime_v3/hybrid_gameplay_data_service.dart': ['careerTimeline','transferDetectiveEvents'],
  'lib/controllers/career_puzzle_controller.dart': ['career_preview_beginner','career_preview_normal','career_preview_legend','_runtimeTimelineFor','_startRoundRuntime','[HybridV3] CareerPuzzle SQLite'],
  'lib/controllers/transfer_detective_controller.dart': ['transferDetectiveEvents','_runtimeEvents','_runtimeStatsHint','fee: 0',"if (_usingRuntimeV3) return '—';",'[HybridV3] TransferDetective SQLite'],
}
errors=[]
for rel, markers in checks.items():
    p=ROOT/rel
    if not p.exists(): errors.append('MISSING: '+rel); continue
    text=p.read_text(encoding='utf-8')
    for m in markers:
        if m not in text: errors.append(f'{rel}: missing {m}')
if errors:
    print('[FAIL] Step 04.2G verification')
    for e in errors: print('  -',e)
    raise SystemExit(1)
print('[PASS] Step 04.2G static integration OK.')
print('[INFO] Android Career Puzzle + Transfer Detective is final verification.')
