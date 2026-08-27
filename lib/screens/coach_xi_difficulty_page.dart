import 'package:flutter/material.dart';

import 'coach_xi_play_page.dart';

/// Zorluk yok — moda tıklanınca direkt oyun.
/// Welcome'daki page: CoachXiDifficultyPage() aynı kalabilir.
class CoachXiDifficultyPage extends StatelessWidget {
  const CoachXiDifficultyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Aninda play sayfasina yonlendir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CoachXiPlayPage()),
      );
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
