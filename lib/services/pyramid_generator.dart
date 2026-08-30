import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../models/player.dart';
import '../models/pyramid_models.dart';
import '../repositories/repository.dart';
import 'runtime_v3/hybrid_gameplay_data_service.dart';

/// Her turda Repository'den rastgele zirve + taban üretir.
class PyramidGenerator {
  PyramidGenerator._();

  static final _rng = Random();
  static final _slots = PyramidGeometry.buildSlots();

  static PyramidBoard generate({
    PyramidDifficulty difficulty = PyramidDifficulty.normal,
  }) {
    final repo = Repository.instance;
    final players = repo.players;
    if (players.isEmpty) {
      return _fallback(difficulty);
    }

    // Zirve: en az 2 kulüplü, bilinen oyuncu tercihi
    final candidates = players
        .where((p) => p.clubs.length >= 2 && p.name.trim().isNotEmpty)
        .toList();
    final pool = candidates.isNotEmpty ? candidates : players;
    // popülerliğe hafif bias: peakMarketValue
    pool.sort((a, b) => b.peakMarketValue.compareTo(a.peakMarketValue));
    final topN = pool.take(min(400, pool.length)).toList();
    final peakPlayer = topN[_rng.nextInt(topN.length)];

    final peak = _fromPlayer(peakPlayer);

    // Aynı kulüplerde oynamışlar
    final clubSet = peakPlayer.clubs.toSet();
    final teammates = players
        .where((p) =>
            p.id != peakPlayer.id &&
            p.clubs.any(clubSet.contains) &&
            p.name.trim().isNotEmpty)
        .toList()
      ..shuffle(_rng);

    final baseEntities = <PyramidEntity>[];

    // 1–2 takım arkadaşı
    for (final t in teammates.take(3)) {
      baseEntities.add(_fromPlayer(t));
      if (baseEntities.length >= 2) break;
    }

    // 1 milliyet
    if (peakPlayer.countries.isNotEmpty) {
      final cName = peakPlayer.countries.first;
      baseEntities.add(PyramidEntity(
        id: 'country_${PyramidEntity.normalize(cName)}',
        type: PyramidNodeType.country,
        name: cName,
        countries: [cName],
      ));
    }

    // 1–2 kulüp entity
    for (final cid in peakPlayer.clubs.take(2)) {
      final club = repo.clubById(cid);
      if (club == null) continue;
      baseEntities.add(_fromClub(club));
      if (baseEntities.where((e) => e.type == PyramidNodeType.club).length >=
          2) {
        break;
      }
    }

    // 5'e tamamla
    var i = 0;
    while (baseEntities.length < 5 && i < teammates.length) {
      final t = teammates[i++];
      if (baseEntities.any((e) => e.id == 'player_${t.id}')) continue;
      baseEntities.add(_fromPlayer(t));
    }
    while (baseEntities.length < 5) {
      // dolgu: zirve ülkesi tekrarı olmasın diye rastgele başka teammate yoksa peak country
      baseEntities.add(peak);
    }
    final base = baseEntities.take(5).toList();

    // Cevap havuzu: teammate + kulüpler + ülkeler + ekstra
    final answerPool = <PyramidEntity>[];
    final seen = <String>{};
    void add(PyramidEntity e) {
      if (seen.add(e.id)) answerPool.add(e);
    }

    add(peak);
    for (final e in base) {
      add(e);
    }
    for (final t in teammates.take(40)) {
      add(_fromPlayer(t));
    }
    for (final cid in clubSet) {
      final club = repo.clubById(cid);
      if (club != null) add(_fromClub(club));
    }
    for (final c in peakPlayer.countries) {
      add(PyramidEntity(
        id: 'country_${PyramidEntity.normalize(c)}',
        type: PyramidNodeType.country,
        name: c,
        countries: [c],
      ));
    }

    final filled = <int, PyramidEntity>{0: peak};
    const baseStart = 10; // 1+2+3+4
    for (var j = 0; j < 5; j++) {
      filled[baseStart + j] = base[j];
    }

    return PyramidBoard(
      id: 'gen_${peakPlayer.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Pyramid', // sabit isimli ağ yok
      difficulty: difficulty,
      slots: _slots,
      initialFilled: filled,
      answerPool: answerPool,
    );
  }

  static PyramidEntity _fromPlayer(Player p) => PyramidEntity(
        id: 'player_${p.id}',
        type: PyramidNodeType.player,
        name: p.name,
        clubIds: List<int>.from(p.clubs),
        countries: List<String>.from(p.countries),
      );

  static PyramidEntity _fromClub(Club c) => PyramidEntity(
        id: 'club_${c.id}',
        type: PyramidNodeType.club,
        name: c.name,
        clubIds: [c.id],
      );

