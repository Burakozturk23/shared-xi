from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "lib/services/runtime_v3/runtime_v3_platform_base.dart"
STUB = ROOT / "lib/services/runtime_v3/runtime_v3_platform_stub.dart"
IO = ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart"
DB = ROOT / "lib/services/runtime_v3/runtime_v3_database.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
CAREER = ROOT / "lib/controllers/career_puzzle_controller.dart"
TRANSFER = ROOT / "lib/controllers/transfer_detective_controller.dart"
FILES = [BASE, STUB, IO, DB, HYBRID, CAREER, TRANSFER]
HYBRID_IMPORT = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"


def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2g.bak")
    if not bak.exists():
        shutil.copy2(path, bak)


def insert_before_class_end(text: str, method: str) -> str:
    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("class end bulunamadi")
    return text[:idx] + method + text[idx:]


def patch_base(text: str) -> str:
    if "transferDetectiveEvents(" in text:
        return text
    marker = "  Future<List<Map<String, Object?>>> careerTimeline(int playerId);"
    if marker not in text:
        raise RuntimeError("base careerTimeline marker yok")
    return text.replace(marker, "  Future<List<Map<String, Object?>>> transferDetectiveEvents();\n\n" + marker, 1)


def patch_stub(text: str) -> str:
    if "transferDetectiveEvents(" in text:
        return text
    marker = "  @override\n  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async =>\n      const [];\n"
    if marker not in text:
        raise RuntimeError("stub careerTimeline marker yok")
    method = "  @override\n  Future<List<Map<String, Object?>>> transferDetectiveEvents() async =>\n      const [];\n\n"
    return text.replace(marker, method + marker, 1)


def patch_io(text: str) -> str:
    old_select = "        c.canonical_key,\n        c.name AS club_name,\n        cs.start_date,"
    new_select = "        c.canonical_key,\n        c.name AS club_name,\n        CASE\n          WHEN c.canonical_key LIKE 'existing:%'\n          THEN CAST(substr(c.canonical_key, 10) AS INTEGER)\n          ELSE NULL\n        END AS exposed_club_id,\n        cs.start_date,"
    if "END AS exposed_club_id" not in text:
        if old_select not in text:
            raise RuntimeError("IO careerTimeline select marker yok")
        text = text.replace(old_select, new_select, 1)

    if "Future<List<Map<String, Object?>>> transferDetectiveEvents" in text:
        return text

    marker = "  @override\n  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {\n"
    if marker not in text:
        raise RuntimeError("IO careerTimeline method marker yok")

    method = r'''  @override
  Future<List<Map<String, Object?>>> transferDetectiveEvents() async {
    return _database.rawQuery(
      """
      SELECT
        t.event_id,
        t.player_id,
        t.transfer_year,
        t.transfer_date,
        CAST(substr(fc.canonical_key, 10) AS INTEGER) AS from_club_id,
        CAST(substr(tc.canonical_key, 10) AS INTEGER) AS to_club_id,
        t.trust,
        p.selection_rank
      FROM event_pools ep
      JOIN transfers t ON t.event_id = ep.event_id
      JOIN players p ON p.id = t.player_id
      JOIN clubs fc ON fc.id = t.from_club_id
      JOIN clubs tc ON tc.id = t.to_club_id
      WHERE ep.pool_name = 'transfer_detective_normal_v3'
        AND p.is_shadow = 0
        AND fc.canonical_key LIKE 'existing:%'
        AND tc.canonical_key LIKE 'existing:%'
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        t.transfer_year DESC,
        t.event_id
      """,
    );
  }

'''
    return text.replace(marker, method + marker, 1)


def patch_db(text: str) -> str:
    if "transferDetectiveEvents(" in text:
        return text
    marker = "  Future<List<Map<String, Object?>>> careerTimeline(int playerId) =>\n      _backend.careerTimeline(playerId);\n"
    if marker not in text:
        raise RuntimeError("database careerTimeline marker yok")
    method = "  Future<List<Map<String, Object?>>> transferDetectiveEvents() =>\n      _backend.transferDetectiveEvents();\n\n"
    return text.replace(marker, method + marker, 1)


