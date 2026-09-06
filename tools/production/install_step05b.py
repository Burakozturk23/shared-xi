from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FUNCTIONS = ROOT / 'functions/index.js'
SERVICE = ROOT / 'lib/services/daily_leaderboard_service.dart'
CONTROLLER = ROOT / 'lib/controllers/daily_challenge_controller.dart'
FIREBASE_JSON = ROOT / 'firebase.json'
RULES = ROOT / 'database.rules.json'
PUBSPEC = ROOT / 'pubspec.yaml'

JS_NAMESPACE_IMPORT = 'const httpsV2 = require("firebase-functions/v2/https");'
JS_START_MARKER = 'LINKBALL_05B_DAILY_AUTHORITY_START'
JS_END_MARKER = 'LINKBALL_05B_DAILY_AUTHORITY_END'


def backup(path: Path) -> None:
    if not path.exists():
        return
    bak = path.with_suffix(path.suffix + '.step05b.bak')
    if not bak.exists():
        shutil.copy2(path, bak)


def write_lf(path: Path, text: str) -> None:
    normalized = text.replace('\\r\\n', '\\n').replace('\\r', '\\n')
    with path.open('w', encoding='utf-8', newline='\\n') as handle:
        handle.write(normalized)

def require_files() -> None:
    for p in (FUNCTIONS, SERVICE, CONTROLLER, FIREBASE_JSON, PUBSPEC):
        if not p.exists():
            raise RuntimeError(f'Required file missing: {p.relative_to(ROOT)}')
    pubspec = PUBSPEC.read_text(encoding='utf-8')
    if 'cloud_functions:' not in pubspec:
        raise RuntimeError('pubspec.yaml cloud_functions dependency icermiyor.')


