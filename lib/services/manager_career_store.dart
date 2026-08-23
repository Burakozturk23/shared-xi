import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/manager_rating.dart';
import '../models/manager_season.dart';
import 'manager_season_service.dart';

class ManagerCareerState {
  final ManagerDifficulty difficulty;
  final int budgetLink;
  final int matchesPlayed;
  final int wins;
  final int draws;
  final int losses;
  final bool started;
  final List<int> squadPlayerIds;
  final String? formationId;
  final ManagerSeason? season;
  final List<int> benchPlayerIds;

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
  });

  bool get hasSquad => squadPlayerIds.length >= 11;
  bool get hasSeason => season != null;

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
  }) {
    return ManagerCareerState(
      difficulty: difficulty,
      budgetLink: budgetLink ?? this.budgetLink,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      wins: wins ?? this.wins,
      draws: draws ?? this.draws,
      losses: losses ?? this.losses,
      started: started ?? this.started,
      squadPlayerIds: squadPlayerIds ?? this.squadPlayerIds,
      formationId: formationId ?? this.formationId,
      season: clearSeason ? null : (season ?? this.season),
      benchPlayerIds: benchPlayerIds ?? this.benchPlayerIds,
    );
  }

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
      };

  factory ManagerCareerState.fromJson(Map<String, dynamic> j) {
    final name = j['difficulty'] as String? ?? 'medium';
    final d = ManagerDifficulty.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ManagerDifficulty.medium,
    );
    final ids = (j['squadPlayerIds'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];
    ManagerSeason? season;
    if (j['season'] is Map) {
      season = ManagerSeason.fromJson(
          Map<String, dynamic>.from(j['season'] as Map));
    }
    return ManagerCareerState(
      difficulty: d,
      budgetLink: j['budgetLink'] as int? ?? d.budgetLink,
      matchesPlayed: j['matchesPlayed'] as int? ?? 0,
      wins: j['wins'] as int? ?? 0,
      draws: j['draws'] as int? ?? 0,
      losses: j['losses'] as int? ?? 0,
      started: j['started'] as bool? ?? false,
      squadPlayerIds: ids,
      formationId: j['formationId'] as String?,
      season: season,
      benchPlayerIds: (j['benchPlayerIds'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );
  }

  factory ManagerCareerState.fresh(ManagerDifficulty d) => ManagerCareerState(
        difficulty: d,
        budgetLink: d.budgetLink,
      );
}

class ManagerCareerStore {
  ManagerCareerStore._();
  static final ManagerCareerStore instance = ManagerCareerStore._();

  static const _prefix = 'club_manager_career_v8_';

  Future<ManagerCareerState> load(ManagerDifficulty d) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix${d.name}');
    if (raw == null || raw.isEmpty) return ManagerCareerState.fresh(d);
    try {
      return ManagerCareerState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return ManagerCareerState.fresh(d);
    }
  }

  Future<void> save(ManagerCareerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${state.difficulty.name}',
      jsonEncode(state.toJson()),
    );
  }

  Future<ManagerCareerState> startIfNeeded(ManagerDifficulty d) async {
    var s = await load(d);
    if (!s.started) {
      s = ManagerCareerState(
        difficulty: d,
        budgetLink: d.budgetLink,
        started: true,
        season: null,
      );
      await save(s);
    }
    return s;
  }

  Future<ManagerCareerState> ensureSeason(ManagerDifficulty d) async {
    var s = await startIfNeeded(d);
    if (s.season == null) {
      // lazy: caller should use ManagerSeasonService
      return s;
    }
    return s;
  }

  Future<ManagerCareerState> applyMatchResult({
    required ManagerDifficulty difficulty,
    required int remainingBudget,
    required bool isWin,
    required bool isDraw,
    required List<int> squadPlayerIds,
    required String formationId,
    String? opponentId,
    int? userGoals,
    int? oppGoals,
  }) async {
    final prev = await load(difficulty);
    var season = prev.season;
    if (season != null && opponentId != null && userGoals != null && oppGoals != null) {
      season = ManagerSeasonService.instance.applyUserResult(
        season,
        opponentId: opponentId,
        userGoals: userGoals,
        oppGoals: oppGoals,
      );
    }
    final next = prev.copyWith(
      budgetLink: remainingBudget,
      matchesPlayed: prev.matchesPlayed + 1,
      wins: prev.wins + (isWin ? 1 : 0),
      draws: prev.draws + (isDraw ? 1 : 0),
      losses: prev.losses + (!isWin && !isDraw ? 1 : 0),
      started: true,
      squadPlayerIds: squadPlayerIds,
      formationId: formationId,
      season: season,
    );
    await save(next);
    return next;
  }

  Future<void> saveSquad({
    required ManagerDifficulty difficulty,
    required int budgetLink,
    required List<int> squadPlayerIds,
    required String formationId,
  }) async {
    final prev = await load(difficulty);
    await save(prev.copyWith(
      budgetLink: budgetLink,
      squadPlayerIds: squadPlayerIds,
      formationId: formationId,
      started: true,
    ));
  }

  Future<void> saveSeason(ManagerDifficulty d, ManagerSeason season) async {
    final prev = await load(d);
    await save(prev.copyWith(season: season, started: true));
  }

  Future<void> reset(ManagerDifficulty d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix${d.name}');
  }
}
