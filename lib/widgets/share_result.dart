import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/daily_footballer.dart';
import '../models/manager_rating.dart';
import '../models/manager_season.dart';

/// Opens the system share sheet. Tests swap it to observe the text.
Future<void> Function(String text) shareResultText = (text) async {
  await SharePlus.instance.share(ShareParams(text: text));
};

/// Günün Futbolcusu without the answer: one row per guess, one cell per
/// compared trait (🟩 same, ⬛ different, ⬆️/⬇️ the target is higher/lower).
String dailyFootballerShare(DailyFootballerRound round) {
  String cell(FootballerMatch match) => switch (match) {
    FootballerMatch.same => '🟩',
    FootballerMatch.different => '⬛',
    FootballerMatch.higher => '⬆️',
    FootballerMatch.lower => '⬇️',
  };
  final rows = [
    for (final guess in round.guesses)
      round.compare(guess).map((c) => cell(c.match)).join(),
  ];
  final date = round.dayKey.split('-').reversed.join('.');
  final score = round.won
      ? '${round.guesses.length}/${round.limit}'
      : 'X/${round.limit}';
  return 'Linkball · Günün Futbolcusu\n$date · $score\n${rows.join('\n')}'
      '${round.assisted ? '\n🧩 Yardımlı' : ''}';
}

/// Günün Sorusu without the question or the options.
String dailyQuestionShare(Map<String, dynamic> data) {
  final question = Map<String, dynamic>.from(data['question'] as Map? ?? {});
  final result = Map<String, dynamic>.from(data['result'] as Map? ?? {});
  final correct = result['correct'] == true;
  final streak = (data['streak'] as num? ?? 0).toInt();
  return 'Linkball · Günün Sorusu\n${question['day'] ?? ''}\n'
      '${correct ? '✅ Doğru' : '❌ Yanlış'}${streak > 0 ? ' · $streak günlük seri' : ''}'
      '${result['assisted'] == true ? '\n🧩 Yardımlı' : ''}';
}

/// "Paylaş" opens the share sheet; "Kopyala" keeps the old clipboard path.
/// Club Manager season card: place, points, record and the board target.
String managerSeasonShare({
  required ManagerSeason season,
  required int seasonNumber,
  required ManagerDifficulty difficulty,
}) {
  final u = season.user;
  final rank = season.userRank();
  return [
    'Linkball · Club Manager',
    'Sezon $seasonNumber · ${difficulty.label}',
    '${rank == 1 ? '🏆 Şampiyon' : '$rank. sıra'} · ${u.points} puan',
    '${u.won}G ${u.drawn}B ${u.lost}M · ${u.gf}:${u.ga}',
    'Hedef ilk ${difficulty.boardTargetRank} ${rank <= difficulty.boardTargetRank ? '✅' : '❌'}',
  ].join('\n');
}

class ShareResultButtons extends StatelessWidget {
  const ShareResultButtons({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton.icon(
        onPressed: () => shareResultText(text),
        icon: const Icon(Icons.ios_share_rounded),
        label: const Text('Paylaş'),
      ),
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cevapsız paylaşım özeti kopyalandı.'),
              ),
            );
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Kopyala'),
      ),
    ],
  );
}
