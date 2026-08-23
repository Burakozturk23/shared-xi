import 'dart:math';

import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/player.dart';
import '../repositories/repository.dart';
import 'manager_link_service.dart';
import 'manager_rating_service.dart';

/// 25 kişilik havuz: 3 GK + 7 DEF + 8 MID + 7 ATT
/// Tier hedefi: 5 Elite + 7 Strong + 8 Normal + 5 Value
class ManagerPoolService {
  ManagerPoolService._();
  static final ManagerPoolService instance = ManagerPoolService._();
  static final _rng = Random();

  static const posTargets = {'GK': 3, 'DEF': 7, 'MID': 8, 'ATT': 7};
  static const tierTargets = {
    ManagerTier.elite: 5,
    ManagerTier.strong: 7,
    ManagerTier.normal: 8,
    ManagerTier.value: 5,
  };

  /// Pozisyon grubu. "Defensive Midfield" MID olmalı (defen tuzak).
  String positionGroup(Player p) {
    final pos = p.position.trim().toLowerCase();
    final det = p.detailedPosition.trim().toLowerCase();
    final raw = '$pos $det';

    // 1) Kaleci
    if (raw.contains('goal') ||
        raw.contains('keeper') ||
        raw.contains('kaleci') ||
        pos == 'g' ||
        pos == 'gk') {
      return 'GK';
    }

    // 2) Orta saha ÖNCE (defensive/attacking midfield, CM, CDM, CAM…)
    if (raw.contains('midfield') ||
        raw.contains('midfielder') ||
        raw.contains('orta saha') ||
        raw.contains('orta-saha') ||
        det.contains('cdm') ||
        det.contains('cam') ||
        det.contains('cm') ||
        det.contains('dm') ||
        det.contains('am') ||
        pos == 'm' ||
        pos == 'mf' ||
        pos == 'mid') {
      return 'MID';
    }
    // "mid" tek başına (ama "middle" vs. nadir)
    if (raw.contains(' mid') || raw.startsWith('mid') || raw.contains('orta')) {
      return 'MID';
    }

    // 3) Forvet / kanat hücum
    if (raw.contains('strik') ||
        raw.contains('forw') ||
        raw.contains('forvet') ||
        raw.contains('second striker') ||
        det.contains('cf') ||
        det.contains('st') ||
        pos == 'f' ||
        pos == 'fw' ||
        pos == 'a' ||
        pos == 'att') {
      return 'ATT';
    }
    // Wing: "left wing" / "right wing" — not wing-back
    if ((raw.contains('wing') && !raw.contains('back') && !raw.contains('wingback') && !raw.contains('wing-back')) ||
        raw.contains('winger') ||
        det == 'lw' ||
        det == 'rw') {
      return 'ATT';
    }
    if (raw.contains('attack') && !raw.contains('midfield')) {
      return 'ATT';
    }

    // 4) Defans (full-back, centre-back, wing-back, stoper…)
    if (raw.contains('defen') ||
        raw.contains('centre-back') ||
        raw.contains('center-back') ||
        raw.contains('center back') ||
        raw.contains('centre back') ||
        raw.contains('full-back') ||
        raw.contains('fullback') ||
        raw.contains('full back') ||
        raw.contains('wing-back') ||
        raw.contains('wingback') ||
        raw.contains('wing back') ||
        raw.contains('stoper') ||
        raw.contains('bek') ||
        raw.contains('stopper') ||
        det.contains('cb') ||
        det.contains('lb') ||
        det.contains('rb') ||
        det.contains('lwb') ||
        det.contains('rwb') ||
        pos == 'd' ||
        pos == 'df' ||
        pos == 'def') {
      return 'DEF';
    }
    // "back" yalnızca defans bağlamında
    if (raw.contains('back') && !raw.contains('mid')) {
      return 'DEF';
    }

    return 'MID';
  }

