from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

BASE = ROOT / "lib/services/runtime_v3/runtime_v3_platform_base.dart"
STUB = ROOT / "lib/services/runtime_v3/runtime_v3_platform_stub.dart"
IO = ROOT / "lib/services/runtime_v3/runtime_v3_platform_io.dart"
DB = ROOT / "lib/services/runtime_v3/runtime_v3_database.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"
BUILD = ROOT / "lib/controllers/build_xi_controller.dart"
FILES = [BASE, STUB, IO, DB, HYBRID, BUILD]
IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"


def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2h.bak")
    if not bak.exists():
        shutil.copy2(path, bak)


def insert_before_class_end(text: str, method: str) -> str:
    idx = text.rfind("\n}")
    if idx < 0:
        raise RuntimeError("class end bulunamadi")
    return text[:idx] + method + text[idx:]


def patch_base(text: str) -> str:
    if "existingGameplayClubMetadata(" in text:
        return text
    marker = "  Future<List<Map<String, Object?>>> careerTimeline(int playerId);"
    if marker not in text:
        raise RuntimeError("base careerTimeline marker yok")
    method = "  Future<List<Map<String, Object?>>> existingGameplayClubMetadata();\n\n"
    return text.replace(marker, method + marker, 1)


def patch_stub(text: str) -> str:
    if "existingGameplayClubMetadata(" in text:
        return text
    marker = "  @override\n  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async =>\n      const [];\n"
    if marker not in text:
        raise RuntimeError("stub careerTimeline marker yok")
    method = "  @override\n  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async =>\n      const [];\n\n"
    return text.replace(marker, method + marker, 1)


def patch_io(text: str) -> str:
    if "Future<List<Map<String, Object?>>> existingGameplayClubMetadata" in text:
        return text
    marker = "  @override\n  Future<List<Map<String, Object?>>> careerTimeline(int playerId) async {\n"
    if marker not in text:
        raise RuntimeError("IO careerTimeline marker yok")
    method = '''  @override
  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async {
    return _database.rawQuery(
      """
      SELECT
        CAST(substr(canonical_key, 10) AS INTEGER) AS exposed_club_id,
        name,
        country,
        competition,
        popularity_seed
      FROM clubs
      WHERE gameplay_eligible = 1
        AND entity_type = 'SENIOR'
        AND canonical_key LIKE 'existing:%'
      ORDER BY popularity_seed DESC, id
      """,
    );
  }

'''
    return text.replace(marker, method + marker, 1)


def patch_db(text: str) -> str:
    if "existingGameplayClubMetadata(" in text:
        return text
    marker = "  Future<List<Map<String, Object?>>> careerTimeline(int playerId) =>\n      _backend.careerTimeline(playerId);\n"
    if marker not in text:
        raise RuntimeError("DB careerTimeline marker yok")
    method = "  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() =>\n      _backend.existingGameplayClubMetadata();\n\n"
    return text.replace(marker, method + marker, 1)


def patch_hybrid(text: str) -> str:
    if "Future<List<Map<String, Object?>>> existingGameplayClubMetadata" in text:
        return text
    method = '''
  Future<List<Map<String, Object?>>> existingGameplayClubMetadata() async {
    if (!isGameplayEnabled) return const [];
    try {
      return await _runtime.database.existingGameplayClubMetadata();
    } catch (e) {
      debugPrint('[HybridV3] existingGameplayClubMetadata fallback: $e');
      return const [];
    }
  }
'''
    return insert_before_class_end(text, method)


