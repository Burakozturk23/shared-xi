import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/league_logos.dart';
import '../theme/app_theme.dart';

/// Lig logosu — asset varsa gösterir.
class LeagueBadge extends StatelessWidget {
  final String league;
  final double size;
  final bool showLabel;

  const LeagueBadge({
    super.key,
    required this.league,
    this.size = 28,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = leagueLogoAsset(league);

    final Widget logo;
    if (asset == null) {
      logo = _fallback();
    } else {
      logo = Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, error, _) {
          // Debug: asset yolu yanlış veya pubspec'te yok
          debugPrint('LeagueBadge asset fail: $asset for "$league" -> $error');
          return _fallback();
        },
      );
    }

    if (!showLabel) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            leagueShortName(league),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        size: size * 0.55,
        color: AppTheme.primaryColor,
      ),
    );
  }
}

/// Uygulama açılışında bir kez çağır: asset gerçekten paketlenmiş mi?
Future<void> debugLeagueAssets() async {
  final samples = [
    'assets/logos/leagues/premier_league.png',
    'assets/logos/leagues/ligue_1.png',
    'assets/logos/leagues/super_lig.png',
  ];
  for (final path in samples) {
    try {
      await rootBundle.load(path);
      debugPrint('ASSET OK: $path');
    } catch (e) {
      debugPrint('ASSET MISSING: $path ($e)');
    }
  }
}