/// Historical records deliberately have a separate identity from live players.
class HistoryRecord {
  HistoryRecord(Map<String, Object?> values) : values = Map.unmodifiable(values);
  final Map<String, Object?> values;
  String text(String key) => values[key]?.toString() ?? '';
  int number(String key) => (values[key] as num?)?.toInt() ?? 0;
  bool has(String key) => values[key] != null;
  String get id => text('id');
  String get score => '${number('home_score')}–${number('away_score')}';
  String get title => has('home') ? '${text('home')} • ${text('away')}' : text('team');
  bool get conflicted => number('conflict') == 1;
}

class HistoryDetail {
  const HistoryDetail({required this.record, this.goals = const [], this.players = const [], this.sources = const []});
  final HistoryRecord record;
  final List<HistoryRecord> goals;
  final List<HistoryRecord> players;
  final List<HistoryRecord> sources;
}

enum HistoryScope { all, championsLeague, international }
