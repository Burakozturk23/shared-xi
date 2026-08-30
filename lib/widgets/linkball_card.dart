import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';

/// Shared card shell for player, club and game cards.
/// Centralizes border, selection, disabled state and interaction feedback.
class LinkballCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool disabled;
  final EdgeInsetsGeometry padding;
  final double radius;

  const LinkballCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.disabled = false,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadii.lg,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppTheme.primaryColor : AppTheme.borderColor;
    final background = selected
        ? AppTheme.primaryColor.withValues(alpha: 0.10)
        : AppTheme.cardColor;

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: disabled ? 0.48 : 1,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AppShadows.soft : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
