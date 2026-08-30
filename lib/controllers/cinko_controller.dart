import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cinko_models.dart';
import '../models/cinko_state.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../data/cinko_pool.dart';
import '../data/popular_clubs_pool.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../services/runtime_v3/hybrid_gameplay_data_service.dart';

class CinkoController extends ChangeNotifier {
  static const int defaultGrid = 5; // 5x5 = 25
  static const int revealMs = 1200;

  final int gridSize;
  final Random _random = Random();

  CinkoController({this.gridSize = defaultGrid});

  CinkoState _state = const CinkoState();
  CinkoState get state => _state;

  List<Player> suggestions = const [];

  Timer? _revealTimer;
  Timer? _feedbackTimer;

  bool _usingRuntimeV3 = false;
  List<Club> _runtimeClubPool = const [];
  Map<int, List<int>> _runtimeClubIdsByPlayer = const {};
  Set<int> _runtimeAnswerPlayerIds = const {};
  Map<int, String> _runtimeLeagueByClubId = const {};


  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    final hybrid = HybridGameplayDataService.instance;
    _usingRuntimeV3 = hybrid.isGameplayEnabled;

    if (_usingRuntimeV3) {
      _runtimeClubPool = await hybrid.topGameplayClubs(limit: 160);

      final answerPlayers = await hybrid.playersInPool('grid_answer');
      _runtimeAnswerPlayerIds = answerPlayers.map((p) => p.id).toSet();

      _runtimeClubIdsByPlayer =
          await hybrid.playerClubIdsForPool('grid_answer');

      final clubRows = await hybrid.existingGameplayClubMetadata();
      _runtimeLeagueByClubId = {
        for (final row in clubRows)
          if ((row['exposed_club_id'] as num?) != null)
            (row['exposed_club_id'] as num).toInt():
                (row['competition']?.toString().trim() ?? ''),
      };

      if (_runtimeClubPool.length < 25 ||
          _runtimeAnswerPlayerIds.length < 5000 ||
          _runtimeClubIdsByPlayer.length < 5000) {
        debugPrint(
          '[HybridV3] Cinko SQLite pool too small; legacy fallback.',
        );
        _usingRuntimeV3 = false;
      } else {
        debugPrint(
          '[HybridV3] Cinko SQLite '
          'clubs=${_runtimeClubPool.length} '
          'answers=${_runtimeAnswerPlayerIds.length}',
        );
      }
    }

    final cells = _buildGrid();
    _state = _state.copyWith(
      cells: cells,
      isLoading: false,
      phase: CinkoPhase.enterPlayer,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  List<CinkoCell> _buildGrid() {
    final n = gridSize * gridSize;

    final clubs = _usingRuntimeV3
        ? List<Club>.from(_runtimeClubPool)
        : PopularClubs.resolveAll();

    final countries = List<String>.from(cinkoFamousCountries);

    final leagues = _usingRuntimeV3
        ? _runtimeLeagueByClubId.values
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
        : List<String>.from(cinkoFamousLeagues);

    clubs.shuffle(_random);
    countries.shuffle(_random);
    leagues.shuffle(_random);

    final clubCount = (n * 0.60).round().clamp(1, clubs.length);
    final countryCount = (n * 0.20).round().clamp(0, countries.length);
    var leagueCount = n - clubCount - countryCount;
    if (leagueCount > leagues.length) leagueCount = leagues.length;

    final cells = <CinkoCell>[];
    final usedLabels = <String>{};

    void addClub(Club c) {
      final key = 'club_${c.id}';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.club,
        label: c.name,
        logoUrl: c.logo,
        clubId: c.id,
      ));
    }

