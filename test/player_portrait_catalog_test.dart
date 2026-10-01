import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/player_portrait_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('approved portrait catalog has 50 unique stable mappings', () {
    expect(PlayerPortraitCatalog.byPlayerId.length, 50);
    expect(PlayerPortraitCatalog.byPlayerId.values.toSet().length, 50);
    expect(
      PlayerPortraitCatalog.byPlayerId.values,
      everyElement(startsWith('assets/player_portraits/legend_')),
    );
    expect(PlayerPortraitCatalog.forAvatarId('persona_emre_ozcan'), isNull);
  });

  test('all approved portrait assets are bundled and readable', () async {
    for (final asset in PlayerPortraitCatalog.byPlayerId.values) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