def patch_functions(text: str) -> str:
    if JS_START_MARKER in text and JS_END_MARKER in text:
        return text
    partial = ['exports.startDailyScoreSession', 'exports.submitDailyScore', 'dailyScoreSessions/', 'serverValidated']
    if any(m in text for m in partial):
        raise RuntimeError('PARTIAL_05B_FUNCTIONS: Daily score authority kismi durumda.')
    if 'admin.initializeApp()' not in text:
        raise RuntimeError('functions/index.js admin.initializeApp() bulunamadi')
    if JS_NAMESPACE_IMPORT not in text:
        inserted = False
        for anchor in ['const logger = require("firebase-functions/logger");', 'const admin = require("firebase-admin");']:
            if anchor in text:
                text = text.replace(anchor, anchor + '\n' + JS_NAMESPACE_IMPORT, 1)
                inserted = True
                break
        if not inserted:
            raise RuntimeError('functions HTTPS import anchor bulunamadi')

    block = r'''

// LINKBALL_05B_DAILY_AUTHORITY_START

/** @param {string} value @return {Date|null} */
function lbParseDailyDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const parsed = new Date(value + "T00:00:00.000Z");
  if (Number.isNaN(parsed.getTime())) return null;
  if (parsed.toISOString().slice(0, 10) !== value) return null;
  return parsed;
}

/** @param {Date} date @return {string} */
function lbDailyDateKey(date) {
  return date.toISOString().slice(0, 10);
}

/** @param {string} dateStr @param {number} delta @return {string} */
function lbShiftDailyDate(dateStr, delta) {
  const date = lbParseDailyDate(dateStr);
  if (!date) return dateStr;
  date.setUTCDate(date.getUTCDate() + delta);
  return lbDailyDateKey(date);
}

/** @param {string} dateStr @return {Promise<Object>} */
async function lbDailyLimits(dateStr) {
  const db = admin.database();
  const snap = await db.ref("daily_fixtures/" + dateStr + "/topMatch").get();
  if (snap.exists() && snap.val()) {
    const fixture = snap.val();
    const leagueId = Number(fixture.leagueId || 0);
    const derby = fixture.isDerby === true;
    if (derby || leagueId === 2 || leagueId === 3 || leagueId === 848) {
      return {roundSeconds: 60, maxLives: 3};
    }
    return {roundSeconds: 90, maxLives: 5};
  }
  const date = lbParseDailyDate(dateStr);
  const weekday = date ? date.getUTCDay() : 0;
  if (weekday === 1 || weekday === 2) {
    return {roundSeconds: 90, maxLives: 5};
  }
  return {roundSeconds: 60, maxLives: 3};
}

/** @param {string} dateStr */
function lbValidateDailyDateWindow(dateStr) {
  const date = lbParseDailyDate(dateStr);
  if (!date) {
    throw new httpsV2.HttpsError("invalid-argument", "Invalid daily challenge date.");
  }
  const now = new Date();
  const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const ageDays = Math.floor((today.getTime() - date.getTime()) / 86400000);
  if (ageDays < -1 || ageDays > 1095) {
    throw new httpsV2.HttpsError("invalid-argument", "Daily challenge date is outside the allowed window.");
  }
}

/** @param {*} value @param {string} field @param {number} min @param {number} max @return {number} */
function lbDailyInt(value, field, min, max) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new httpsV2.HttpsError("invalid-argument", field + " is outside the allowed range.");
  }
  return parsed;
}

/** @param {string} uid @return {Promise<string>} */
async function lbDailyDisplayName(uid) {
  try {
    const snap = await admin.database().ref("users/" + uid + "/displayName").get();
    const raw = snap.exists() ? String(snap.val() || "") : "";
    const cleaned = raw.trim().replace(/\s+/g, " ").slice(0, 32);
    if (cleaned) return cleaned;
  } catch (err) {
    logger.warn("Daily display name lookup failed", {uid: uid, error: String(err)});
  }
  return "Oyuncu_" + uid.slice(0, 5);
}

exports.startDailyScoreSession = httpsV2.onCall(
    {region: "europe-west1", maxInstances: 30},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new httpsV2.HttpsError("unauthenticated", "Authentication is required.");
      }
      const data = request.data || {};
      const dateStr = String(data.dateKey || "");
      lbValidateDailyDateWindow(dateStr);
      const uid = request.auth.uid;
      const limits = await lbDailyLimits(dateStr);
      const ref = admin.database().ref("dailyScoreSessions/" + uid + "/" + dateStr);
      const now = Date.now();
      const result = await ref.transaction((current) => {
        if (current && typeof current === "object" && Number.isFinite(Number(current.startedAt))) {
          return current;
        }
        return {
          dateKey: dateStr,
          startedAt: now,
          roundSeconds: limits.roundSeconds,
          maxLives: limits.maxLives,
          validationVersion: 1,
        };
      });
      const session = result.snapshot.val() || {};
      return {
        ok: true,
        dateKey: dateStr,
        startedAt: Number(session.startedAt || now),
        roundSeconds: Number(session.roundSeconds || limits.roundSeconds),
        maxLives: Number(session.maxLives || limits.maxLives),
        alreadySubmitted: session.submittedAt != null,
      };
    },
);

exports.submitDailyScore = httpsV2.onCall(
    {region: "europe-west1", maxInstances: 30},
    async (request) => {
      if (!request.auth || !request.auth.uid) {
        throw new httpsV2.HttpsError("unauthenticated", "Authentication is required.");
      }
      const data = request.data || {};
      const dateStr = String(data.dateKey || "");
      lbValidateDailyDateWindow(dateStr);
      const foundCount = lbDailyInt(data.foundCount, "foundCount", 0, 80);
      const targetCount = lbDailyInt(data.targetCount, "targetCount", 1, 80);
      const wrongCount = lbDailyInt(data.wrongCount, "wrongCount", 0, 10);
      if (foundCount > targetCount) {
        throw new httpsV2.HttpsError("invalid-argument", "foundCount cannot exceed targetCount.");
      }

      const uid = request.auth.uid;
      const db = admin.database();
      const sessionRef = db.ref("dailyScoreSessions/" + uid + "/" + dateStr);
      const sessionSnap = await sessionRef.get();
      if (!sessionSnap.exists() || !sessionSnap.val()) {
        throw new httpsV2.HttpsError("failed-precondition", "Daily score session was not started.");
      }
      const session = sessionSnap.val();
      const startedAt = Number(session.startedAt || 0);
      const roundSeconds = lbDailyInt(session.roundSeconds, "roundSeconds", 30, 180);
      const maxLives = lbDailyInt(session.maxLives, "maxLives", 1, 10);
      if (wrongCount > maxLives) {
        throw new httpsV2.HttpsError("invalid-argument", "wrongCount exceeds the server challenge limit.");
      }
      if (!Number.isFinite(startedAt) || startedAt <= 0) {
        throw new httpsV2.HttpsError("failed-precondition", "Daily score session is invalid.");
      }

      const now = Date.now();
      const elapsedSeconds = Math.floor(Math.max(0, now - startedAt) / 1000);
      const secondsLeft = Math.max(0, roundSeconds - elapsedSeconds);
      const score = foundCount * 10;
      const successRate = Math.max(0, Math.min(1, foundCount / targetCount));

      const previousDate = lbShiftDailyDate(dateStr, -1);
      const previousSnap = await db.ref("dailyLeaderboard/" + previousDate + "/" + uid).get();
      let serverStreak = 1;
      if (previousSnap.exists() && previousSnap.val()) {
        const previousStreak = Number(previousSnap.val().streak || 0);
        if (Number.isFinite(previousStreak) && previousStreak > 0) {
          serverStreak = Math.min(3660, previousStreak + 1);
        }
      }

      const displayName = await lbDailyDisplayName(uid);
      const leaderboardRef = db.ref("dailyLeaderboard/" + dateStr + "/" + uid);
      let accepted = false;
      const transaction = await leaderboardRef.transaction((current) => {
        if (current && typeof current === "object") {
          const oldScore = Number(current.score || 0);
          const oldSeconds = Number(current.secondsLeft || -1);
          if (score < oldScore) return current;
          if (score === oldScore && secondsLeft <= oldSeconds) return current;
        }
        accepted = true;
        return {
          displayName: displayName,
          score: score,
          successRate: successRate,
          secondsLeft: secondsLeft,
          streak: serverStreak,
          foundCount: foundCount,
          targetCount: targetCount,
          wrongCount: wrongCount,
          finishedAt: now,
          serverValidated: true,
          validationVersion: 1,
        };
      });

      const saved = transaction.snapshot.val() || {};
      await sessionRef.update({
        submittedAt: now,
        lastSubmittedScore: Number(saved.score || score),
        lastSubmittedSecondsLeft: Number(saved.secondsLeft ?? secondsLeft),
      });
      logger.info("Daily leaderboard submission", {
        uid: uid,
        dateKey: dateStr,
        accepted: accepted,
        score: Number(saved.score || score),
        secondsLeft: Number(saved.secondsLeft ?? secondsLeft),
      });
      return {
        ok: true,
        accepted: accepted,
        score: Number(saved.score || score),
        successRate: Number(saved.successRate ?? successRate),
        secondsLeft: Number(saved.secondsLeft ?? secondsLeft),
        streak: Number(saved.streak ?? serverStreak),
      };
    },
);

// LINKBALL_05B_DAILY_AUTHORITY_END
'''
    return text.rstrip() + '\n' + block.lstrip('\n')


