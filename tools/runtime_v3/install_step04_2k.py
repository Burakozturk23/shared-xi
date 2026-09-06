from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STREAK = ROOT / "lib/controllers/streak_controller.dart"
RANDOM_FIVE = ROOT / "lib/controllers/random_five_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2k.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, anchor: str) -> str:
    if IMPORT_LINE in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor bulunamadi: {anchor}")
    return text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

def patch_streak(text: str) -> str:
    if "Streak SQLite" in text and "_nextRoundRuntime" in text:
        return text

    for marker in [
        "import 'dart:async';",
        "import '../services/high_score_service.dart';",
        "void initialize() {",
        "void _nextRound({bool resetLivesAndStreak = false}) {",
        "final found = GameService.matchingPlayers(",
        "_feedback(\"Süre doldu!\", false);",
        '_feedback("Doğru! ${player.name} — Seri: $streak", true);',
    ]:
        if marker not in text:
            raise RuntimeError(f"Streak local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/high_score_service.dart';")

    field_marker = "  Timer? _feedbackTimer;"
    if field_marker not in text:
        raise RuntimeError("Streak feedback field yok")
    text = text.replace(
        field_marker,
        field_marker + r"""

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeQuizClubs = const [];
  int _roundGenerationToken = 0;
""",
        1,
    )

    old_init = """  void initialize() {
    _nextRound(resetLivesAndStreak: true);
  }"""
    new_init = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeQuizClubs = await hybrid.topGameplayClubs(limit: 120);
      if (_runtimeQuizClubs.length < 20) {
        debugPrint(
          '[HybridV3] Streak SQLite club pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Streak SQLite clubs=${_runtimeQuizClubs.length}',
        );
      }
    }

    if (_usingRuntimeV3) {
      unawaited(_nextRoundRuntime(resetLivesAndStreak: true));
    } else {
      _nextRound(resetLivesAndStreak: true);
    }
  }"""
    if old_init not in text:
        raise RuntimeError("Streak initialize exact block yok")
    text = text.replace(old_init, new_init, 1)

    marker = "  void _nextRound({bool resetLivesAndStreak = false}) {"
    runtime = r"""  Future<void> _nextRoundRuntime({
    bool resetLivesAndStreak = false,
  }) async {
    final token = ++_roundGenerationToken;
    final clubs = _runtimeQuizClubs;

    if (clubs.length < 2) {
      _usingRuntimeV3 = false;
      _nextRound(resetLivesAndStreak: resetLivesAndStreak);
      return;
    }

    for (var attempts = 0; attempts < 180; attempts++) {
      final club1 = clubs[_random.nextInt(clubs.length)];
      final club2 = clubs[_random.nextInt(clubs.length)];
      if (club1.id == club2.id) continue;

      final ids =
          await HybridGameplayDataService.instance.sharedXiAnswerIds(
        club1.id,
        club2.id,
        playerPool: 'shared_xi_answer',
      );

      if (token != _roundGenerationToken) return;
      if (ids.length < _minSharedPlayers) continue;

      final found = <Player>[];
      for (final id in ids) {
        final player = Repository.instance.playerById(id);
        if (player != null) found.add(player);
      }
      if (found.length < _minSharedPlayers) continue;

      final entity1 = MatchEntity.club(club1);
      final entity2 = MatchEntity.club(club2);

      _timer?.cancel();
      _state = _state.copyWith(
        isLoading: false,
        streak: resetLivesAndStreak ? 0 : _state.streak,
        lives: resetLivesAndStreak ? 3 : _state.lives,
        hintsLeft: resetLivesAndStreak ? 3 : _state.hintsLeft,
        isGameOver: false,
        entity1: entity1,
        entity2: entity2,
        matchingPlayers: found,
        suggestions: const [],
        wrongAttempts: const {},
        secondsLeft: _roundSeconds,
      );
      _startTimer();
      notifyListeners();
      return;
    }

    debugPrint(
      '[HybridV3] Streak could not find valid SQLite pair; '
      'legacy fallback for round.',
    );
    _nextRound(resetLivesAndStreak: resetLivesAndStreak);
  }

  void _advanceRound() {
    if (_usingRuntimeV3) {
      unawaited(_nextRoundRuntime());
    } else {
      _nextRound();
    }
  }

