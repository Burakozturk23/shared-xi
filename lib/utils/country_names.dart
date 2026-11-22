/// Ülke adlarını İngilizce kanonik forma çevirir.
/// UI ve eşleştirmede tek isim kullanılsın (Turkey, not Türkiye).
class CountryNames {
  CountryNames._();

  /// local (lower) → display canonical
  static const Map<String, String> _aliases = {
    'türkiye': 'Turkey',
    'turkiye': 'Turkey',
    'turkey': 'Turkey',
    // sık görülen diğer varyantlar
    'czechia': 'Czech Republic',
    'czech republic': 'Czech Republic',
    'united states': 'USA',
    'united states of america': 'USA',
    'usa': 'USA',
    'korea republic': 'South Korea',
    'korea, south': 'South Korea',
    'south korea': 'South Korea',
    "cote d'ivoire": "Côte d'Ivoire",
    "côte d'ivoire": "Côte d'Ivoire",
    'ivory coast': "Côte d'Ivoire",
    'bosnia-herzegovina': 'Bosnia and Herzegovina',
    'bosnia and herzegovina': 'Bosnia and Herzegovina',
    'holland': 'Netherlands',
    'the netherlands': 'Netherlands',
  };

  static String _key(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i');
  }

  /// Gösterim / eşleştirme için tek isim.
  static String canonical(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    return _aliases[_key(t)] ?? t;
  }

  /// Every spelling that canonicalizes to [raw]'s canonical name, canonical
  /// first. Raw data stores e.g. "Türkiye", so SQL lookups must match all of
  /// them rather than the canonical display name alone.
  static List<String> variants(String raw) {
    final c = canonical(raw);
    if (c.isEmpty) return const <String>[];
    final out = <String>[c];
    final seen = <String>{c.toLowerCase()};
    _aliases.forEach((key, value) {
      if (value == c && seen.add(key)) out.add(key);
    });
    return out;
  }

  static List<String> canonicalList(Iterable<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final r in raw) {
      final c = canonical(r);
      if (c.isEmpty) continue;
      if (seen.add(c)) out.add(c);
    }
    return out;
  }

  /// İki ülke adı aynı ülkeyi mi gösteriyor?
  static bool same(String a, String b) =>
      canonical(a).toLowerCase() == canonical(b).toLowerCase();
}
