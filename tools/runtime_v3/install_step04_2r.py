from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CTRL = ROOT / "lib/controllers/mystery_player_controller.dart"
HYBRID = ROOT / "lib/services/runtime_v3/hybrid_gameplay_data_service.dart"

IMPORT_LINE = "import '../services/runtime_v3/hybrid_gameplay_data_service.dart';"

FINAL_MARKERS = [
    "_runtimePlayers",
    "_runtimeClubIdsByPlayer",
    "_runtimeFactsByPlayer",
    "_runtimeClubNameById",
    "playersInPool('normal_v3')",
    "playerClubIdsForPool('normal_v3')",
    "playerFactsForPool('normal_v3')",
    "_startRoundRuntime",
    "_runtimeStatsHint",
    "[HybridV3] MysteryPlayer SQLite",
]

def backup(path: Path) -> None:
    bak = path.with_suffix(path.suffix + ".step04_2r.bak")
    if not bak.exists():
        shutil.copy2(path, bak)

def main() -> None:
    if not CTRL.exists():
        raise SystemExit(f"[FAIL] Eksik: {CTRL}")
    if not HYBRID.exists():
        raise SystemExit("[FAIL] Hybrid Runtime V3 service yok.")

    original = CTRL.read_text(encoding="utf-8")
    text = original

    if all(marker in text for marker in FINAL_MARKERS):
        print("[PASS] Mystery Player already fully migrated.")
        return

    if any(marker in text for marker in FINAL_MARKERS):
        raise RuntimeError(
            "PARTIAL_04_2R: Mystery Player kismi migration durumunda. "
            "Otomatik ustune yazilmadi."
        )

    required = [
        "import '../services/search_service.dart';",
        "Timer? _feedbackTimer;",
        "void initialize() {",
        "void newRound() {",
        "void _startRound({required bool keepSession}) {",
        "String _valueBucket(double value) {",
        "List<String> _leagueNamesFor(Player p) {",
        "String? _starTeammateName(Player target) {",
        "List<MysteryHint> _buildHints(Player p) {",
        "void skip() {",
    ]
    for marker in required:
        if marker not in text:
            raise RuntimeError(f"Mystery Player local shape bulunamadi: {marker}")

    if IMPORT_LINE not in text:
        anchor = "import '../services/search_service.dart';"
        text = text.replace(anchor, anchor + "\n" + IMPORT_LINE, 1)

    text = text.replace(
        "  Timer? _feedbackTimer;",
        """  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Player> _runtimePlayers = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Map<int, Map<String, Object?>> _runtimeFactsByPlayer = const {};
  Map<int, String> _runtimeClubNameById = const {};
  Map<int, String> _runtimeLeagueByClubId = const {};
""",
        1,
    )

    old_init = """  void initialize() {
    _startRound(keepSession: false);
  }

  void newRound() {
    _startRound(keepSession: true);
  }"""

    new_init = r"""  void initialize() {
    unawaited(_initializeHybrid());
  }

  void newRound() {
    if (_usingRuntimeV3) {
      unawaited(_startRoundRuntime(keepSession: true));
    } else {
      _startRound(keepSession: true);
    }
  }

  Future<void> _initializeHybrid() async {
    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimePlayers = await hybrid.playersInPool('normal_v3');
      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');
      _runtimeFactsByPlayer =
          await hybrid.playerFactsForPool('normal_v3');

      final clubRows = await hybrid.existingGameplayClubMetadata();

      _runtimeClubNameById = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['name']?.toString().trim() ?? ''),
      };

      _runtimeLeagueByClubId = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['competition']?.toString().trim() ?? ''),
      };

      if (_runtimePlayers.length < 1000 ||
          _runtimeClubIdsByPlayer.length < 1000 ||
          _runtimeFactsByPlayer.length < 1000 ||
          _runtimeClubNameById.length < 100) {
        debugPrint(
          '[HybridV3] MysteryPlayer SQLite source too small; '
          'legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] MysteryPlayer SQLite '
          'players=${_runtimePlayers.length} '
          'facts=${_runtimeFactsByPlayer.length} '
          'clubs=${_runtimeClubNameById.length}',
        );
      }
    }

    if (_usingRuntimeV3) {
      await _startRoundRuntime(keepSession: false);
    } else {
      _startRound(keepSession: false);
    }
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  String _runtimePositionRaw(Player player) {
    if (!_usingRuntimeV3) return player.position;

    final row = _runtimeFactsByPlayer[player.id];
    final raw =
        row?['position_group']?.toString().trim() ?? '';

    return raw.isNotEmpty ? raw : player.position;
  }

  String _runtimeStatsHint(Player player) {
    if (!_usingRuntimeV3) {
      return 'Kariyer golü: ${player.careerGoals}';
    }

    final row = _runtimeFactsByPlayer[player.id];
    if (row == null) return 'Kapsanan istatistik sınırlı';

    final apps = (row['appearances'] as num?)?.toInt() ?? 0;
    final goals = (row['goals'] as num?)?.toInt() ?? 0;
    final assists = (row['assists'] as num?)?.toInt() ?? 0;

    return 'Kapsanan veri: $apps maç • $goals gol • $assists asist';
  }

  String _runtimeCoverageHint(Player player) {
    if (!_usingRuntimeV3) {
      final value = player.peakMarketValue > 0
          ? player.peakMarketValue
          : player.marketValue;
      return 'Piyasa değeri: ${_valueBucket(value)}';
    }

    final row = _runtimeFactsByPlayer[player.id];
    final first =
        (row?['coverage_first_year'] as num?)?.toInt() ?? 0;
    final last =
        (row?['coverage_last_year'] as num?)?.toInt() ?? 0;

    if (first <= 0 || last <= 0) {
      return 'Veri dönemi sınırlı';
    }

    return 'Kapsanan veri dönemi: $first-$last';
  }

  Future<void> _startRoundRuntime({
    required bool keepSession,
  }) async {
    final existingClubIds = _runtimeClubNameById.keys.toSet();

    final eligible = _runtimePlayers.where((player) {
      final clubs = _clubIdsForPlayer(player)
          .where(existingClubIds.contains)
          .toSet();
      return clubs.length >= 2;
    }).take(2200).toList();

    if (eligible.length < 100) {
      debugPrint(
        '[HybridV3] MysteryPlayer eligible pool too small; '
        'legacy fallback for round.',
      );
      _startRound(keepSession: keepSession);
      return;
    }

    final envelope =
        eligible.take(1600).toList()..shuffle(_random);
    final target = envelope[_random.nextInt(envelope.length)];

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
  }"""

    if old_init not in text:
        raise RuntimeError("Mystery Player initialize/newRound block bulunamadi")
    text = text.replace(old_init, new_init, 1)

    old_league = """  List<String> _leagueNamesFor(Player p) {
    final names = <String>{};
    for (final id in p.clubs) {
      final club = Repository.instance.clubById(id);
      final league = club?.league;
      if (league != null && league.trim().isNotEmpty) {
        names.add(league.trim());
      }
    }
    final list = names.toList()..sort();
    return list.take(4).toList();
  }"""

    new_league = r"""  List<String> _leagueNamesFor(Player p) {
    final names = <String>{};

    for (final id in _clubIdsForPlayer(p)) {
      final league = _usingRuntimeV3
          ? (_runtimeLeagueByClubId[id] ?? '')
          : (Repository.instance.clubById(id)?.league ?? '');

      if (league.trim().isNotEmpty) {
        names.add(league.trim());
      }
    }

    final list = names.toList()..sort();
    return list.take(4).toList();
  }"""

    if old_league not in text:
        raise RuntimeError("Mystery Player league helper bulunamadi")
    text = text.replace(old_league, new_league, 1)

    old_team = """  String? _starTeammateName(Player target) {
    final clubSet = target.clubs.toSet();
    Player? best;
    for (final p in Repository.instance.players) {
      if (p.id == target.id) continue;
      if (!p.clubs.any(clubSet.contains)) continue;
      if (best == null || p.peakMarketValue > best.peakMarketValue) {
        best = p;
      }
    }
    return best?.name;
  }"""

    new_team = r"""  String? _starTeammateName(Player target) {
    if (_usingRuntimeV3) {
      final clubSet = _clubIdsForPlayer(target).toSet();
      if (clubSet.isEmpty) return null;

      // normal_v3 is selectionRankV3 ordered.
      for (final player in _runtimePlayers) {
        if (player.id == target.id) continue;

        final clubs = _clubIdsForPlayer(player);
        if (clubs.any(clubSet.contains)) {
          return player.name;
        }
      }

      return null;
    }

    final clubSet = target.clubs.toSet();
    Player? best;

    for (final p in Repository.instance.players) {
      if (p.id == target.id) continue;
      if (!p.clubs.any(clubSet.contains)) continue;

      if (best == null ||
          p.peakMarketValue > best.peakMarketValue) {
        best = p;
      }
    }

    return best?.name;
  }"""

    if old_team not in text:
        raise RuntimeError("Mystery Player teammate helper bulunamadi")
    text = text.replace(old_team, new_team, 1)

    old_club_names = """    final clubNames = p.clubs
        .map((id) => Repository.instance.clubById(id)?.name)
        .whereType<String>()
        .toList();"""

    new_club_names = """    final clubIds = _clubIdsForPlayer(p);

    final clubNames = clubIds
        .map(
          (id) => _usingRuntimeV3
              ? (_runtimeClubNameById[id] ?? '')
              : (Repository.instance.clubById(id)?.name ?? ''),
        )
        .where((name) => name.isNotEmpty)
        .toList();"""

    if old_club_names not in text:
        raise RuntimeError("Mystery Player clubNames block bulunamadi")
    text = text.replace(old_club_names, new_club_names, 1)

    text = text.replace(
        "        text: _positionLabel(p.position),",
        "        text: _positionLabel(_runtimePositionRaw(p)),",
        1,
    )

    text = text.replace(
        "        text: '${p.clubs.length} farklı kulüpte forma giymiş',",
        "        text: '${clubIds.toSet().length} farklı kulüpte forma giymiş',",
        1,
    )

    text = text.replace(
        "        text: 'Kariyer golü: ${p.careerGoals}',",
        "        text: _runtimeStatsHint(p),",
        1,
    )

    old_market = """      MysteryHint(
        kind: MysteryHintKind.marketValue,
        title: 'Piyasa',
        text: 'Piyasa değeri: ${_valueBucket(p.peakMarketValue > 0 ? p.peakMarketValue : p.marketValue)}',
        cost: 15,
      ),"""

    new_market = """      MysteryHint(
        kind: MysteryHintKind.marketValue,
        title: _usingRuntimeV3 ? 'Veri dönemi' : 'Piyasa',
        text: _runtimeCoverageHint(p),
        cost: 15,
      ),"""

    if old_market not in text:
        raise RuntimeError("Mystery Player market hint block bulunamadi")
    text = text.replace(old_market, new_market, 1)

    old_skip = """    _state = _state.copyWith(streak: 0);
    _feedback('Pas geçildi — seri sıfırlandı.', false);
    _startRound(keepSession: true);
  }"""

    new_skip = """    _state = _state.copyWith(streak: 0);
    _feedback('Pas geçildi — seri sıfırlandı.', false);

    if (_usingRuntimeV3) {
      unawaited(_startRoundRuntime(keepSession: true));
    } else {
      _startRound(keepSession: true);
    }
  }"""

    if old_skip not in text:
        raise RuntimeError("Mystery Player skip block bulunamadi")
    text = text.replace(old_skip, new_skip, 1)

    old_resolve = """    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: answer,
    );"""

    new_resolve = """    final resolved = SearchService.resolve(
      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,
      answer: answer,
    );"""

    if old_resolve not in text:
        raise RuntimeError("Mystery Player resolve block bulunamadi")
    text = text.replace(old_resolve, new_resolve, 1)

    old_suggestions = """    return SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
    );"""

    new_suggestions = """    return SearchService.suggestions(
      players: _usingRuntimeV3
          ? _runtimePlayers
          : Repository.instance.players,
      query: query,
    );"""

    if old_suggestions not in text:
        raise RuntimeError("Mystery Player suggestions block bulunamadi")
    text = text.replace(old_suggestions, new_suggestions, 1)

    for marker in FINAL_MARKERS:
        if marker not in text:
            raise RuntimeError(f"Mystery Player final marker eksik: {marker}")

    backup(CTRL)
    CTRL.write_text(text, encoding="utf-8")

    print("[OK] patched lib/controllers/mystery_player_controller.dart")
    print("[DONE] Step 04.2R Mystery Player Runtime V3 installed.")
    print("[SAFE] Flag OFF keeps legacy behavior.")

if __name__ == "__main__":
    main()
