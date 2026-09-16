import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/manager_formation.dart';
import '../models/manager_pool.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import '../models/manager_transfer.dart';
import 'manager_season_service.dart';

class StoredManagerOffer {
  final int playerId, askLink;
  final String note;
  const StoredManagerOffer(this.playerId, this.askLink, this.note);
  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'askLink': askLink,
    'note': note,
  };
  factory StoredManagerOffer.fromJson(Map<String, dynamic> j) =>
      StoredManagerOffer(
        (j['playerId'] as num).toInt(),
        (j['askLink'] as num).toInt(),
        j['note'] as String? ?? '',
      );
}

class ManagerCareerState {
  final ManagerDifficulty difficulty;
  final int budgetLink, matchesPlayed, wins, draws, losses, seasonNumber;
  final bool started, formatUpgradeNotice;
  final List<int> squadPlayerIds, benchPlayerIds;
  final Map<String, int> squadSlots;
  final String? formationId;
  final ManagerSeason? season;
  final List<ManagerSeason> archivedSeasons;
  final String marketKey;
  final List<StoredManagerOffer> marketOffers;

  const ManagerCareerState({
    required this.difficulty,
    required this.budgetLink,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.started = false,
    this.squadPlayerIds = const [],
    this.formationId,
    this.season,
    this.benchPlayerIds = const [],
    this.squadSlots = const {},
    this.archivedSeasons = const [],
    this.seasonNumber = 1,
    this.formatUpgradeNotice = false,
    this.marketKey = '',
    this.marketOffers = const [],
  });

  Set<int> get ownedIds => {...squadPlayerIds, ...benchPlayerIds};
  bool get hasSquad => squadPlayerIds.toSet().length == 11;
  bool get hasSeason => season != null;
  String get currentMarketKey => season?.nextFixture == null
      ? ''
      : '${season!.id}:${season!.nextFixture!.week}';

  ManagerCareerState copyWith({
    int? budgetLink,
    int? matchesPlayed,
    int? wins,
    int? draws,
    int? losses,
    bool? started,
    List<int>? squadPlayerIds,
    String? formationId,
    ManagerSeason? season,
    bool clearSeason = false,
    List<int>? benchPlayerIds,
    Map<String, int>? squadSlots,
    List<ManagerSeason>? archivedSeasons,
    int? seasonNumber,
    bool? formatUpgradeNotice,
    String? marketKey,
    List<StoredManagerOffer>? marketOffers,
  }) => ManagerCareerState(
    difficulty: difficulty,
    budgetLink: budgetLink ?? this.budgetLink,
    matchesPlayed: matchesPlayed ?? this.matchesPlayed,
    wins: wins ?? this.wins,
    draws: draws ?? this.draws,
    losses: losses ?? this.losses,
    started: started ?? this.started,
    squadPlayerIds: squadPlayerIds ?? this.squadPlayerIds,
    formationId: formationId ?? this.formationId,
    season: clearSeason ? null : season ?? this.season,
    benchPlayerIds: benchPlayerIds ?? this.benchPlayerIds,
    squadSlots: squadSlots ?? this.squadSlots,
    archivedSeasons: archivedSeasons ?? this.archivedSeasons,
    seasonNumber: seasonNumber ?? this.seasonNumber,
    formatUpgradeNotice: formatUpgradeNotice ?? this.formatUpgradeNotice,
    marketKey: marketKey ?? this.marketKey,
    marketOffers: marketOffers ?? this.marketOffers,
  );

  Map<String, dynamic> toJson() => {
    'difficulty': difficulty.name,
    'budgetLink': budgetLink,
    'matchesPlayed': matchesPlayed,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'started': started,
    'squadPlayerIds': squadPlayerIds,
    'formationId': formationId,
    'season': season?.toJson(),
    'benchPlayerIds': benchPlayerIds,
    'squadSlots': squadSlots,
    'archivedSeasons': archivedSeasons.map((s) => s.toJson()).toList(),
    'seasonNumber': seasonNumber,
    'formatUpgradeNotice': formatUpgradeNotice,
    'marketKey': marketKey,
    'marketOffers': marketOffers.map((o) => o.toJson()).toList(),
  };