  /// Yeni 25'li havuz üret.
  ManagerPool generate({
    ManagerDifficulty difficulty = ManagerDifficulty.medium,
    Repository? repository,
  }) {
    final repo = repository ?? Repository.instance;
    final ratingSvc = ManagerRatingService.instance;
    final linkSvc = ManagerLinkService.instance;

    // Adayları rate et (filtre: isim + pozisyon)
    final rated = <({Player p, ManagerPlayerRating r, String pos, double link})>[];
    for (final p in repo.players) {
      if (p.name.trim().isEmpty) continue;
      final pos = positionGroup(p);
      final r = ratingSvc.rate(p, repository: repo);
      final link = linkSvc.potentialFor(p, repository: repo);
      rated.add((p: p, r: r, pos: pos, link: link));
    }

    // Zorluğa göre peak/rating eğilimi
    rated.sort((a, b) {
      final cmp = b.r.rating.compareTo(a.r.rating);
      switch (difficulty) {
        case ManagerDifficulty.easy:
          return cmp; // yüksek rating önce
        case ManagerDifficulty.hard:
          return -cmp; // düşük önce
        case ManagerDifficulty.medium:
          return 0; // karışık
      }
    });
    if (difficulty == ManagerDifficulty.medium) {
      rated.shuffle(_rng);
    } else {
      // üst/alt dilimden karışık seçim için kısmi shuffle
      final take = min(rated.length, difficulty == ManagerDifficulty.easy ? 4000 : 6000);
      final slice = rated.take(take).toList()..shuffle(_rng);
      rated
        ..clear()
        ..addAll(slice);
      // kalanları da ekle (yetersiz kalırsa)
      // (basit tut: sadece slice)
    }

    final picked = <int>{};
    final result = <ManagerPoolPlayer>[];

    // Önce pozisyon kotalarını doldur; tier dengesine yaklaş
    final tierCount = {
      ManagerTier.elite: 0,
      ManagerTier.strong: 0,
      ManagerTier.normal: 0,
      ManagerTier.value: 0,
    };

    ManagerPoolPlayer toPool(
        ({Player p, ManagerPlayerRating r, String pos, double link}) e) {
      return ManagerPoolPlayer(
        playerId: e.p.id,
        name: e.p.name,
        positionGroup: e.pos,
        rating: e.r,
        linkPotential: double.parse(e.link.toStringAsFixed(1)),
      );
    }

    bool tryPick(
      String pos,
      ManagerTier? preferredTier,
    ) {
      final candidates = rated.where((e) {
        if (picked.contains(e.p.id)) return false;
        if (e.pos != pos) return false;
        if (preferredTier != null && e.r.tier != preferredTier) return false;
        return true;
      }).toList();
      if (candidates.isEmpty) return false;
      candidates.shuffle(_rng);
      final e = candidates.first;
      picked.add(e.p.id);
      result.add(toPool(e));
      tierCount[e.r.tier] = (tierCount[e.r.tier] ?? 0) + 1;
      return true;
    }

    // Tier hedeflerini pozisyonlara yay
    final tierQueue = <ManagerTier>[
      ...List.filled(tierTargets[ManagerTier.elite]!, ManagerTier.elite),
      ...List.filled(tierTargets[ManagerTier.strong]!, ManagerTier.strong),
      ...List.filled(tierTargets[ManagerTier.normal]!, ManagerTier.normal),
      ...List.filled(tierTargets[ManagerTier.value]!, ManagerTier.value),
    ]..shuffle(_rng);

    final posQueue = <String>[
      ...List.filled(posTargets['GK']!, 'GK'),
      ...List.filled(posTargets['DEF']!, 'DEF'),
      ...List.filled(posTargets['MID']!, 'MID'),
      ...List.filled(posTargets['ATT']!, 'ATT'),
    ]..shuffle(_rng);

    // Eşleştir: her slot için pozisyon + tercihli tier
    for (var i = 0; i < 25; i++) {
      final pos = i < posQueue.length ? posQueue[i] : 'MID';
      final tier = i < tierQueue.length ? tierQueue[i] : null;
      if (tryPick(pos, tier)) continue;
      // tier gevşet
      if (tryPick(pos, null)) continue;
      // herhangi pozisyon (nadir)
      final any = rated.where((e) => !picked.contains(e.p.id)).toList();
      if (any.isEmpty) break;
      any.shuffle(_rng);
      final e = any.first;
      picked.add(e.p.id);
      result.add(toPool(e));
      tierCount[e.r.tier] = (tierCount[e.r.tier] ?? 0) + 1;
    }

    // 25'e tamamla
    while (result.length < 25) {
      final any = rated.where((e) => !picked.contains(e.p.id)).toList();
      if (any.isEmpty) break;
      any.shuffle(_rng);
      final e = any.first;
      picked.add(e.p.id);
      result.add(toPool(e));
    }

    return ManagerPool(
      difficulty: difficulty,
      budgetLink: difficulty.budgetLink,
      players: result.take(25).toList(),
    );
  }
}
