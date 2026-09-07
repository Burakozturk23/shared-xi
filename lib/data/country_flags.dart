import 'country_codes.dart';

String _regionalIndicatorFlag(String iso) {
  if (iso.length != 2) return '🏳️';

  final upper = iso.toUpperCase();
  final a = upper.codeUnitAt(0);
  final b = upper.codeUnitAt(1);

  if (a < 65 || a > 90 || b < 65 || b > 90) return '🏳️';

  return String.fromCharCodes([0x1F1E6 + (a - 65), 0x1F1E6 + (b - 65)]);
}

String _subdivisionFlag(String code) {
  if (code == 'gb-eng') {
    return String.fromCharCodes([
      0x1F3F4,
      0xE0067,
      0xE0062,
      0xE0065,
      0xE006E,
      0xE0067,
      0xE007F,
    ]);
  }

  if (code == 'gb-sct') {
    return String.fromCharCodes([
      0x1F3F4,
      0xE0067,
      0xE0062,
      0xE0073,
      0xE0063,
      0xE0074,
      0xE007F,
    ]);
  }

  if (code == 'gb-wls') {
    return String.fromCharCodes([
      0x1F3F4,
      0xE0067,
      0xE0062,
      0xE0077,
      0xE006C,
      0xE0073,
      0xE007F,
    ]);
  }

  if (code == 'gb-nir') {
    // Unicode has no RGI Northern Ireland flag emoji.
    // Use the UK flag instead of a meaningless white flag.
    return _regionalIndicatorFlag('gb');
  }

  return '🏳️';
}

/// Country flag fallback derived from the same ISO map used by flagcdn.
///
/// This removes the old duplicated/incomplete emoji table: any country that
/// has an ISO mapping now also has an offline emoji fallback.
String flagFor(String country) {
  final iso = countryIso(country);
  if (iso == null || iso.isEmpty) return '🏳️';

  if (iso.contains('-')) {
    return _subdivisionFlag(iso);
  }

  if (iso == 'xk') {
    // Kosovo is commonly rendered by modern Android fonts even though XK is
    // user-assigned rather than ISO-3166 official.
    return _regionalIndicatorFlag('xk');
  }

  return _regionalIndicatorFlag(iso);
}
