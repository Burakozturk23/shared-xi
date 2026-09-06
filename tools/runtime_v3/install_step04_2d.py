from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

BASE = ROOT / "lib/services/runtime_v3/runtime_v3_platform_base.dart"
STUB = ROOT / "lib/services/runtime_v3/runtime_v3_platform_stub.dart"
IO = ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart"
DB = ROOT / "lib/services/runtime_v3/runtime_v3_database.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
MYSTERY = ROOT / "lib/controllers/mystery_player_controller.dart"

FILES = [BASE, STUB, IO, DB, HYBRID, MYSTERY]
IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"


def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2d.bak")
    if not bak.exists():
        shutil.copy2(path, bak)


def patch_base(text: str) -> str:
    if "playerFactsForPool(" in text:
        return text
    marker = "  Future<List<Map<String, Object?>>> careerTimeline(int playerId);"
    if marker not in text:
        raise RuntimeError("runtime_v3_platform_base careerTimeline marker yok")
    method = """  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  );

"""
    return text.replace(marker, method + marker, 1)


def patch_stub(text: str) -> str:
    if "playerFactsForPool(" in text:
        return text
    marker = """  @override
  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async =>
      const [];
"""
    if marker not in text:
        raise RuntimeError("runtime_v3_platform_stub careerTimeline marker yok")
    method = """  @override
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async =>
      const {};

"""
    return text.replace(marker, method + marker, 1)


def patch_io(text: str) -> str:
    if "Future<Map<int, Map<String, Object?>>> playerFactsForPool" in text:
        return text
    marker = """  @override
  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {
"""
    if marker not in text:
        raise RuntimeError("runtime_v3_platform_io careerTimeline marker yok")
    method = r'''  @override
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async {
    final rows = await _database.rawQuery(
      """
      SELECT
        p.id AS player_id,
        p.selection_rank,
        p.selection_score,
        p.country,
        p.position,
        pr.birth_year,
        pr.citizenship,
        pr.position_group,
        pr.detailed_position,
        pr.foot,
        pr.height_cm,
        pr.international_caps,
        pr.international_goals,
        ps.appearances,
        ps.goals,
        ps.assists,
        ps.minutes,
        ps.ucl_appearances,
        ps.big5_appearances,
        ps.top_competition_appearances,
        ps.coverage_first_year,
        ps.coverage_last_year,
        ps.coverage_class
      FROM player_pools pp
      JOIN players p ON p.id = pp.player_id
      LEFT JOIN profiles pr ON pr.player_id = p.id
      LEFT JOIN player_stats ps ON ps.player_id = p.id
      WHERE pp.pool_name = ?
        AND p.is_shadow = 0
      ORDER BY
        CASE WHEN p.selection_rank IS NULL THEN 1 ELSE 0 END,
        p.selection_rank,
        p.id
      """,
      [poolName],
    );

    final result = <int, Map<String, Object?>>{};
    for (final row in rows) {
      final playerId = (row['player_id'] as num).toInt();
      result[playerId] = Map<String, Object?>.from(row);
    }
    return result;
  }

'''
    return text.replace(marker, method + marker, 1)


def patch_db(text: str) -> str:
    if "playerFactsForPool(" in text:
        return text
    marker = """  Future<List<Map<String, Object?>>> careerTimeline(int playerId) =>
      _backend.careerTimeline(playerId);
"""
    if marker not in text:
        raise RuntimeError("runtime_v3_database careerTimeline marker yok")
    method = """  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) =>
      _backend.playerFactsForPool(poolName);

"""
    return text.replace(marker, method + marker, 1)


def patch_hybrid(text: str) -> str:
    if "Future<Map<int, Map<String, Object?>>> playerFactsForPool" in text:
        return text
    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("hybrid_gameplay_data_service class end yok")
    method = r'''
  Future<Map<int, Map<String, Object?>>> playerFactsForPool(
    String poolName,
  ) async {
    if (!isGameplayEnabled) return const {};
    try {
      return await _runtime.database.playerFactsForPool(poolName);
    } catch (e) {
      debugPrint('[HybridV3] playerFactsForPool($poolName) fallback: $e');
      return const {};
    }
  }
'''
    return text[:idx] + method + text[idx:]


