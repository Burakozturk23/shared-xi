import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../theme/ortak_saha_theme.dart';

class PitchPanel extends StatelessWidget {
  const PitchPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class PitchSectionTitle extends StatelessWidget {
  const PitchSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class PitchRow extends StatelessWidget {
  const PitchRow({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.leading,
    this.highlight = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return PitchPanel(
      onTap: onTap,
      child: Row(
        children: [
          leading ?? Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: highlight ? p.tint : p.raised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: highlight ? p.accent : p.muted, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}

/// Feedback respects Reduce Motion; the actual button retains a 56 dp target.
class PitchAction extends StatefulWidget {
  const PitchAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.neutral = false,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, neutral, busy;
  final IconData icon;
  @override
  State<PitchAction> createState() => _PitchActionState();
}

class _PitchActionState extends State<PitchAction> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final child = Row(
      children: [
        Expanded(child: Text(widget.label)),
        const SizedBox(width: 12),
        widget.busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.icon, size: 24),
      ],
    );
    void tap() {
      AppFeedback.selection();
      widget.onPressed?.call();
    }

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerCancel: (_) => setState(() => _pressed = false),
      onPointerUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: !reduced && _pressed && widget.onPressed != null ? .98 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 110),
        child: widget.secondary
            ? OutlinedButton(
                style: widget.neutral
                    ? OutlinedButton.styleFrom(
                        foregroundColor: PitchColors.of(context).text,
                        side: BorderSide(color: PitchColors.of(context).border),
                      )
                    : null,
                onPressed: widget.busy || widget.onPressed == null ? null : tap,
                child: child,
              )
            : FilledButton(
                onPressed: widget.busy || widget.onPressed == null ? null : tap,
                child: child,
              ),
      ),
    );
  }
}

class PitchField extends StatelessWidget {
  const PitchField({super.key, required this.child, this.height = 136});
  final Widget child;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _FieldPainter(PitchColors.of(context).border),
      child: child,
    ),
  );
}

class _FieldPainter extends CustomPainter {
  const _FieldPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      p,
    );
    canvas.drawLine(
      Offset(size.width / 2, 1),
      Offset(size.width / 2, size.height - 1),
      p,
    );
    canvas.drawCircle(size.center(Offset.zero), size.height * .24, p);
    canvas.drawRect(
      Rect.fromLTWH(1, size.height * .28, size.width * .13, size.height * .44),
      p,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .87,
        size.height * .28,
        size.width * .13 - 1,
        size.height * .44,
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) =>
      oldDelegate.color != color;
}
