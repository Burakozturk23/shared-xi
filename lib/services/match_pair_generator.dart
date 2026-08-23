import 'dart:math';

import '../models/match_pair_models.dart';
import '../repositories/repository.dart';

class MatchPairGenerator {
  MatchPairGenerator._();
  static final _rng = Random();

  /// Bilinen lig anahtarları (club.league fuzzy).
  static const _majorLeagueKeys = [
    'premier league',
    'la liga',
    'laliga',
    'serie a',
    'bundesliga',
    'ligue 1',
    'süper lig',
    'super lig',
    'eredivisie',
    'primeira liga',
    'liga portugal',
    'championship',
    'segunda',
    'serie b',
    '2. bundesliga',
    'ligue 2',
    'tff 1',
    'superliga',
    'scottish',
    'belgian',
    'jupiler',
    'ekstraklasa',
  ];

  /// Açıkça istenmeyen (U21, academy, reserve vb.).
  static final _junkClub = RegExp(
    r'u\s*1[89]|u\s*2[01]|u21|u23|academy|youth|reserve|ii$|\sb$|amator|amateur|women|wfc|ladies',
    caseSensitive: false,
  );

  static bool _isMajorLeague(String league) {
    final L = league.toLowerCase().trim();
    if (L.isEmpty) return false;
    for (final k in _majorLeagueKeys) {
      if (L.contains(k)) return true;
    }
    return false;
  }

  static bool _isSaneClubName(String name) {
    final n = name.trim();
    if (n.length < 3) return false;
    if (_junkClub.hasMatch(n)) return false;
    return true;
  }

  static MatchBoard generate({
    MatchDifficulty difficulty = MatchDifficulty.medium,
    int? pairCount,
  }) {
    final n = pairCount ?? difficulty.pairCount;
    final repo = Repository.instance;
    final (minV, maxV) = difficulty.valueRange;

    var players = repo.players.where((p) {
      final v = p.peakMarketValue;
      return v >= minV &&
          v < maxV &&
          p.clubs.isNotEmpty &&
          p.name.trim().isNotEmpty;
    }).toList();

    if (players.length < n * 2) {
      players = repo.players
          .where((p) => p.clubs.isNotEmpty && p.name.trim().isNotEmpty)
          .toList();
    }

    players.sort((a, b) {
      final c = b.peakMarketValue.compareTo(a.peakMarketValue);
      return difficulty == MatchDifficulty.hard ? -c : c;
    });

    // Kulüp → oyuncular (sadece makul kulüpler)
    final byClub = <int, List<int>>{};
    for (final p in players) {
      for (final cid in p.clubs) {
        final club = repo.clubById(cid);
        if (club == null) continue;
        if (!_isSaneClubName(club.name)) continue;
        (byClub[cid] ??= []).add(p.id);
      }
    }

    // Önce büyük lig + çok oyunculu kulüpler
    int scoreClub(int cid) {
      final club = repo.clubById(cid);
      if (club == null) return -1;
      var s = byClub[cid]?.length ?? 0;
      if (_isMajorLeague(club.league)) s += 100;
      // isimde ülke ligi ipucu
      final ln = club.name.toLowerCase();
      if (ln.contains('fc') ||
          ln.contains('united') ||
          ln.contains('city') ||
          ln.contains('real') ||
          ln.contains('inter') ||
          ln.contains('milan') ||
          ln.contains('spor')) {
        s += 5;
      }
      return s;
    }

    var clubIds = byClub.keys.toList();
    // En az 2 oyuncu olanlar tercih
    clubIds = clubIds.where((id) => (byClub[id]?.length ?? 0) >= 1).toList();
    clubIds.sort((a, b) => scoreClub(b).compareTo(scoreClub(a)));

    // Üst kaliteyi al, sonra karıştır (hep aynı 12 kulüp gelmesin)
    final top = clubIds.take(min(80, clubIds.length)).toList()..shuffle(_rng);

    final pairs = <MatchCard>[];
    final usedPlayers = <int>{};
    var pairId = 0;

    for (final cid in top) {
      if (pairId >= n) break;
      final club = repo.clubById(cid);
      if (club == null || !_isSaneClubName(club.name)) continue;

      // Büyük lig yoksa ve yeterince çift varsa atla (son çarede kullan)
      if (pairId < n - 2 && !_isMajorLeague(club.league)) {
        // orta/hard'da daha toleranslı
        if (difficulty == MatchDifficulty.easy) continue;
      }

      final pids = byClub[cid]!
          .where((id) => !usedPlayers.contains(id))
          .toList();
      if (pids.isEmpty) continue;

      pids.sort((a, b) {
        final pa = repo.playerById(a)?.peakMarketValue ?? 0;
        final pb = repo.playerById(b)?.peakMarketValue ?? 0;
        final c = pb.compareTo(pa);
        return difficulty == MatchDifficulty.hard ? -c : c;
      });

      final player = repo.playerById(pids.first);
      if (player == null) continue;

      usedPlayers.add(player.id);
      pairs.add(MatchCard(
        id: 'c_${pairId}_$cid',
        pairId: pairId,
        kind: MatchCardKind.club,
        label: club.name,
        clubId: cid,
      ));
      pairs.add(MatchCard(
        id: 'p_${pairId}_${player.id}',
        pairId: pairId,
        kind: MatchCardKind.player,
        label: player.name,
        playerId: player.id,
        clubId: cid,
      ));
      pairId++;
    }

    // Hâlâ eksikse büyük lig şartını gevşet
    if (pairId < n) {
      for (final cid in clubIds) {
        if (pairId >= n) break;
        if (pairs.any((c) => c.clubId == cid && c.kind == MatchCardKind.club)) {
          continue;
        }
        final club = repo.clubById(cid);
        if (club == null || !_isSaneClubName(club.name)) continue;
        final pids = byClub[cid]!
            .where((id) => !usedPlayers.contains(id))
            .toList();
        if (pids.isEmpty) continue;
        pids.sort((a, b) => (repo.playerById(b)?.peakMarketValue ?? 0)
            .compareTo(repo.playerById(a)?.peakMarketValue ?? 0));
        final player = repo.playerById(pids.first);
        if (player == null) continue;
        usedPlayers.add(player.id);
        pairs.add(MatchCard(
          id: 'c_${pairId}_$cid',
          pairId: pairId,
          kind: MatchCardKind.club,
          label: club.name,
          clubId: cid,
        ));
        pairs.add(MatchCard(
          id: 'p_${pairId}_${player.id}',
          pairId: pairId,
          kind: MatchCardKind.player,
          label: player.name,
          playerId: player.id,
          clubId: cid,
        ));
        pairId++;
      }
    }

    if (pairs.length < 4) {
      return _fallback(n, difficulty);
    }

    final cards = List<MatchCard>.from(pairs)..shuffle(_rng);
    return MatchBoard(
      cards: cards,
      pairCount: pairs.length ~/ 2,
      difficulty: difficulty,
    );
  }

  static MatchBoard _fallback(int n, MatchDifficulty difficulty) {
    final count = n.clamp(2, 12);
    final cards = <MatchCard>[];
    for (var i = 0; i < count; i++) {
      cards.add(MatchCard(
        id: 'fc_$i',
        pairId: i,
        kind: MatchCardKind.club,
        label: 'Kulüp $i',
      ));
      cards.add(MatchCard(
        id: 'fp_$i',
        pairId: i,
        kind: MatchCardKind.player,
        label: 'Oyuncu $i',
      ));
    }
    cards.shuffle(_rng);
    return MatchBoard(
      cards: cards,
      pairCount: count,
      difficulty: difficulty,
    );
  }
}
