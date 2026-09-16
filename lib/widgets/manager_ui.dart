import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

String managerError(Object error) => error is StateError
    ? error.message.toString()
    : 'İşlem tamamlanamadı. Yeniden deneyebilirsin.';

class ManagerMessage extends StatelessWidget {
  const ManagerMessage({
    super.key,
    required this.title,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final String title, message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 24),
      Icon(
        Icons.sports_soccer_rounded,
        size: 48,
        color: PitchColors.of(context).accent,
      ),
      const SizedBox(height: 20),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(message),
      const SizedBox(height: 24),
      if (loading) const LinearProgressIndicator(),
      if (onRetry != null)
        PitchAction(label: 'Yeniden dene', onPressed: onRetry),
    ],
  );
}

class ManagerMetrics extends StatelessWidget {
  const ManagerMetrics({super.key, required this.values});
  final List<({String label, String value})> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = (box.maxWidth / (112 * scale)).floor().clamp(
        1,
        values.length,
      );
      final width = (box.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: PitchPanel(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value.value,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: PitchColors.of(context).accent),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class ManagerTag extends StatelessWidget {
  const ManagerTag(this.text, {super.key, this.active = false});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? p.tint : p.raised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: active ? p.accent : p.muted),
      ),
    );
  }
}