def patch_service(text: str) -> str:
    final = ['FirebaseFunctions.instanceFor', 'startDailyScoreSession', "httpsCallable('submitDailyScore')", 'foundCount', 'targetCount', 'wrongCount']
    if all(m in text for m in final):
        return text
    if any(m in text for m in ['startDailyScoreSession', "httpsCallable('submitDailyScore')"]):
        raise RuntimeError('PARTIAL_05B_SERVICE: daily leaderboard service kismi migration.')
    if 'class DailyLeaderboardService' not in text:
        raise RuntimeError('DailyLeaderboardService class bulunamadi')
    if "package:cloud_functions/cloud_functions.dart" not in text:
        anchor = "import 'package:firebase_core/firebase_core.dart';"
        if anchor not in text:
            raise RuntimeError('Firebase Core import anchor bulunamadi')
        text = text.replace(anchor, anchor + "\nimport 'package:cloud_functions/cloud_functions.dart';", 1)
    class_anchor = 'class DailyLeaderboardService {\n  DailyLeaderboardService._();\n'
    if class_anchor not in text:
        raise RuntimeError('DailyLeaderboardService class anchor bulunamadi')
    text = text.replace(class_anchor, class_anchor + "\n  static final FirebaseFunctions _functions =\n      FirebaseFunctions.instanceFor(\n    app: Firebase.app(),\n    region: 'europe-west1',\n  );\n", 1)
    method_start = text.find('  static Future<void> submitScore({')
    fetch_comment = text.find('  /// Bugün / verilen gün sıralaması', method_start)
    if method_start < 0 or fetch_comment < 0:
        raise RuntimeError('Daily submitScore method boundary bulunamadi')
    new_methods = r'''  static Future<bool> startSession({
    required DateTime date,
    String? displayName,
  }) async {
    await AuthService.ensureSignedIn(displayName: displayName);
    final dateKey = DailyChallengeService.dateKeyFor(date);
    try {
      final callable = _functions.httpsCallable('startDailyScoreSession');
      final response = await callable.call(<String, dynamic>{
        'dateKey': dateKey,
      });
      final data = response.data;
      return data is Map && data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> submitScore({
    required DateTime date,
    required int score,
    required double successRate,
    int? secondsLeft,
    int? streak,
    String? displayName,
    int? foundCount,
    int? targetCount,
    int? wrongCount,
  }) async {
    await AuthService.ensureSignedIn(displayName: displayName);
    final dateKey = DailyChallengeService.dateKeyFor(date);
    final safeFound = foundCount ?? (score ~/ 10).clamp(0, 80);
    var safeTarget = targetCount;
    if (safeTarget == null || safeTarget <= 0) {
      if (successRate > 0 && safeFound > 0) {
        safeTarget = (safeFound / successRate).round();
      } else {
        safeTarget = safeFound > 0 ? safeFound : 1;
      }
    }
    safeTarget = safeTarget.clamp(safeFound, 80);
    final safeWrong = (wrongCount ?? 0).clamp(0, 10);
    final callable = _functions.httpsCallable('submitDailyScore');
    await callable.call(<String, dynamic>{
      'dateKey': dateKey,
      'foundCount': safeFound,
      'targetCount': safeTarget,
      'wrongCount': safeWrong,
    });
  }

'''
    return text[:method_start] + new_methods + text[fetch_comment:]