"""
    text = text.replace(marker, runtime + marker, 1)

    text = text.replace(
        '    _feedback("Süre doldu!", false);\n    _nextRound();',
        '    _feedback("Süre doldu!", false);\n    _advanceRound();',
        1,
    )
    text = text.replace(
        '    _feedback("Doğru! ${player.name} — Seri: $streak", true);\n    _nextRound();',
        '    _feedback("Doğru! ${player.name} — Seri: $streak", true);\n    _advanceRound();',
        1,
    )

    for marker in [
        "_runtimeQuizClubs",
        "_nextRoundRuntime",
        "playerPool: 'shared_xi_answer'",
        "_advanceRound",
        "[HybridV3] Streak SQLite clubs=",
    ]:
        if marker not in text:
            raise RuntimeError(f"Streak final marker eksik: {marker}")

    return text

def patch_random_five(text: str) -> str:
    if "RandomFive SQLite" in text and "_runtimeClubIdsByPlayer" in text:
        return text

    for marker in [
        "import 'dart:async';",
        "import '../services/search_service.dart';",
        "Timer? _feedbackTimer;",
        "void initialize() {",
        "void _pickNewClubs() {",
        "void updateSuggestions(String query) {",
        "_state.clubs.where((c) => player.clubs.contains(c.id)).toList();",
    ]:
        if marker not in text:
            raise RuntimeError(f"Random Five local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/search_service.dart';")

    field_marker = "  Timer? _feedbackTimer;"
    text = text.replace(
        field_marker,
        field_marker + r"""

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Set<int> _runtimeAnswerPlayerIds = const {};
""",
        1,
    )

    old_init = """  void initialize() {
    _pickNewClubs();
  }"""
    new_init = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 120);
      final broadPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeAnswerPlayerIds = broadPlayers.map((p) => p.id).toSet();
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      if (_runtimeClubPool.length < 20 ||
          _runtimeAnswerPlayerIds.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] RandomFive SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] RandomFive SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayerIds.length}',
        );
      }
    }

    _pickNewClubs();
  }

  List<Club> _pickRuntimeDiverseClubs() {
    final shuffled = List<Club>.from(_runtimeClubPool)..shuffle(_random);
    final result = <Club>[];
    final leagueCounts = <String, int>{};
    final countryCounts = <String, int>{};

    for (final club in shuffled) {
      final league = club.league.trim();
      final country = club.country.trim();

      if (league.isNotEmpty && (leagueCounts[league] ?? 0) >= 1) continue;
      if (country.isNotEmpty && (countryCounts[country] ?? 0) >= 2) continue;

      result.add(club);
      if (league.isNotEmpty) {
        leagueCounts[league] = (leagueCounts[league] ?? 0) + 1;
      }
      if (country.isNotEmpty) {
        countryCounts[country] = (countryCounts[country] ?? 0) + 1;
      }
      if (result.length >= 5) break;
    }

    if (result.length < 5) {
      for (final club in shuffled) {
        if (result.any((c) => c.id == club.id)) continue;
        result.add(club);
        if (result.length >= 5) break;
      }
    }
    return result;
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }"""
    if old_init not in text:
        raise RuntimeError("Random Five initialize exact block yok")
    text = text.replace(old_init, new_init, 1)

    old_pick = """    // Farklı liglerden popüler kulüpler (aynı lig kümelenmesi yok)
    final clubs = PopularClubs.pickDiverse(
      count: 5,
      maxPerLeague: 1,
      maxPerCountry: 2,
      random: _random,
    );"""
    new_pick = """    // Runtime V3: canonical popularity pool. Legacy: static pool.
    final clubs = _usingRuntimeV3
        ? _pickRuntimeDiverseClubs()
        : PopularClubs.pickDiverse(
            count: 5,
            maxPerLeague: 1,
            maxPerCountry: 2,
            random: _random,
          );"""
    if old_pick not in text:
        raise RuntimeError("Random Five club picker block yok")
    text = text.replace(old_pick, new_pick, 1)

    old_suggestions = """    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""
    new_suggestions = """    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    suggestions = SearchService.suggestions(
      players: source,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );"""
    if old_suggestions not in text:
        raise RuntimeError("Random Five suggestions block yok")
    text = text.replace(old_suggestions, new_suggestions, 1)

    old_matched = """    final matched =
        _state.clubs.where((c) => player.clubs.contains(c.id)).toList();"""
    new_matched = """    if (_usingRuntimeV3 &&
        !_runtimeAnswerPlayerIds.contains(player.id)) {
      _feedback('${player.name} cevap havuzunda değil.', false);
      return;
    }

    final playerClubIds = _clubIdsForPlayer(player).toSet();
    final matched =
        _state.clubs.where((c) => playerClubIds.contains(c.id)).toList();"""
    if old_matched not in text:
        raise RuntimeError("Random Five matched block yok")
    text = text.replace(old_matched, new_matched, 1)

    for marker in [
        "_runtimeClubPool",
        "_runtimeClubIdsByPlayer",
        "_runtimeAnswerPlayerIds",
        "playersInPool('grid_answer')",
        "playerClubIdsForPool('grid_answer')",
        "_pickRuntimeDiverseClubs",
        "[HybridV3] RandomFive SQLite",
    ]:
        if marker not in text:
            raise RuntimeError(f"Random Five final marker eksik: {marker}")

    return text

def main() -> None:
    for p in (STREAK, RANDOM_FIVE, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")
    for marker in [
        "sharedXiAnswerIds",
        "topGameplayClubs",
        "playersInPool",
        "playerClubIdsForPool",
    ]:
        if marker not in hybrid_text:
            raise SystemExit(f"[FAIL] Hybrid runtime method eksik: {marker}")

    originals = {
        STREAK: STREAK.read_text(encoding="utf-8"),
        RANDOM_FIVE: RANDOM_FIVE.read_text(encoding="utf-8"),
    }
    patched = {
        STREAK: patch_streak(originals[STREAK]),
        RANDOM_FIVE: patch_random_five(originals[RANDOM_FIVE]),
    }

    for p in (STREAK, RANDOM_FIVE):
        backup(p)
    for p in (STREAK, RANDOM_FIVE):
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print("[DONE] Step 04.2K Streak + Random Five installed.")
    print("[SAFE] Feature flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
