from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DAILY = ROOT / "lib/controllers/daily_challenge_controller.dart"
ENDLESS = ROOT / "lib/controllers/endless_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2m.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def add_import(text: str, anchor: str) -> str:
    if IMPORT_LINE in text:
        return text
    if anchor not in text:
        raise RuntimeError(f"import anchor bulunamadi: {anchor}")
    return text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

def patch_daily(text: str) -> str:
    if (
        "DailyChallenge SQLite" in text
        and "_runtimeMatchingPlayers" in text
        and "shared_xi_answer" in text
    ):
        return text

    for marker in [
        "import '../services/search_service.dart';",
        "Timer? _feedbackTimer;",
        "Future<void> initialize() async {",
        "final matchingPlayers = DailyChallengeService.qualityMatchingPlayers(",
    ]:
        if marker not in text:
            raise RuntimeError(f"Daily local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/search_service.dart';")

    text = text.replace(
        "  Timer? _feedbackTimer;",
        """  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
""",
        1,
    )

    initialize_marker = "  Future<void> initialize() async {"
    helpers = r"""  bool _runtimeMatchesEntity(
    Player player,
    MatchEntity entity,
  ) {
    switch (entity.type) {
      case MatchEntityType.club:
        final ids =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        return entity.clubId != null && ids.contains(entity.clubId);
      case MatchEntityType.country:
        return entity.countryName != null &&
            player.countries.contains(entity.countryName);
    }
  }

  Future<List<Player>> _runtimeMatchingPlayers(
    MatchEntity entity1,
    MatchEntity entity2,
  ) async {
    final hybrid = HybridGameplayDataService.instance;
    final players = await hybrid.playersInPool('shared_xi_answer');
    _runtimeClubIdsByPlayer =
        await hybrid.playerClubIdsForPool('shared_xi_answer');

    return players
        .where((p) => _runtimeMatchesEntity(p, entity1))
        .where((p) => _runtimeMatchesEntity(p, entity2))
        .toList();
  }

"""
    text = text.replace(initialize_marker, helpers + initialize_marker, 1)

    old_matching = """    final matchingPlayers = DailyChallengeService.qualityMatchingPlayers(
      entity1: entity1,
      entity2: entity2,
    );"""
    new_matching = r"""    var matchingPlayers =
        DailyChallengeService.qualityMatchingPlayers(
      entity1: entity1,
      entity2: entity2,
    );

    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      final runtimeMatches =
          await _runtimeMatchingPlayers(entity1, entity2);

      if (runtimeMatches.length >= 3) {
        matchingPlayers = runtimeMatches;
        debugPrint(
          '[HybridV3] DailyChallenge SQLite '
          'answers=${matchingPlayers.length} '
          'pair=${entity1.displayName} x ${entity2.displayName}',
        );
      } else {
        _usingRuntimeV3 = false;
        debugPrint(
          '[HybridV3] DailyChallenge canonical answers too small '
          '(${runtimeMatches.length}); legacy fallback for fixture.',
        );
      }
    }"""
    if old_matching not in text:
        raise RuntimeError("Daily matching block bulunamadi")
    text = text.replace(old_matching, new_matching, 1)

    return text

