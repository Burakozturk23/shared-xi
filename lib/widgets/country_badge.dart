import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/country_codes.dart';
import '../data/country_flags.dart';

/// Ülke bayrağı: flagcdn (cache) → emoji yedek.
class CountryBadge extends StatelessWidget {
  final String country;
  final double width;
  final double height;
  final bool showLabel;

  const CountryBadge({
    super.key,
    required this.country,
    this.width = 32,
    this.height = 22,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = countryFlagUrl(
      country,
      width: (width * 3).round().clamp(48, 160),
    );

    final flag = url != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              memCacheWidth: (width * 3).round().clamp(48, 320),
              fadeInDuration: const Duration(milliseconds: 120),
              // A usable flag is visible immediately, including offline use.
              placeholder: (_, _) => _emojiFallback(),
              errorWidget: (_, _, _) => _emojiFallback(),
            ),
          )
        : _emojiFallback();

    if (!showLabel) return flag;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        flag,
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            country,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _emojiFallback() {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Text(
          flagFor(country),
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: height * 0.9),
        ),
      ),
    );
  }
}
