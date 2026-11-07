import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.semanticLabel = 'Linkball'});
  final double size;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    // The mark is a self-contained dark tile, so it reads on both themes.
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          'assets/brand/ortak_saha_mark.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: size, semanticLabel: null),
        const SizedBox(width: 12),
        Text(
          'LINKBALL',
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w800,
            fontSize: size * .57,
            letterSpacing: .6,
            color: PitchColors.of(context).text,
          ),
        ),
      ],
    ),
  );
}
