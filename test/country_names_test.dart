import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/utils/country_names.dart';

void main() {
  test('variants covers raw spellings stored in the data', () {
    // The V4 data stores most Turkish players as "Türkiye"; a lookup by the
    // canonical "Turkey" alone returned 0 for Barcelona × Turkey.
    final turkey = CountryNames.variants('Turkey');
    expect(turkey.first, 'Turkey');
    expect(turkey, containsAll(<String>['türkiye', 'turkiye']));
    expect(CountryNames.variants('Türkiye'), turkey);
  });

  test('variants of an unaliased country is just the name', () {
    expect(CountryNames.variants('Spain'), <String>['Spain']);
    expect(CountryNames.variants('  '), isEmpty);
  });
}
