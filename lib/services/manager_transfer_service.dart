import 'dart:math';

import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_transfer.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'manager_link_service.dart';
import 'manager_pool_service.dart';
import 'manager_rating_service.dart';

class ManagerTransferService {
  ManagerTransferService._();
  static final ManagerTransferService instance = ManagerTransferService._();
  static final _rng = Random();

  static const _notes = [
    'Ajans kısa listede',
    'Sözleşme sonu fırsatı',
    'Kulüp satışa açık',
    'Genç yetenek denemesi',
    'Tecrübeli rotasyon',
    'Piyasa düşüşü',
  ];

  /// Mevcut XI id'leri hariç 4–5 teklif.
  List<ManagerTransferOffer> generateOffers({
    required ManagerDifficulty difficulty,
    required Set<int> excludeIds,
    int count = 5,
  }) {
    final repo = Repository.instance;
    final ratingSvc = ManagerRatingService.instance;
    final linkSvc = ManagerLinkService.instance;
    final poolSvc = ManagerPoolService.instance;

    final candidates = <({Player p, ManagerPlayerRating r, double link, String pos})>[];
    for (final p in repo.players) {
      if (excludeIds.contains(p.id)) continue;
      final pos = poolSvc.positionGroup(p);
      if (pos != 'GK' && pos != 'DEF' && pos != 'MID' && pos != 'ATT') continue;
      final r = ratingSvc.rate(p, repository: repo);
      // zorluğa göre band
      final minR = switch (difficulty) {
        ManagerDifficulty.easy => 55.0,
        ManagerDifficulty.medium => 60.0,
        ManagerDifficulty.hard => 58.0,
      };
      final maxR = switch (difficulty) {
        ManagerDifficulty.easy => 96.0,
        ManagerDifficulty.medium => 93.0,
        ManagerDifficulty.hard => 90.0,
      };
      if (r.rating < minR || r.rating > maxR) continue;
      final link = linkSvc.potentialFor(p, repository: repo);
      candidates.add((p: p, r: r, link: link, pos: pos));
    }
    candidates.shuffle(_rng);

    // Mevki dengesi: en az birer dene
    final picked = <ManagerTransferOffer>[];
    final need = ['GK', 'DEF', 'MID', 'ATT'];
    for (final g in need) {
      final hit = candidates.where((c) => c.pos == g).take(1).toList();
      for (final c in hit) {
        picked.add(_toOffer(c));
        candidates.removeWhere((x) => x.p.id == c.p.id);
      }
    }
    while (picked.length < count && candidates.isNotEmpty) {
      final c = candidates.removeAt(0);
      if (picked.any((o) => o.player.playerId == c.p.id)) continue;
      picked.add(_toOffer(c));
    }
    return picked.take(count).toList();
  }

  ManagerTransferOffer _toOffer(
      ({Player p, ManagerPlayerRating r, double link, String pos}) c) {
    final base = c.r.costLink;
    // -2 .. +4 pazarlık
    final ask = (base + _rng.nextInt(7) - 2).clamp(4, 22);
    return ManagerTransferOffer(
      player: ManagerPoolPlayer(
        playerId: c.p.id,
        name: c.p.name,
        positionGroup: c.pos,
        rating: c.r,
        linkPotential: double.parse(c.link.toStringAsFixed(1)),
      ),
      askLink: ask,
      note: _notes[_rng.nextInt(_notes.length)],
    );
  }
}
