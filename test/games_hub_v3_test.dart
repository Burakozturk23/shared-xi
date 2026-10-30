import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/theme/app_theme.dart';

import 'support/qa_capture.dart';

final _boundary = GlobalKey();

void main() {
  setUpAll(loadQaFonts);
  for (final light in [false, true]) {
    testWidgets('games hub previews bot modes and category contents '
        'light=$light', (t) async {
      t.view.physicalSize = const Size(390, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
          home: RepaintBoundary(
            key: _boundary,
            child: const Scaffold(body: GamesCatalogPage()),
          ),
        ),
      );
      await t.pumpAndSettle();
      await captureQa(t, _boundary, 'games-hub-${light ? 'light' : 'dark'}');

      // The bot hero lists its five sub-modes and has a full-width CTA.
      for (final mode in ['Loto', 'Takım Yarışı', 'Grid', 'Çinko', 'Beşler']) {
        expect(find.text(mode), findsOneWidget, reason: mode);
      }
      expect(find.text('Bota karşı oyna'), findsOneWidget);
      expect(find.text('Botla oyna'), findsOneWidget);

      // Each category names its featured mode and how many more it holds.
      for (final preview in [
        'Club Manager · +4',
        'Transfer Detective · +4',
        'UCL Moments · +7',
        'Futbol Lingo · +2',
        'Burst · +3',
        'O mu Bu mu? · +2',
      ]) {
        await t.scrollUntilVisible(
          find.text(preview),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(preview), findsOneWidget, reason: preview);
      }
      // Catalog header and story closing the list, full width.
      expect(find.text('Katalog & Modlar'), findsOneWidget);
      expect(find.text('6 KATEGORİ'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('Hikâye Modu')).dy,
        greaterThan(t.getTopLeft(find.text('Seçim & Sıralama').last).dy),
      );
      expect(t.takeException(), isNull);
    });
  }
}
