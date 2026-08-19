import 'daily_challenge_service.dart';

class DailyShareHelper {
  DailyShareHelper._();

  static String buildText({
    required String label,
    required int score,
    required int target,
    required double successRate,
    required int streak,
    String? themeBadge,
    int? rank,
    int? totalPlayers,
    String? dateKey,
  }) {
    final pct = (successRate * 100).round();
    final buf = StringBuffer();
    buf.writeln('⚽ Shared XI — Günün Mücadelesi');
    if (themeBadge != null && themeBadge.isNotEmpty) {
      buf.writeln('[$themeBadge]');
    }
    if (dateKey != null) buf.writeln(dateKey);
    buf.writeln(label);
    buf.writeln('✅ $score${target > 0 ? '/$target' : ''} doğru · %$pct başarı');
    if (streak > 0) buf.writeln('🔥 $streak günlük seri');
    if (rank != null) {
      if (totalPlayers != null) {
        buf.writeln('🌍 Sıra: #$rank / $totalPlayers');
      } else {
        buf.writeln('🌍 Sıra: #$rank');
      }
    }
    buf.writeln('Sen kaç yapabilirsin?');
    return buf.toString().trim();
  }

  /// Eski API uyumu
  static String fromLegacy({
    required String label,
    required int score,
    required double successRate,
    required int streak,
  }) =>
      buildText(
        label: label,
        score: score,
        target: 0,
        successRate: successRate,
        streak: streak,
      );
}
