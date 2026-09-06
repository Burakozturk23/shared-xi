from __future__ import annotations
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
errors = []

def check(rel, markers):
    p = ROOT / rel
    if not p.exists():
        errors.append(f'MISSING: {rel}')
        return
    text = p.read_text(encoding='utf-8')
    for marker in markers:
        if marker not in text:
            errors.append(f'{rel}: missing {marker}')

check('functions/index.js', [
    'exports.startDailyScoreSession', 'exports.submitDailyScore',
    'dailyScoreSessions/', 'serverValidated: true', 'httpsV2.onCall'])
check('lib/services/daily_leaderboard_service.dart', [
    'FirebaseFunctions.instanceFor', "httpsCallable('startDailyScoreSession')",
    "httpsCallable('submitDailyScore')", "'foundCount': safeFound",
    "'targetCount': safeTarget", "'wrongCount': safeWrong"])
check('lib/controllers/daily_challenge_controller.dart', [
    'DailyLeaderboardService.startSession',
    'foundCount: _state.foundPlayerIds.length',
    'targetCount: _state.matchingPlayers.length',
    'wrongCount: _state.wrongAttempts.length'])
check('database.rules.json', [
    '"dailyLeaderboard"', '"dailyScoreSessions"', '".write": false',
    '"matchmaking"', '"matches"', '"rooms"', '"gridMatches"',
    '"cinkoMatches"', '"fiveMatches"'])

firebase_path = ROOT / 'firebase.json'
try:
    firebase = json.loads(firebase_path.read_text(encoding='utf-8'))
    database = firebase.get('database')
    if not isinstance(database, dict) or database.get('rules') != 'database.rules.json':
        errors.append('firebase.json database rules config missing/mismatch')
except Exception as exc:
    errors.append(f'firebase.json parse failed: {exc}')

service = (ROOT / 'lib/services/daily_leaderboard_service.dart').read_text(encoding='utf-8')
start = service.find('static Future<void> submitScore')
end = service.find('/// Bugün / verilen gün sıralaması', start)
block = service[start:end] if start >= 0 and end >= 0 else ''
if 'ref.set(' in block or 'ref.update(' in block:
    errors.append('Daily submitScore still contains direct RTDB write')

try:
    result = subprocess.run(['node', '--check', str(ROOT / 'functions/index.js')], cwd=ROOT,
                            capture_output=True, text=True, check=False)
    if result.returncode != 0:
        errors.append('node --check failed: ' + result.stderr.strip())
except FileNotFoundError:
    print('[WARN] node not found; JS syntax check skipped.')

if errors:
    print('[FAIL] Step 05B verification')
    for e in errors:
        print('  -', e)
    raise SystemExit(1)

print('[PASS] Step 05B static security integration OK.')
print('[PASS] Direct client Daily leaderboard write removed.')
print('[PASS] Server session + server scoring callables present.')
print('[PASS] RTDB leaderboard/session writes denied to clients.')
print('[INFO] App Check enforcement intentionally waits for Step 05C.')
