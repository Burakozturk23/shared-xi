import 'package:flutter/material.dart';
import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

/// Shared story surfaces use the same palette in both app themes.
class StoryArchiveHero extends StatelessWidget {
  const StoryArchiveHero({super.key, required this.eyebrow, required this.title,
    required this.description, required this.icon, this.footer});
  final String eyebrow, title, description;
  final IconData icon;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context), text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: p.accent, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text(eyebrow, style: text.labelMedium?.copyWith(color: p.accent))),
        ]),
        const SizedBox(height: 18),
        Text(title, style: text.headlineMedium),
        const SizedBox(height: 8),
        Text(description, style: text.bodyMedium?.copyWith(color: p.muted)),
        if (footer != null) ...[const SizedBox(height: 20), footer!],
      ]),
    );
  }
}

class StoryArchiveProgress extends StatelessWidget {
  const StoryArchiveProgress({super.key, required this.completed, required this.total, required this.label});
  final int completed, total;
  final String label;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$completed / $total $label', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        value: total == 0 ? 0 : (completed / total).clamp(0.0, 1.0),
        minHeight: 6, borderRadius: BorderRadius.circular(8),
        color: p.accent, backgroundColor: p.raised,
        semanticsLabel: label, semanticsValue: '$completed / $total',
      ),
    ]);
  }
}

/// Informational counters are deliberately distinct from selectable filters.
class StoryArchiveStats extends StatelessWidget {
  const StoryArchiveStats({super.key, required this.items});
  final List<(IconData, String)> items;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (icon, label) in items) Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: p.accent), const SizedBox(width: 8),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: p.text))),
        ]),
      ),
    ]);
  }
}

class StoryArchiveRewards extends StatelessWidget {
  const StoryArchiveRewards({super.key, required this.storageId, required this.summary, required this.children});
  final String storageId, summary;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return PitchPanel(padding: EdgeInsets.zero, child: ExpansionTile(
      key: PageStorageKey(storageId),
      leading: Icon(Icons.toll_outlined, color: p.limeInk),
      title: Text(summary, style: Theme.of(context).textTheme.titleSmall),
      subtitle: const Text('Ödüller ve koleksiyon bonusları'),
      iconColor: p.accent, collapsedIconColor: p.muted,
      shape: const Border(), collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ));
  }
}
