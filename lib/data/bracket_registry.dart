import '../models/bracket_candidate.dart';
import 'city_derby_rivalries_64_data.dart';
import 'era_clash_64_data.dart';
import 'historical_season_kings_64_data.dart';
import 'position_rivalry_64_data.dart';
import 'prime_battles_32_data.dart';
import 'super_lig_legends_64_data.dart';
import 'turkish_peak_squads_64_data.dart';
import 'ucl_dynasties_64_data.dart';

/// Futbolcu vs Futbolcu bracket'leri.
class BracketRegistry {
  BracketRegistry._();

  static final List<BracketDefinition> playerBrackets = [
    PrimeBattles32Data.definition,
    EraClash64Data.definition,
    PositionRivalry64Data.definition,
    SuperLigLegends64Data.definition,
  ];

  /// Kulüp vs Kulüp bracket'leri.
  static final List<BracketDefinition> clubBrackets = [
    UclDynasties64Data.definition,
    HistoricalSeasonKings64Data.definition,
    TurkishPeakSquads64Data.definition,
    CityDerbyRivalries64Data.definition,
  ];

  static BracketDefinition? byId(String id) {
    for (final b in playerBrackets) {
      if (b.id == id) return b;
    }
    for (final b in clubBrackets) {
      if (b.id == id) return b;
    }
    return null;
  }
}