import '../models/player.dart';
import '../repositories/repository.dart';

enum PlayerBondKind { none, league, country, club, clubAndCountry }

class PlayerBond {
  final PlayerBondKind kind;
  final String? detail;

  const PlayerBond(this.kind, [this.detail]);

  bool get hasBond => kind != PlayerBondKind.none;

  /// Link gücü: kulüp+ülke > kulüp > ülke > lig
  double get weight {
    switch (kind) {
      case PlayerBondKind.clubAndCountry:
        return 1.45;
      case PlayerBondKind.club:
        return 1.0;
      case PlayerBondKind.country:
        return 0.55;
      case PlayerBondKind.league:
        return 0.2;
      case PlayerBondKind.none:
        return 0;
    }
  }
}

class ManagerLinkService {
  ManagerLinkService._();
  static final ManagerLinkService instance = ManagerLinkService._();

  static Set<int> clubIdsOf(Player p) {
    final ids = <int>{};
    for (final id in p.clubs) {
      if (id > 0) ids.add(id);
    }
    for (final s in p.careerTimeline) {
      if (s.clubId > 0) ids.add(s.clubId);
    }
    return ids;
  }

  static Set<String> leaguesOf(Player p, Repository repo) {
    final set = <String>{};
    for (final id in clubIdsOf(p)) {
      final L = repo.clubById(id)?.league.trim().toLowerCase() ?? '';
      if (L.isNotEmpty) set.add(L);
    }
    return set;
  }

  static Set<String> countriesOf(Player p) {
    return p.countries
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  PlayerBond bondBetween(Player a, Player b, {Repository? repository}) {
    final repo = repository ?? Repository.instance;

    String? sharedClubName;
    final commonClubs = clubIdsOf(a).intersection(clubIdsOf(b));
    for (final id in commonClubs) {
      final c = repo.clubById(id);
      if (c != null && c.name.trim().isNotEmpty) {
        sharedClubName = c.name.trim();
        break;
      }
    }
    final sameClub = sharedClubName != null;

    final commonCountry = countriesOf(a).intersection(countriesOf(b));
    final sameCountry = commonCountry.isNotEmpty;

    if (sameClub && sameCountry) {
      return PlayerBond(
        PlayerBondKind.clubAndCountry,
        '$sharedClubName · ${commonCountry.first}',
      );
    }
    if (sameClub) {
      return PlayerBond(PlayerBondKind.club, sharedClubName);
    }
    if (sameCountry) {
      return PlayerBond(PlayerBondKind.country, commonCountry.first);
    }

    final la = leaguesOf(a, repo);
    final lb = leaguesOf(b, repo);
    final commonLeague = la.intersection(lb);
    if (commonLeague.isNotEmpty) {
      for (final id in clubIdsOf(a)) {
        final c = repo.clubById(id);
        final L = c?.league.trim() ?? '';
        if (L.isNotEmpty && commonLeague.contains(L.toLowerCase())) {
          return PlayerBond(PlayerBondKind.league, L);
        }
      }
      return PlayerBond(PlayerBondKind.league, commonLeague.first);
    }

    return const PlayerBond(PlayerBondKind.none);
  }

  double potentialFor(Player p, {Repository? repository}) {
    final repo = repository ?? Repository.instance;
    final clubs = clubIdsOf(p);
    final leagues = leaguesOf(p, repo);
    final clubPart = (clubs.length * 10.0).clamp(0.0, 50.0);
    final leaguePart = (leagues.length * 6.0).clamp(0.0, 24.0);
    final natPart =
        p.countries.isNotEmpty || p.nationalTeams.isNotEmpty ? 12.0 : 0.0;
    return (clubPart + leaguePart + natPart).clamp(5.0, 100.0);
  }

  double pairLink(Player a, Player b, {Repository? repository}) {
    return bondBetween(a, b, repository: repository).weight;
  }

  double squadLink(List<Player> xi, {Repository? repository}) {
    if (xi.length < 2) return 0;
    final repo = repository ?? Repository.instance;
    double total = 0;
    for (var i = 0; i < xi.length; i++) {
      for (var j = i + 1; j < xi.length; j++) {
        total += pairLink(xi[i], xi[j], repository: repo);
      }
    }
    return total;
  }
}


class SquadBondEntry {
  final String nameA;
  final String nameB;
  final PlayerBond bond;

  const SquadBondEntry({
    required this.nameA,
    required this.nameB,
    required this.bond,
  });
}

class SquadBondSummary {
  final List<SquadBondEntry> top;
  final int clubCount;
  final int countryCount;
  final int leagueCount;
  final int dualCount;
  final double totalLink;

  const SquadBondSummary({
    required this.top,
    required this.clubCount,
    required this.countryCount,
    required this.leagueCount,
    required this.dualCount,
    required this.totalLink,
  });
}

extension ManagerLinkServiceSummary on ManagerLinkService {
  SquadBondSummary summarizeSquad(List<Player> xi, {Repository? repository}) {
    final repo = repository ?? Repository.instance;
    final entries = <SquadBondEntry>[];
    var club = 0, country = 0, league = 0, dual = 0;
    for (var i = 0; i < xi.length; i++) {
      for (var j = i + 1; j < xi.length; j++) {
        final b = bondBetween(xi[i], xi[j], repository: repo);
        if (!b.hasBond) continue;
        switch (b.kind) {
          case PlayerBondKind.clubAndCountry:
            dual++;
            break;
          case PlayerBondKind.club:
            club++;
            break;
          case PlayerBondKind.country:
            country++;
            break;
          case PlayerBondKind.league:
            league++;
            break;
          case PlayerBondKind.none:
            break;
        }
        entries.add(SquadBondEntry(
          nameA: xi[i].name,
          nameB: xi[j].name,
          bond: b,
        ));
      }
    }
    entries.sort((a, b) => b.bond.weight.compareTo(a.bond.weight));
    return SquadBondSummary(
      top: entries.take(8).toList(),
      clubCount: club,
      countryCount: country,
      leagueCount: league,
      dualCount: dual,
      totalLink: squadLink(xi, repository: repo),
    );
  }
}
