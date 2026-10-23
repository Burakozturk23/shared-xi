import 'package:flutter/material.dart';
import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

/// Shared spacing and readable width for setup, play, and result screens.
class GameContent extends StatelessWidget {
  const GameContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640), child: child,
    )),
  );
}

class GameIntro extends StatelessWidget {
  const GameIntro({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    return PitchPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: colors.accent, size: 24),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted)),
      ],
    ));
  }
}

/// Scrolls with the game instead of squeezing the board below a long error.
class GameErrorPanel extends StatelessWidget {
  const GameErrorPanel({super.key, required this.message, this.onRetry, this.accountChanged = false});
  final String message;
  final VoidCallback? onRetry;
  final bool accountChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Semantics(liveRegion: true, child: PitchPanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: Icon(Icons.cloud_off_rounded,
          color: PitchColors.of(context).muted, size: 32)),
        const SizedBox(height: 12),
        Text(accountChanged ? 'Hesap değişti' : 'Oyunla bağlantı kurulamadı',
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8), Text(message), const SizedBox(height: 16),
        PitchAction(label: accountChanged ? 'Geri dön' : 'Tekrar dene',
          icon: accountChanged ? Icons.arrow_back_rounded : Icons.refresh_rounded,
          onPressed: accountChanged ? () => Navigator.of(context).maybePop() : onRetry),
      ],
    ))),
  );
}

class GameStats extends StatelessWidget {
  const GameStats({super.key, required this.items});
  final List<(IconData, String)> items;
  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Wrap(
      spacing: 8, runSpacing: 8, children: [for (final item in items)
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(item.$1, size: 18, color: colors.accent), const SizedBox(width: 8),
            Flexible(child: Text(item.$2, style: Theme.of(context).textTheme.labelLarge)),
          ])),
      ],
    ));
  }
}
