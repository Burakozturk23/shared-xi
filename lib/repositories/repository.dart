import '../models/club.dart';
import '../models/coach.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';
import '../utils/country_names.dart';
import '../utils/player_dedupe.dart';
import '../services/database_service.dart';
import '../services/search_service.dart';

class Repository {
  Repository._();

  static final Repository instance = Repository._();

  bool _initialized = false;

  // STEP 07A.8: concurrency-safe repository initialization.
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
    final meta = await DatabaseService.loadMeta();
    _dataVersion = meta['dataVersion']?.toString() ?? 'legacy';

    final results = await Future.wait([
      DatabaseService.loadClubs(),
      DatabaseService.loadPlayers(),
      DatabaseService.loadFamousTransfers(),
      DatabaseService.loadCoaches(),
    ]);

    _clubs = results[0] as List<Club>;
    final rawPlayers = results[1] as List<Player>;
    _famousTransfers = results[2] as List<FamousTransfer>;
    _coaches = results[3] as List<Coach>;

    _rawPlayerCount = rawPlayers.length;
    _playerById = {for (final p in rawPlayers) p.id: p};
    _players = PlayerDedupe.dedupe(rawPlayers);
    _clubById = {for (final c in _clubs) c.id: c};

    SearchService.buildIndex(_players);
    _initialized = true;
  }

  bool get isInitialized => _initialized;
  bool get isInitializing => _initializeFuture != null;
  String get dataVersion => _dataVersion;
  int get playerCount => _initialized ? _players.length : 0;
  int get rawPlayerCount => _initialized ? _rawPlayerCount : 0;
  int get clubCount => _initialized ? _clubs.length : 0;

  List<Club> get clubs => _clubs;
  List<Player> get players => _players;
  List<Coach> get coaches => _coaches;
  List<FamousTransfer> get famousTransfers => _famousTransfers;

  List<String> get countries {
    if (_countriesCache != null) return _countriesCache!;
    final set = <String>{};
    for (final player in _players) {
      set.addAll(CountryNames.canonicalList(player.countries));
    }
    final list = set.toList()..sort();
    _countriesCache = list;
    return list;
  }

  Club? clubById(int id) => _clubById[id];
  Player? playerById(int id) => _playerById[id];
}
