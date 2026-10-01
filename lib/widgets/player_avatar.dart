import 'package:flutter/material.dart';

import '../data/country_flags.dart';
import '../data/player_kit_identity.dart';
import '../data/player_portrait_catalog.dart';
import '../data/season_portrait_catalog.dart';
import '../models/player.dart';

/// Uses approved local portrait sets when a player is mapped and keeps the
/// symbolic offline kit identity as a deterministic fallback for every other player.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double size;

  const PlayerAvatar({super.key, required this.player, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final (accent, code, label) = PlayerKitIdentity.position(player.position);
    final detailed = size >= 64;
    final portraitAsset = PlayerPortraitCatalog.forPlayerId(player.id);
    final seasonPortrait = portraitAsset == null
        ? SeasonPortraitCatalog.forPlayerName(player.name)
        : null;
    return Semantics(
      image: true,
      label:
          '${player.name}, $label${player.countries.isEmpty ? '' : ', ${player.countryLabel}'}',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C2C35), Color(0xFF0C151D)],
            ),
            border: Border.all(color: accent.withValues(alpha: .45)),
          ),
          child: portraitAsset != null
              ? Image.asset(
                  portraitAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => _KitIdentity(
                    player: player,
                    size: size,
                    accent: accent,
                    code: code,
                    detailed: detailed,
                  ),
                )
              : seasonPortrait != null
              ? _SeasonPortrait(
                  spec: seasonPortrait,
                  size: size,
                  fallback: _KitIdentity(
                    player: player,
                    size: size,
                    accent: accent,
                    code: code,
                    detailed: detailed,
                  ),
                )
              : _KitIdentity(
                  player: player,
                  size: size,
                  accent: accent,
                  code: code,
                  detailed: detailed,
                ),
        ),
      ),
    );
  }
}

class _SeasonPortrait extends StatelessWidget {
  const _SeasonPortrait({
    required this.spec,
    required this.size,
    required this.fallback,
  });

  final SeasonPortraitSpec spec;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final sheetWidth = size * 7;
    final sheetHeight = size * 8;
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            left: -spec.column * size,
            top: -spec.row * size,
            width: sheetWidth,
            height: sheetHeight,
            child: Image.asset(
              spec.asset,
              width: sheetWidth,
              height: sheetHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => SizedBox(
                width: sheetWidth,
                height: sheetHeight,
                child: Align(
                  alignment: Alignment(
                    -1 + (2 * spec.column / 6),
                    -1 + (2 * spec.row / 7),
                  ),
                  child: SizedBox(width: size, height: size, child: fallback),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KitIdentity extends StatelessWidget {
  const _KitIdentity({
    required this.player,
    required this.size,
    required this.accent,
    required this.code,
    required this.detailed,
  });

  final Player player;
  final double size;
  final Color accent;
  final String code;
  final bool detailed;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: CustomPaint(painter: _KitPainter(accent, detailed))),
      Positioned(
        left: size * .24,
        right: size * .24,
        top: size * (detailed ? .32 : .37),
        height: size * .25,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            PlayerKitIdentity.initials(player.name),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: const Color(0xFFF4F8FC),
              fontSize: size * .23,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: .2,
            ),
          ),
        ),
      ),
      if (detailed) ...[
        Positioned(
          bottom: size * .045,
          left: 0,
          right: 0,
          child: Text(
            code,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: accent,
              fontSize: size * .13,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (player.countries.isNotEmpty)
          Positioned(
            right: size * .055,
            top: size * .045,
            child: Text(
              flagFor(player.countries.first),
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: size * .19, height: 1),
            ),
          ),
      ],
    ],
  );
}

class _KitPainter extends CustomPainter {
  final Color accent;
  final bool detailed;
  const _KitPainter(this.accent, this.detailed);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    if (detailed) {
      canvas.translate(0, -.035);
      canvas.scale(1, .94);
    }
    final shirt = Path()
      ..moveTo(.35, .20)
      ..lineTo(.22, .24)
      ..lineTo(.10, .43)
      ..lineTo(.25, .52)
      ..lineTo(.30, .44)
      ..lineTo(.30, .80)
      ..quadraticBezierTo(.50, .85, .70, .80)
      ..lineTo(.70, .44)
      ..lineTo(.75, .52)
      ..lineTo(.90, .43)
      ..lineTo(.78, .24)
      ..lineTo(.65, .20)
      ..quadraticBezierTo(.50, .31, .35, .20)
      ..close();
    canvas.drawPath(
      shirt,
      Paint()..color = Color.lerp(const Color(0xFF17242F), accent, .19)!,
    );
    canvas.save();
    canvas.clipPath(shirt);
    canvas.drawRect(
      const Rect.fromLTWH(.37, .20, .065, .66),
      Paint()..color = accent.withValues(alpha: .12),
    );
    canvas.drawRect(
      const Rect.fromLTWH(.565, .20, .065, .66),
      Paint()..color = accent.withValues(alpha: .12),
    );
    canvas.restore();
    canvas.drawPath(
      shirt,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = .019
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(.35, .20)
        ..quadraticBezierTo(.50, .40, .65, .20),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = .024,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KitPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.detailed != detailed;
}
