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
