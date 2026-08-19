import '../models/club.dart';
import '../models/famous_transfer.dart';
import '../models/player.dart';
import '../utils/country_names.dart';
import '../services/database_service.dart';
import '../services/search_service.dart';

class Repository {
  Repository._();

  static final Repository instance = Repository._();

  bool _initialized = false;

  late final List<Club> _clubs;
  late final List<Player> _players;
  late final List<FamousTransfer> _famousTransfers;

  List<String>? _countriesCache;

  Future<void> initialize() async {
    if (_initialized) return;

    final results = await Future.wait([
      DatabaseService.loadClubs(),
      DatabaseService.loadPlayers(),
      DatabaseService.loadFamousTransfers(),
    ]);

    _clubs = results[0] as List<Club>;
    _players = results[1] as List<Player>;
    _famousTransfers = results[2] as List<FamousTransfer>;

    SearchService.buildIndex(_players);
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  List<Club> get clubs => _clubs;

  List<Player> get players => _players;

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

  Club? clubById(int id) {
    try {
      return _clubs.firstWhere((club) => club.id == id);
    } catch (_) {
      return null;
    }
  }

  Player? playerById(int id) {
    try {
      return _players.firstWhere((player) => player.id == id);
    } catch (_) {
      return null;
    }
  }
}