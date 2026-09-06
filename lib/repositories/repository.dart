import '../models/club.dart';
import '../models/coach.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';

import '../services/database_service.dart';
import '../services/runtime_v4/game_data_v4_database.dart';
import '../services/runtime_v4/game_data_v4_legacy_bridge.dart';
import '../services/search_service.dart';

import '../utils/country_names.dart';

import 'package:flutter/foundation.dart';

class Repository {
  Repository._();

  static final Repository instance = Repository._();

  bool _initialized = false;

  Future<void>? _initializeFuture;

  late final List<Club> _clubs;
  late final List<Player> _players;
  late final List<Coach> _coaches;
  late final List<FamousTransfer> _famousTransfers;

  late final Map<int, Club> _clubById;
  late final Map<int, Player> _playerById;

  late final String _dataVersion;
  late final int _rawPlayerCount;

  List<String>? _countriesCache;

  Future<void> initialize() async {
    if (_initialized) return;

    final inFlight = _initializeFuture;

    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initializeInternal();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    final totalWatch = Stopwatch()..start();

    // -------------------------------------------------------
    // V4 database is now the canonical player/club source.
    // -------------------------------------------------------

    final v4 = GameDataV4Database.instance;

    await v4.initialize();

    _dataVersion =
        v4.metadata['data_version'] ??
        v4.metadata['schema_version'] ??
        'v4';

    // -------------------------------------------------------
    // Transitional compatibility bridge.
    //
    // Players + clubs come from V4 SQLite.
    //
    // Famous transfers and coaches remain on the old tiny
    // JSON assets for this intermediate migration step.
    // -------------------------------------------------------

    final loadWatch = Stopwatch()..start();

    final results = await Future.wait([
      GameDataV4LegacyBridge.loadClubs(),
      GameDataV4LegacyBridge.loadPlayers(),
      DatabaseService.loadFamousTransfers(),
      DatabaseService.loadCoaches(),
    ]);

    loadWatch.stop();

    _clubs = results[0] as List<Club>;
    _players = results[1] as List<Player>;
    _famousTransfers =
        results[2] as List<FamousTransfer>;
    _coaches = results[3] as List<Coach>;

    _rawPlayerCount = _players.length;

    // -------------------------------------------------------
    // Canonical maps
    // -------------------------------------------------------

    final mapWatch = Stopwatch()..start();

    _playerById = {
      for (final player in _players)
        player.id: player,
    };

    _clubById = {
      for (final club in _clubs)
        club.id: club,
    };

    // Legacy references that were frozen as canonical
    // shadow remaps during V4 compilation.
    //
    // They are NOT members of _players.
    // They only preserve playerById(oldId) compatibility.
    final raulGarcia =
        _playerById[631002];

    if (raulGarcia != null) {
      _playerById[34601] = raulGarcia;
    }

    final suso =
        _playerById[1650];

    if (suso != null) {
      _playerById[111961] = suso;
    }

    mapWatch.stop();

    // -------------------------------------------------------
    // Temporary legacy search compatibility.
    //
    // This is only 30,135 players now, not 128K/173K.
    // Next migration step moves SearchService to SQLite.
    // -------------------------------------------------------

    final searchWatch = Stopwatch()..start();

    SearchService.buildIndex(_players);

    searchWatch.stop();

    _initialized = true;

    totalWatch.stop();

    debugPrint(
      '[V4Repository] load=${loadWatch.elapsedMilliseconds}ms '
      'maps=${mapWatch.elapsedMilliseconds}ms '
      'search=${searchWatch.elapsedMilliseconds}ms '
      'TOTAL=${totalWatch.elapsedMilliseconds}ms '
      'players=${_players.length} '
      'clubs=${_clubs.length}',
    );
  }

  bool get isInitialized => _initialized;

  bool get isInitializing =>
      _initializeFuture != null;

  String get dataVersion => _dataVersion;

  int get playerCount =>
      _initialized ? _players.length : 0;

  int get rawPlayerCount =>
      _initialized ? _rawPlayerCount : 0;

  int get clubCount =>
      _initialized ? _clubs.length : 0;

  List<Club> get clubs => _clubs;

  List<Player> get players => _players;

  List<Coach> get coaches => _coaches;

  List<FamousTransfer> get famousTransfers =>
      _famousTransfers;

  List<String> get countries {
    if (_countriesCache != null) {
      return _countriesCache!;
    }

    final set = <String>{};

    for (final player in _players) {
      set.addAll(
        CountryNames.canonicalList(
          player.countries,
        ),
      );
    }

    final list = set.toList()
      ..sort();

    _countriesCache = list;

    return list;
  }

  Club? clubById(int id) =>
      _clubById[id];

  Player? playerById(int id) =>
      _playerById[id];
}