  static PyramidBoard _fallback(PyramidDifficulty d) {
    final peak = const PyramidEntity(
      id: 'fallback_peak',
      type: PyramidNodeType.player,
      name: 'Örnek Oyuncu',
      clubIds: [1],
      countries: ['Türkiye'],
    );
    final base = List.generate(
      5,
      (i) => PyramidEntity(
        id: 'fallback_$i',
        type: PyramidNodeType.player,
        name: 'Aday $i',
        clubIds: [1],
      ),
    );
    final filled = <int, PyramidEntity>{0: peak};
    for (var i = 0; i < 5; i++) {
      filled[10 + i] = base[i];
    }
    return PyramidBoard(
      id: 'fallback',
      title: 'Pyramid',
      difficulty: d,
      slots: _slots,
      initialFilled: filled,
      answerPool: [peak, ...base],
    );
  }

  static PyramidEntity _fromRuntimePlayer(
    Player player,
    Map<int, List<int>> clubIdsByPlayer,
  ) {
    return PyramidEntity(
      id: 'player_${player.id}',
      type: PyramidNodeType.player,
      name: player.name,
      clubIds: List<int>.from(
        clubIdsByPlayer[player.id] ?? const <int>[],
      ),
      countries: List<String>.from(player.countries),
    );
  }

  static PyramidEntity _fromRuntimeClub({
    required int clubId,
    required String name,
  }) {
    return PyramidEntity(
      id: 'club_$clubId',
      type: PyramidNodeType.club,
      name: name,
      clubIds: [clubId],
    );
  }

