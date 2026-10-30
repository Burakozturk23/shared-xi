import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/screens/chain_mode_selection_page.dart';
import 'package:shared_xi/screens/grid_mode_selection_page.dart';
import 'package:shared_xi/screens/odd_club_mode_selection_page.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

import 'support/qa_capture.dart';

final _boundary = GlobalKey();

void main() {
  setUpAll(loadQaFonts);
  // The grid page's club-pool picker reads its saved choice from prefs.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final pages = <(String, Widget, List<String>, List<String>)>[
    (
      'chain',
      const ChainModeSelectionPage(),
      ['Zincir Ustalığı', 'Zincir Sprinti'],
      ['Süre yok', 'En az hamle', 'PAR hedefi', 'En fazla 180 sn'],
    ),
    (
      'odd-club',
      const OddClubModeSelectionPage(),
      ['Sonsuz Seri', 'Hız Serisi'],
      ['Süresiz', '1 ücretsiz 50/50', 'kalıcı rekor', 'yardımsız'],
    ),
    (
      'grid',
      const GridModeSelectionPage(),
      ['Klasik', 'Tersten', 'Rastgele Eşleşme'],
      ['Kriterlere uyan doğru oyuncuyu bul'],
    ),
  ];
  for (final light in [false, true]) {
    for (final (name, page, titles, specs) in pages) {
      testWidgets('$name styles are mode cards with spec lines '
          'light=$light', (t) async {
        t.view.physicalSize = const Size(390, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
            home: RepaintBoundary(key: _boundary, child: page),
          ),
        );
        await t.pumpAndSettle();
        await captureQa(t, _boundary, 'mode-$name-${light ? 'light' : 'dark'}');
        expect(find.byType(ModeStyleCard), findsNWidgets(titles.length));
        for (final title in titles) {
          expect(
            find.descendant(
              of: find.byType(ModeStyleCard),
              matching: find.text(title),
            ),
            findsOneWidget,
            reason: title,
          );
        }
        // Each " · " rule of the old subtitle is its own checklist line.
        for (final spec in specs) {
          expect(find.text(spec), findsOneWidget, reason: spec);
        }
        expect(t.takeException(), isNull);
      });
    }
  }
}
