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
    final url = countryFlagUrl(country, width: (width * 3).round().clamp(48, 160));

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
              placeholder: (_, _) => SizedBox(
                width: width,
                height: height,
                child: Center(
                  child: SizedBox(
                    width: width * 0.35,
                    height: width * 0.35,
                    child: const CircularProgressIndicator(strokeWidth: 1.2),
                  ),
                ),
              ),
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
    return Text(
      flagFor(country),
      style: TextStyle(fontSize: height * 0.9),
    );
  }
}