  static Future<PyramidBoard?> generateRuntime({
    PyramidDifficulty difficulty = PyramidDifficulty.normal,
  }) async {
    final hybrid = HybridGameplayDataService.instance;
    if (!hybrid.isGameplayEnabled) return null;

    try {
      final orderedPlayers =
          await hybrid.playersInPool('normal_v3');
      final clubIdsByPlayer =
          await hybrid.playerClubIdsForPool('normal_v3');
      final clubRows =
          await hybrid.existingGameplayClubMetadata();

      if (orderedPlayers.length < 1000 ||
          clubIdsByPlayer.length < 1000 ||
          clubRows.length < 100) {
        debugPrint(
          '[HybridV3] Pyramid SQLite source too small; '
          'legacy fallback.',
        );
        return null;
      }

      final clubNameById = <int, String>{};

      for (final row in clubRows) {
        final rawId = row['exposed_club_id'] as num?;
        if (rawId == null) continue;

        final id = rawId.toInt();
        final name = row['name']?.toString().trim() ?? '';

        if (name.isEmpty) continue;
        if (name.toLowerCase().startsWith('club ')) continue;

        clubNameById[id] = name;
      }

      if (clubNameById.length < 100) {
        debugPrint(
          '[HybridV3] Pyramid SQLite mapped clubs too small; '
          'legacy fallback.',
        );
        return null;
      }

      final existingClubIds = clubNameById.keys.toSet();

      final playersByClub = <int, List<Player>>{};

      for (final player in orderedPlayers) {
        final clubIds =
            clubIdsByPlayer[player.id] ?? const <int>[];

        for (final clubId in clubIds) {
          if (!existingClubIds.contains(clubId)) continue;

          playersByClub
              .putIfAbsent(clubId, () => <Player>[])
              .add(player);
        }
      }

      final anchorClubIds = playersByClub.entries
          .where((e) => e.value.length >= 16)
          .map((e) => e.key)
          .toList();

      if (anchorClubIds.length < 10) {
        debugPrint(
          '[HybridV3] Pyramid SQLite anchor clubs too shallow; '
          'legacy fallback.',
        );
        return null;
      }

      final List<Player> rankWindow;

      switch (difficulty) {
        case PyramidDifficulty.easy:
          rankWindow =
              orderedPlayers.take(min(900, orderedPlayers.length)).toList();
          break;

        case PyramidDifficulty.normal:
          final skip = min(
            150,
            max(0, orderedPlayers.length - 300),
          );
          rankWindow = orderedPlayers
              .skip(skip)
              .take(min(1800, orderedPlayers.length - skip))
              .toList();
          break;

        case PyramidDifficulty.hard:
          final skip = min(
            700,
            max(0, orderedPlayers.length - 400),
          );
          rankWindow = orderedPlayers
              .skip(skip)
              .take(min(3200, orderedPlayers.length - skip))
              .toList();
          break;
      }

      final anchorSet = anchorClubIds.toSet();

      final peakCandidates = rankWindow.where((player) {
        final clubs =
            clubIdsByPlayer[player.id] ?? const <int>[];

        return clubs.any(anchorSet.contains) &&
            player.name.trim().isNotEmpty;
      }).toList();

      if (peakCandidates.length < 40) {
        debugPrint(
          '[HybridV3] Pyramid SQLite peak pool too small; '
          'legacy fallback.',
        );
        return null;
      }

      final peakEnvelope = peakCandidates
          .take(min(280, peakCandidates.length))
          .toList()
        ..shuffle(_rng);

      Player? peakPlayer;
      int? anchorClubId;
      List<Player> anchorPlayers = const [];

      for (final candidate in peakEnvelope) {
        final candidateClubs =
            clubIdsByPlayer[candidate.id] ?? const <int>[];

        final deepClubs = candidateClubs
            .where(anchorSet.contains)
            .toList();

        if (deepClubs.isEmpty) continue;

        deepClubs.shuffle(_rng);

        for (final clubId in deepClubs) {
          final all =
              playersByClub[clubId] ?? const <Player>[];

          final others = all
              .where(
                (p) =>
                    p.id != candidate.id &&
                    p.name.trim().isNotEmpty,
              )
              .toList();

          if (others.length < 14) continue;

          peakPlayer = candidate;
          anchorClubId = clubId;
          anchorPlayers = others;
          break;
        }

        if (peakPlayer != null) break;
      }

      if (peakPlayer == null ||
          anchorClubId == null ||
          anchorPlayers.length < 14) {
        debugPrint(
          '[HybridV3] Pyramid SQLite could not resolve '
          'finishable anchor; legacy fallback.',
        );
        return null;
      }

      final peak = _fromRuntimePlayer(
        peakPlayer,
        clubIdsByPlayer,
      );

      final int teammateEnvelope;

      switch (difficulty) {
        case PyramidDifficulty.easy:
          teammateEnvelope = min(18, anchorPlayers.length);
          break;
        case PyramidDifficulty.normal:
          teammateEnvelope = min(30, anchorPlayers.length);
          break;
        case PyramidDifficulty.hard:
          teammateEnvelope = anchorPlayers.length;
          break;
      }

      final teammatePool =
          anchorPlayers.take(teammateEnvelope).toList()
            ..shuffle(_rng);

      if (teammatePool.length < 13) {
        debugPrint(
          '[HybridV3] Pyramid SQLite teammate pool too small; '
          'legacy fallback.',
        );
        return null;
      }

      final anchorClub = _fromRuntimeClub(
        clubId: anchorClubId,
        name: clubNameById[anchorClubId]!,
      );

      final basePlayers = teammatePool.take(4).toList();

      if (basePlayers.length < 4) return null;

      final base = <PyramidEntity>[
        for (final p in basePlayers)
          _fromRuntimePlayer(p, clubIdsByPlayer),
        anchorClub,
      ];

      final initialUsedPlayerIds = <int>{
        peakPlayer.id,
        ...basePlayers.map((p) => p.id),
      };

      final answerPool = <PyramidEntity>[];
      final seen = <String>{};

      void add(PyramidEntity entity) {
        if (seen.add(entity.id)) answerPool.add(entity);
      }

      add(peak);
      for (final entity in base) {
        add(entity);
      }

      for (final player in teammatePool) {
        if (initialUsedPlayerIds.contains(player.id)) continue;
        add(_fromRuntimePlayer(player, clubIdsByPlayer));
      }

      for (final player in anchorPlayers) {
        if (initialUsedPlayerIds.contains(player.id)) continue;
        add(_fromRuntimePlayer(player, clubIdsByPlayer));
        if (answerPool.length >= 45) break;
      }

      add(anchorClub);

      for (final clubId
          in (clubIdsByPlayer[peakPlayer.id] ?? const <int>[])) {
        final name = clubNameById[clubId];
        if (name == null || name.isEmpty) continue;

        add(
          _fromRuntimeClub(
            clubId: clubId,
            name: name,
          ),
        );
      }

      if (difficulty != PyramidDifficulty.hard) {
        for (final country in peakPlayer.countries) {
          if (country.trim().isEmpty) continue;

          add(
            PyramidEntity(
              id:
                  'country_${PyramidEntity.normalize(country)}',
              type: PyramidNodeType.country,
              name: country,
              countries: [country],
            ),
          );
        }
      }

      final remainingPlayerEntities = answerPool
          .where((e) => e.type == PyramidNodeType.player)
          .where((e) => !base.any((b) => b.id == e.id))
          .where((e) => e.id != peak.id)
          .length;

      if (remainingPlayerEntities < 9) {
        debugPrint(
          '[HybridV3] Pyramid SQLite answer pool not finishable '
          'remainingPlayers=$remainingPlayerEntities; legacy fallback.',
        );
        return null;
      }

      final filled = <int, PyramidEntity>{0: peak};
      const baseStart = 10;

      for (var i = 0; i < 5; i++) {
        filled[baseStart + i] = base[i];
      }

      debugPrint(
        '[HybridV3] Pyramid SQLite '
        'difficulty=${difficulty.name} '
        'peak=${peakPlayer.name} '
        'anchor=${clubNameById[anchorClubId]} '
        'answers=${answerPool.length}',
      );

      return PyramidBoard(
        id:
            'v3_${peakPlayer.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Pyramid',
        difficulty: difficulty,
        slots: _slots,
        initialFilled: filled,
        answerPool: answerPool,
      );
    } catch (e) {
      debugPrint('[HybridV3] Pyramid SQLite fallback: $e');
      return null;
    }
  }

}