def patch_hybrid(text: str) -> str:
    methods = ""
    if "Future<List<Map<String, Object?>>> careerTimeline(" not in text:
        methods += r'''
  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.careerTimeline(playerId);
    } catch (e) {
      debugPrint('[HybridV3] careerTimeline($playerId) fallback: $e');
      return const [];
    }
  }
'''
    if "Future<List<Map<String, Object?>>> transferDetectiveEvents(" not in text:
        methods += r'''
  Future<List<Map<String, Object?>>> transferDetectiveEvents() async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.transferDetectiveEvents();
    } catch (e) {
      debugPrint('[HybridV3] transferDetectiveEvents fallback: $e');
      return const [];
    }
  }
'''
    return text if not methods else insert_before_class_end(text, methods)


def add_import(text: str, anchor: str) -> str:
    if HYBRID_IMPORT in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor yok: {anchor}")
    return text.replace(anchor, anchor + "\n" + HYBRID_IMPORT, 1)


def patch_career(text: str) -> str:
    if "career_preview_beginner" in text and "_startRoundRuntime" in text:
        return text
    for marker in ["import 'dart:async';", "import '../services/search_service.dart';", "Timer? _feedbackTimer;", "void initialize() {", "void restart() {", "void _startRound({required bool keepSession}) {", "p.peakMarketValue", "p.careerTimeline"]:
        if marker not in text:
            raise RuntimeError(f"Career local shape bulunamadi: {marker}")
    text = add_import(text, "import '../services/search_service.dart';")
    text = text.replace("  Timer? _feedbackTimer;", "  Timer? _feedbackTimer;\n\n  bool _usingRuntimeV3 = false;\n  List<Player> _runtimeCandidatePool = const [];", 1)

    old_init = "  void initialize() {\n    _startRound(keepSession: false);\n  }\n\n  void restart() {\n    _startRound(keepSession: true);\n  }"
    new_init = r'''  void initialize() {
    unawaited(_initializeHybrid());
  }

  void restart() {
    if (_usingRuntimeV3) {
      unawaited(_startRoundRuntime(keepSession: true));
    } else {
      _startRound(keepSession: true);
    }
  }

  String get _runtimePoolName {
    switch (difficulty) {
      case CareerPuzzleDifficulty.beginner:
        return 'career_preview_beginner';
      case CareerPuzzleDifficulty.normal:
        return 'career_preview_normal';
      case CareerPuzzleDifficulty.legend:
        return 'career_preview_legend';
    }
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;
    if (_usingRuntimeV3) {
      _runtimeCandidatePool = await hybrid.playersInPool(_runtimePoolName);
      if (_runtimeCandidatePool.length < 100) {
        debugPrint('[HybridV3] CareerPuzzle SQLite pool too small; legacy fallback.');
        _usingRuntimeV3 = false;
      } else {
        debugPrint('[HybridV3] CareerPuzzle SQLite difficulty=${difficulty.name} players=${_runtimeCandidatePool.length}');
      }
    }
    if (_usingRuntimeV3) {
      await _startRoundRuntime(keepSession: false);
    } else {
      _startRound(keepSession: false);
    }
  }

  Future<List<CareerStop>> _runtimeTimelineFor(Player player) async {
    final rows = await HybridGameplayDataService.instance.careerTimeline(player.id);
    final seen = <int>{};
    final result = <CareerStop>[];
    for (final row in rows) {
      final clubId = (row['exposed_club_id'] as num?)?.toInt();
      if (clubId == null || clubId <= 0) continue;
      if (Repository.instance.clubById(clubId) == null) continue;
      if (!seen.add(clubId)) continue;
      final startDate = row['start_date']?.toString() ?? '';
      final endDate = row['end_date']?.toString() ?? '';
      final startYear = int.tryParse(startDate.length >= 4 ? startDate.substring(0, 4) : '');
      if (startYear == null) continue;
      final endYear = int.tryParse(endDate.length >= 4 ? endDate.substring(0, 4) : '');
      result.add(CareerStop(clubId: clubId, startYear: startYear, endYear: endYear));
    }
    return result;
  }

  Future<void> _startRoundRuntime({required bool keepSession}) async {
    final (minS, maxS) = _stopRange;
    if (_runtimeCandidatePool.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }
    final envelopeSize = _runtimeCandidatePool.length.clamp(100, 1800);
    final candidates = _runtimeCandidatePool.take(envelopeSize).toList()..shuffle(_random);
    for (final target in candidates.take(120)) {
      final uniqueStops = await _runtimeTimelineFor(target);
      if (uniqueStops.length < minS) continue;
      if (difficulty == CareerPuzzleDifficulty.beginner && uniqueStops.length > maxS + 3) continue;
      final desired = minS + (maxS > minS ? _random.nextInt(maxS - minS + 1) : 0);
      final take = desired.clamp(minS, uniqueStops.length);
      final maxStart = uniqueStops.length - take;
      final startIndex = maxStart > 0 ? _random.nextInt(maxStart + 1) : 0;
      final chosenStops = uniqueStops.skip(startIndex).take(take).toList();
      final displayClubs = chosenStops.map((s) => Repository.instance.clubById(s.clubId)).whereType<Club>().toList()..shuffle(_random);
      if (displayClubs.length != chosenStops.length) continue;
      _state = CareerPuzzleState(
        isLoading: false,
        phase: CareerPuzzlePhase.guessingPlayer,
        difficulty: difficulty,
        target: target,
        correctStops: chosenStops,
        displayClubs: displayClubs,
        lives: keepSession ? _state.lives : CareerPuzzleState.maxLives,
        coins: keepSession ? _state.coins : CareerPuzzleState.startingCoins,
        sessionScore: keepSession ? _state.sessionScore : 0,
        roundScore: 0,
        playerGuessed: false,
        orderUntouched: true,
        orderCheckedOnce: false,
        revealedEraIndexes: const {},
        shortStayMarkedClubIds: const {},
        connectedPairs: const [],
      );
      notifyListeners();
      return;
    }
    debugPrint('[HybridV3] CareerPuzzle no compatible existing-club timeline; legacy fallback for this round.');
    _startRound(keepSession: keepSession);
  }'''
    if old_init not in text:
        raise RuntimeError("Career initialize/restart block bulunamadi")
    return text.replace(old_init, new_init, 1)