def patch_mystery(text: str) -> str:
    if (
        "mystery_normal" in text
        and "_runtimeFactsByPlayer" in text
        and "_factualStatsText" in text
    ):
        return text

    required = [
        "import 'dart:async';",
        "import '../services/search_service.dart';",
        "Timer? _feedbackTimer;",
        "void initialize() {",
        "_startRound(keepSession: false);",
        "void _startRound({required bool keepSession}) {",
        "String _positionLabel(String raw) {",
        "List<String> _leagueNamesFor(Player p) {",
        "String? _starTeammateName(Player target) {",
        "List<MysteryHint> _buildHints(Player p) {",
        "text: 'Kariyer golü: ${p.careerGoals}',",
        "title: 'Piyasa',",
        "void skip() {",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Mystery local shape bulunamadi: {marker}")

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    field_marker = "  Timer? _feedbackTimer;"
    text = text.replace(
        field_marker,
        field_marker + r'''

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
''',
        1,
    )

    old_init = """  void initialize() {
    _startRound(keepSession: false);
  }"""
    new_init = r'''  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePool = await hybrid.playersInPool('mystery_normal');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('mystery_normal');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('mystery_normal');

      _runtimePool = _runtimePool
          .where(
            (p) =>
                (_runtimeClubIdsByPlayer[p.id] ?? const <int>[]).length >= 2,
          )
          .toList();

      if (_runtimePool.length < 500 ||
          _runtimeFactsByPlayer.length < 500) {
        debugPrint(
          '[HybridV3] Mystery SQLite factual pool too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Mystery SQLite '
          'players=${_runtimePool.length} '
          'facts=${_runtimeFactsByPlayer.length}',
        );
      }
    }

    _startRound(keepSession: false);
  }'''
    if old_init not in text:
        raise RuntimeError("Mystery initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    round_marker = "  void _startRound({required bool keepSession}) {"
    runtime_round = r'''  void _startRound({required bool keepSession}) {
    if (_usingRuntimeV3) {
      if (_runtimePool.isEmpty) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        return;
      }

      // Pool is already selectionRankV3 ordered; no market-value weighting.
      final takeCount = _runtimePool.length.clamp(500, 3500);
      final top = _runtimePool.take(takeCount).toList()..shuffle(_random);
      final target = top[_random.nextInt(top.length)];
      final hints = _buildHints(target);

      final withFirst = List<MysteryHint>.from(hints);
      if (withFirst.isNotEmpty) {
        withFirst[0] = withFirst[0].copyWith(unlocked: true);
      }

      _state = MysteryPlayerState(
        isLoading: false,
        target: target,
        hints: withFirst,
        lives: keepSession ? _state.lives : MysteryPlayerState.maxLives,
        streak: keepSession ? _state.streak : 0,
        sessionScore: keepSession ? _state.sessionScore : 0,
        coins: keepSession ? _state.coins : MysteryPlayerState.startingCoins,
        roundPoints: MysteryPlayerState.baseRoundPoints,
        isSolved: false,
        isFailed: false,
        wrongGuesses: const [],
        revealedLetterIndexes: const {},
        roundStartedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }
'''
    text = text.replace(round_marker, runtime_round, 1)

    helper_anchor = "  String _positionLabel(String raw) {"
    helpers = r'''  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  Map<String, Object?>? _factsFor(Player player) {
    return _usingRuntimeV3 ? _runtimeFactsByPlayer[player.id] : null;
  }

  String _factualStatsText(Player player) {
    final facts = _factsFor(player);
    if (facts == null) {
      return 'Kariyer golü: ${player.careerGoals}';
    }

    final apps = (facts['appearances'] as num?)?.toInt() ?? 0;
    final goals = (facts['goals'] as num?)?.toInt() ?? 0;
    final assists = (facts['assists'] as num?)?.toInt() ?? 0;
    final first = (facts['coverage_first_year'] as num?)?.toInt() ?? 0;
    final last = (facts['coverage_last_year'] as num?)?.toInt() ?? 0;

    final prefix =
        first > 0 && last > 0 ? '$first-$last kapsanan veri: ' : '';
    return '$prefix$apps maç • $goals gol • $assists asist';
  }

  String _physicalProfileText(Player player) {
    final facts = _factsFor(player);
    if (facts == null) return 'Profil bilgisi sınırlı';

    final height = (facts['height_cm'] as num?)?.toInt() ?? 0;
    final foot = facts['foot']?.toString().trim() ?? '';
    final caps = (facts['international_caps'] as num?)?.toInt() ?? 0;

    final parts = <String>[];
    if (height > 0) parts.add('$height cm');

    if (foot.isNotEmpty) {
      final lower = foot.toLowerCase();
      parts.add(
        lower == 'left'
            ? 'Sol ayak'
            : lower == 'right'
                ? 'Sağ ayak'
                : foot,
      );
    }

    if (caps > 0) parts.add('$caps milli maç');

    return parts.isEmpty ? 'Profil bilgisi sınırlı' : parts.join(' • ');
  }

'''
    text = text.replace(helper_anchor, helpers + helper_anchor, 1)

    league_start = text.find("  List<String> _leagueNamesFor(Player p) {")
    teammate_start = text.find("  String? _starTeammateName(Player target) {")
    if league_start < 0 or teammate_start < 0 or teammate_start <= league_start:
        raise RuntimeError("Mystery league/teammate boundaries bulunamadi")
    league_block = text[league_start:teammate_start]
    if "for (final id in p.clubs)" not in league_block:
        raise RuntimeError("Mystery league p.clubs loop bulunamadi")
    league_block = league_block.replace(
        "for (final id in p.clubs)",
        "for (final id in _clubIdsForPlayer(p))",
        1,
    )
    text = text[:league_start] + league_block + text[teammate_start:]

    teammate_start = text.find("  String? _starTeammateName(Player target) {")
    hints_start = text.find("  List<MysteryHint> _buildHints(Player p) {")
    if teammate_start < 0 or hints_start < 0 or hints_start <= teammate_start:
        raise RuntimeError("Mystery teammate/buildHints boundaries bulunamadi")
    teammate_method = r'''  String? _starTeammateName(Player target) {
    final clubSet = _clubIdsForPlayer(target).toSet();

    if (_usingRuntimeV3) {
      // mystery_normal is selection-rank ordered.
      for (final p in _runtimePool) {
        if (p.id == target.id) continue;
        if (_clubIdsForPlayer(p).any(clubSet.contains)) {
          return p.name;
        }
      }
      return null;
    }

    Player? best;
    for (final p in Repository.instance.players) {
      if (p.id == target.id) continue;
      if (!p.clubs.any(clubSet.contains)) continue;
      if (best == null || p.peakMarketValue > best.peakMarketValue) {
        best = p;
      }
    }
    return best?.name;
  }

'''
    text = text[:teammate_start] + teammate_method + text[hints_start:]

    hints_start = text.find("  List<MysteryHint> _buildHints(Player p) {")
    unlock_start = text.find("  void unlockHint(int index) {", hints_start)
    if hints_start < 0 or unlock_start < 0:
        raise RuntimeError("Mystery buildHints boundary bulunamadi")
    block = text[hints_start:unlock_start]

    if "    final clubNames = p.clubs" not in block:
        raise RuntimeError("Mystery clubNames legacy block yok")
    block = block.replace(
        "    final clubNames = p.clubs",
        "    final clubNames = _clubIdsForPlayer(p)",
        1,
    )
    if "        text: '${p.clubs.length} farklı kulüpte forma giymiş'," not in block:
        raise RuntimeError("Mystery club count hint yok")
    block = block.replace(
        "        text: '${p.clubs.length} farklı kulüpte forma giymiş',",
        "        text: '${_clubIdsForPlayer(p).length} farklı kulüpte forma giymiş',",
        1,
    )
    if "        text: 'Kariyer golü: ${p.careerGoals}'," not in block:
        raise RuntimeError("Mystery careerGoals hint yok")
    block = block.replace(
        "        text: 'Kariyer golü: ${p.careerGoals}',",
        "        text: _usingRuntimeV3\n"
        "            ? _factualStatsText(p)\n"
        "            : 'Kariyer golü: ${p.careerGoals}',",
        1,
    )

    old_value = """      MysteryHint(
        kind: MysteryHintKind.marketValue,
        title: 'Piyasa',
        text: 'Piyasa değeri: ${_valueBucket(p.peakMarketValue > 0 ? p.peakMarketValue : p.marketValue)}',
        cost: 15,
      ),"""
    new_value = """      MysteryHint(
        // Keep enum slot for UI compatibility. Runtime V3 replaces market
        // value with factual profile data.
        kind: MysteryHintKind.marketValue,
        title: _usingRuntimeV3 ? 'Profil' : 'Piyasa',
        text: _usingRuntimeV3
            ? _physicalProfileText(p)
            : 'Piyasa değeri: ${_valueBucket(p.peakMarketValue > 0 ? p.peakMarketValue : p.marketValue)}',
        cost: 15,
      ),"""
    if old_value not in block:
        raise RuntimeError("Mystery marketValue hint exact block bulunamadi")
    block = block.replace(old_value, new_value, 1)

    text = text[:hints_start] + block + text[unlock_start:]

    final_markers = [
        "mystery_normal",
        "_runtimeClubIdsByPlayer",
        "_runtimeFactsByPlayer",
        "_factualStatsText",
        "_physicalProfileText",
        "for (final id in _clubIdsForPlayer(p))",
        "mystery_normal is selection-rank ordered",
        "title: _usingRuntimeV3 ? 'Profil' : 'Piyasa'",
        "[HybridV3] Mystery SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Mystery final marker eksik: {marker}")

    return text


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
        MYSTERY: patch_mystery(originals[MYSTERY]),
    }

    # Every transform succeeded before any project file is written.
    for p in FILES:
        backup(p)
    for p in FILES:
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print()
    print("[DONE] Step 04.2D Mystery factual migration installed.")
    print("[SAFE] Legacy value/goal path stays feature-flag OFF fallback.")


if __name__ == "__main__":
    main()
