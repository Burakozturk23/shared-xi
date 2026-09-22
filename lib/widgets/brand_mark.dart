import 'package:flutter/material.dart';

import '../theme/ortak_saha_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.semanticLabel = 'Linkball'});
  final double size;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(light ? size * .12 : 0),
        decoration: light
            ? BoxDecoration(
                color: PitchColors.dark.background,
                borderRadius: BorderRadius.circular(size * .24),
              )
            : null,
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