def patch_transfer(text: str) -> str:
    if "transferDetectiveEvents" in text and "_startRoundRuntime" in text:
        return text
    for marker in ["import 'dart:async';", "import '../services/search_service.dart';", "Timer? _feedbackTimer;", "void initialize() {", "void restart() {", "Repository.instance.famousTransfers", "tr.fee", "target.peakMarketValue", "text: '${target.careerGoals} gol',", "String formatFee() {"]:
        if marker not in text:
            raise RuntimeError(f"Transfer local shape bulunamadi: {marker}")
    text = add_import(text, "import '../services/search_service.dart';")
    if "import '../models/famous_transfer.dart';" not in text:
        anchor = "import '../models/player.dart';"
        if anchor not in text:
            raise RuntimeError("Transfer Player model import anchor yok")
        text = text.replace(anchor, anchor + "\nimport '../models/famous_transfer.dart';", 1)
    text = text.replace("  Timer? _feedbackTimer;", "  Timer? _feedbackTimer;\n\n  bool _usingRuntimeV3 = false;\n  List<Map<String, Object?>> _runtimeEvents = const [];\n  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};", 1)

    old_init = "  void initialize() {\n    _startRound(keepSession: false);\n  }\n\n  void restart() {\n    _startRound(keepSession: true);\n  }"
    new_init = r'''  void initialize() {
    unawaited(_initializeHybrid());
  }

  void restart() {
    if (_usingRuntimeV3) {
      _startRoundRuntime(keepSession: true);
    } else {
      _startRound(keepSession: true);
    }
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;
    if (_usingRuntimeV3) {
      _runtimeEvents = await hybrid.transferDetectiveEvents();
      _runtimeFactsByPlayer = await hybrid.playerFactsForPool('transfer_detective_normal');
      if (_runtimeEvents.length < 1000) {
        debugPrint('[HybridV3] TransferDetective SQLite event pool too small; legacy fallback.');
        _usingRuntimeV3 = false;
      } else {
        debugPrint('[HybridV3] TransferDetective SQLite events=${_runtimeEvents.length} facts=${_runtimeFactsByPlayer.length}');
      }
    }
    if (_usingRuntimeV3) {
      _startRoundRuntime(keepSession: false);
    } else {
      _startRound(keepSession: false);
    }
  }

  void _startRoundRuntime({required bool keepSession}) {
    if (_runtimeEvents.isEmpty) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return;
    }
    final envelopeSize = _runtimeEvents.length.clamp(1000, 12000);
    final source = _runtimeEvents.take(envelopeSize).toList()..shuffle(_random);
    for (final row in source.take(200)) {
      final playerId = (row['player_id'] as num?)?.toInt();
      final year = (row['transfer_year'] as num?)?.toInt();
      final fromClubId = (row['from_club_id'] as num?)?.toInt();
      final toClubId = (row['to_club_id'] as num?)?.toInt();
      if (playerId == null || year == null || fromClubId == null || toClubId == null) continue;
      final target = Repository.instance.playerById(playerId);
      final fromClub = Repository.instance.clubById(fromClubId);
      final toClub = Repository.instance.clubById(toClubId);
      if (target == null || fromClub == null || toClub == null) continue;
      final transfer = FamousTransfer(playerId: playerId, year: year, fee: 0, fromClubId: fromClubId, toClubId: toClubId);
      final hints = _buildHints(target, fromClub);
      _state = TransferDetectiveState(
        isLoading: false,
        target: target,
        transfer: transfer,
        fromClub: fromClub,
        toClub: toClub,
        hints: hints,
        lives: keepSession ? _state.lives : TransferDetectiveState.maxLives,
        streak: keepSession ? _state.streak : 0,
        sessionScore: keepSession ? _state.sessionScore : 0,
        coins: keepSession ? _state.coins : TransferDetectiveState.startingCoins,
        roundPoints: TransferDetectiveState.baseRoundPoints,
        isSolved: false,
        isFailed: false,
        wrongGuesses: const [],
        revealedLetterIndexes: const {},
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  String _runtimeStatsHint(Player player) {
    final facts = _runtimeFactsByPlayer[player.id];
    if (facts == null) return 'İstatistik verisi sınırlı';
    final apps = (facts['appearances'] as num?)?.toInt() ?? 0;
    final goals = (facts['goals'] as num?)?.toInt() ?? 0;
    final assists = (facts['assists'] as num?)?.toInt() ?? 0;
    final first = (facts['coverage_first_year'] as num?)?.toInt() ?? 0;
    final last = (facts['coverage_last_year'] as num?)?.toInt() ?? 0;
    final prefix = first > 0 && last > 0 ? '$first-$last kapsanan veri: ' : '';
    return '$prefix$apps maç • $goals gol • $assists asist';
  }'''
    if old_init not in text:
        raise RuntimeError("Transfer initialize/restart block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    old_hint = "        text: '${target.careerGoals} gol',"
    new_hint = "        text: _usingRuntimeV3\n            ? _runtimeStatsHint(target)\n            : '${target.careerGoals} gol',"
    if old_hint not in text:
        raise RuntimeError("Transfer careerGoals hint marker yok")
    text = text.replace(old_hint, new_hint, 1)

    pattern = re.compile(r"  String formatFee\(\)\s*\{\s*final fee = _state\.transfer\?\.fee \?\? 0;\s*return _formatFee\(fee\);\s*\}", re.S)
    m = pattern.search(text)
    if not m:
        raise RuntimeError("Transfer formatFee method bulunamadi")
    repl = "  String formatFee() {\n    if (_usingRuntimeV3) return '—';\n    final fee = _state.transfer?.fee ?? 0;\n    return _formatFee(fee);\n  }"
    return text[:m.start()] + repl + text[m.end():]


def main() -> None:
    for p in FILES:
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")
    originals = {p: p.read_text(encoding="utf-8") for p in FILES}
    patched = {
        BASE: patch_base(originals[BASE]),
        STUB: patch_stub(originals[STUB]),
        IO: patch_io(originals[IO]),
        DB: patch_db(originals[DB]),
        HYBRID: patch_hybrid(originals[HYBRID]),
        CAREER: patch_career(originals[CAREER]),
        TRANSFER: patch_transfer(originals[TRANSFER]),
    }
    for p in FILES:
        backup(p)
    for p in FILES:
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")
    print("[DONE] Step 04.2G Career Puzzle + Transfer Detective installed.")
    print("[SAFE] Legacy paths remain available when gameplay flag is OFF.")

if __name__ == "__main__":
    main()