def patch_endless(text: str) -> str:
    if (
        "Endless SQLite" in text
        and "_generateRuntimePair" in text
        and "_runtimePlayersByClub" in text
    ):
        return text

    for marker in [
        "import '../services/high_score_service.dart';",
        "Timer? _clockTimer;",
        "String get _highScoreKey =>",
        "Future<void> initialize() async {",
        "List<Club> _quizClubs() {",
        "_generatePair() {",
        "final matching = GameService.matchingPlayers(",
    ]:
        if marker not in text:
            raise RuntimeError(f"Endless local shape bulunamadi: {marker}")

    text = add_import(text, "import '../services/high_score_service.dart';")

    text = text.replace(
        "  Timer? _clockTimer;",
        """  Timer? _clockTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeQuizClubs = const [];
  List<Player> _runtimeAnswerPlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, List<Player>> _runtimePlayersByClub = const {};
""",
        1,
    )

    old_key = """  String get _highScoreKey => isBlitz
      ? 'endless_blitz_high_score'
      : 'endless_survival_high_score';"""
    new_key = r"""  String get _highScoreKey {
    if (_usingRuntimeV3) {
      return 'endless_${matchMode.name}_${gameStyle.name}_v3_best';
    }

    return isBlitz
        ? 'endless_blitz_high_score'
        : 'endless_survival_high_score';
  }"""
    if old_key not in text:
        raise RuntimeError("Endless high score key block bulunamadi")
    text = text.replace(old_key, new_key, 1)

    old_init = """  Future<void> initialize() async {
    final bestScore = await HighScoreService.getHighScore(key: _highScoreKey);

    _state = _state.copyWith(
      bestScore: bestScore,
      lives: isSurvival ? _survivalLives : 999,
      secondsLeft: isBlitz ? _blitzRoundSeconds : 0,
      skipsLeft: _initialSkips,
    );

    _startNewRound();
  }"""
    new_init = r"""  Future<void> initialize() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeQuizClubs = await hybrid.topGameplayClubs(limit: 120);
      _runtimeAnswerPlayers =
          await hybrid.playersInPool('shared_xi_answer');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('shared_xi_answer');

      final byClub = <int, List<Player>>{};
      for (final player in _runtimeAnswerPlayers) {
        final clubIds =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        for (final clubId in clubIds) {
          byClub.putIfAbsent(clubId, () => <Player>[]).add(player);
        }
      }
      _runtimePlayersByClub = {
        for (final e in byClub.entries)
          e.key: List<Player>.unmodifiable(e.value),
      };

      if (_runtimeQuizClubs.length < 20 ||
          _runtimeAnswerPlayers.length < 5000 ||
          _runtimePlayersByClub.length < 100) {
        debugPrint(
          '[HybridV3] Endless SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Endless SQLite '
          'mode=${matchMode.name} style=${gameStyle.name} '
          'clubs=${_runtimeQuizClubs.length} '
          'answers=${_runtimeAnswerPlayers.length}',
        );
      }
    }

    final bestScore =
        await HighScoreService.getHighScore(key: _highScoreKey);

    _state = _state.copyWith(
      bestScore: bestScore,
      lives: isSurvival ? _survivalLives : 999,
      secondsLeft: isBlitz ? _blitzRoundSeconds : 0,
      skipsLeft: _initialSkips,
    );

    _startNewRound();
  }"""
    if old_init not in text:
        raise RuntimeError("Endless initialize exact block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    text = text.replace(
        "  List<Club> _quizClubs() {",
        """  List<Club> _quizClubs() {
    if (_usingRuntimeV3 && _runtimeQuizClubs.length >= 2) {
      return List<Club>.from(_runtimeQuizClubs);
    }""",
        1,
    )

    pair_marker = """  ({MatchEntity entity1, MatchEntity entity2, List<Player> matching})
      _generatePair() {"""
    if pair_marker not in text:
        raise RuntimeError("Endless _generatePair signature bulunamadi")

    helpers = r"""  bool _runtimeMatchesEntity(
    Player player,
    MatchEntity entity,
  ) {
    switch (entity.type) {
      case MatchEntityType.club:
        final ids =
            _runtimeClubIdsByPlayer[player.id] ?? const <int>[];
        return entity.clubId != null && ids.contains(entity.clubId);
      case MatchEntityType.country:
        return entity.countryName != null &&
            player.countries.contains(entity.countryName);
    }
  }

  List<Player> _runtimeMatches(
    MatchEntity entity1,
    MatchEntity entity2,
  ) {
    Iterable<Player> source = _runtimeAnswerPlayers;

    if (entity1.type == MatchEntityType.club &&
        entity1.clubId != null) {
      source =
          _runtimePlayersByClub[entity1.clubId] ?? const <Player>[];
    } else if (entity2.type == MatchEntityType.club &&
        entity2.clubId != null) {
      source =
          _runtimePlayersByClub[entity2.clubId] ?? const <Player>[];
    }

    return source
        .where((p) => _runtimeMatchesEntity(p, entity1))
        .where((p) => _runtimeMatchesEntity(p, entity2))
        .toList();
  }

  ({MatchEntity entity1, MatchEntity entity2, List<Player> matching})
      _generateRuntimePair() {
    final clubs = _quizClubs();
    final countries = _quizCountries();

    var bestEntity1 = MatchEntity.club(clubs[0]);
    var bestEntity2 =
        MatchEntity.club(clubs.length > 1 ? clubs[1] : clubs[0]);
    var bestMatching = <Player>[];

    for (var attempt = 0; attempt < _maxPickAttempts; attempt++) {
      final club1 = clubs[_random.nextInt(clubs.length)];
      final entity1 = MatchEntity.club(club1);

      final useCountry = matchMode == EndlessMatchMode.clubCountry;
      final MatchEntity entity2;

      if (useCountry && countries.isNotEmpty) {
        entity2 = MatchEntity.country(
          countries[_random.nextInt(countries.length)],
        );
      } else {
        final others = clubs
            .where((c) => c.id != club1.id)
            .toList()
          ..shuffle(_random);

        Club? club2;
        for (final c in others) {
          if (c.league.trim().isNotEmpty &&
              club1.league.trim().isNotEmpty &&
              c.league != club1.league) {
            club2 = c;
            break;
          }
        }
        club2 ??= others.isNotEmpty ? others.first : club1;
        entity2 = MatchEntity.club(club2);
      }

      final matching = _runtimeMatches(entity1, entity2);

      if (matching.length > bestMatching.length) {
        bestEntity1 = entity1;
        bestEntity2 = entity2;
        bestMatching = matching;
      }

      if (matching.length >= _minPlayersPerRound) {
        return (
          entity1: entity1,
          entity2: entity2,
          matching: matching,
        );
      }
    }

    return (
      entity1: bestEntity1,
      entity2: bestEntity2,
      matching: bestMatching,
    );
  }

"""
    text = text.replace(pair_marker, helpers + pair_marker, 1)
    text = text.replace(
        pair_marker + "\n",
        pair_marker + """
    if (_usingRuntimeV3) {
      return _generateRuntimePair();
    }
""",
        1,
    )

    old_extra = """      final extra = SearchService.suggestions(
        players: Repository.instance.players,
        query: query,
        excludedPlayerIds: _state.foundPlayerIds,
      );"""
    if old_extra in text:
        text = text.replace(
            old_extra,
            """      final extra = SearchService.suggestions(
        players: _usingRuntimeV3
            ? _runtimeAnswerPlayers
            : Repository.instance.players,
        query: query,
        excludedPlayerIds: _state.foundPlayerIds,
      );""",
            1,
        )

    old_resolve = """    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.foundPlayerIds,
    );"""
    if old_resolve in text:
        text = text.replace(
            old_resolve,
            """    final resolved = SearchService.resolve(
      players: _usingRuntimeV3
          ? _runtimeAnswerPlayers
          : Repository.instance.players,
      answer: answer,
      excludedPlayerIds: _state.foundPlayerIds,
    );""",
            1,
        )

    for marker in [
        "_runtimeQuizClubs",
        "_runtimeAnswerPlayers",
        "_runtimeClubIdsByPlayer",
        "_runtimePlayersByClub",
        "_generateRuntimePair",
        "endless_${matchMode.name}_${gameStyle.name}_v3_best",
        "[HybridV3] Endless SQLite",
    ]:
        if marker not in text:
            raise RuntimeError(f"Endless final marker eksik: {marker}")

    return text

def main() -> None:
    for p in (DAILY, ENDLESS, HYBRID):
        if not p.exists():
            raise SystemExit(f"[FAIL] Eksik gerekli dosya: {p}")

    hybrid_text = HYBRID.read_text(encoding="utf-8")
    for marker in ["playersInPool", "playerClubIdsForPool", "topGameplayClubs"]:
        if marker not in hybrid_text:
            raise SystemExit(f"[FAIL] Hybrid runtime method eksik: {marker}")

    originals = {
        DAILY: DAILY.read_text(encoding="utf-8"),
        ENDLESS: ENDLESS.read_text(encoding="utf-8"),
    }

    patched = {
        DAILY: patch_daily(originals[DAILY]),
        ENDLESS: patch_endless(originals[ENDLESS]),
    }

    for p in (DAILY, ENDLESS):
        backup(p)
    for p in (DAILY, ENDLESS):
        p.write_text(patched[p], encoding="utf-8")
        print(f"[OK] patched {p.relative_to(ROOT)}")

    print("[DONE] Step 04.2M Daily answer authority + Endless installed.")
    print("[NOTE] Daily scheduling/leaderboard backend authority is not changed here.")

if __name__ == "__main__":
    main()