  factory ManagerCareerState.fromJson(Map<String, dynamic> j) {
    final difficulty = ManagerDifficulty.values.firstWhere(
      (d) => d.name == j['difficulty'],
      orElse: () => ManagerDifficulty.medium,
    );
    List<int> ids(String key) => (j[key] as List? ?? const [])
        .map((v) => (v as num).toInt())
        .toSet()
        .toList();
    return ManagerCareerState(
      difficulty: difficulty,
      budgetLink: (j['budgetLink'] as num?)?.toInt() ?? difficulty.budgetLink,
      matchesPlayed: (j['matchesPlayed'] as num?)?.toInt() ?? 0,
      wins: (j['wins'] as num?)?.toInt() ?? 0,
      draws: (j['draws'] as num?)?.toInt() ?? 0,
      losses: (j['losses'] as num?)?.toInt() ?? 0,
      started: j['started'] as bool? ?? false,
      squadPlayerIds: ids('squadPlayerIds'),
      benchPlayerIds: ids('benchPlayerIds'),
      formationId: j['formationId'] as String?,
      squadSlots: (j['squadSlots'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
      season: j['season'] is Map
          ? ManagerSeason.fromJson(
              Map<String, dynamic>.from(j['season'] as Map),
            )
          : null,
      archivedSeasons: (j['archivedSeasons'] as List? ?? const [])
          .map(
            (s) => ManagerSeason.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
      seasonNumber: (j['seasonNumber'] as num?)?.toInt() ?? 1,
      formatUpgradeNotice: j['formatUpgradeNotice'] as bool? ?? false,
      marketKey: j['marketKey'] as String? ?? '',
      marketOffers: (j['marketOffers'] as List? ?? const [])
          .map(
            (o) => StoredManagerOffer.fromJson(
              Map<String, dynamic>.from(o as Map),
            ),
          )
          .toList(),
    );
  }

  factory ManagerCareerState.fresh(ManagerDifficulty d) =>
      ManagerCareerState(difficulty: d, budgetLink: d.budgetLink);
}

class ManagerCareerStore {
  ManagerCareerStore({ManagerSeasonService? seasons})
    : _seasons = seasons ?? ManagerSeasonService.instance;
  static final instance = ManagerCareerStore();
  static const maxRoster = 25;
  // Preserve the existing key. Legacy seasons are archived, never discarded.
  static const _prefix = 'club_manager_career_v8_';
  final ManagerSeasonService _seasons;
  final Map<ManagerDifficulty, Future<void>> _tails = {};

  Future<T> _locked<T>(ManagerDifficulty d, Future<T> Function() action) {
    final result = (_tails[d] ?? Future<void>.value()).then((_) => action());
    _tails[d] = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _write(ManagerCareerState s) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      '$_prefix${s.difficulty.name}',
      jsonEncode(s.toJson()),
    );
    if (!saved) throw StateError('Kariyer kaydedilemedi. Yeniden dene.');
  }

  Future<ManagerCareerState> _read(ManagerDifficulty d) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix${d.name}');
    if (raw == null || raw.isEmpty) return ManagerCareerState.fresh(d);
    // A damaged save must not silently become a new career and overwrite itself.
    var s = ManagerCareerState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (s.difficulty != d) throw StateError('Kariyer kaydı doğrulanamadı.');
    final old = s.season;
    if (old != null && !old.isCurrentFormat) {
      if (old.formatVersion >= ManagerSeason.currentFormat) {
        throw StateError('Sezon kaydı eksik. Mevcut kayıt korundu.');
      }
      s = s.copyWith(
        archivedSeasons: [...s.archivedSeasons, old],
        season: _seasons.createSeason(userName: old.user.name, difficulty: d),
        seasonNumber: s.seasonNumber + 1,
        formatUpgradeNotice: true,
        marketKey: '',
        marketOffers: const [],
      );
      await _write(s);
    }
    return s;
  }

  Future<ManagerCareerState> load(ManagerDifficulty d) =>
      _locked(d, () => _read(d));
  Future<void> save(ManagerCareerState s) =>
      _locked(s.difficulty, () => _write(s));

  Future<ManagerCareerState> _change(
    ManagerDifficulty d,
    ManagerCareerState Function(ManagerCareerState) change,
  ) => _locked(d, () async {
    final previous = await _read(d);
    final next = change(previous);
    if (!identical(next, previous)) await _write(next);
    return next;
  });

  Future<ManagerCareerState> startIfNeeded(ManagerDifficulty d) => _change(
    d,
    (s) => s.started && s.season != null
        ? s
        : s.copyWith(
            started: true,
            season: s.season ?? _seasons.createSeason(difficulty: d),
          ),
  );

  Future<ManagerCareerState> dismissUpgrade(ManagerDifficulty d) =>
      _change(d, (s) => s.copyWith(formatUpgradeNotice: false));

  Future<ManagerCareerState> nextSeason(ManagerDifficulty d) => _change(d, (s) {
    if (s.season == null || !s.season!.isComplete) {
      throw StateError('Yeni sezon için mevcut 38 maçı tamamla.');
    }
    return s.copyWith(
      archivedSeasons: [...s.archivedSeasons, s.season!],
      season: _seasons.createSeason(
        userName: s.season!.user.name,
        difficulty: d,
      ),
      seasonNumber: s.seasonNumber + 1,
      formatUpgradeNotice: false,
      marketKey: '',
      marketOffers: const [],
    );
  });

  Future<ManagerCareerState> saveSquad({
    required ManagerDifficulty difficulty,
    required String seasonId,
    required ManagerFormation formation,
    required Map<String, ManagerPoolPlayer> assignments,
  }) => _change(difficulty, (s) {
    _checkActive(s, seasonId);
    final ids = assignments.values.map((p) => p.playerId).toSet();
    if (ids.length != assignments.length ||
        assignments.length > 11 ||
        assignments.entries.any(
          (e) =>
              !formation.slots.contains(e.key) ||
              ManagerFormation.groupOf(e.key) != e.value.positionGroup,
        )) {
      throw StateError('Oyuncu veya mevki seçimi geçersiz.');
    }
    final fresh = assignments.values.where(
      (p) => !s.ownedIds.contains(p.playerId),
    );
    final spent = fresh.fold<int>(0, (sum, p) => sum + p.costLink);
    if (fresh.any((p) => p.costLink <= 0) || spent > s.budgetLink) {
      throw StateError('Bu kadro için kasa yetersiz.');
    }
    final owned = {...s.ownedIds, ...ids};
    if (owned.length > maxRoster && owned.length > s.ownedIds.length) {
      throw StateError(
        'Kadro en fazla 25 oyuncu olabilir. Önce bir yedeği sat.',
      );
    }
    return s.copyWith(
      budgetLink: s.budgetLink - spent,
      formationId: formation.id,
      squadPlayerIds: [
        for (final slot in formation.slots)
          if (assignments[slot] != null) assignments[slot]!.playerId,
      ],
      squadSlots: assignments.map((k, v) => MapEntry(k, v.playerId)),
      benchPlayerIds: owned.difference(ids).toList(),
    );
  });

  Future<ManagerCareerState> prepareMarket({
    required ManagerDifficulty difficulty,
    required String marketKey,
    required List<ManagerTransferOffer> offers,
  }) => _change(difficulty, (s) {
    if (marketKey.isEmpty || s.currentMarketKey != marketKey) {
      throw StateError('Transfer haftası değişti. Ekranı yenile.');
    }
    if (s.marketKey == marketKey) return s;
    return s.copyWith(
      marketKey: marketKey,
      marketOffers: offers
          .map((o) => StoredManagerOffer(o.player.playerId, o.askLink, o.note))
          .toList(),
    );
  });

  Future<ManagerCareerState> buy(ManagerDifficulty d, int id) => _change(d, (
    s,
  ) {
    if (s.ownedIds.contains(id)) return s;
    if (s.marketKey.isEmpty || s.marketKey != s.currentMarketKey) {
      throw StateError('Transfer listesi yenilenmeli.');
    }
    final offers = s.marketOffers.where((o) => o.playerId == id).toList();
    if (offers.length != 1 || offers.single.askLink <= 0) {
      throw StateError('Bu teklif artık geçerli değil.');
    }
    if (s.ownedIds.length >= maxRoster) throw StateError('Kadro dolu (25/25).');
    if (s.budgetLink < offers.single.askLink)
      throw StateError('Kasa yetersiz.');
    return s.copyWith(
      budgetLink: s.budgetLink - offers.single.askLink,
      benchPlayerIds: [...s.benchPlayerIds, id],
    );
  });

  Future<ManagerCareerState> sellReserve(
    ManagerDifficulty d,
    ManagerPoolPlayer player,
  ) => _change(d, (s) {
    if (!s.benchPlayerIds.contains(player.playerId) ||
        s.squadPlayerIds.contains(player.playerId)) {
      throw StateError('Yalnızca yedek oyuncular satılabilir.');
    }
    return s.copyWith(
      budgetLink: s.budgetLink + (player.costLink * .7).floor(),
      benchPlayerIds: s.benchPlayerIds
          .where((id) => id != player.playerId)
          .toList(),
    );
  });

  Future<ManagerCareerState> applyMatchResult({
    required ManagerDifficulty difficulty,
    required String seasonId,
    required int week,
    required String opponentId,
    required int userGoals,
    required int oppGoals,
  }) => _change(difficulty, (s) {
    if (s.season?.id != seasonId) throw StateError('Sezon değişti.');
    final fixtures = s.season!.fixtures
        .where((f) => f.week == week && f.opponentId == opponentId)
        .toList();
    if (fixtures.length != 1) throw StateError('Fikstür bulunamadı.');
    final fixture = fixtures.single;
    if (fixture.played) {
      if (fixture.userGoals == userGoals && fixture.oppGoals == oppGoals)
        return s;
      throw StateError('Bu maçın farklı bir sonucu zaten kaydedilmiş.');
    }
    if (!s.hasSquad) throw StateError('Önce 11 oyuncuyu kaydet.');
    final season = _seasons.applyUserResult(
      s.season!,
      opponentId: opponentId,
      expectedWeek: week,
      userGoals: userGoals,
      oppGoals: oppGoals,
    );
    final win = userGoals > oppGoals;
    final draw = userGoals == oppGoals;
    return s.copyWith(
      season: season,
      budgetLink: s.budgetLink + (win ? difficulty.winBonusLink : 0),
      matchesPlayed: s.matchesPlayed + 1,
      wins: s.wins + (win ? 1 : 0),
      draws: s.draws + (draw ? 1 : 0),
      losses: s.losses + (!win && !draw ? 1 : 0),
    );
  });

  void _checkActive(ManagerCareerState s, String id) {
    if (s.season?.id != id || s.season!.isComplete) {
      throw StateError('Sezon değişti veya tamamlandı.');
    }
  }

  Future<void> reset(ManagerDifficulty d) => _locked(d, () async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove('$_prefix${d.name}')) {
      throw StateError('Kariyer sıfırlanamadı.');
    }
  });
}