def patch_build(text: str) -> str:
    if "build_xi_preview" in text and "_buildRuntimePool" in text:
        return text

    required = [
        "import '../services/search_service.dart';",
        "late List<Player> _pool;",
        "void initialize() {",
        "List<Player> _buildPool() {",
        "Map<int, int> _computeCosts(List<Player> pool) {",
        "b.peakMarketValue.compareTo(a.peakMarketValue)",
        "final detailed = p.detailedPosition.trim();",
        "final common = pi.clubs.toSet().intersection(pj.clubs.toSet());",
        "players[i].clubs.toSet().intersection(players[j].clubs.toSet())",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Build XI local shape bulunamadi: {marker}")

    if "import 'dart:async';" not in text:
        text = "import 'dart:async';\n\n" + text

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    field_marker = "  late List<Player> _pool;"
    fields = '''

  bool _usingRuntimeV3 = false;
  List<Player> _runtimeBasePool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeClubMetaById = const {};
  Map<int, int> _runtimeRankByPlayer = const {};
'''
    text = text.replace(field_marker, field_marker + fields, 1)

    old_init = '''  void initialize() {
    _pool = _buildPool();
    final costs = _computeCosts(_pool);

    _state = BuildXiState(
      isLoading: false,
      theme: theme,
      formation: formation,
      slotPlayers: List<Player?>.filled(formation.slots.length, null),
      costs: costs,
    );

    notifyListeners();
  }'''

    new_init = '''  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeBasePool = await hybrid.playersInPool('build_xi_preview');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('build_xi_preview');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('build_xi_preview');

      final clubRows = await hybrid.existingGameplayClubMetadata();
      _runtimeClubMetaById = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                Map<String, Object?>.from(row),
      };

      _runtimeRankByPlayer = {
        for (var i = 0; i < _runtimeBasePool.length; i++)
          _runtimeBasePool[i].id: i + 1,
      };

      if (_runtimeBasePool.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000 ||
          _runtimeClubMetaById.length < 100) {
        debugPrint(
          '[HybridV3] BuildXI SQLite base pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      }
    }

    _pool = _usingRuntimeV3 ? _buildRuntimePool() : _buildPool();

    if (_usingRuntimeV3 && _pool.length < 35) {
      debugPrint(
        '[HybridV3] BuildXI theme pool too small '
        'theme=${theme.id} players=${_pool.length}; legacy fallback.',
      );
      _usingRuntimeV3 = false;
      _pool = _buildPool();
    }

    final costs = _computeCosts(_pool);

    _state = BuildXiState(
      isLoading: false,
      theme: theme,
      formation: formation,
      slotPlayers: List<Player?>.filled(formation.slots.length, null),
      costs: costs,
    );

    if (_usingRuntimeV3) {
      debugPrint(
        '[HybridV3] BuildXI SQLite '
        'theme=${theme.id} players=${_pool.length}',
      );
    }

    notifyListeners();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  String _detailedPositionFor(Player player) {
    if (!_usingRuntimeV3) return player.detailedPosition.trim();
    final facts = _runtimeFactsByPlayer[player.id];
    final factual = facts?['detailed_position']?.toString().trim() ?? '';
    return factual.isNotEmpty ? factual : player.detailedPosition.trim();
  }

  String _broadPositionFor(Player player) {
    if (!_usingRuntimeV3) return player.position.trim();
    final facts = _runtimeFactsByPlayer[player.id];
    final factual = facts?['position_group']?.toString().trim() ?? '';
    return factual.isNotEmpty ? factual : player.position.trim();
  }

  List<Player> _buildRuntimePool() {
    final players = _runtimeBasePool;

    switch (theme.poolType) {
      case BuildXiPoolType.league:
        final leagueName = theme.leagueName ?? '';
        final leagueClubIds = _runtimeClubMetaById.entries
            .where(
              (e) =>
                  (e.value['competition']?.toString().trim() ?? '') ==
                  leagueName,
            )
            .map((e) => e.key)
            .toSet();
        return players.where((p) {
          return _clubIdsForPlayer(p).any(leagueClubIds.contains);
        }).toList();

      case BuildXiPoolType.region:
        final countrySet = theme.countries!.toSet();
        return players
            .where((p) => p.countries.any(countrySet.contains))
            .toList();

      case BuildXiPoolType.clubPair:
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players.where((p) {
          final ids = _clubIdsForPlayer(p);
          return ids.contains(a) && ids.contains(b);
        }).toList();

      case BuildXiPoolType.clubUnion:
        final a = theme.clubPairIds![0];
        final b = theme.clubPairIds![1];
        return players.where((p) {
          final ids = _clubIdsForPlayer(p);
          return ids.contains(a) || ids.contains(b);
        }).toList();

      case BuildXiPoolType.all:
        var list = List<Player>.from(players);
        if (theme.minClubs != null) {
          list = list
              .where(
                (p) => _clubIdsForPlayer(p).length >= theme.minClubs!,
              )
              .toList();
        }
        return list;
    }
  }'''

    if old_init not in text:
        raise RuntimeError("Build XI initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    old_sort = '''    final sorted = List<Player>.from(pool)
      ..sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));'''
    new_sort = '''    final sorted = List<Player>.from(pool)
      ..sort((a, b) {
        if (_usingRuntimeV3) {
          final ra = _runtimeRankByPlayer[a.id] ?? 999999;
          final rb = _runtimeRankByPlayer[b.id] ?? 999999;
          return ra.compareTo(rb);
        }
        return b.peakMarketValue.compareTo(a.peakMarketValue);
      });'''
    if old_sort not in text:
        raise RuntimeError("Build XI cost sort block bulunamadi")
    text = text.replace(old_sort, new_sort, 1)

    old_pos = '''      // Sadece detaylı pozisyon eşleşmesi (RB ↔ CB karışmasın)
      final detailed = p.detailedPosition.trim();
      final positionMatch = detailed.isNotEmpty &&
          slot.acceptedDetailedPositions.contains(detailed);
      if (!positionMatch) return false;'''
    new_pos = '''      // Runtime V3 factual detailed position kullanır. Detay yoksa
      // yalnızca broad-position fallback'e izin verilir.
      final detailed = _detailedPositionFor(p);
      final positionMatch = detailed.isNotEmpty
          ? slot.acceptedDetailedPositions.contains(detailed)
          : _broadPositionFor(p) == slot.fallbackBroadPosition;
      if (!positionMatch) return false;'''
    if old_pos not in text:
        raise RuntimeError("Build XI position block bulunamadi")
    text = text.replace(old_pos, new_pos, 1)

    text = text.replace(
        "final common = pi.clubs.toSet().intersection(pj.clubs.toSet());",
        "final common = _clubIdsForPlayer(pi)\n"
        "            .toSet()\n"
        "            .intersection(_clubIdsForPlayer(pj).toSet());",
        1,
    )

    old_pair = "players[i].clubs.toSet().intersection(players[j].clubs.toSet())"
    new_pair = (
        "_clubIdsForPlayer(players[i])\n"
        "              .toSet()\n"
        "              .intersection(_clubIdsForPlayer(players[j]).toSet())"
    )
    if text.count(old_pair) < 2:
        raise RuntimeError("Build XI shared club intersections eksik")
    text = text.replace(old_pair, new_pair)

    final_markers = [
        "build_xi_preview",
        "_runtimeClubIdsByPlayer",
        "_runtimeFactsByPlayer",
        "_runtimeClubMetaById",
        "_buildRuntimePool",
        "_runtimeRankByPlayer[a.id]",
        "_detailedPositionFor(p)",
        "_clubIdsForPlayer(pi)",
        "[HybridV3] BuildXI SQLite",
    ]
    for marker in final_markers:
        if marker not in text:
            raise RuntimeError(f"Build XI final marker eksik: {marker}")
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
        BUILD: patch_build(originals[BUILD]),
    }

    for p in FILES:
        backup(p)
    for p in FILES:
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print()
    print("[DONE] Step 04.2H Build XI migration installed.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")


if __name__ == "__main__":
    main()
