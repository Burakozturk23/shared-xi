import 'package:shared_xi/data/build_xi_formations.dart';
import 'package:shared_xi/models/squad_challenge.dart';
import 'package:shared_xi/services/squad_challenge_service.dart';

SquadCatalog squadFixture({bool unique = false}) {
  final players = <int, SquadPlayer>{};
  for (final (i, slot) in formation433.slots.indexed) {
    players[i + 1] = SquadPlayer(
      id: i + 1,
      name: 'Futbolcu ${i + 1}',
      position: slot.fallbackBroadPosition,
      detailedPosition: slot.acceptedDetailedPositions.first,
      countries: ['Ülke ${i + 1}'],
      clubs: const [77],
    );
  }
  players[12] = const SquadPlayer(
    id: 12,
    name: 'Yedek kaleci',
    position: 'Goalkeeper',
    detailedPosition: 'Goalkeeper',
    countries: ['Ülke 2'],
    clubs: [77],
  );
  final theme = SquadTheme(
    id: 'fixture',
    name: 'Deneme Ligi',
    description: 'Ortak kulüpleri keşfet.',
    category: 'leagues',
    playerIds: players.keys.toList(),
    costs: {for (final id in players.keys) id: id == 12 ? 15 : 8},
    uniqueCountries: unique,
  );
  return SquadCatalog(
    version: 'test-v1',
    players: players,
    themes: {theme.id: theme},
    formations: {formation433.id: formation433},
    continents: {for (var i = 1; i <= 11; i++) 'Ülke $i': 'Kıta ${i % 3}'},
  );
}

const squadMission = SquadMission(
  id: '2026-09-18__0__fixture',
  day: '2026-09-18',
  themeId: 'fixture',
  formationId: '4-3-3',
  label: 'Isınma',
  reward: 20,
  budget: 135,
  links: 4,
  countries: 3,
);

/// UI orchestration fake only. Currency authority/concurrency use the actual
/// callable and wallet normalizers in the Node suite.
class FakeSquadGateway extends SquadGateway {
  @override
  String? userId = 'alice';
  int coins = 100, free = 3, loads = 0, starts = 0;
  bool premium = false,
      offline = false,
      interruptStart = false,
      interruptFinish = false;
  SquadRun? active, finished;
  final submissions = <List<int>>[];
  final requestIds = <String>[];
  SquadHub get hub => SquadHub(
    version: 'test-v1',
    day: squadMission.day,
    coins: coins,
    freeRemaining: free,
    freeTotal: 3,
    extraPrice: 20,
    extraRemaining: 3,
    premium: premium,
    dailyMaxCoins: 90,
    completedTotal: finished == null ? 0 : 1,
    resetsAt: 1790024400000,
    missions: const [squadMission],
    active: active,
  );

  @override
  Future<SquadHub> load(String version) async {
    loads++;
    if (offline) throw StateError('Bağlantı kurulamadı.');
    return hub;
  }

  @override
  Future<SquadResponse> start(
    String version,
    String missionId,
    String requestId, {
    bool spendCoins = false,
  }) async {
    starts++;
    requestIds.add(requestId);
    if (active == null) {
      if (!premium) {
        if (free > 0) {
          free--;
        } else if (spendCoins) {
          coins -= 20;
        } else {
          throw StateError('Onay gerekli.');
        }
      }
      active = SquadRun(
        id: requestId,
        mission: squadMission,
        payment: premium
            ? 'premium'
            : spendCoins
            ? 'coins'
            : 'free',
        status: 'active',
      );
    }
    if (interruptStart) {
      interruptStart = false;
      throw StateError('Yanıt kesildi.');
    }
    return SquadResponse(hub, active);
  }

  @override
  Future<SquadResponse> finish(
    String version,
    String runId,
    List<int> playerIds,
  ) async {
    submissions.add(List.of(playerIds));
    if (finished == null) {
      coins += 20;
      finished = SquadRun(
        id: runId,
        mission: squadMission,
        payment: active!.payment,
        status: 'finished',
        playerIds: List.of(playerIds),
        result: const SquadResult(
          won: true,
          reward: 20,
          score: 67,
          cost: 88,
          links: 16,
          countries: 11,
        ),
      );
      active = null;
    }
    if (interruptFinish) {
      interruptFinish = false;
      throw StateError('Yanıt kesildi.');
    }
    return SquadResponse(hub, finished);
  }

  @override
  Future<SquadResponse> abandon(String version, String runId) async {
    active = null;
    return SquadResponse(hub, null);
  }
}
