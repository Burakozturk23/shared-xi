import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/cinko_models.dart';
import '../models/cinko_state.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import '../data/cinko_pool.dart';
import '../services/search_service.dart';

enum VsBotCinkoTurn { user, bot, gameOver }

/// Ortak çinko tahtası; sıra sıra kullanıcı ve bot boyar.
class VsBotCinkoController extends ChangeNotifier {
  static const int defaultGrid = 5;
  static const int revealMs = 1000;

  final int gridSize;
  final Random _random = Random();

  VsBotCinkoController({this.gridSize = defaultGrid});

  CinkoState _state = const CinkoState();
  CinkoState get state => _state;

  List<Player> suggestions = const [];

  VsBotCinkoTurn turn = VsBotCinkoTurn.user;
  int userScore = 0;
  int botScore = 0;
  String? lastBotInfo;

  Timer? _revealTimer;
  Timer? _feedbackTimer;
  Timer? _botTimer;
  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    _state = _state.copyWith(isLoading: true);
    _safeNotify();
    final cells = _buildGrid();
    userScore = 0;
    botScore = 0;
    turn = VsBotCinkoTurn.user;
    lastBotInfo = null;
    _state = _state.copyWith(
      cells: cells,
      isLoading: false,
      phase: CinkoPhase.enterPlayer,
      score: 0,
      usedPlayerIds: const {},
      clearPlayer: true,
      clearFeedback: true,
    );
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _revealTimer?.cancel();
    _feedbackTimer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  List<CinkoCell> _buildGrid() {
    final n = gridSize * gridSize;

    // Sadece bilinen kulüpler (chain pool)
    final clubs = cinkoFamousClubIds
        .map((id) => Repository.instance.clubById(id))
        .whereType<Club>()
        .toList()
      ..shuffle(_random);

    // Ülkeler: bilinen milli takımlar ∩ veritabanı
    final countrySet = {
      for (final c in Repository.instance.countries) c.toLowerCase(),
    };
    final countries = cinkoFamousCountries
        .where((c) => countrySet.contains(c.toLowerCase()))
        .toList()
      ..shuffle(_random);
    // DB isimleriyle eşleşen gerçek label'ları kullan
    final countryLabels = <String>[];
    for (final want in countries) {
      for (final real in Repository.instance.countries) {
        if (real.toLowerCase() == want.toLowerCase()) {
          countryLabels.add(real);
          break;
        }
      }
    }

    // Ligler: sadece ünlü lig isimleri
    final allLeagues = Repository.instance.clubs
        .map((c) => c.league)
        .where((l) => l.trim().isNotEmpty)
        .toSet();
    final leagues = <String>[];
    for (final famous in cinkoFamousLeagues) {
      for (final real in allLeagues) {
        if (real.toLowerCase() == famous.toLowerCase() ||
            real.toLowerCase().contains(famous.toLowerCase()) ||
            famous.toLowerCase().contains(real.toLowerCase())) {
          if (!leagues.contains(real)) leagues.add(real);
        }
      }
    }
    leagues.shuffle(_random);

    // ~%70 kulüp, ~%15 ülke, ~%15 lig
    final clubCount = (n * 0.70).round().clamp(1, clubs.length);
    final countryCount =
        (n * 0.15).round().clamp(0, countryLabels.length);
    var leagueCount = n - clubCount - countryCount;
    if (leagueCount > leagues.length) leagueCount = leagues.length;
    if (leagueCount < 0) leagueCount = 0;

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
    for (var i = 0; i < countryCount && i < countryLabels.length; i++) {
      addCountry(countryLabels[i]);
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

  bool _playerMatchesCell(Player player, CinkoCell cell) {
    switch (cell.type) {
      case CinkoCellType.club:
        return cell.clubId != null && player.clubs.contains(cell.clubId);
      case CinkoCellType.country:
        return player.countries.any(
          (c) => c.toLowerCase() == cell.label.toLowerCase(),
        );
      case CinkoCellType.league:
        for (final clubId in player.clubs) {
          final club = Repository.instance.clubById(clubId);
          if (club != null &&
              club.league.toLowerCase() == cell.label.toLowerCase()) {
            return true;
          }
        }
        return false;
    }
  }


  int get _gs => _state.gridSize;

  List<int> _orthoNeighbors(int index) {
    final size = _gs;
    final r = index ~/ size;
    final c = index % size;
    final out = <int>[];
    if (r > 0) out.add((r - 1) * size + c);
    if (r < size - 1) out.add((r + 1) * size + c);
    if (c > 0) out.add(r * size + (c - 1));
    if (c < size - 1) out.add(r * size + (c + 1));
    return out;
  }

  /// 4-yön bağlantı (çapraz yok). L şekli ve düz çizgi geçerli.
  bool _isOrthoConnected(List<int> indexes) {
    if (indexes.length <= 1) return true;
    final set = indexes.toSet();
    final visited = <int>{};
    final queue = <int>[indexes.first];
    visited.add(indexes.first);
    while (queue.isNotEmpty) {
      final i = queue.removeAt(0);
      for (final n in _orthoNeighbors(i)) {
        if (set.contains(n) && visited.add(n)) {
          queue.add(n);
        }
      }
    }
    return visited.length == set.length;
  }

  List<int> _selectedIndexes() {
    final out = <int>[];
    for (var i = 0; i < _state.cells.length; i++) {
      if (_state.cells[i].status == CinkoCellStatus.selected) out.add(i);
    }
    return out;
  }

  /// En büyük bağlı bileşeni bul (bot için).
  List<int> _largestConnectedComponent(List<int> indexes) {
    if (indexes.isEmpty) return const [];
    final set = indexes.toSet();
    final remaining = set.toSet();
    List<int> best = const [];
    while (remaining.isNotEmpty) {
      final start = remaining.first;
      final comp = <int>[];
      final queue = <int>[start];
      remaining.remove(start);
      while (queue.isNotEmpty) {
        final i = queue.removeAt(0);
        comp.add(i);
        for (final n in _orthoNeighbors(i)) {
          if (remaining.remove(n)) queue.add(n);
        }
      }
      if (comp.length > best.length) best = comp;
    }
    return best;
  }

  
  void updateSuggestions(String query) {
    if (_disposed || turn != VsBotCinkoTurn.user) {
      suggestions = const [];
      _safeNotify();
      return;
    }
    suggestions = SearchService.suggestions(
      players: Repository.instance.players,
      query: query,
      excludedPlayerIds: _state.usedPlayerIds,
    );
    _safeNotify();
  }

  void clearSuggestions() {
    if (suggestions.isEmpty) return;
    suggestions = const [];
    _safeNotify();
  }

  /// Listeden seçilen oyuncu — isimle tekrar resolve etme.
  void submitResolvedPlayer(Player player) {
    suggestions = const [];
    _acceptPlayer(player);
  }

  void submitPlayerName(String raw) {
    if (_disposed || turn != VsBotCinkoTurn.user) return;
    if (_state.phase != CinkoPhase.enterPlayer) return;

    final name = raw.trim();
    if (name.isEmpty) return;

    final resolved = SearchService.resolve(
      players: Repository.instance.players,
      answer: name,
      excludedPlayerIds: _state.usedPlayerIds,
    );

    if (resolved.status == ResolveStatus.ambiguous) {
      suggestions = resolved.candidates;
      _feedback(resolved.message, false);
      _safeNotify();
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
    if (_disposed || turn != VsBotCinkoTurn.user) return;
    if (_state.phase != CinkoPhase.enterPlayer) return;

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
    _safeNotify();
  }

  void toggleCell(int index) {
    if (_disposed || turn != VsBotCinkoTurn.user) return;
    if (_state.phase != CinkoPhase.selecting) return;
    if (index < 0 || index >= _state.cells.length) return;

    final cell = _state.cells[index];
    if (cell.status == CinkoCellStatus.correct) return;
    if (cell.status == CinkoCellStatus.wrongFlash) return;

    final cells = List<CinkoCell>.from(_state.cells);
    if (cell.status == CinkoCellStatus.selected) {
      // Kaldırınca kalan seçim bağlı kalmalı
      cells[index] = cell.copyWith(status: CinkoCellStatus.open);
      final remaining = <int>[];
      for (var i = 0; i < cells.length; i++) {
        if (cells[i].status == CinkoCellStatus.selected) remaining.add(i);
      }
      if (!_isOrthoConnected(remaining)) {
        _feedback('Seçim bağlantısı bozulur, önce uçları kaldır.', false);
        return;
      }
    } else if (cell.status == CinkoCellStatus.open) {
      final selected = _selectedIndexes();
      if (selected.isNotEmpty) {
        final touches = selected.any((s) => _orthoNeighbors(s).contains(index));
        if (!touches) {
          _feedback(
            'Kutu seçime komşu olmalı (yan / üst-alt). Çapraz yok.',
            false,
          );
          return;
        }
      }
      cells[index] = cell.copyWith(status: CinkoCellStatus.selected);
    }

    _state = _state.copyWith(cells: cells);
    _safeNotify();
  }

  void cancelSelection() {
    if (_disposed || turn != VsBotCinkoTurn.user) return;
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
    _safeNotify();
  }

  void confirmSelection() {
    if (_disposed || turn != VsBotCinkoTurn.user) return;
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

    if (!_isOrthoConnected(selectedIndexes)) {
      _feedback(
        'Seçimler birbirine bağlı olmalı (yan / üst-alt, L olur; çapraz yok).',
        false,
      );
      return;
    }

    _applySelection(player, selectedIndexes, byUser: true);
  }

  void _applySelection(Player player, List<int> selectedIndexes,
      {required bool byUser}) {
    var delta = 0;
    final cells = List<CinkoCell>.from(_state.cells);

    for (final i in selectedIndexes) {
      final cell = cells[i];
      final ok = _playerMatchesCell(player, cell);
      if (ok) {
        cells[i] = cell.copyWith(
          status: CinkoCellStatus.correct,
          owner: byUser ? 1 : 2,
        );
        delta += 1;
      } else {
        cells[i] = cell.copyWith(status: CinkoCellStatus.wrongFlash);
        delta -= 1;
      }
    }

    final used = Set<int>.from(_state.usedPlayerIds)..add(player.id);

    if (byUser) {
      userScore += delta;
    } else {
      botScore += delta;
      lastBotInfo = '${player.name}: ${delta >= 0 ? '+$delta' : '$delta'}';
    }

    final msg = byUser
        ? (delta >= 0 ? '+$delta puan' : '$delta puan')
        : 'Bot: ${player.name} (${delta >= 0 ? '+$delta' : '$delta'})';

    _state = _state.copyWith(
      cells: cells,
      usedPlayerIds: used,
      phase: CinkoPhase.revealing,
      feedback: msg,
      feedbackIsSuccess: delta >= 0,
      clearPlayer: true,
    );
    _safeNotify();

    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: revealMs), () {
      _finishReveal(byUser: byUser);
    });
  }

  void _finishReveal({required bool byUser}) {
    if (_disposed) return;

    final cells = _state.cells.map((c) {
      if (c.status == CinkoCellStatus.wrongFlash) {
        return c.copyWith(status: CinkoCellStatus.open);
      }
      return c;
    }).toList();

    final done = cells.every((c) => c.status == CinkoCellStatus.correct);

    if (done) {
      turn = VsBotCinkoTurn.gameOver;
      _state = _state.copyWith(
        cells: cells,
        phase: CinkoPhase.gameOver,
        clearFeedback: true,
      );
      _safeNotify();
      return;
    }

    _state = _state.copyWith(
      cells: cells,
      phase: CinkoPhase.enterPlayer,
      clearFeedback: true,
    );

    if (byUser) {
      turn = VsBotCinkoTurn.bot;
      _safeNotify();
      _botTimer?.cancel();
      _botTimer = Timer(
        Duration(milliseconds: 800 + _random.nextInt(700)),
        _botPlay,
      );
    } else {
      turn = VsBotCinkoTurn.user;
      lastBotInfo = null;
      _safeNotify();
    }
  }

  void _botPlay() {
    if (_disposed || turn != VsBotCinkoTurn.bot) return;

    final openIndexes = <int>[];
    for (var i = 0; i < _state.cells.length; i++) {
      if (_state.cells[i].status == CinkoCellStatus.open) openIndexes.add(i);
    }
    if (openIndexes.isEmpty) {
      turn = VsBotCinkoTurn.gameOver;
      _state = _state.copyWith(phase: CinkoPhase.gameOver);
      _safeNotify();
      return;
    }

    // En çok açık kutu boyayan oyuncuyu bul
    Player? bestPlayer;
    List<int> bestIndexes = [];
    var bestCount = 0;

    final used = _state.usedPlayerIds;
    final candidates = Repository.instance.players
        .where((p) => !used.contains(p.id))
        .toList()
      ..shuffle(_random);

    // Performans: ilk 400 aday yeterli
    final sample = candidates.take(400).toList();
    for (final p in sample) {
      final matches = <int>[];
      for (final i in openIndexes) {
        if (_playerMatchesCell(p, _state.cells[i])) matches.add(i);
      }
      if (matches.length > bestCount) {
        bestCount = matches.length;
        bestPlayer = p;
        bestIndexes = matches;
        if (bestCount >= 4) break;
      }
    }

    if (bestPlayer == null || bestIndexes.isEmpty) {
      // Bot pas — kullanıcıya dön
      turn = VsBotCinkoTurn.user;
      lastBotInfo = 'Bot pas geçti';
      _feedback('Bot pas geçti.', true);
      return;
    }

    // Bot da sadece bağlı (4-yön) bir küme boyar
    final connected = _largestConnectedComponent(bestIndexes);
    if (connected.isEmpty) {
      turn = VsBotCinkoTurn.user;
      lastBotInfo = 'Bot pas geçti';
      _feedback('Bot pas geçti.', true);
      return;
    }

    _applySelection(bestPlayer, connected, byUser: false);
  }

  void restart() {
    _revealTimer?.cancel();
    _botTimer?.cancel();
    _feedbackTimer?.cancel();
    _state = const CinkoState();
    initialize();
  }

  void _feedback(String message, bool success) {
    _feedbackTimer?.cancel();
    _state = _state.copyWith(feedback: message, feedbackIsSuccess: success);
    _safeNotify();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_disposed) return;
      _state = _state.copyWith(clearFeedback: true);
      _safeNotify();
    });
  }
}