def patch_controller(text: str) -> str:
    if 'DailyLeaderboardService.submitScore(' not in text:
        raise RuntimeError('Daily leaderboard submit call bulunamadi')
    if '_startClock();' not in text:
        raise RuntimeError('Daily _startClock call bulunamadi')
    if 'DailyLeaderboardService.startSession' not in text:
        init_pos = text.find('Future<void> initialize() async')
        start_pos = text.find('_startClock();', init_pos)
        if init_pos < 0 or start_pos < 0:
            raise RuntimeError('Daily initialize clock boundary bulunamadi')
        replacement = "final sessionReady =\n          await DailyLeaderboardService.startSession(date: _day);\n      if (!sessionReady) {\n        debugPrint(\n          '[Security05B] Daily server session unavailable; gameplay continues.',\n        );\n      }\n      _startClock();"
        text = text[:start_pos] + text[start_pos:].replace('_startClock();', replacement, 1)
    call_pos = text.find('await DailyLeaderboardService.submitScore(')
    end_pos = text.find('\n      );', call_pos)
    if end_pos < 0:
        end_pos = text.find('\n    );', call_pos)
    if end_pos < 0:
        raise RuntimeError('Daily submitScore close bulunamadi')
    block = text[call_pos:end_pos]
    additions = []
    if 'foundCount:' not in block:
        additions.append('        foundCount: _state.foundPlayerIds.length,')
    if 'targetCount:' not in block:
        additions.append('        targetCount: _state.matchingPlayers.length,')
    if 'wrongCount:' not in block:
        additions.append('        wrongCount: _state.wrongAttempts.length,')
    if additions:
        text = text[:end_pos] + '\n' + '\n'.join(additions) + text[end_pos:]
    return text


def patch_firebase_json(text: str) -> str:
    data = json.loads(text)
    existing = data.get('database')
    if existing is None:
        data['database'] = {'rules': 'database.rules.json'}
    elif isinstance(existing, dict):
        existing['rules'] = 'database.rules.json'
    else:
        raise RuntimeError('firebase.json database config unsupported shape')
    return json.dumps(data, indent=2, ensure_ascii=False) + '\n'


RULES_TEXT = r'''{
  "rules": {
    ".read": true,
    ".write": false,
    "daily_fixtures": { ".read": true, ".write": false },
    "dailyLeaderboard": { ".read": true, ".write": false },
    "dailyScoreSessions": { ".read": false, ".write": false },
    "users": { "$uid": { ".write": "auth != null && auth.uid == $uid" } },
    "matchmaking": { ".write": "auth != null" },
    "matches": { ".write": "auth != null" },
    "rooms": { ".write": "auth != null" },
    "gridMatches": { ".write": "auth != null" },
    "cinkoMatches": { ".write": "auth != null" },
    "fiveMatches": { ".write": "auth != null" }
  }
}
'''


def main() -> None:
    require_files()
    originals = {
        FUNCTIONS: FUNCTIONS.read_text(encoding='utf-8'),
        SERVICE: SERVICE.read_text(encoding='utf-8'),
        CONTROLLER: CONTROLLER.read_text(encoding='utf-8'),
        FIREBASE_JSON: FIREBASE_JSON.read_text(encoding='utf-8'),
    }
    patched_functions = patch_functions(originals[FUNCTIONS])
    patched_service = patch_service(originals[SERVICE])
    patched_controller = patch_controller(originals[CONTROLLER])
    patched_firebase = patch_firebase_json(originals[FIREBASE_JSON])
    for p in (FUNCTIONS, SERVICE, CONTROLLER, FIREBASE_JSON, RULES):
        backup(p)
    FUNCTIONS.write_text(patched_functions, encoding='utf-8')
    SERVICE.write_text(patched_service, encoding='utf-8')
    CONTROLLER.write_text(patched_controller, encoding='utf-8')
    FIREBASE_JSON.write_text(patched_firebase, encoding='utf-8')
    RULES.write_text(RULES_TEXT, encoding='utf-8')
    print('[OK] functions/index.js -> server Daily authority')
    print('[OK] daily_leaderboard_service.dart -> callable submit')
    print('[OK] daily_challenge_controller.dart -> server session + counters')
    print('[OK] firebase.json + database.rules.json')
    print('[DONE] Step 05B installed locally. Firebase NOT deployed yet.')


if __name__ == '__main__':
    main()
