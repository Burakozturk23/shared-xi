import 'package:flutter/material.dart';

import '../app/route_appearance.dart';
import '../screens/sign_in_page.dart';
import 'pitch_ui.dart';

/// Shared, theme-aware vocabulary for the social and support screens.
class SocialHero extends StatelessWidget {
  const SocialHero({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    this.footer,
  });
  final IconData icon;
  final String eyebrow, title, message;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary.withValues(alpha: .12), colors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  eyebrow,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 18), footer!],
        ],
      ),
    );
  }
}

class SocialStatus extends StatelessWidget {
  const SocialStatus(this.label, {super.key, this.complete = false});
  final String label;
  final bool complete;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = complete ? colors.onSurfaceVariant : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class SocialNotice extends StatelessWidget {
  const SocialNotice({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
  });
  final String title, message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => PitchPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel ?? 'Tekrar dene'),
          ),
        ],
      ],
    ),
  );
}

class SocialAccountGate extends StatelessWidget {
  const SocialAccountGate({super.key, required this.onReturn});
  final VoidCallback onReturn;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SocialHero(
        icon: Icons.groups_outlined,
        eyebrow: 'BİRLİKTE OYNA',
        title: 'Profilini bağla,\narkadaşlarına katıl.',
        message:
            'Arkadaşların, davetlerin ve güvenlik tercihlerin Google hesabına bağlı Linkball profilinde tutulur.',
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        icon: const Icon(Icons.login_rounded),
        label: const Text('Google hesabını bağla'),
        onPressed: () async {
          await Navigator.of(context).push(
            LinkballRoute<void>(
              modern: false,
              builder: (_) => const LinkballSignInPage(allowSkip: false),
            ),
          );
          if (context.mounted) onReturn();
        },
      ),
    ],
  );
}

String socialDate(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return 'Tarih bilgisi yok';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
}
