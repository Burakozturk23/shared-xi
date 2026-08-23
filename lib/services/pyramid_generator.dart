import 'dart:math';

import '../models/club.dart';
import '../models/player.dart';
import '../models/pyramid_models.dart';
import '../repositories/repository.dart';

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
}
