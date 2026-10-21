/// Historical source observations, not current career totals or scoring evidence.
class CoachHonour {
  const CoachHonour({required this.competitionId, required this.label,
    required this.category, required this.count});
  final String competitionId, label, category;
  final int count;
}

class CoachArchiveProfile {
  CoachArchiveProfile(Map<String, dynamic> json)
      : birthDate = json['birthDate'] as String?,
        citizenship = json['citizenship'] as String?,
        snapshotClub = json['snapshotClub'] as String?,
        snapshotLeague = json['snapshotLeague'] as String?,
        snapshotFormation = json['snapshotFormation'] as String?;
  final String? birthDate, citizenship, snapshotClub, snapshotLeague, snapshotFormation;
}

class CoachHonoursRecord {
  CoachHonoursRecord._({required this.id, required this.name, required this.coachId,
    required this.aliases, required this.profile, required this.hasTrophyRecord,
    required this.unclassifiedCount, required this.honours});
  final String id, name;
  final String? coachId;
  final List<String> aliases;
  final CoachArchiveProfile profile;
  final bool hasTrophyRecord;
  final int? unclassifiedCount;
  final List<CoachHonour> honours;

  String get coverageLabel => !hasTrophyRecord ? 'Kupa verisi bulunmuyor'
      : honours.isEmpty ? 'Adlandırılmış başarı kaydı yok'
      : '${honours.length} başarı türü';
}

class CoachHonoursCatalog {
  CoachHonoursCatalog._(this.coaches, this.snapshotDate);
  final List<CoachHonoursRecord> coaches;
  final String? snapshotDate;

  CoachHonoursRecord? forCoach(String id) {
    for (final coach in coaches) {
      if (coach.coachId == id) return coach;
    }
    return null;
  }

  factory CoachHonoursCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) throw const FormatException('Unsupported coach archive');
    final definitions = <String, Map<String, dynamic>>{};
    for (final item in json['competitions'] as List<dynamic>) {
      final row = item as Map<String, dynamic>;
      final id = row['id'] as String;
      if (id == 'NONE' || definitions.containsKey(id) ||
          !coachHonourCategories.containsKey(row['category'])) {
        throw const FormatException('Invalid achievement definition');
      }
      definitions[id] = row;
    }
    final ids = <String>{}, coachIds = <String>{};
    final records = <CoachHonoursRecord>[];
    for (final item in json['coaches'] as List<dynamic>) {
      final row = item as Map<String, dynamic>;
      final id = row['id'] as String, coachId = row['coachId'] as String?;
      if (!ids.add(id) || (coachId != null && !coachIds.add(coachId))) {
        throw const FormatException('Duplicate coach archive identity');
      }
      final honours = <CoachHonour>[];
      final competitionIds = <String>{};
      for (final item in row['honours'] as List<dynamic>) {
        final honour = item as Map<String, dynamic>;
        final competitionId = honour['competitionId'] as String;
        final definition = definitions[competitionId];
        final count = honour['count'];
        if (definition == null || count is! int || count <= 0 || !competitionIds.add(competitionId)) {
          throw const FormatException('Invalid achievement count');
        }
        honours.add(CoachHonour(competitionId: competitionId,
          label: definition['label'] as String, category: definition['category'] as String, count: count));
      }
      final hasTrophyRecord = row['hasTrophyRecord'] as bool;
      final unclassified = row['unclassifiedCount'] as int?;
      if ((!hasTrophyRecord && (honours.isNotEmpty || unclassified != null)) ||
          (unclassified != null && unclassified < 0)) {
        throw const FormatException('Invalid achievement coverage');
      }
      records.add(CoachHonoursRecord._(id: id, name: row['name'] as String, coachId: coachId,
        aliases: List<String>.unmodifiable((row['aliases'] as List<dynamic>).cast<String>()),
        profile: CoachArchiveProfile(row['profile'] as Map<String, dynamic>),
        hasTrophyRecord: hasTrophyRecord, unclassifiedCount: unclassified,
        honours: List<CoachHonour>.unmodifiable(honours)));
    }
    return CoachHonoursCatalog._(List<CoachHonoursRecord>.unmodifiable(records),
      (json['source'] as Map<String, dynamic>)['snapshotDate'] as String?);
  }
}

const coachHonourCategories = {
  'senior': 'Üst düzey kupalar',
  'lowerTier': 'Alt lig başarıları',
  'youth': 'Genç takım başarıları',
  'individual': 'Bireysel ödüller',
  'medal': 'Madalyalar',
};