    void addCountry(String name) {
      final key = 'country_$name';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.country,
        label: name,
      ));
    }

    void addLeague(String name) {
      final key = 'league_$name';
      if (usedLabels.contains(key)) return;
      usedLabels.add(key);
      cells.add(CinkoCell(
        id: key,
        type: CinkoCellType.league,
        label: name,
      ));
    }

    for (var i = 0; i < clubCount && i < clubs.length; i++) {
      addClub(clubs[i]);
    }
    for (var i = 0; i < countryCount && i < countries.length; i++) {
      addCountry(countries[i]);
    }
    for (var i = 0; i < leagueCount && i < leagues.length; i++) {
      addLeague(leagues[i]);
    }

    var ci = clubCount;
    while (cells.length < n && ci < clubs.length) {
      addClub(clubs[ci]);
      ci++;
    }

    cells.shuffle(_random);
    return cells.take(n).toList();
  }

  List<int> _clubIdsForPlayer(Player player) {
    return _usingRuntimeV3
        ? (_runtimeClubIdsByPlayer[player.id] ?? const <int>[])
        : player.clubs;
  }

  bool _playerMatchesCell(Player player, CinkoCell cell) {
    switch (cell.type) {
      case CinkoCellType.club:
        return cell.clubId != null &&
            _clubIdsForPlayer(player).contains(cell.clubId);
      case CinkoCellType.country:
        return player.countries.any(
          (c) => c.toLowerCase() == cell.label.toLowerCase(),
        );
      case CinkoCellType.league:
        for (final clubId in _clubIdsForPlayer(player)) {
          final league = _usingRuntimeV3
              ? (_runtimeLeagueByClubId[clubId] ?? '')
              : (Repository.instance.clubById(clubId)?.league ?? '');

          if (league.toLowerCase() == cell.label.toLowerCase()) {
            return true;
          }
        }
        return false;
    }
  }

  
  void updateSuggestions(String query) {
    if (_state.phase != CinkoPhase.enterPlayer) {
      suggestions = const [];
      notifyListeners();
      return;
    }
    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    suggestions = SearchService.suggestions(
      players: source,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );
    notifyListeners();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    notifyListeners();
  }

  /// Listeden seçilen oyuncu — isimle yeniden arama YAPMA (Luis Suárez vb.).
  void submitResolvedPlayer(Player player) {
    suggestions = const [];
    _acceptPlayer(player);
  }

  void submitPlayerName(String raw) {
    if (_state.phase != CinkoPhase.enterPlayer) return;

    final name = raw.trim();
    if (name.isEmpty) return;

    final source = _usingRuntimeV3
        ? Repository.instance.players
            .where((p) => _runtimeAnswerPlayerIds.contains(p.id))
            .toList()
        : Repository.instance.players;

    final resolved = SearchService.resolve(
      players: source,
      answer: name,
      excludedPlayerIds: _state.usedPlayerIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _feedback(resolved.message, false);
      notifyListeners();
      return;
    }
    if (!resolved.isFound) {
      suggestions = const [];
      _feedback('Oyuncu bulunamadı.', false);
      return;
    }

    suggestions = const [];
    _acceptPlayer(resolved.player!);
  }

  void _acceptPlayer(Player found) {
    if (_state.phase != CinkoPhase.enterPlayer) return;

    if (_usingRuntimeV3 &&
        !_runtimeAnswerPlayerIds.contains(found.id)) {
      _feedback('Bu oyuncu Çinko cevap havuzunda değil.', false);
      return;
    }

    if (_state.usedPlayerIds.contains(found.id)) {
      _feedback('Bu oyuncu daha önce kullanıldı.', false);
      return;
    }

    final hasMatch = _state.cells.any(
      (c) =>
          c.status == CinkoCellStatus.open && _playerMatchesCell(found, c),
    );
    if (!hasMatch) {
      _feedback('Bu oyuncunun bu ızgarada eşleşen kutusu yok.', false);
      return;
    }

    _state = _state.copyWith(
      currentPlayer: found,
      phase: CinkoPhase.selecting,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void toggleCell(int index) {
    if (_state.phase != CinkoPhase.selecting) return;
    if (index < 0 || index >= _state.cells.length) return;

    final cell = _state.cells[index];
    if (cell.status == CinkoCellStatus.correct) return;
    if (cell.status == CinkoCellStatus.wrongFlash) return;

    final cells = List<CinkoCell>.from(_state.cells);
    if (cell.status == CinkoCellStatus.selected) {
      cells[index] = cell.copyWith(status: CinkoCellStatus.open);
    } else if (cell.status == CinkoCellStatus.open) {
      cells[index] = cell.copyWith(status: CinkoCellStatus.selected);
    }

    _state = _state.copyWith(cells: cells);
    notifyListeners();
  }

  void cancelSelection() {
    if (_state.phase != CinkoPhase.selecting) return;

    final cells = _state.cells.map((c) {
      if (c.status == CinkoCellStatus.selected) {
        return c.copyWith(status: CinkoCellStatus.open);
      }
      return c;
    }).toList();

    _state = _state.copyWith(
      cells: cells,
      phase: CinkoPhase.enterPlayer,
      clearPlayer: true,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void confirmSelection() {
    if (_state.phase != CinkoPhase.selecting) return;
    final player = _state.currentPlayer;
    if (player == null) return;

    final selectedIndexes = <int>[];
    for (var i = 0; i < _state.cells.length; i++) {
      if (_state.cells[i].status == CinkoCellStatus.selected) {
        selectedIndexes.add(i);
      }
    }

    if (selectedIndexes.isEmpty) {
      _feedback('En az bir kutu seç.', false);
      return;
    }

    var delta = 0;
    final cells = List<CinkoCell>.from(_state.cells);

    for (final i in selectedIndexes) {
      final cell = cells[i];
      final ok = _playerMatchesCell(player, cell);
      if (ok) {
        cells[i] = cell.copyWith(status: CinkoCellStatus.correct);
        delta += 1;
      } else {
        cells[i] = cell.copyWith(status: CinkoCellStatus.wrongFlash);
        delta -= 1;
      }
    }

    final used = Set<int>.from(_state.usedPlayerIds)..add(player.id);
    final newScore = _state.score + delta;
    final msg = delta >= 0 ? '+$delta puan' : '$delta puan';

    _state = _state.copyWith(
      cells: cells,
      score: newScore,
      usedPlayerIds: used,
      phase: CinkoPhase.revealing,
      feedback: msg,
      feedbackIsSuccess: delta >= 0,
      clearPlayer: true,
    );
    notifyListeners();

    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: revealMs), () {
      _finishReveal();
    });
  }

  void _finishReveal() {
    final cells = _state.cells.map((c) {
      if (c.status == CinkoCellStatus.wrongFlash) {
        return c.copyWith(status: CinkoCellStatus.open);
      }
      return c;
    }).toList();

    final done = cells.every((c) => c.status == CinkoCellStatus.correct);

    _state = _state.copyWith(
      cells: cells,
      phase: done ? CinkoPhase.gameOver : CinkoPhase.enterPlayer,
      clearFeedback: true,
    );
    notifyListeners();
  }

  void restart() {
    _revealTimer?.cancel();
    _state = const CinkoState();
    initialize();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    notifyListeners();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      _state = _state.copyWith(clearFeedback: true);
      notifyListeners();
    });
  }
}